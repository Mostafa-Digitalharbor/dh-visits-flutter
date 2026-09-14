"""Validation and formatting shared by work days, their points and the API."""

import math
from datetime import datetime, timedelta

from odoo.exceptions import ValidationError

# A device estimates the server's clock; two estimates can differ slightly.
CLOCK_TOLERANCE = timedelta(minutes=2)
# How far in the future a timestamp may be before it is refused.
FUTURE_TOLERANCE = timedelta(minutes=5)
# An offline device may upload a work day it started this long ago.
MAX_START_AGE = timedelta(days=7)

SOURCES = ("start", "track", "end")


def parse_utc(env, value, label):
    """A naive UTC datetime from `YYYY-MM-DD HH:MM:SS`, ISO `...T...`, an
    optional fraction and an optional `Z` / `+00:00` suffix; None when empty.
    Any other time zone is refused rather than silently misread."""
    if value in (None, False, ""):
        return None
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            raise ValidationError(env._("%(label)s must be in UTC.", label=label))
        return value.replace(microsecond=0)
    text = str(value).strip().replace("T", " ")
    if text.endswith("Z"):
        text = text[:-1]
    elif len(text) > 19 and text[19:].lstrip(".0123456789") in ("+00:00", "+0000"):
        text = text[: len(text) - len(text[19:].lstrip(".0123456789"))]
    text = text.split(".", 1)[0]
    try:
        return datetime.strptime(text, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        raise ValidationError(
            env._("%(label)s is not a valid UTC date and time.", label=label)
        ) from None


def to_float(env, value, label, required=False):
    if value in (None, False, ""):
        if required:
            raise ValidationError(env._("%(label)s is required.", label=label))
        return None
    if isinstance(value, bool):
        raise ValidationError(env._("%(label)s must be a number.", label=label))
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ValidationError(env._("%(label)s must be a number.", label=label)) from None
    if math.isnan(number) or math.isinf(number):
        raise ValidationError(env._("%(label)s must be a finite number.", label=label))
    return number


def check_position(env, latitude, longitude):
    """Raises ValidationError unless (latitude, longitude) is a real fix."""
    if not -90.0 <= latitude <= 90.0:
        raise ValidationError(
            env._("Latitude %(value)s is out of range (-90 to 90).", value=latitude)
        )
    if not -180.0 <= longitude <= 180.0:
        raise ValidationError(
            env._("Longitude %(value)s is out of range (-180 to 180).", value=longitude)
        )
    if latitude == 0.0 and longitude == 0.0:
        # What a device reports when it has no fix at all.
        raise ValidationError(env._("Position 0, 0 is not a valid GPS fix."))


def haversine_km(lat1, lng1, lat2, lng2):
    radius = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(min(1.0, math.sqrt(a)))


def format_utc(value):
    """Datetimes leave the API as naive UTC ISO strings, like /api/visit/*."""
    return value.strftime("%Y-%m-%dT%H:%M:%S") if value else False
