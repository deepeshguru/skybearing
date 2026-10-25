#!/usr/bin/env python3
"""Build the bundled, searchable SQLite catalog from pinned public datasets."""

import argparse
import csv
import json
import math
import re
import sqlite3
from pathlib import Path


def parse_sexagesimal(value: str, hours: bool = False) -> float | None:
    value = (value or "").strip()
    if not value:
        return None
    parts = value.split(":")
    sign = -1 if parts[0].startswith("-") else 1
    first = abs(float(parts[0]))
    minutes = float(parts[1]) if len(parts) > 1 else 0.0
    seconds = float(parts[2]) if len(parts) > 2 else 0.0
    result = sign * (first + minutes / 60 + seconds / 3600)
    return result if not hours else result


def clean_aliases(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result = []
    for value in values:
        value = re.sub(r"\s+", " ", value.strip())
        if value and value.casefold() not in seen:
            seen.add(value.casefold())
            result.append(value)
    return result


def parse_float(value: str | None) -> float | None:
    try:
        number = float(value or "")
        return number if math.isfinite(number) else None
    except (TypeError, ValueError):
        return None


def type_label(code: str) -> str:
    return {
        "G": "Galaxy", "GPair": "Galaxy pair", "GGroup": "Galaxy group",
        "GCl": "Globular cluster", "OCl": "Open cluster", "Cl+N": "Cluster with nebula",
        "Neb": "Nebula", "PN": "Planetary nebula", "HII": "Emission nebula",
        "DrkN": "Dark nebula", "EmN": "Emission nebula", "RfN": "Reflection nebula",
        "SNR": "Supernova remnant", "Nova": "Nova", "QSO": "Quasar",
        "**": "Star", "*": "Star", "Ast": "Asterism", "Dup": "Duplicate entry",
    }.get(code, code or "Deep-sky object")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hyg", required=True, type=Path)
    parser.add_argument("--openngc", required=True, type=Path)
    parser.add_argument("--stellarium", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    sky = json.loads(args.stellarium.read_text(encoding="utf-8"))
    constellations = sky["constellations"]
    lines_by_hip: set[int] = set()
    for constellation in constellations:
        for chain in constellation.get("lines", []):
            lines_by_hip.update(int(hip) for hip in chain if isinstance(hip, int))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        args.output.unlink()
    db = sqlite3.connect(args.output)
    db.executescript("""
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        CREATE TABLE objects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          kind TEXT NOT NULL,
          ra_hours REAL NOT NULL,
          dec_deg REAL NOT NULL,
          epoch REAL NOT NULL DEFAULT 2000.0,
          pmra_masyr REAL,
          pmdec_masyr REAL,
          magnitude REAL,
          magnitude_band TEXT,
          distance_ly REAL,
          constellation TEXT,
          description TEXT NOT NULL,
          aliases TEXT NOT NULL,
          search_text TEXT NOT NULL,
          source TEXT NOT NULL
        );
        CREATE TABLE constellations (
          abbreviation TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          aliases TEXT NOT NULL
        );
        CREATE TABLE constellation_lines (
          constellation TEXT NOT NULL,
          hip_from INTEGER NOT NULL,
          hip_to INTEGER NOT NULL,
          PRIMARY KEY (constellation, hip_from, hip_to)
        );
    """)

    def add_object(row: tuple) -> None:
        db.execute("INSERT OR IGNORE INTO objects VALUES (" + ",".join("?" for _ in row) + ")", row)

    star_rows = 0
    with args.hyg.open(newline="", encoding="utf-8-sig") as source:
        for star in csv.DictReader(source):
            mag = parse_float(star.get("mag"))
            hip = parse_float(star.get("hip"))
            if (mag is None or mag > 6.5) and (hip is None or int(hip) not in lines_by_hip):
                continue
            ra = parse_float(star.get("ra"))
            dec = parse_float(star.get("dec"))
            if ra is None or dec is None:
                continue
            hip_id = int(hip) if hip is not None else None
            star_id = f"star:hip:{hip_id}" if hip_id else f"star:hyg:{star.get('id')}"
            proper = (star.get("proper") or "").strip()
            bf = (star.get("bf") or "").strip()
            name = proper or bf or (f"HIP {hip_id}" if hip_id else f"HYG {star.get('id')}")
            aliases = clean_aliases([
                proper, bf,
                f"HIP {hip_id}" if hip_id else "",
                f"HD {star.get('hd')}" if star.get("hd") else "",
                f"HR {star.get('hr')}" if star.get("hr") else "",
                f"GL {star.get('gl')}" if star.get("gl") else "",
                f"HYG {star.get('id')}" if star.get("id") else "",
            ])
            distance_pc = parse_float(star.get("dist"))
            distance_ly = distance_pc * 3.26156 if distance_pc and 0 < distance_pc < 100000 else None
            pmra = parse_float(star.get("pmra"))
            pmdec = parse_float(star.get("pmdec"))
            constellation = (star.get("con") or "").strip()
            description = "Bright star from HYG v4.1; coordinates are epoch J2000.0."
            row = (star_id, name, "Star", ra, dec, 2000.0, pmra, pmdec, mag, "V", distance_ly,
                   constellation, description, "|".join(aliases), " ".join([name, *aliases]).casefold(), "HYG v4.1")
            add_object(row)
            star_rows += 1

    ngc_rows = 0
    with args.openngc.open(newline="", encoding="utf-8-sig") as source:
        for item in csv.DictReader(source, delimiter=";"):
            ra_hours = parse_sexagesimal(item.get("RA"), hours=True)
            dec_deg = parse_sexagesimal(item.get("Dec"))
            if ra_hours is None or dec_deg is None:
                continue
            if ra_hours is None or not 0 <= ra_hours < 24 or not -90 <= dec_deg <= 90:
                continue
            code = (item.get("Type") or "").strip()
            if code == "***" or code == "NonEx" or code == "Dup":
                continue
            ngc = (item.get("NGC") or "").strip()
            ic = (item.get("IC") or "").strip()
            messier = (item.get("M") or "").strip()
            messier_number = str(int(messier)) if messier.isdigit() else ""
            ngc_number = str(int(ngc)) if ngc.isdigit() else ""
            ic_number = str(int(ic)) if ic.isdigit() else ""
            identifiers = [part.strip() for part in (item.get("Identifiers") or "").split(",")]
            common_names = [part.strip() for part in (item.get("Common names") or "").split(",")]
            display_code = ngc or ic or item.get("Name", "")
            base_name = common_names[0] if common_names else (f"M {messier}" if messier else display_code)
            kind = type_label(code)
            aliases = clean_aliases([
                item.get("Name", ""),
                f"NGC {ngc}" if ngc else "", f"NGC {ngc_number}" if ngc_number else "",
                f"IC {ic}" if ic else "", f"IC {ic_number}" if ic_number else "",
                f"M {messier}" if messier else "", f"M {messier_number}" if messier_number else "",
                f"M{messier_number}" if messier_number else "",
                f"Messier {messier}" if messier else "", f"Messier {messier_number}" if messier_number else "",
                *identifiers, *common_names,
            ])
            magnitude = parse_float(item.get("V-Mag"))
            band = "V" if magnitude is not None else None
            if magnitude is None:
                magnitude = parse_float(item.get("B-Mag"))
                band = "B" if magnitude is not None else None
            const = (item.get("Const") or "").strip()
            source_text = "OpenNGC v20260501"
            description = f"{kind} catalog entry from OpenNGC."
            if item.get("Hubble"):
                description += f" Morphology: {item['Hubble']}."
            row = (f"dso:{display_code.casefold()}", base_name, kind, ra_hours, dec_deg, 2000.0,
                   None, None, magnitude, band, None, const, description, "|".join(aliases),
                   " ".join([base_name, *aliases]).casefold(), source_text)
            try:
                add_object(row)
                ngc_rows += 1
            except sqlite3.IntegrityError:
                continue

    line_count = 0
    for constellation in constellations:
        abbreviation = constellation["id"].split()[-1]
        names = constellation.get("common_name", {})
        name = names.get("english") or names.get("native") or abbreviation
        aliases = clean_aliases([name, names.get("native", ""), abbreviation])
        db.execute("INSERT INTO constellations VALUES (?, ?, ?)", (abbreviation, name, "|".join(aliases)))
        for chain in constellation.get("lines", []):
            for hip_from, hip_to in zip(chain, chain[1:]):
                if isinstance(hip_from, int) and isinstance(hip_to, int):
                    db.execute("INSERT OR IGNORE INTO constellation_lines VALUES (?, ?, ?)",
                               (abbreviation, hip_from, hip_to))
                    line_count += 1

    db.executescript("""
      CREATE INDEX objects_search ON objects(search_text);
      CREATE INDEX objects_kind ON objects(kind);
      CREATE INDEX objects_constellation ON objects(constellation);
      CREATE INDEX objects_magnitude ON objects(magnitude);
      CREATE INDEX constellation_lines_hip ON constellation_lines(hip_from, hip_to);
    """)
    db.commit()
    db.close()
    print(f"Wrote {args.output}: {star_rows} stars, {ngc_rows} deep-sky records, "
          f"{len(constellations)} constellations, {line_count} stick-figure segments")


if __name__ == "__main__":
    main()
