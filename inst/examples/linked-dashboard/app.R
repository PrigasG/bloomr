# bloomr + ggplot2 + Plotly: 2020 county population explorer
# Run with: shiny::runApp(system.file("examples", "linked-dashboard", package = "bloomr"))
# Optional packages for this example: install.packages(c("ggplot2", "plotly"))

for (pkg in c("ggplot2", "plotly")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Install the optional package '", pkg, "' to run this example.", call. = FALSE)
  }
}

library(shiny)
library(bloomr)

# Read the county attributes already shipped with bloomr. No online data calls.
county_file <- system.file(
  "htmlwidgets", "lib", "bloomr-geo", "data", "nj_counties.geojson",
  package = "bloomr", mustWork = TRUE
)
features <- jsonlite::fromJSON(county_file, simplifyVector = FALSE)$features
county_data <- data.frame(
  id = vapply(features, function(f) f$properties$id, character(1)),
  geoid = vapply(features, function(f) f$properties$geoid, character(1)),
  county = vapply(features, function(f) f$properties$name, character(1)),
  population = vapply(features, function(f) f$properties$population_2020, numeric(1)),
  density = vapply(features, function(f) f$properties$population_density, numeric(1)),
  stringsAsFactors = FALSE
)

metric_specs <- list(
  population = list(label = "Population (2020)", suffix = "", short = "residents"),
  density = list(label = "Population density", suffix = " per sq mi", short = "people per sq mi")
)

ui <- fluidPage(
  tags$head(tags$style(HTML("\n    body { background: #f5f7fb; color: #1b2a3c; }\n    .bloomr-demo { max-width: 1480px; margin: 12px auto 40px; }\n    .bloomr-demo h2 { font-weight: 720; margin-top: 8px; }\n    .bloomr-demo-lead { color: #53667b; max-width: 850px; margin-bottom: 16px; }\n    .bloomr-demo-box { background: #fff; border: 1px solid #dae3ee;\n      border-radius: 12px; padding: 15px; margin-bottom: 16px; }\n    .bloomr-demo-box h4 { font-size: 16px; margin: 0 0 7px; font-weight: 650; }\n    .bloomr-demo-help { color: #596c81; font-size: 12px; line-height: 1.45; }\n    .bloomr-demo-map { min-height: 430px; }\n    .bloomr-demo-metric { font-size: 13px; color: #435c76; min-height: 20px; }\n    .bloomr-demo .form-group { margin-bottom: 8px; }\n    .bloomr-demo .control-label { font-size: 12px; }\n    .bloomr-demo-buttons { display: flex; gap: 8px; flex-wrap: wrap; padding: 16px 0 6px; }\n    .bloomr-demo-buttons .btn { border-radius: 7px; }\n    .bloomr-demo-footnote { font-size: 12px; color: #64748b; margin-top: 4px; }\n    @media(max-width:767px){ .bloomr-demo { margin: 4px 2px 24px; } }\n  "))),
  div(class = "bloomr-demo",
    h2("County population explorer"),
    p(class = "bloomr-demo-lead",
      "See how bloom size and spacing change a geographic map. Select a county in either Bloom view ",
      "or click a point in Plotly to explore the same county in the charts. ",
      "The example uses the 2020 population figures bundled with bloomr."),
    div(class = "bloomr-demo-box",
      fluidRow(
        column(3, selectInput("metric", "Color and chart measure",
          choices = c("Population" = "population", "Population density" = "density"),
          selected = "population", width = "100%")),
        column(3, sliderInput("size", "Expanded shape size", min = 1, max = 1.6,
          value = 1.6, step = 0.05, width = "100%")),
        column(3, sliderInput("spread", "Expanded spacing", min = 0.5, max = 1.5,
          value = 1.35, step = 0.05, width = "100%")),
        column(3, div(class = "bloomr-demo-buttons",
          actionButton("expand", "Bloom both maps", class = "btn-primary"),
          actionButton("reset", "Reset maps")))
      ),
      div(class = "bloomr-demo-help",
        "Shape size changes only the expanded geographic polygons. Spacing changes their distance apart. ",
        "Neither changes the underlying values, the original geographic boundaries, or the origin dots.")
    ),
    fluidRow(
      column(6, div(class = "bloomr-demo-box",
        h4("Standard Bloom (1.00× size, 1.00× spacing)"),
        p(class = "bloomr-demo-help", "Reference view using the package defaults."),
        bloomOutput("map_standard", height = "475px")
      )),
      column(6, div(class = "bloomr-demo-box",
        h4(textOutput("adjusted_heading", inline = TRUE)),
        p(class = "bloomr-demo-help", "Adjust the sliders above. This map changes without resetting its selection."),
        bloomOutput("map_adjusted", height = "475px")
      ))
    ),
    div(class = "bloomr-demo-box",
      h4("County details"),
      div(class = "bloomr-demo-metric", textOutput("selection_summary")),
      p(class = "bloomr-demo-help", "Selecting a local area keeps the county-level charts focused on its parent county.")
    ),
    fluidRow(
      column(6, div(class = "bloomr-demo-box",
        h4("County comparison | ggplot2"),
        plotOutput("county_bars", height = "370px")
      )),
      column(6, div(class = "bloomr-demo-box",
        h4("Population and density | Plotly"),
        plotly::plotlyOutput("county_scatter", height = "370px")
      ))
    ),
    p(class = "bloomr-demo-footnote",
      "Source: bundled New Jersey county attributes. Population is from the 2020 U.S. Census; ",
      "density is calculated using the included county area. See inst/COPYRIGHTS and ",
      "docs/DATA_SOURCES.md in bloomr for data details.")
  )
)

server <- function(input, output, session) {
  # Only the indicator changes. Geometry and interactive map positions are kept.
  selection_id <- reactiveVal(NULL)
  output$map_standard <- renderBloom({
    bloom_map("nj", data = county_data, key = "geoid", value = "population",
      value_label = "Population (2020)", tooltip_fields = c("Population" = "population",
      "Density" = "density"), controls = FALSE, appearance = "seamless")
  })
  output$map_adjusted <- renderBloom({
    bloom_map("nj", data = county_data, key = "geoid", value = "population",
      value_label = "Population (2020)", tooltip_fields = c("Population" = "population",
      "Density" = "density"), controls = FALSE, appearance = "seamless",
      bloom_scale = 1.6, bloom_spread = 1.35)
  })

  # The adjusted map receives changes through a proxy, not renderBloom().
  # Debounce limits geographic re-layout while someone drags a slider.
  tuned <- shiny::debounce(reactive(list(size = input$size, spread = input$spread)), 250)
  observeEvent(tuned(), {
    bloom_update_bloom(bloomProxy("map_adjusted"),
      bloom_scale = tuned()$size, bloom_spread = tuned()$spread)
  }, ignoreInit = TRUE)

  output$adjusted_heading <- renderText({
    sprintf("Adjusted Bloom (%.2f× size, %.2f× spacing)", input$size, input$spread)
  })

  observeEvent(input$expand, {
    bloom_expand(bloomProxy("map_standard"), "county")
    bloom_expand(bloomProxy("map_adjusted"), "county")
  })
  observeEvent(input$reset, {
    bloom_reset(bloomProxy("map_standard"))
    bloom_reset(bloomProxy("map_adjusted"))
    selection_id(NULL)
  })

  observeEvent(input$metric, {
    spec <- metric_specs[[input$metric]]
    for (id in c("map_standard", "map_adjusted")) {
      bloom_update_data(bloomProxy(id), county_data, key = "geoid",
        value = input$metric, value_label = spec$label,
        value_suffix = spec$suffix)
    }
  }, ignoreInit = TRUE)

  use_selection <- function(x) {
    if (is.null(x)) return()
    # A local-area selection references its parent county by `parent_id`.
    index <- if (identical(x$level, "local")) {
      match(as.character(x$parent_id), county_data$id)
    } else {
      match(as.character(x$geoid), county_data$geoid)
    }
    if (length(index) == 1L && !is.na(index)) selection_id(county_data$geoid[index])
  }
  observeEvent(input$map_standard_selected, use_selection(input$map_standard_selected))
  observeEvent(input$map_adjusted_selected, use_selection(input$map_adjusted_selected))

  # Plotly is bidirectional: click a point to highlight its county on both maps.
  observeEvent(plotly::event_data("plotly_click", source = "county_scatter"), {
    event <- plotly::event_data("plotly_click", source = "county_scatter")
    if (is.null(event) || is.null(event$key) || !length(event$key)) return()
    geo_id <- as.character(event$key[[1]])
    if (!geo_id %in% county_data$geoid) return()
    selection_id(geo_id)
    for (map_id in c("map_standard", "map_adjusted")) {
      bloom_select(bloomProxy(map_id), geo_id)
    }
  })

  selected_row <- reactive({
    id <- selection_id()
    if (is.null(id)) return(NULL)
    county_data[match(id, county_data$geoid), , drop = FALSE]
  })
  output$selection_summary <- renderText({
    row <- selected_row()
    if (is.null(row)) return("Select a county on either Bloom map or in Plotly to inspect it.")
    sprintf("%s | %s residents in 2020 | %s residents per square mile",
      row$county, format(row$population, big.mark = ",", scientific = FALSE),
      format(round(row$density), big.mark = ",", scientific = FALSE))
  })

  output$county_bars <- renderPlot({
    metric <- input$metric
    spec <- metric_specs[[metric]]
    d <- county_data[order(county_data[[metric]], decreasing = TRUE), , drop = FALSE]
    d <- utils::head(d, 12)
    chosen <- selected_row()
    if (!is.null(chosen) && !chosen$geoid %in% d$geoid) {
      d <- rbind(d, chosen)
    }
    d$county <- factor(d$county, levels = rev(d$county))
    d$chart_value <- d[[metric]]
    d$highlight <- if (!is.null(chosen)) d$geoid == chosen$geoid else FALSE
    ggplot2::ggplot(d, ggplot2::aes(x = county, y = chart_value, fill = highlight)) +
      ggplot2::geom_col(width = .75) +
      ggplot2::coord_flip() +
      ggplot2::scale_fill_manual(values = c(`FALSE` = "#9dbad5", `TRUE` = "#e59c37"), guide = "none") +
      ggplot2::scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) +
      ggplot2::labs(x = NULL, y = spec$label) +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank())
  }, res = 105)

  output$county_scatter <- plotly::renderPlotly({
    chosen <- selected_row()
    d <- county_data
    d$highlight <- factor(if (is.null(chosen)) "Other" else
      ifelse(d$geoid == chosen$geoid, "Selected", "Other"),
      levels = c("Other", "Selected"))
    d$hover_text <- sprintf("%s<br>Population (2020): %s<br>Density: %s / sq mi",
      d$county,
      format(d$population, big.mark = ",", scientific = FALSE, trim = TRUE),
      format(round(d$density), big.mark = ",", scientific = FALSE, trim = TRUE))
    plotly::plot_ly(d, x = ~population, y = ~density, key = ~geoid,
      text = ~hover_text, hoverinfo = "text", source = "county_scatter",
      color = ~highlight, colors = c(Other = "#96b4cf", Selected = "#e59c37"),
      type = "scatter", mode = "markers", showlegend = FALSE,
      marker = list(size = 12, opacity = .85)) |>
      plotly::layout(xaxis = list(title = "Residents (2020)", tickformat = ","),
        yaxis = list(title = "Residents per square mile"),
        margin = list(l = 65, r = 15, t = 15, b = 55),
        paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff") |>
      plotly::config(displaylogo = FALSE)
  })
}

shinyApp(ui, server)
