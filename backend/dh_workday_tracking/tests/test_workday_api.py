from datetime import timedelta

from odoo.tests import HttpCase, JsonRpcException, tagged
from odoo.tools import mute_logger

from .common import WorkdayFixture


@tagged("post_install", "-at_install", "dh_workday")
class TestWorkdayApi(WorkdayFixture, HttpCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.setup_workday_fixture()

    def login(self, user):
        self.authenticate(user.login, f"{user.login}-Pass-2026")

    def call(self, route, **params):
        return self.make_jsonrpc_request(f"/api/workday/{route}", params)

    def test_full_day_through_the_api(self):
        self.login(self.user_employee)
        self.assertEqual(self.call("active"), {"session": False})

        started = self.call("start", client_uid="wd-1", latitude=24.7136, longitude=46.6753, device_id="pixel")
        self.assertTrue(started["created"])
        session = started["session"]
        self.assertEqual(session["state"], "active")
        self.assertEqual(session["client_uid"], "wd-1")
        self.assertRegex(session["started_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$")

        again = self.call("start", client_uid="wd-1")
        self.assertEqual((again["created"], again["session"]["id"]), (False, session["id"]))
        self.assertEqual(self.call("active")["session"]["id"], session["id"])
        self.assertEqual(self.call("get", client_uid="wd-1")["session"]["id"], session["id"])

        points = [self.fix(1), self.fix(2, source="track"), self.fix(3, latitude=999)]
        logged = self.call("log_locations", session_id=session["id"], points=points)
        self.assertEqual(logged["created"], 2)
        self.assertEqual([r["index"] for r in logged["rejected"]], [2])
        self.assertIn("out of range", logged["rejected"][0]["error"])
        resent = self.call("log_locations", session_id=session["id"], points=points[:2])
        self.assertEqual((resent["created"], resent["duplicates"]), (0, [0, 1]))

        track = self.call("track", session_id=session["id"])
        self.assertEqual([p["client_uid"] for p in track["points"]], ["fix-1", "fix-2"])
        self.assertGreater(track["tracked_distance_km"], 0)
        day = self.call("track", date_from=self.utc(-timedelta(hours=12)), date_to=self.utc(timedelta(hours=12)))
        self.assertEqual([s["id"] for s in day["sessions"]], [session["id"]])
        self.assertEqual(len(day["sessions"][0]["points"]), 2)

        ended = self.call("end", session_id=session["id"], latitude=24.72, longitude=46.68)
        self.assertEqual((ended["session"]["state"], ended["already_completed"]), ("completed", False))
        self.assertTrue(self.call("end", session_id=session["id"])["already_completed"])
        self.assertEqual(self.call("active"), {"session": False})

        with mute_logger("odoo.http"), self.assertRaises(JsonRpcException) as refused:
            self.call("log_locations", session_id=session["id"], points=[self.fix(4)])
        self.assertIn("UserError", str(refused.exception))

    def test_another_employee_cannot_use_my_day(self):
        self.login(self.user_employee)
        session = self.call("start", client_uid="mine")["session"]
        self.login(self.user_other)
        self.assertEqual(self.call("get", session_id=session["id"]), {"session": False})
        for route, params in (
            ("log_locations", {"session_id": session["id"], "points": [self.fix(1)]}),
            ("end", {"session_id": session["id"]}),
            ("track", {"session_id": session["id"]}),
        ):
            with mute_logger("odoo.http"), self.assertRaises(JsonRpcException):
                self.call(route, **params)

    def test_manager_reads_team_day_but_cannot_change_it(self):
        self.login(self.user_employee)
        session = self.call("start", client_uid="team")["session"]
        self.call("log_locations", session_id=session["id"], points=[self.fix(1)])
        self.login(self.user_manager)
        track = self.call("track", session_id=session["id"])
        self.assertEqual(len(track["points"]), 1)
        window = {"date_from": self.utc(-timedelta(hours=1)), "date_to": self.utc(timedelta(hours=1))}
        team = self.call("track", employee_id=self.emp_employee.id, **window)
        self.assertEqual([s["id"] for s in team["sessions"]], [session["id"]])
        with mute_logger("odoo.http"), self.assertRaises(JsonRpcException):
            self.call("end", session_id=session["id"])
        self.login(self.user_outsider)
        self.assertEqual(self.call("track", employee_id=self.emp_employee.id, **window), {"sessions": []})
