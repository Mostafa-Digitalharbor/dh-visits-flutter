import psycopg2

from odoo import api, fields, models
from odoo.exceptions import AccessError, UserError, ValidationError

from .geo import CLOCK_TOLERANCE, FUTURE_TOLERANCE, SOURCES, check_position, format_utc, parse_utc, to_float

MAX_POINTS_PER_CALL = 500


class DhWorkLocation(models.Model):
    """One GPS fix of a work day. Append-only: once stored it is never
    edited, and only a system administrator can delete it (retention)."""

    _name = "dh.work.location"
    _description = "Work Day GPS Point"
    _order = "logged_at asc, id asc"
    _rec_name = "logged_at"

    session_id = fields.Many2one("dh.work.session", required=True, readonly=True, index=True, ondelete="cascade")
    employee_id = fields.Many2one(related="session_id.employee_id", store=True, index=True)
    user_id = fields.Many2one(related="session_id.user_id", store=True)
    company_id = fields.Many2one(related="session_id.company_id", store=True, index=True)
    visit_id = fields.Many2one("dh.visit", readonly=True, index="btree_not_null", ondelete="set null")
    logged_at = fields.Datetime(required=True, readonly=True, help="Time of the fix on the device, in server time.")
    latitude = fields.Float(digits=(10, 7), required=True, readonly=True)
    longitude = fields.Float(digits=(10, 7), required=True, readonly=True)
    accuracy = fields.Float(readonly=True, help="Metres")
    altitude = fields.Float(readonly=True, help="Metres")
    speed = fields.Float(readonly=True, help="m/s")
    heading = fields.Float(readonly=True, help="Degrees clockwise from true north")
    device_id = fields.Char(readonly=True)
    client_uid = fields.Char(string="Client UID", readonly=True, copy=False)
    source = fields.Selection(
        [("start", "Work day start"), ("track", "Track"), ("end", "Work day end")],
        required=True,
        readonly=True,
        default="track",
    )

    _client_uid_per_session = models.UniqueIndex(
        "(session_id, client_uid) WHERE client_uid IS NOT NULL",
        "This GPS point was already uploaded.",
    )
    _session_time_idx = models.Index("(session_id, logged_at, id)")
    _latitude_range = models.Constraint("CHECK (latitude BETWEEN -90 AND 90)", "Latitude is out of range.")
    _longitude_range = models.Constraint("CHECK (longitude BETWEEN -180 AND 180)", "Longitude is out of range.")
    _accuracy_positive = models.Constraint("CHECK (accuracy >= 0)", "Accuracy cannot be negative.")

    # ------------------------------------------------------------------
    # ORM guards
    # ------------------------------------------------------------------

    @api.model_create_multi
    def create(self, vals_list):
        sessions = self.env["dh.work.session"].browse({v.get("session_id") for v in vals_list if v.get("session_id")})
        for session in sessions:
            session._lock_for_points()
        for vals in vals_list:
            session = sessions.filtered(lambda s: s.id == vals.get("session_id"))
            if not session:
                raise ValidationError(self.env._("A GPS point needs its work day."))
            self._validate_point(session, vals)
        return super().create(vals_list)

    def write(self, vals):
        raise UserError(self.env._("GPS points cannot be changed once recorded."))

    def unlink(self):
        if not self.env.su and not self.env.user.has_group("base.group_system"):
            raise UserError(self.env._("GPS points cannot be deleted."))
        return super().unlink()

    @api.model
    def _validate_point(self, session, vals):
        """Normalises `vals` in place, raising ValidationError/AccessError."""
        env = self.env
        if not env.su and session.sudo().employee_id.user_id != env.user:
            raise AccessError(env._("You can only record positions into your own work day."))
        latitude = to_float(env, vals.get("latitude"), env._("Latitude"), required=True)
        longitude = to_float(env, vals.get("longitude"), env._("Longitude"), required=True)
        check_position(env, latitude, longitude)
        vals["latitude"], vals["longitude"] = latitude, longitude

        logged_at = parse_utc(env, vals.get("logged_at"), env._("The position timestamp"))
        if logged_at is None:
            raise ValidationError(env._("The position timestamp is required."))
        now = fields.Datetime.now()
        if logged_at > now + FUTURE_TOLERANCE:
            raise ValidationError(env._("A position cannot be dated in the future."))
        if logged_at < session.started_at - CLOCK_TOLERANCE:
            raise ValidationError(
                env._(
                    "A position cannot predate the start of the work day (%(start)s).",
                    start=format_utc(session.started_at),
                )
            )
        vals["logged_at"] = logged_at

        for key, low, high in (("accuracy", 0, None), ("speed", 0, None), ("heading", 0, 360), ("altitude", None, None)):
            value = to_float(env, vals.get(key), key)
            if value is None:
                vals[key] = 0.0
                continue
            if (low is not None and value < low) or (high is not None and value > high):
                raise ValidationError(env._("%(field)s %(value)s is out of range.", field=key, value=value))
            vals[key] = value

        source = vals.get("source") or "track"
        if source not in SOURCES:
            raise ValidationError(env._("Unknown position source %(value)s.", value=source))
        vals["source"] = source

        visit_id = vals.get("visit_id")
        if visit_id:
            visit = env["dh.visit"].browse(int(visit_id)).exists()
            if not visit:
                raise ValidationError(env._("Visit %(id)s does not exist.", id=visit_id))
            # The visit must be one the employee is allowed to see.
            visit.check_access("read")
            vals["visit_id"] = visit.id
        else:
            vals["visit_id"] = False
        for key, size in (("client_uid", 96), ("device_id", 128)):
            if vals.get(key):
                vals[key] = str(vals[key]).strip()[:size]
        return vals

    # ------------------------------------------------------------------
    # Batch upload used by /api/workday/log_locations
    # ------------------------------------------------------------------

    @api.model
    def log_points(self, session, raw_points):
        """Stores what it can of `raw_points` into `session`.

        Each point is judged on its own: an invalid one is reported in
        `rejected` (with its index in the request) and never costs the rest.
        A point whose `client_uid` is already stored is reported in
        `duplicates` and not stored again, so re-sending a batch whose
        response was lost is harmless."""
        session.ensure_one()
        if not isinstance(raw_points, list):
            raise ValidationError(self.env._("points must be a list."))
        if len(raw_points) > MAX_POINTS_PER_CALL:
            raise ValidationError(
                self.env._("At most %(max)s points can be sent at once.", max=MAX_POINTS_PER_CALL)
            )
        session._lock_for_points()

        uids = [p.get("client_uid") for p in raw_points if isinstance(p, dict) and p.get("client_uid")]
        stored = set()
        if uids:
            stored = set(
                self.sudo()
                .search([("session_id", "=", session.id), ("client_uid", "in", [str(u)[:96] for u in uids])])
                .mapped("client_uid")
            )
        rejected, duplicates, valid, seen = [], [], [], set()
        for index, raw in enumerate(raw_points):
            if not isinstance(raw, dict):
                rejected.append({"index": index, "error": self.env._("A point must be an object.")})
                continue
            vals = {
                key: raw.get(key)
                for key in (
                    "latitude", "longitude", "logged_at", "accuracy", "altitude", "speed",
                    "heading", "visit_id", "device_id", "client_uid", "source",
                )
            }
            vals["session_id"] = session.id
            try:
                self._validate_point(session, vals)
            except (ValidationError, UserError, AccessError) as error:
                rejected.append({"index": index, "error": str(error.args[0])})
                continue
            uid = vals.get("client_uid")
            if uid and (uid in stored or uid in seen):
                duplicates.append(index)
                continue
            if uid:
                seen.add(uid)
            valid.append((index, vals))

        created = 0
        if valid:
            try:
                with self.env.cr.savepoint():
                    self.create([vals for _index, vals in valid])
                created = len(valid)
            except psycopg2.IntegrityError:
                # Raced with an identical upload: find out point by point.
                for index, vals in valid:
                    try:
                        with self.env.cr.savepoint():
                            self.create([vals])
                        created += 1
                    except psycopg2.errors.UniqueViolation:
                        duplicates.append(index)
                    except psycopg2.IntegrityError as error:
                        rejected.append({"index": index, "error": str(error).splitlines()[0]})
        session.invalidate_recordset(["location_count", "tracked_distance_km"])
        return {
            "session_id": session.id,
            "created": created,
            "duplicates": sorted(duplicates),
            "rejected": sorted(rejected, key=lambda r: r["index"]),
            "location_count": session.location_count,
            "tracked_distance_km": session.tracked_distance_km,
        }

    def _api_dict(self):
        self.ensure_one()
        return {
            "id": self.id,
            "session_id": self.session_id.id,
            "visit_id": self.visit_id.id or False,
            "visit_name": self.visit_id.sudo().display_name if self.visit_id else False,
            "logged_at": format_utc(self.logged_at),
            "latitude": self.latitude,
            "longitude": self.longitude,
            "accuracy": self.accuracy,
            "altitude": self.altitude,
            "speed": self.speed,
            "heading": self.heading,
            "device_id": self.device_id or False,
            "client_uid": self.client_uid or False,
            "source": self.source,
        }
