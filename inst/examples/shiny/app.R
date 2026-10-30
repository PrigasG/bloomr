library(shiny)
library(bloomr)

# Demonstrates geography, embedding, external selection, and reactive colors.
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
      helpText("Select a county to send its data to Shiny. Use Display on the map for boundary lines and labels. Map positions stay put when values change."),
      verbatimTextOutput("selected")
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
  output$selected <- renderPrint({
    req(input$map_selected)
    input$map_selected
  })
}
shinyApp(ui, server)
