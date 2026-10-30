# bloomr

**Interactive geographic maps that keep their connections.**

`bloomr` lets you spread geographic areas apart to explore them more easily, without losing sight of where they belong. Original-location dots and dotted lines link each expanded area back to its place on the map. Add a Bloom map to an R workflow, HTML report, or Shiny dashboard with just a few lines of code.

## Preview

![An expanded county map with original-location dots and dotted connector lines](man/figures/nj-county-bloom.png)

*An example using the included New Jersey boundaries. The original county outlines remain visible while areas expand outward.*

## Installation

For the current v0.1.0 source release, download `bloomr_0.1.0.tar.gz` and install it:

```r
install.packages(c("htmlwidgets", "htmltools", "jsonlite", "shiny"))
install.packages("path/to/bloomr_0.1.0.tar.gz", repos = NULL, type = "source")
```

Once **CRAN** and **GitHub** releases are available, the installation commands will be:

```r
# CRAN, after publication
install.packages("bloomr")

# GitHub, after the repository is public
# Replace ACCOUNT with the repository owner's GitHub username.
install.packages("remotes")
remotes::install_github("ACCOUNT/bloomr")
```

The source release includes its map assets. No online mapping service or `sf` installation is needed for the included examples.

## Quick start

```r
library(bloomr)

bloom_map()
```

Choose **Bloom counties** to expand the map. Select a county and choose **Bloom municipalities** to explore smaller areas. Drag shapes to rearrange them, hover for names, and use **Back** to return to the previous view.

The default example uses New Jersey. You can also try the included Texas map with `bloom_map("tx")`. Version 0.1.0 includes prepared geography for these two examples; you can add your own indicator data, but custom geographic boundaries are not yet supported.

## Main features

### See where each area came from

Dots mark original locations, dotted connectors follow expanded shapes, and the original boundaries remain visible. All three are enabled by default, so you don't need to configure anything.

### Explore your own data

Add numeric values to the map using a geographic ID:

```r
rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3)
)

bloom_map(data = rates, key = "geoid", value = "rate")
```

Keep identifiers such as GEOIDs as text to preserve leading zeros. Missing values are displayed separately from valid numbers.

### Add Bloom to Shiny

```r
library(shiny)

ui <- fluidPage(bloomOutput("map"))

server <- function(input, output, session) {
  output$map <- renderBloom({ bloom_map() })
}

shinyApp(ui, server)
```

Selections are available through `input$map_selected`. See [Using Bloom in Shiny](vignettes/using-in-shiny.Rmd) for reactive values, linked outputs, and updates that keep the current map layout.

## Customization

The defaults are designed for clean, light-colored dashboards. Hover tooltips stay on, while printed map labels stay off to avoid crowding.

| Option | Default | What it changes |
| --- | --- | --- |
| `theme` | `"light"` | Use `"dark"` or `"auto"` when needed |
| `labels` | `"none"` | Show selected, all non-overlapping, or chosen labels |
| `dots` | `TRUE` | Mark each area's original location |
| `connectors` | `TRUE` | Draw dotted lines back to original locations |
| `overview_boundaries` | `TRUE` | Show county lines in the original state map |
| `local_boundaries` | `TRUE` | Show municipality or subdivision lines in the selected county |
| `draggable` | `TRUE` | Allow expanded areas to be moved |
| `duration` | `470` | Set animation time in milliseconds |

For example, label only a few areas while keeping tooltips for the rest:

```r
bloom_map(
  labels = "custom",
  label_areas = c("bergen", "essex")
)
```

Use the map's **Display** menu to change boundary and label visibility interactively. The overview and local boundary controls work independently.

## More examples

- [Getting started](vignettes/getting-started.Rmd): your first map and indicator data.
- [Using Bloom in Shiny](vignettes/using-in-shiny.Rmd): selections, reactive updates, and dashboard integration.
- [Appearance and keyboard](vignettes/appearance-and-keyboard.Rmd): themes, boundaries, labels, and shortcuts.
- [Boundaries and labels example](inst/examples/boundaries-and-labels.R): simple display settings.
- [Two-map Shiny example](inst/examples/two-maps.R): independent maps on one page.

Want to try a complete Shiny example? Run:

```r
bloomr::run_bloom_example()
```

## Troubleshooting

| If you see... | Try this |
| --- | --- |
| Areas are gray or values are missing | Check that your geographic IDs match the included boundaries and that the value column is numeric. Use `bloom_check_data(rates, value = "rate")` for the example above. |
| A warning about short GEOIDs | Read the ID column as character to preserve leading zeros. |
| The map feels crowded | Keep `labels = "none"` (the default), or use `labels = "custom"` to label only chosen areas. Tooltips still work. |
| An error for custom `sf` or GeoJSON geography | Version 0.1.0 accepts your own indicator values, but not replacement boundaries. |
| A saved HTML page is missing assets | Publish the HTML file together with its generated dependency folder. Single-file HTML export is not yet verified. |

For all arguments, see `?bloom_map`. For a working dashboard, start with `bloomr::run_bloom_example()`.
