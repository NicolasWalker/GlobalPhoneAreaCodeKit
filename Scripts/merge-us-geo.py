#!/usr/bin/env python3
"""Merge US area-code centroids from us-area-code-geo.csv into the bundled US-codes.json.

Joins on the bare area code (geo "201" <-> JSON "code": "201"). Entries without
a matching centroid are left untouched (latitude/longitude keys omitted).

Usage: python3 Scripts/merge-us-geo.py
"""

import csv
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GEO_CSV = REPO_ROOT / "us-area-code-geo.csv"
US_JSON = REPO_ROOT / "Sources" / "GlobalPhoneAreaCodeKit" / "Resources" / "US-codes.json"


def main() -> None:
    centroids = {}
    with GEO_CSV.open(newline="") as f:
        for row in csv.reader(f):
            if len(row) < 3:
                continue
            code, lat, lon = row[0].strip(), row[1].strip(), row[2].strip()
            centroids[code] = (float(lat), float(lon))

    entries = json.loads(US_JSON.read_text())
    matched = 0
    for entry in entries:
        coords = centroids.get(entry["code"])
        if coords:
            entry["latitude"], entry["longitude"] = coords
            matched += 1
        else:
            entry.pop("latitude", None)
            entry.pop("longitude", None)

    US_JSON.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")
    print(f"Merged centroids for {matched}/{len(entries)} US entries")


if __name__ == "__main__":
    main()
