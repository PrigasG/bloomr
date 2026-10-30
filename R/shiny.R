#' Place a Bloom map in a Shiny UI
#' @param outputId Shiny output ID.
#' @param width,height CSS sizing strings.
#' @return Shiny UI tag.
#' @export
bloomOutput <- function(outputId, width = "100%", height = "520px") {
  htmlwidgets::shinyWidgetOutput(outputId, "bloom_map", width, height, package = "bloomr")
}

#' Render a Bloom map in Shiny
#' @param expr An expression returning `bloom_map()`.
#' @param env,quoted Standard Shiny rendering arguments.
#' @return Shiny render function.
#' @export
renderBloom <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(expr, bloomOutput, env, quoted = TRUE)
}

#' Create a command proxy for an existing map
#' @param outputId Map output ID.
#' @param session A Shiny session; defaults to the current reactive domain.
#' @export
bloomProxy <- function(outputId, session = shiny::getDefaultReactiveDomain()) {
  if (is.null(session)) stop("No Shiny session available.", call. = FALSE)
  structure(list(id = session$ns(outputId), session = session), class = "bloomr_proxy")
}

.bloom_command <- function(proxy, command, args = list()) {
  if (!inherits(proxy, "bloomr_proxy")) stop("Use bloomProxy() to create a proxy.", call. = FALSE)
  proxy$session$sendCustomMessage("bloomr:command", list(id = proxy$id, command = command, args = args))
  invisible(proxy)
}

#' Select a geography without resetting its layout
#' @param proxy Result of `bloomProxy()`.
#' @param id Geographic identifier, such as `"bergen"` or `"34003"`.
#' @export
bloom_select <- function(proxy, id) .bloom_command(proxy, "select", list(id = as.character(id)))

#' Expand the state or the selected county
#' @param proxy Result of `bloomProxy()`.
#' @param level `"county"` or `"local"`.
#' @export
bloom_expand <- function(proxy, level = c("county", "local")) {
  .bloom_command(proxy, "expand", list(level = match.arg(level)))
}

#' Update map values without rebuilding geography or resetting positions
#' @param proxy Result of `bloomProxy()`.
#' @param data A data.frame with unique geographic identifiers.
#' @param key,value Column names.
#' @export
bloom_update_data <- function(proxy, data, key = "geoid", value) {
  .bloom_command(proxy, "data", list(rows = .bloom_rows(data, key, value)))
}

#' Return a Bloom map to its initial state
#' @param proxy Result of `bloomProxy()`.
#' @export
bloom_reset <- function(proxy) .bloom_command(proxy, "reset")

#' Run the bundled Shiny integration example
#' @export
run_bloom_example <- function() {
  shiny::runApp(system.file("examples", "shiny", package = "bloomr"))
}
