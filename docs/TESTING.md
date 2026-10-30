# Testing bloomr

This guide is for package maintainers and contributors. The [README](../README.md) covers installation and everyday use.

## R package checks

From the directory containing the `bloomr` package folder:

```sh
R CMD build bloomr
R CMD check --as-cran bloomr_0.1.0.tar.gz
```

In R, also run:

```r
testthat::test_local("bloomr")
library(bloomr)
bloom_map()
run_bloom_example()
```

Install the package before running the example. Check that all three vignettes build and that the Shiny app works with selections and indicator updates.

## JavaScript and geography checks

Run from the package root:

```sh
node --check inst/htmlwidgets/lib/bloomr/bloom-core.js
node tests/browser/check-assets.js
python tests/browser/run_browser_smoke.py
python tests/browser/test_transitions.py
python tests/browser/test_boundaries_labels.py
python tests/browser/test_svg_export.py
```

The Python browser tests require Playwright and Chromium. They use bundled New Jersey and Texas geography.

## Check the user experience

- Expand and collapse both geographic levels; verify smooth return transitions.
- Drag an area and check that its origin dot and dotted connector stay aligned.
- Show and hide overview and local boundary lines independently.
- Try no labels, selected labels, and chosen labels.
- Change values through a Shiny proxy without moving the geography.
- Render two maps on one page and check that they stay independent.
- Test light and dark themes, narrow screens, hidden Shiny tabs, keyboard selection, and reduced motion.
- Publish an HTML report with its dependency folder and confirm that the map loads.

The browser tests do not replace an R package check. Confirm boundary-data provenance and redistribution permissions as part of publication review.
