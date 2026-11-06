# Publish the bloomr website

The package website uses the README as its home page, the R help files as its reference, and the four vignettes as guides.

## Preview locally

Run from the package root:

```r
install.packages(c("pkgdown", "rmarkdown", "knitr"))
pkgdown::build_site()
```

Open `site/index.html` to preview it. The generated site is ignored by Git and excluded from the CRAN source tarball.

## Publish with GitHub Pages

1. Push `_pkgdown.yml` and `.github/workflows/pkgdown.yaml` to `master`.
2. In **Settings > Pages**, set **Build and deployment** to **GitHub Actions**.
3. Open **Actions > pkgdown** and select **Run workflow** if it has not run automatically.
4. Once deployment succeeds, visit https://prigasg.github.io/bloomr/ and check the Get started, Reference, Guides, and Changelog pages.

The workflow deploys directly through GitHub Pages Actions. It creates no `gh-pages` branch. Updates to `master` rebuild the site.

Site files are generated during CI and do not need to be committed.

## Before announcing v0.1.0

From the parent folder containing the `bloomr` directory, run the package checks in [RELEASE_CHECKS.md](RELEASE_CHECKS.md). Confirm the GitHub checks pass, the spatial-file example works, and the geographic data attribution review is complete. Create the `v0.1.0` tag only after these checks.
