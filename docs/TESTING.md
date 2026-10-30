# Testing and validation

## Can be run without R

From the package source folder:

```sh
node --check inst/htmlwidgets/lib/bloomr/bloom-core.js
node tests/browser/check-assets.js
```

A browser test fixture is included. Serve the source directory on localhost
and open `tests/browser/fixture.html`; the test uses the actual bundled NJ
GeoJSON and the package browser engine.

The included Playwright smoke script uses real bundled NJ/TX geometry inline:

```sh
python tests/browser/run_browser_smoke.py
```

Observed build results: New Jersey (21 counties and Bergen's 70 municipalities),
Texas (254 counties and Anderson's subdivisions), active dotted connectors,
value updates retaining manual offsets, local back navigation, two simultaneous
map instances, and isolated light/dark styling all passed browser smoke tests.
The included screenshot shows the county-bloom default appearance.

## R environment checks (required before release)

```r
install.packages(c("htmlwidgets", "htmltools", "jsonlite", "shiny", "testthat"))
install.packages(".", repos = NULL, type = "source")
library(bloomr)
bloom_map("nj")
bloomr::run_bloom_example()
testthat::test_dir("tests/testthat")
# From the source project, with an installed R toolchain:
# R CMD check --as-cran .
```

## Recommended manual Shiny checklist

- New Jersey initial silhouette, county bloom, local bloom (Bergen), drag,
  dotted connector tracking and collapse.
- Texas 254-county bloom performance and 2 local-area subdivisions.
- Dark and light themes embedded in light and dark dashboard cards.
- Two map instances on a single page, different selected counties.
- Data-only Shiny updates preserve geographic offsets.
- Keyboard selection, reduced motion and small viewport/touch interactions.
- Single-file HTML publishing: confirm all geography files are copied with the
  widget dependency and no external network is requested.

Limitations of initial validation: the build environment has no R executable,
so R installation, R CMD check, Quarto, and a Shiny runtime have not been run.
Do not treat JavaScript/browser checks as substitutes for those release gates.
