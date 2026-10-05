#!/usr/bin/env python3
"""Recomputes the sunrise and sunset columns of docs/fixtures/sun-times.csv.

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
from astral.sun import time_of_transit

ZENITH = 90.833
PATH = pathlib.Path(__file__).resolve().parent.parent / "docs" / "fixtures" / "sun-times.csv"


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


def main():
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
