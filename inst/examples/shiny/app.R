library(shiny)
library(bloomr)

# Example data from the included county boundaries.
raw <- jsonlite::fromJSON(system.file(
  "htmlwidgets", "lib", "bloomr-geo", "data", "nj_counties.geojson",
  package = "bloomr"
), simplifyVector = FALSE)
county_data <- data.frame(
  geoid = vapply(raw$features, function(x) x$properties$geoid, character(1)),
  population = vapply(raw$features, function(x) as.numeric(x$properties$population_2020), numeric(1)),
  density = vapply(raw$features, function(x) as.numeric(x$properties$population_density), numeric(1)),
  stringsAsFactors = FALSE
)

ui <- fluidPage(
  titlePanel("Bloom in a Shiny dashboard"),
  fluidRow(
    column(3,
      selectInput("measure", "Indicator", c("Population" = "population", "Density" = "density")),
      helpText("Click the map to bloom counties, then select one to see its name."),
      textOutput("selected")
    ),
    column(9, bloomOutput("map", height = "550px"))
  )
)
server <- function(input, output, session) {
  output$map <- renderBloom({
    bloom_map("nj", data = county_data, key = "geoid", value = "population")
  })
  observeEvent(input$measure, {
    bloom_update_data(bloomProxy("map"), county_data, key = "geoid", value = input$measure)
  }, ignoreInit = TRUE)
  output$selected <- renderText({
    selection <- input$map_selected
    if (is.null(selection)) return("No location selected yet.")
    paste0("Selected: ", selection$name, " (", selection$level, ")")
  })
}
shinyApp(ui, server)
