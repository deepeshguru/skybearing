"""Offline validation for the bundled SQLite sky catalog."""

from pathlib import Path
import json
import sqlite3
import unittest


ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "assets" / "catalogs" / "sky_catalog.sqlite"


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.connection = sqlite3.connect(f"file:{DATABASE}?mode=ro", uri=True)

    @classmethod
    def tearDownClass(cls):
        cls.connection.close()

    def test_database_integrity_and_prepackaged_size(self):
        self.assertEqual(self.connection.execute("PRAGMA integrity_check").fetchone()[0], "ok")
        self.assertGreater(DATABASE.stat().st_size, 1_000_000)

    def test_real_star_search_names_and_identifiers(self):
        self.assertEqual(
            self.connection.execute("SELECT id FROM objects WHERE lower(name) = 'sirius'").fetchone()[0],
            "star:hip:32349",
        )
        for query in ("m31", "ngc 224", "hip 32349", "9alp cma"):
            with self.subTest(query=query):
                self.assertGreater(
                    self.connection.execute(
                        "SELECT count(*) FROM objects WHERE search_text LIKE ?",
                        (f"%{query.lower()}%",),
                    ).fetchone()[0],
                    0,
                )

    def test_all_88_constellations_and_reference_lines_exist(self):
        count = self.connection.execute("SELECT count(*) FROM constellations").fetchone()[0]
        lines = self.connection.execute("SELECT count(*) FROM constellation_lines").fetchone()[0]
        self.assertEqual(count, 88)
        self.assertGreater(lines, 600)

    def test_license_notices_are_bundled(self):
        licenses = ROOT / "assets" / "licenses"
        self.assertTrue((licenses / "HYG_CC_BY-SA_4.0.txt").is_file())
        self.assertTrue((licenses / "CREATIVE_COMMONS_BY-SA_4.0.txt").is_file())
        self.assertTrue((licenses / "OPENNGC_CODE_MIT.txt").is_file())
        self.assertTrue((licenses / "THIRD_PARTY_DATA.md").is_file())
        self.assertTrue((licenses / "OPEN_DATABASE_LICENSE_1.0.txt").is_file())
        self.assertTrue((licenses / "ASTRONOMY_ENGINE_MIT.txt").is_file())

    def test_notable_black_hole_and_milky_way_records_are_offline(self):
        records = json.loads(
            (ROOT / "assets" / "catalogs" / "notable_objects.json").read_text()
        )
        black_holes = [record for record in records if record["id"].startswith("black-hole:")]
        milky_way = next(record for record in records if record["id"] == "galaxy:milky-way")
        self.assertEqual(len(black_holes), 8)
        self.assertEqual(milky_way["name"], "Milky Way")
        for record in records:
            self.assertGreaterEqual(record["ra_hours"], 0)
            self.assertLess(record["ra_hours"], 24)
            self.assertGreaterEqual(record["dec_deg"], -90)
            self.assertLessEqual(record["dec_deg"], 90)
            self.assertNotIn("magnitude", record)


if __name__ == "__main__":
    unittest.main(verbosity=2)
