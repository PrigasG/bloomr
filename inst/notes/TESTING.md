# Tests

Run these browser checks from the editable source ZIP:

```sh
node --check inst/htmlwidgets/lib/bloomr/bloom-core.js
node tests/browser/check-assets.js
python tests/browser/run_browser_smoke.py
python tests/browser/test_transitions.py
python tests/browser/test_svg_export.py
```

The tests cover real NJ/TX bundled geography, dotted connectors, Shiny-style
selection events, value updates, multiple widgets, camera return, keyboard
navigation and reduced motion.

When R is available, install the dependencies, build the package, and run:

```sh
R CMD build bloomr
R CMD check --as-cran bloomr_0.1.0.tar.gz
```

The initial archive is assembled without an R executable. A real R build and
Shiny deployment test are required before calling 0.1.0 a public release.
