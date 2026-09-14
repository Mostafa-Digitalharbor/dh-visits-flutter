{
    "name": "DH Workday Tracking",
    "version": "19.0.1.0.0",
    "category": "Human Resources",
    "summary": "Whole-workday GPS route (Start Work Day -> End Work Day) for the Visits mobile app",
    "description": """
Stores an employee's GPS route for an entire work day, including the movement
between visits, and exposes it to the Visits mobile app through dedicated
JSON-RPC routes under /api/workday/*.

Replaces the temporary no-code models x_dh_work_session / x_dh_work_location.
The existing /api/visit/* routes and dh.visit.location.log are not touched.

See docs/WORKDAY_TRACKING.md in the mobile repository for the contract.
""",
    "author": "Digital Harbor",
    "license": "LGPL-3",
    "depends": ["hr", "dh_visit_management"],
    "data": [
        "security/ir.model.access.csv",
        "security/workday_security.xml",
        "views/workday_views.xml",
    ],
    "installable": True,
    "application": False,
}
