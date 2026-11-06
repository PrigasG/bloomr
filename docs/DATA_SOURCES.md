# Geographic data and attribution

The package includes simplified boundaries for interactive visualization, not
survey or legal boundaries. The source preparation records are in the original
`nj_hierarchical_bloom` project (`R/prepare_boundary_data.R`,
`R/prepare_municipal_data.R`, and `scripts/prepare_state_from_tiger.R`). The
original download timestamps are not preserved in this package, so the exact
snapshot dates of the bundled New Jersey files cannot be independently stated.

| Bundled data | Recorded source and preparation |
| --- | --- |
| New Jersey state and counties | New Jersey Office of Information Technology, Office of GIS (NJOGIS), [Government Boundaries service](https://maps.nj.gov/arcgis/rest/services/Framework/Government_Boundaries/MapServer), state layer 0 and county layer 1. The original preparation also allowed a local source or a county union fallback. |
| New Jersey municipalities | NJOGIS [hosted municipal boundaries](https://www.arcgis.com/home/item.html?id=a1b13541f0484415b06cf9c8969bfd6c) or a local source, split by county in the original preparation. |
| Texas state, counties, and county subdivisions | U.S. Census Bureau [2025 TIGER/Line county subdivisions](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.2025.html); the original script simplified the subdivisions and dissolved them to counties and a state outline. |

The [NJOGIS municipal metadata](https://www.arcgis.com/sharing/rest/content/items/1c6b26a9a14e4132895194e80d6b30f8/info/metadata/metadata.xml?format=default&output=html)
lists no access restriction, asks for acknowledgement of NJOGIS in derived
products, and warns against survey or legal use. The [2025 Census technical
documentation](https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2025/TGRSHP2025_TechDoc.pdf)
states that U.S. government works may be reproduced, asks for a Census Bureau
citation, and requests a prominent statement that TIGER/Line® is a Census Bureau
trademark. Those notices are included in `inst/COPYRIGHTS`, which ships with the
package. The MIT license for package code does not replace the source notices
for the geography.
