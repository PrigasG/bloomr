# A Bloom map that blends into an existing Shiny dashboard.
library(shiny)
library(bloomr)

ui <- fluidPage(
  h3("Explore geographic areas"),
  bloomOutput("map", height = "480px")
)

server <- function(input, output, session) {
  output$map <- renderBloom({
    bloom_map(appearance = "seamless", controls = FALSE)
  })
}

shinyApp(ui, server)
