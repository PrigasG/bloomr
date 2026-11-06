# Release checks for bloomr 0.1.0

Run these checks before publishing a GitHub release or submitting to CRAN.

## R and package checks

From the folder containing the `bloomr` source directory, use an RStudio **Terminal** (not the R Console):

```sh
R CMD build bloomr
R CMD check --as-cran bloomr_0.1.0.tar.gz
```

The check should finish with zero errors and zero warnings. Review and resolve notes that affect the release. These commands avoid the separate Windows Quarto environment-argument issue sometimes seen in `devtools::check()` reporting.

From within the package project, also run:

```r
devtools::document()
devtools::test()
pkgdown::build_site()
```

Inspect the generated `site/` pages for missing images, broken reference links, and vignette errors. To check documentation URLs, run `urlchecker::url_check()` if `urlchecker` is installed.

## Verify an actual spatial file

```r
library(bloomr)
file <- system.file("extdata", "demo-service-areas.geojson", package = "bloomr")
stopifnot(file.exists(file))
map <- bloom_map(file, parent = "district", id = "area_id", label = "area_name",
                 value = "rate", value_label = "Example rate", value_suffix = "%")
map
```

Check that four parent regions load. Bloom those regions, select one, expand its child areas, drag a shape, and return to the parent view. Confirm that origin dots and dotted connectors remain visible, labels are hidden by default, and hovering shows area names.

## Interactive and export checks

- Run `bloomr::run_bloom_example()` and verify that indicator updates do not reset the layout.
- Check NJ and Texas transitions, keyboard controls, light and dark themes, and narrow displays.
- Test two maps in one Shiny session; verify independent state and event IDs.
- Save a portable HTML widget and open it without a server.
- Review `.github/workflows/R-CMD-check.yaml` status for Windows, macOS, and Linux.
- Confirm pkgdown publishes the site's vignettes and reference pages.
- Confirm geographic attribution, data source versions, licenses, and redistribution permissions in [DATA_SOURCES.md](DATA_SOURCES.md).

## Release

Once checks and attribution review are complete, create and push the `v0.1.0` Git tag. Prepare a short GitHub release description from `NEWS.md`.
