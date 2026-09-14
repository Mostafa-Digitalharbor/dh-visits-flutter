from datetime import timedelta

import psycopg2

from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.tests import TransactionCase, tagged
from odoo.tools import mute_logger

from .common import WorkdayFixture


@tagged("post_install", "-at_install", "dh_workday")
class TestWorkdayModels(WorkdayFixture, TransactionCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.setup_workday_fixture()
        cls.Session = cls.env["dh.work.session"]
        cls.Location = cls.env["dh.work.location"]

    def _start(self, user, uid="day-1", **kw):
        return self.Session.with_user(user).start_day(uid, latitude=24.7136, longitude=46.6753, **kw)

    # --- one active work day -------------------------------------------------

    def test_start_is_idempotent_and_never_opens_a_second_day(self):
        session, created = self._start(self.user_employee)
        self.assertTrue(created)
        self.assertEqual(session.state, "active")
        self.assertEqual(session.employee_id, self.emp_employee)

        again, created = self._start(self.user_employee)
        self.assertFalse(created)
        self.assertEqual(again, session)

        other_uid, created = self._start(self.user_employee, uid="day-from-another-phone")
        self.assertFalse(created, "an open day is returned instead of opening a second one")
        self.assertEqual(other_uid, session)
        self.assertEqual(self.Session.sudo().search_count([("employee_id", "=", self.emp_employee.id)]), 1)

    def test_database_refuses_a_second_active_day(self):
        self._start(self.user_employee)
        with self.assertRaises(psycopg2.errors.UniqueViolation), mute_logger("odoo.sql_db"):
            with self.env.cr.savepoint():
                self.Session.sudo().create({"employee_id": self.emp_employee.id, "client_uid": "raw-second"})
                self.env.flush_all()

    def test_employee_cannot_open_a_day_for_someone_else(self):
        with self.assertRaises(AccessError):
            self.Session.with_user(self.user_employee).create(
                {"employee_id": self.emp_other.id, "client_uid": "not-mine"}
            )

    def test_start_in_future_or_inside_completed_day_is_refused(self):
        with self.assertRaises(ValidationError):
            self._start(self.user_employee, uid="future", started_at=self.utc(timedelta(hours=1)))
        session, _created = self._start(self.user_employee)
        session.with_user(self.user_employee).end_day()
        with self.assertRaises(ValidationError):
            self._start(self.user_employee, uid="backdated", started_at=self.utc(-timedelta(hours=2)))

    # --- lifecycle -------------------------------------------------------------

    def test_end_is_idempotent_and_a_completed_day_cannot_be_reopened(self):
        session, _created = self._start(self.user_employee)
        as_employee = session.with_user(self.user_employee)
        self.assertTrue(as_employee.end_day(latitude=24.72, longitude=46.68))
        self.assertEqual(session.state, "completed")
        self.assertTrue(session.ended_at)
        self.assertFalse(as_employee.end_day(), "a retried end is harmless")
        with self.assertRaises(UserError):
            as_employee.write({"state": "active"})
        with self.assertRaises(UserError):
            session.sudo().write({"state": "active"})

    def test_start_fields_are_immutable(self):
        session, _created = self._start(self.user_employee)
        with self.assertRaises(UserError):
            session.with_user(self.user_employee).write({"started_at": self.utc(-timedelta(hours=3))})

    def test_days_cannot_be_deleted_by_employees_or_managers(self):
        session, _created = self._start(self.user_employee)
        for user in (self.user_employee, self.user_manager, self.user_admin):
            with self.assertRaises(UserError):
                session.with_user(user).unlink()

    # --- points ----------------------------------------------------------------

    def test_points_are_validated(self):
        session, _created = self._start(self.user_employee)
        Location = self.Location.with_user(self.user_employee)
        bad = [
            self.fix(1, latitude=999.0),
            self.fix(2, longitude=-181.0),
            self.fix(3, latitude=0.0, longitude=0.0),
            self.fix(4, logged_at="garbage"),
            self.fix(5, delta=timedelta(minutes=10)),
            self.fix(6, delta=-timedelta(minutes=10)),
            self.fix(7, accuracy=-1),
            self.fix(8, source="teleport"),
            {"latitude": 24.7, "longitude": 46.7},
        ]
        result = Location.log_points(session, bad + [self.fix(20)])
        self.assertEqual([r["index"] for r in result["rejected"]], list(range(len(bad))))
        self.assertEqual(result["created"], 1)
        self.assertEqual(result["location_count"], 1)
        for vals in bad[:3]:
            with self.assertRaises(ValidationError):
                Location.create([dict(vals, session_id=session.id)])

    def test_upload_is_idempotent_on_client_uid(self):
        session, _created = self._start(self.user_employee)
        Location = self.Location.with_user(self.user_employee)
        batch = [self.fix(1), self.fix(2), self.fix(3)]
        first = Location.log_points(session, batch)
        self.assertEqual((first["created"], first["duplicates"]), (3, []))
        second = Location.log_points(session, batch + [self.fix(4)])
        self.assertEqual((second["created"], second["duplicates"]), (1, [0, 1, 2]))
        inside = Location.log_points(session, [self.fix(9), self.fix(9)])
        self.assertEqual((inside["created"], inside["duplicates"]), (1, [1]))
        self.assertEqual(session.location_count, 5)

    def test_points_are_append_only(self):
        session, _created = self._start(self.user_employee)
        self.Location.with_user(self.user_employee).log_points(session, [self.fix(1)])
        point = session.location_ids
        for user in (self.user_employee, self.user_admin):
            with self.assertRaises(UserError):
                point.with_user(user).write({"latitude": 25.0})
            with self.assertRaises(UserError):
                point.with_user(user).unlink()
        with self.assertRaises(UserError):
            point.sudo().write({"latitude": 25.0})

    def test_no_point_after_the_day_is_completed(self):
        session, _created = self._start(self.user_employee)
        session.with_user(self.user_employee).end_day()
        with self.assertRaises(UserError):
            self.Location.with_user(self.user_employee).log_points(session, [self.fix(1)])
        with self.assertRaises(UserError):
            self.Location.with_user(self.user_employee).create([dict(self.fix(2), session_id=session.id)])

    def test_nobody_records_into_another_employees_day(self):
        session, _created = self._start(self.user_employee)
        for user in (self.user_other, self.user_manager, self.user_admin):
            with self.assertRaises(AccessError):
                self.Location.with_user(user).create([dict(self.fix(1), session_id=session.id)])

    def test_visit_on_a_point_must_be_visible_to_the_employee(self):
        session, _created = self._start(self.user_employee)
        own = self.visit(self.emp_employee)
        foreign = self.visit(self.emp_other)
        result = self.Location.with_user(self.user_employee).log_points(session, [
            self.fix(1, visit_id=own.id),
            self.fix(2, visit_id=foreign.id),
            self.fix(3, visit_id=987654321),
        ])
        self.assertEqual(result["created"], 1)
        self.assertEqual([r["index"] for r in result["rejected"]], [1, 2])
        self.assertEqual(session.location_ids.visit_id, own)

    # --- who sees what ---------------------------------------------------------

    def test_record_rules(self):
        mine, _created = self._start(self.user_employee)
        self.Location.with_user(self.user_employee).log_points(mine, [self.fix(1)])
        theirs, _created = self._start(self.user_other, uid="other-day")

        def visible(user, model="dh.work.session"):
            return self.env[model].with_user(user).search([])

        self.assertEqual(visible(self.user_employee), mine)
        self.assertEqual(visible(self.user_other), theirs)
        self.assertEqual(visible(self.user_manager), mine, "a manager reads their team only")
        self.assertFalse(visible(self.user_outsider), "a manager of nobody reads nobody")
        # An administrator reads every day; the database may already hold other
        # employees' days (a real server does), so only require these two.
        self.assertEqual(visible(self.user_admin) & (mine | theirs), mine | theirs)
        self.assertEqual(visible(self.user_manager, "dh.work.location"), mine.location_ids)
        self.assertFalse(visible(self.user_other, "dh.work.location"))

        with self.assertRaises(AccessError):
            mine.with_user(self.user_manager).write({"state": "completed"})
        with self.assertRaises(AccessError):
            mine.with_user(self.user_other).end_day()
        # A visit administrator may close a day left open.
        theirs.with_user(self.user_admin).end_day()
        self.assertEqual(theirs.state, "completed")
