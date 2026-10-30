# Two independent maps in one Shiny dashboard
library(shiny)
library(bloomr)

ui <- fluidPage(
  fluidRow(
    column(6, bloomOutput("nj", height = "440px")),
    column(6, bloomOutput("tx", height = "440px"))
  )
)
server <- function(input, output, session) {
  output$nj <- renderBloom({ bloom_map("nj") })
  output$tx <- renderBloom({ bloom_map("tx", theme = "dark") })
}
shinyApp(ui, server)
