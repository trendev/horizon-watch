#!/usr/bin/env python3
"""Builds HorizonApp/Resources/cities15000.bin, the offline city list.

    python3 Tools/build_cities.py

Downloads GeoNames cities15000 (cities above 15,000 inhabitants, CC BY 4.0,
https://www.geonames.org) and keeps what the app needs. This runs on the Mac at
development time; the app itself never touches the network.

Layout, little endian, read by HorizonCore's CityIndex: "HZC1", count (uint32), then
per city 20 bytes (latitude float32, longitude float32, population uint32, name offset
uint32, name length uint16, country code 2 bytes), then the UTF-8 names. Cities are
sorted by decreasing population.
"""
import io
import pathlib
import re
import struct
import urllib.request
import zipfile

URL = "https://download.geonames.org/export/dump/cities15000.zip"
TARGET = pathlib.Path(__file__).resolve().parent.parent / "HorizonApp" / "Resources" / "cities15000.bin"


def main():
    with urllib.request.urlopen(URL) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    lines = archive.read("cities15000.txt").decode("utf-8").splitlines()

    rows = [line.split("\t") for line in lines]
    names = {(f[8], f[1]) for f in rows}

    cities = []
    for f in rows:
        country = f[8]
        # Sections of a city are not places people name: GeoNames' PPLX, and numbered
        # districts of a listed city such as "Paris 04 Hôtel-de-Ville" or "Marseille 01".
        district = re.match(r"(.+?) \d{1,2}\b", f[1])
        if len(country) != 2 or f[7] == "PPLX" or (district and (country, district.group(1)) in names):
            continue
        cities.append((int(f[14] or 0), f[1], country, float(f[4]), float(f[5])))
    cities.sort(key=lambda city: (-city[0], city[1]))

    records, blob = bytearray(), bytearray()
    for population, name, country, latitude, longitude in cities:
        encoded = name.encode("utf-8")
        records += struct.pack(
            "<ffIIH2s", latitude, longitude, min(population, 0xFFFFFFFF), len(blob), len(encoded),
            country.encode("ascii"))
        blob += encoded

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(b"HZC1" + struct.pack("<I", len(cities)) + records + blob)
    print(f"{len(cities)} cities, {TARGET.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
