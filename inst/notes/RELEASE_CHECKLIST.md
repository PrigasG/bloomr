# Version 0.1.0 release checklist

This is a small release, not a plan for adding more map controls.

## Before publishing

- [ ] Replace placeholder author/maintainer email in `DESCRIPTION`.
- [ ] Replace the placeholder copyright holder in `LICENSE`.
- [ ] Confirm the NJ and Texas geometry sources, dates, permissions, and credits.
- [ ] Install the source archive in a fresh R library.
- [ ] Run `R CMD build bloomr` and `R CMD check --as-cran bloomr_0.1.0.tar.gz`.
- [ ] Run `testthat::test_local("bloomr")` or `devtools::test("bloomr")`.
- [ ] Run the browser tests in `tests/browser/` before building the archive.
- [ ] Open the example in Shiny and verify selection plus data updates.
- [ ] Check the default NJ map in a light dashboard, and TX in dark mode.
- [ ] Check keyboard focus, Escape, reduced motion, mobile toolbar and a hidden Shiny tab.
- [ ] Verify all three vignettes build and installed examples run.

## Browser tests

From the source directory:

```sh
node --check inst/htmlwidgets/lib/bloomr/bloom-core.js
node tests/browser/check-assets.js
python tests/browser/run_browser_smoke.py
python tests/browser/test_transitions.py
python tests/browser/test_svg_export.py
```

The browser scripts are included in the **editable source ZIP**, not the
minimal R package tarball. They require Playwright and Chromium. Browser success does not
replace an R installation check. The tarball provided with this release candidate
was assembled in an environment without R, so it must be rebuilt with
`R CMD build` after the checks above.

## Stable defaults

- Light theme with all CSS scoped to the map.
- Original-location dots and dotted connectors enabled.
- No outside JavaScript CDN and no external geographic server at runtime.
- Smooth county/local transitions, including the return camera.
- Numeric data updates do not change dragged positions.
- Small public API and built-in examples.

## After version 0.1.0

Custom `sf` geography, full lab-style history and advanced visual editing can
wait. They should not delay the small initial release.
