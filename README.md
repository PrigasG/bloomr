# bloomr

**Interactive maps that keep geography in view.**

`bloomr` spreads geographic areas apart so you can explore them without losing their original locations. Dots and dotted lines connect each area to its position on the map. Use it in R, an HTML report, or a Shiny dashboard, with no JavaScript or CSS setup.

## Preview

![Expanded geographic areas connected to their original locations](man/figures/nj-county-bloom.png)

*County bloom using the included New Jersey map. The original boundaries, dots, and dotted connectors remain visible.*

## Installation

Install from [GitHub](https://github.com/PrigasG/bloomr):

```r
install.packages("remotes")
remotes::install_github("PrigasG/bloomr")
```

## Quick start

```r
library(bloomr)

bloom_map()
```

Choose **Bloom counties**, select a county, and then choose **Bloom municipalities** to explore smaller areas. Drag an area to move it, hover to see its name, or use **Back** to return.

The package includes ready-to-use maps for New Jersey (`"nj"`, the default) and Texas (`"tx"`). Both work without an online mapping service.

## Main features

### Keep the geographic connection

Origin dots, dotted connectors, and the original boundary lines are visible by default. They show where each expanded area belongs.

### Color the map with your data

Provide a data frame with geographic IDs and a numeric column:

```r
rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3)
)

bloom_map(data = rates, key = "geoid", value = "rate")
```

Keep geographic IDs as text so leading zeros are preserved. The package matches values to the included geography and displays missing values separately.

### Add a map to Shiny

```r
library(shiny)
library(bloomr)

ui <- fluidPage(bloomOutput("map"))

server <- function(input, output, session) {
  output$map <- renderBloom({ bloom_map() })
}

shinyApp(ui, server)
```

Read `input$map_selected` to connect selections to tables, charts, and other outputs. Use `bloom_update_data()` to update indicators without resetting the map. See [Using Bloom in Shiny](vignettes/using-in-shiny.Rmd).

## Customization

Light mode, tooltips, and smooth animations are on by default. Map labels are hidden to keep crowded areas easy to explore.

| Option | Default | Purpose |
| --- | --- | --- |
| `theme` | `"light"` | Light, dark, or automatic theme |
| `labels` | `"none"` | No labels, selected area, chosen areas, or non-overlapping labels |
| `dots` | `TRUE` | Show original locations |
| `connectors` | `TRUE` | Link expanded areas to their origins |
| `overview_boundaries` | `TRUE` | Show county lines on the original state map |
| `local_boundaries` | `TRUE` | Show municipality or subdivision lines in the county |
| `draggable` | `TRUE` | Move expanded areas |
| `duration` | `470` | Animation duration in milliseconds |

For example, show only two county labels while leaving hover tooltips available everywhere:

```r
bloom_map(labels = "custom", label_areas = c("bergen", "essex"))
```

Use the **Display** menu to change labels or boundary lines while exploring the map.

## More examples

- [Getting started](vignettes/getting-started.Rmd): explore a map and add indicator values.
- [Use Bloom in Shiny](vignettes/using-in-shiny.Rmd): link selections and update map values.
- [Appearance and keyboard](vignettes/appearance-and-keyboard.Rmd): themes, map guides, labels, and shortcuts.
- [Boundaries and labels](inst/examples/boundaries-and-labels.R): choose what appears on the map.
- [Two maps in Shiny](inst/examples/two-maps.R): use independent maps on the same page.

To open the included Shiny app:

```r
run_bloom_example()
```

## Troubleshooting

| Issue | What to check |
| --- | --- |
| Values do not appear | Check the numeric column and geographic IDs. Try `bloom_check_data(rates, value = "rate")`. |
| IDs have lost leading zeros | Read the ID column as character, not numeric. |
| Labels overlap or feel crowded | Keep `labels = "none"` or use `"custom"` to label selected locations. Tooltips still work. |
| A custom `sf` or GeoJSON map is rejected | `bloomr` accepts indicator data for its included NJ and TX maps; it does not accept replacement boundaries. |
| An exported HTML file cannot load map data | Keep the HTML file and its dependency folder together when publishing. |

See `?bloom_map` for the full function reference or visit the [GitHub repository](https://github.com/PrigasG/bloomr) for code and issues.
