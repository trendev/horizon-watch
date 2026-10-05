#!/usr/bin/env python3
"""Builds the String Catalogs from docs/strings.csv.

    python3 Tools/generate_strings.py

Writes HorizonApp/Resources/Localizable.xcstrings and InfoPlist.xcstrings.
Edit the CSV, never the catalogs.
"""
import csv
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "strings.csv"
TARGET = ROOT / "HorizonApp" / "Resources"
INFO_PLIST_PREFIX = "InfoPlist."


def entry(row, locales):
    return {
        "comment": row["comment"],
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": row[locale]}}
            for locale in locales
            if row[locale]
        },
    }


def write(name, strings):
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    text = json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "))
    (TARGET / name).write_text(text + "\n", encoding="utf-8")


def main():
    with SOURCE.open(encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        locales = [name for name in reader.fieldnames if name not in ("key", "comment")]
        rows = list(reader)

    localizable, info_plist = {}, {}
    for row in rows:
        key = row["key"]
        if key.startswith(INFO_PLIST_PREFIX):
            info_plist[key[len(INFO_PLIST_PREFIX):]] = entry(row, locales)
        else:
            localizable[key] = entry(row, locales)

    TARGET.mkdir(parents=True, exist_ok=True)
    write("Localizable.xcstrings", localizable)
    write("InfoPlist.xcstrings", info_plist)
    print(f"{len(localizable)} strings, {len(info_plist)} Info.plist strings, {len(locales)} locales")


if __name__ == "__main__":
    main()
