# Included geography

`bloomr` includes prepared geographic files for its New Jersey and Texas maps. The browser loads local-area files only when a county is opened.

## New Jersey

- `nj_state.geojson`: state outline.
- `nj_counties.geojson`: county polygons and geographic IDs.
- `boundaries/index.json`: county lookup information and asset paths.
- `municipalities/index.json`: local-area lookup information.
- `municipalities/*.geojson`: municipality polygons, one county per file.

## Texas

- `tx/state.geojson`: state outline.
- `tx/counties.geojson`: county polygons and geographic IDs.
- `tx/boundaries/index.json`: county lookup information.
- `tx/municipalities/index.json`: local-area lookup information.
- `tx/municipalities/*.geojson`: census county subdivision polygons, one county per file.

Map data is bundled with the package. Users do not need to download boundaries or connect to an external mapping service for these examples. These prepared geometries are for visualization and should not be used to determine legal boundaries.
