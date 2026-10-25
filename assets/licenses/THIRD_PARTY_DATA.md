# Bundled astronomical data

The file `assets/catalogs/sky_catalog.sqlite` is a combined, adapted database.
The catalog data and constellation stick figures in it are shared under
Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0).

## HYG star catalog

David Nash / Astronexus, HYG Database v4.1, `hygdata_v41.csv`, repository
snapshot `c7f7f883fe678cc7680169a50ccd7dcc49b060ce` (2025-02-14).
Source: <https://github.com/astronexus/HYG-Database>
License: CC BY-SA 4.0. This app selects stars to visual magnitude 6.5 plus
stars referenced by the modern constellation patterns. It keeps names,
designations, J2000 coordinates, proper motions, magnitudes, and available
distances; the local database is adapted and normalized.

## OpenNGC

Mattia Verga and contributors, OpenNGC release `v20260501`, commit
`36cb178a0f69dba8bfc03a99c10512831edf1c6b`.
Source: <https://github.com/mattiaverga/OpenNGC>
License: CC BY-SA 4.0. The app imports valid positions, types, catalog
designations, common names, and available visual magnitudes into its own
search schema. It excludes duplicate/nonexistent rows and converts RA/Dec
sexagesimal fields to numeric coordinates.

## Stellarium modern sky culture

Stellarium team, `skycultures/modern/index.json`, repository snapshot
`8184399cd363a5fea10e5fb7703a4687752812ae` (2026-10-16).
Source: <https://github.com/Stellarium/stellarium/tree/master/skycultures/modern>
License stated by the source: text and data CC BY-SA 4.0; illustrations are
under a different license and are not included. This app uses only the 88
constellation names/abbreviations and star-stick-figure line data, mapped to
the bundled star catalog. These line figures are illustrative; they are not
the IAU constellation boundaries.

Changes to source data are described above. The applicable license text is
bundled in `CREATIVE_COMMONS_BY-SA_4.0.txt` and `HYG_CC_BY-SA_4.0.txt`.

## Notable targets

`assets/catalogs/notable_objects.json` is a small, separate offline data file.
It contains eight known black-hole source locations and a Milky Way center
marker. Coordinates, names, and cross-identifiers were selected from SIMBAD
records queried on 2026-10-16 and converted from ICRS J2000 sexagesimal form
to decimal right ascension/declination. SIMBAD is operated by CDS, Strasbourg,
France and offers its database under ODbL 1.0. The selected SIMBAD records are
retained as a separate JSON sidecar under ODbL 1.0; the complete license is
bundled in `OPEN_DATABASE_LICENSE_1.0.txt`. This keeps the SIMBAD database
subset separate from the CC BY-SA catalog database above.
Sources: <https://simbad.cds.unistra.fr/simbad/> and
<https://opendatacommons.org/licenses/odbl/1-0/>.

The black-hole marker shows the measured radio, optical, infrared, or X-ray
counterpart/system coordinates. It does not claim that the event horizon is
visually resolved. No magnitude or distance is supplied where the data file
does not include one. The Milky Way marker indicates the Galactic Center at
Sagittarius A*; the sky map draws the extended Milky Way band from an IAU J2000
Galactic-to-equatorial transformation.

Source and license attribution is available in the app's Offline data settings
and in this file. SIMBAD requests citation of its original database paper:
Wenger et al. 2000, A&AS 143, 9.

The applicable license texts are bundled in `CREATIVE_COMMONS_BY-SA_4.0.txt`,
`HYG_CC_BY-SA_4.0.txt`, `OPEN_DATABASE_LICENSE_1.0.txt`, and
`OPENNGC_CODE_MIT.txt`.
