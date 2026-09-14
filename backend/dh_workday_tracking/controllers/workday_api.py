"""/api/workday/* — the whole-workday route for the Visits mobile app.

Same conventions as /api/visit/*: POST, Odoo JSON-RPC 2.0, `auth='user'`
(session cookie), naive UTC datetimes (send `YYYY-MM-DD HH:MM:SS`, receive
`YYYY-MM-DDTHH:MM:SS`), `false` for empty values, and refusals as
UserError / ValidationError / AccessError in the JSON-RPC `error` block.

Nothing here uses sudo to read or write work days: record rules decide what
the caller sees, and the model methods enforce ownership and the rules of a
work day. See docs/WORKDAY_TRACKING.md in the mobile repository.
"""

from odoo import http
from odoo.exceptions import UserError, ValidationError
from odoo.http import request

from ..models.geo import parse_utc


class WorkdayApiController(http.Controller):

    def _session(self, session_id=None, client_uid=None):
        Session = request.env["dh.work.session"]
        if session_id:
            try:
                domain = [("id", "=", int(session_id))]
            except (TypeError, ValueError):
                raise ValidationError(request.env._("session_id must be a number.")) from None
        elif client_uid:
            domain = [
                ("client_uid", "=", str(client_uid)[:64]),
                ("employee_id", "=", Session._current_employee().id),
            ]
        else:
            raise ValidationError(request.env._("session_id or client_uid is required."))
        # search() applies the record rules: another employee's day is simply
        # not found, rather than revealing that it exists.
        return Session.search(domain, limit=1)

    def _own_session(self, session_id):
        session = self._session(session_id=session_id)
        if not session:
            raise UserError(request.env._("Work day %(id)s was not found.", id=session_id))
        if session.employee_id != session._current_employee():
            raise UserError(request.env._("Work day %(id)s is not yours.", id=session_id))
        return session

    @staticmethod
    def _with_points(session):
        data = session._api_dict()
        data["points"] = [point._api_dict() for point in session.location_ids.sorted(lambda p: (p.logged_at, p.id))]
        return data

    @http.route("/api/workday/start", type="jsonrpc", auth="user", methods=["POST"])
    def start(self, client_uid=None, latitude=None, longitude=None, started_at=None, device_id=None, **_kw):
        session, created = request.env["dh.work.session"].start_day(
            client_uid=client_uid,
            latitude=latitude,
            longitude=longitude,
            started_at=started_at,
            device_id=device_id,
        )
        return {"session": session._api_dict(), "created": created}

    @http.route("/api/workday/active", type="jsonrpc", auth="user", methods=["POST"])
    def active(self, **_kw):
        Session = request.env["dh.work.session"]
        session = Session.search(
            [("employee_id", "=", Session._current_employee().id), ("state", "=", "active")], limit=1
        )
        return {"session": session._api_dict() if session else False}

    @http.route("/api/workday/get", type="jsonrpc", auth="user", methods=["POST"])
    def get(self, session_id=None, client_uid=None, **_kw):
        session = self._session(session_id=session_id, client_uid=client_uid)
        return {"session": session._api_dict() if session else False}

    @http.route("/api/workday/log_locations", type="jsonrpc", auth="user", methods=["POST"])
    def log_locations(self, session_id=None, points=None, **_kw):
        session = self._own_session(session_id)
        return request.env["dh.work.location"].log_points(session, points or [])

    @http.route("/api/workday/end", type="jsonrpc", auth="user", methods=["POST"])
    def end(self, session_id=None, latitude=None, longitude=None, ended_at=None, **_kw):
        session = self._own_session(session_id)
        changed = session.end_day(ended_at=ended_at, latitude=latitude, longitude=longitude)
        return {"session": session._api_dict(), "already_completed": not changed}

    @http.route("/api/workday/track", type="jsonrpc", auth="user", methods=["POST"])
    def track(self, session_id=None, date_from=None, date_to=None, employee_id=None, **_kw):
        """One work day with its points (`session_id`), or every work day
        overlapping [date_from, date_to) — the caller's own, or `employee_id`'s
        when the record rules let the caller see that employee."""
        Session = request.env["dh.work.session"]
        if session_id:
            session = self._session(session_id=session_id)
            if not session:
                raise UserError(request.env._("Work day %(id)s was not found.", id=session_id))
            return self._with_points(session)
        start = parse_utc(request.env, date_from, "date_from")
        end = parse_utc(request.env, date_to, "date_to")
        if not start or not end or end <= start:
            raise ValidationError(request.env._("date_from and date_to are required, date_to after date_from."))
        if employee_id:
            try:
                employee = int(employee_id)
            except (TypeError, ValueError):
                raise ValidationError(request.env._("employee_id must be a number.")) from None
        else:
            employee = Session._current_employee().id
        sessions = Session.search(
            [
                ("employee_id", "=", employee),
                ("started_at", "<", end),
                "|",
                ("state", "=", "active"),
                ("ended_at", ">=", start),
            ],
            order="started_at asc, id asc",
        )
        return {"sessions": [self._with_points(session) for session in sessions]}
