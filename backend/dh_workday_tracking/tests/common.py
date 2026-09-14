from datetime import timedelta

from odoo import Command, fields


class WorkdayFixture:
    """Users and a small hierarchy: `manager` manages `employee`; `other` and
    `outsider` (a manager of nobody) are unrelated; `admin` is a visit
    administrator."""

    @classmethod
    def setup_workday_fixture(cls):
        env = cls.env
        base_user = env.ref("base.group_user")
        groups = {
            "user": env.ref("dh_visit_management.group_visit_user"),
            "manager": env.ref("dh_visit_management.group_visit_manager"),
            "admin": env.ref("dh_visit_management.group_visit_admin"),
        }

        def user(login, group):
            return env["res.users"].with_context(no_reset_password=True).create({
                "name": login.title(),
                "login": login,
                "password": f"{login}-Pass-2026",
                "group_ids": [Command.set([base_user.id, groups[group].id])],
            })

        cls.user_manager = user("wd_manager", "manager")
        cls.user_employee = user("wd_employee", "user")
        cls.user_other = user("wd_other", "user")
        cls.user_outsider = user("wd_outsider", "manager")
        cls.user_admin = user("wd_admin", "admin")

        Employee = env["hr.employee"]
        cls.emp_manager = Employee.create({"name": "WD Manager", "user_id": cls.user_manager.id})
        cls.emp_employee = Employee.create(
            {"name": "WD Employee", "user_id": cls.user_employee.id, "parent_id": cls.emp_manager.id}
        )
        cls.emp_other = Employee.create({"name": "WD Other", "user_id": cls.user_other.id})
        cls.emp_outsider = Employee.create({"name": "WD Outsider", "user_id": cls.user_outsider.id})
        cls.emp_admin = Employee.create({"name": "WD Admin", "user_id": cls.user_admin.id})

    @classmethod
    def visit(cls, employee):
        """A dh.visit with the fields the real dh_visit_management requires
        (probed on Odoo 19.0+e, module 19.0.2.1.0): visit_type, employee_id,
        scheduled_datetime, purpose, and a project for a project visit ("A
        project is required for a project visit")."""
        env = cls.env
        if not getattr(cls, "_visit_project", None):
            cls._visit_project = env["project.project"].sudo().create({"name": "WD Visits"})
        return env["dh.visit"].sudo().create({
            "name": f"VIS/{employee.name}",
            "visit_type": "project",
            "project_id": cls._visit_project.id,
            "employee_id": employee.id,
            "user_id": employee.user_id.id,
            "scheduled_datetime": cls.utc(timedelta(hours=1)),
            "purpose": "Work-day test visit",
        })

    @staticmethod
    def utc(delta=timedelta()):
        return fields.Datetime.to_string(fields.Datetime.now() + delta)

    @classmethod
    def fix(cls, index, delta=timedelta(), **extra):
        point = {
            "latitude": 24.7136 + index * 0.0004,
            "longitude": 46.6753 + index * 0.0003,
            "logged_at": cls.utc(delta),
            "accuracy": 8.0,
            "client_uid": f"fix-{index}",
        }
        point.update(extra)
        return point
