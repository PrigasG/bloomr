Prepared browser data for Hierarchical Bloom Lab.

- `nj_counties.geojson`: five-decimal authoritative county display geometry
- `nj_state.geojson`: state outline synchronized from the finalized county union
- `boundaries/index.json`: lightweight county names, identifiers, metrics, and static asset URLs
- `municipalities/index.json`: lightweight county index and statewide metric summary
- `municipalities/<county>.geojson`: municipality geometry loaded only when that county is opened

Build-only full-resolution sources are intentionally excluded from the runtime distribution. `scripts/prepare_data_once.R` can refresh these caches from the official NJGIS services, or from an optional local `data_source/` folder created by the developer.
