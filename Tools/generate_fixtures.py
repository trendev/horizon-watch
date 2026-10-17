#!/usr/bin/env python3
"""Recomputes the reference values used by the HorizonCore tests.

docs/fixtures/sun-times.csv: sunrise and sunset columns.
docs/fixtures/sun-altitudes.csv: the sun's true altitude (no refraction) at given instants,
used to check the path drawn on the arc.

The reference values come from astral 3.x, an implementation independent of the app,
at the spec's definition: sun's upper limb at -0.833 degrees (zenith 90.833).
astral's own default adds a refraction model that puts the horizon at 90.789 degrees,
which is not the convention of NOAA or Apple Weather, so the zenith is passed explicitly.

    python3 -m venv venv && venv/bin/pip install astral
    venv/bin/python Tools/generate_fixtures.py
"""
import csv
import datetime
import pathlib
import zoneinfo

from astral import Observer, SunDirection
from astral.sun import elevation, time_of_transit

ZENITH = 90.833
FIXTURES = pathlib.Path(__file__).resolve().parent.parent / "docs" / "fixtures"
PATH = FIXTURES / "sun-times.csv"
ALTITUDES = FIXTURES / "sun-altitudes.csv"

# city, latitude, longitude, time zone, local instants
ALTITUDE_CASES = [
    ("Paris", 48.8566, 2.3522, "Europe/Paris", [
        "2026-03-21T13:00", "2026-06-21T13:30", "2026-09-29T07:47", "2026-09-29T13:40",
        "2026-09-29T16:17", "2026-12-21T12:50", "2026-10-17T16:17"]),
    ("Quito", -0.1807, -78.4678, "America/Guayaquil", ["2026-03-21T12:20", "2026-06-21T09:00"]),
    ("Sydney", -33.8688, 151.2093, "Australia/Sydney", ["2026-12-21T13:00", "2026-06-21T12:00"]),
    ("Tromsø", 69.6492, 18.9553, "Europe/Oslo", ["2026-12-21T11:45", "2026-06-21T23:59"]),
    ("Reykjavik", 64.1466, -21.9426, "Atlantic/Reykjavik", ["2026-06-21T13:30"]),
]


def transit(observer, day, direction):
    try:
        return time_of_transit(observer, day, ZENITH, direction, with_refraction=False)
    except ValueError:
        return None


def sunrise(observer, day, zone):
    """Sunrise on the local date. astral answers for the UTC date, a day off east of Greenwich."""
    for shift in (0, -1, 1):
        moment = transit(observer, day + datetime.timedelta(days=shift), SunDirection.RISING)
        if moment and moment.astimezone(zone).date() == day:
            return moment
    return None


def sunset(observer, day, rise):
    """First sunset after that day's sunrise, even when it falls after local midnight."""
    for shift in (-1, 0, 1):
        moment = transit(observer, day + datetime.timedelta(days=shift), SunDirection.SETTING)
        if moment and moment > rise:
            return moment
    return None


def text(moment, zone):
    if moment is None:
        return "none"
    moment = (moment + datetime.timedelta(microseconds=500_000)).replace(microsecond=0)
    return moment.astimezone(zone).isoformat()


def altitudes():
    with ALTITUDES.open("w", encoding="utf-8", newline="") as target:
        writer = csv.writer(target, lineterminator="\n")
        writer.writerow(["city", "latitude", "longitude", "time", "altitude"])
        for city, latitude, longitude, zone, instants in ALTITUDE_CASES:
            observer = Observer(latitude, longitude, 0)
            for text in instants:
                moment = datetime.datetime.fromisoformat(text).replace(tzinfo=zoneinfo.ZoneInfo(zone))
                value = elevation(observer, moment, with_refraction=False)
                writer.writerow([city, latitude, longitude, moment.isoformat(), f"{value:.4f}"])


def main():
    altitudes()
    with PATH.open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    for row in rows:
        observer = Observer(float(row["latitude"]), float(row["longitude"]), 0)
        day = datetime.date.fromisoformat(row["date"])
        zone = zoneinfo.ZoneInfo(row["time_zone"])
        rise = sunrise(observer, day, zone)
        row["sunrise"] = text(rise, zone)
        row["sunset"] = text(sunset(observer, day, rise) if rise else None, zone)
    with PATH.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
