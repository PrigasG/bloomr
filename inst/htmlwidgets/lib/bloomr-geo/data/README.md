# Included geography

`bloomr` includes prepared geographic files for its New Jersey and Texas maps. The browser loads local-area files only when a county is opened.

## New Jersey

- `nj_state.geojson`: state outline.
- `nj_counties.geojson`: county polygons and geographic IDs.
- `municipalities/*.geojson`: municipality polygons, one county per file.

## Texas

- `tx/state.geojson`: state outline.
- `tx/counties.geojson`: county polygons and geographic IDs.
- `tx/municipalities/*.geojson`: census county subdivision polygons, one county per file.

Map data is bundled with the package. Users do not need to download boundaries or connect to an external mapping service for these examples. These prepared geometries are for visualization and should not be used to determine legal boundaries.

## Source information

The included maps were prepared from source boundary data and simplified for interactive viewing. Source and rights details are in `COPYRIGHTS` at the installed package root. The original project records refer to:

- **New Jersey municipalities:** New Jersey Office of GIS (NJOGIS) municipal boundaries, using its ArcGIS hosted data service and download endpoints.
- **Texas counties and county subdivisions:** U.S. Census Bureau TIGER/Line county subdivision geography (2025 preparation workflow).

The preparation scripts can be found in the original Hierarchical Bloom Lab project. The packaged assets are visualization copies and should not be treated as authoritative legal boundaries.
