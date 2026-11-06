# Use bloomr alongside ggplot2 and Plotly in a Shiny dashboard.
# This optional example also needs ggplot2 and plotly installed.

for (pkg in c("ggplot2", "plotly")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Install the optional package '", pkg, "' to run this example.", call. = FALSE)
  }
}

library(shiny)
library(bloomr)

# Use the county indicators bundled with bloomr for this demonstration.
# The same pattern works with your own geography and indicator data.
geojson <- system.file(
  "htmlwidgets", "lib", "bloomr-geo", "data", "nj_counties.geojson",
  package = "bloomr", mustWork = TRUE
)
features <- jsonlite::fromJSON(geojson, simplifyVector = FALSE)$features

counties <- data.frame(
  id = vapply(features, function(x) x$properties$id, character(1)),
  geoid = vapply(features, function(x) x$properties$geoid, character(1)),
  county = vapply(features, function(x) x$properties$name, character(1)),
  population = vapply(features, function(x) x$properties$population_2020, numeric(1)),
  density = vapply(features, function(x) x$properties$population_density, numeric(1)),
  stringsAsFactors = FALSE
)

ui <- fluidPage(
  tags$head(tags$style(HTML("\n    .bloomr-coexist { max-width: 1400px; margin: 0 auto; }
    .bloomr-coexist .intro { color: #526176; margin-bottom: 20px; }
    .bloomr-coexist .plot-panel { background: #fff; border: 1px solid #e0e6ef;
      border-radius: 10px; padding: 12px; margin-bottom: 14px; }
    .bloomr-coexist .plot-panel h4 { margin: 0 0 8px; font-weight: 600; }
    .bloomr-coexist .selected-text { min-height: 22px; color: #43516a; }
  "))),
  div(class = "bloomr-coexist",
    h2("Bloom with ggplot2 and Plotly"),
    p(class = "intro",
      "Click the map to bloom counties, then select one to highlight it in both charts. ",
      "The example uses 2020 county data supplied with bloomr."),
    fluidRow(
      column(7,
        div(class = "plot-panel",
          h4("Geographic view · bloomr"),
          bloomOutput("map", height = "585px")
        )
      ),
      column(5,
        div(class = "plot-panel",
          h4("County density · ggplot2"),
          plotOutput("density_plot", height = "230px"),
          div(class = "selected-text", textOutput("selected_area"))
        ),
        div(class = "plot-panel",
          h4("Population and density · Plotly"),
          plotly::plotlyOutput("comparison_plot", height = "275px")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # Bloom uses the same rows as the two charts.
  output$map <- renderBloom({
    bloom_map(
      geography = "nj", data = counties, key = "geoid", value = "density",
      value_label = "Population density", value_suffix = " people/mi²",
      tooltip_fields = c("Population" = "population"),
      appearance = "seamless", controls = FALSE,
      style = list(bloom_outline_color = "#2C6FA8",
                   bloom_outline_width = 2,
                   connector_color = "#64748B", dot_color = "#2563EB",
                   selected_outline_color = "#2563EB")
    )
  })

  # Clicking a county returns its GEOID. When a smaller area is selected,
  # use its parent county ID so the county-level charts still make sense.
  selected_county <- reactive({
    selection <- input$map_selected
    if (is.null(selection)) return(NULL)
    if (identical(selection$level, "county")) {
      key <- selection$geoid
      index <- match(key, counties$geoid)
    } else if (identical(selection$level, "local")) {
      key <- selection$parent_id
      index <- match(key, counties$id)
    } else {
      return(NULL)
    }
    if (length(index) != 1L || is.na(index)) return(NULL)
    counties[index, , drop = FALSE]
  })

  output$selected_area <- renderText({
    selected <- selected_county()
    if (is.null(selected)) {
      "Select a county in Bloom to highlight it in both charts."
    } else {
      paste("Highlighted:", selected$county)
    }
  })

  output$density_plot <- renderPlot({
    chart <- ggplot2::ggplot(counties, ggplot2::aes(x = density)) +
      ggplot2::geom_histogram(
        bins = 8, fill = "#adc8e8", color = "white", linewidth = 0.6
      ) +
      ggplot2::labs(x = "People per square mile", y = "Counties") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    selected <- selected_county()
    if (!is.null(selected)) {
      chart <- chart + ggplot2::geom_vline(
        xintercept = selected$density, color = "#2563eb", linewidth = 1.1
      )
    }
    chart
  }, res = 96)

  output$comparison_plot <- plotly::renderPlotly({
    selected <- selected_county()
    chart_data <- counties
    chart_data$population_millions <- chart_data$population / 1e6
    chart_data$highlight <- factor(
      if (is.null(selected)) {
        rep("Other", nrow(chart_data))
      } else {
        ifelse(chart_data$geoid == selected$geoid, "Selected", "Other")
      },
      levels = c("Other", "Selected")
    )
    chart_data$hover_text <- sprintf(
      "%s<br>Population: %s<br>Density: %s per mi²",
      chart_data$county,
      format(chart_data$population, big.mark = ",", scientific = FALSE, trim = TRUE),
      format(round(chart_data$density), big.mark = ",", scientific = FALSE, trim = TRUE)
    )

    plotly::plot_ly(
      data = chart_data, x = ~population_millions, y = ~density,
      text = ~hover_text, hoverinfo = "text", type = "scatter", mode = "markers",
      color = ~highlight,
      colors = c("Other" = "#9cb5cc", "Selected" = "#2563eb"),
      marker = list(size = 11, opacity = 0.9), showlegend = FALSE
    ) |>
      plotly::layout(
        xaxis = list(title = "Population (millions)", zeroline = FALSE),
        yaxis = list(title = "People per square mile", zeroline = FALSE),
        margin = list(l = 70, r = 18, b = 52, t = 12),
        plot_bgcolor = "#ffffff", paper_bgcolor = "#ffffff"
      ) |>
      plotly::config(displaylogo = FALSE)
  })
}

shinyApp(ui, server)
