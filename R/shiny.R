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
#' @return A `bloomr_proxy` object containing the map output ID and Shiny session.
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
#' @return Invisibly returns `proxy` after sending the selection command.
#' @export
bloom_select <- function(proxy, id) .bloom_command(proxy, "select", list(id = as.character(id)))

#' Expand the state or the selected county
#' @param proxy Result of `bloomProxy()`.
#' @param level `"county"` or `"local"`.
#' @return Invisibly returns `proxy` after sending the expansion command.
#' @export
bloom_expand <- function(proxy, level = c("county", "local")) {
  .bloom_command(proxy, "expand", list(level = match.arg(level)))
}

#' Update map values without rebuilding geography or resetting positions
#' @param proxy Result of `bloomProxy()`.
#' @param data A data.frame with unique geographic identifiers.
#' @param key,value Column names.
#' @param tooltip_fields Optional named character vector of additional tooltip
#'   fields to update alongside the indicator values.
#' @param tooltip_data Optional separate tooltip data frame, using `key` as
#'   its identifier column. Existing tooltip details are preserved when
#'   `tooltip_fields` is not supplied.
#' @param value_label Optional new legend title (keeps the current title when
#'   `NULL`). Useful when switching the indicator in a running dashboard.
#' @param value_suffix Optional new unit suffix, such as `"%"` or
#'   `" people/mi2"`; `NULL` preserves the current suffix.
#' @return Invisibly returns `proxy` after sending the updated data.
#' @export
bloom_update_data <- function(proxy, data, key = "geoid", value,
                              tooltip_fields = NULL, tooltip_data = NULL,
                              value_label = NULL, value_suffix = NULL) {
  if (!is.null(tooltip_data) && is.null(tooltip_fields)) {
    stop("Set `tooltip_fields` when providing `tooltip_data`.", call. = FALSE)
  }
  args <- list(rows = .bloom_rows(data, key, value))
  if (!is.null(value_label)) {
    if (!is.character(value_label) || length(value_label) != 1L || is.na(value_label)) {
      stop("`value_label` must be one text string.", call. = FALSE)
    }
    args$valueLabel <- value_label
  }
  if (!is.null(value_suffix)) {
    if (!is.character(value_suffix) || length(value_suffix) != 1L || is.na(value_suffix)) {
      stop("`value_suffix` must be one text string.", call. = FALSE)
    }
    args$valueSuffix <- value_suffix
  }
  if (!is.null(tooltip_fields)) {
    args$tooltipRows <- .bloom_tooltip_rows(
      if (is.null(tooltip_data)) data else tooltip_data, key, tooltip_fields)
    if (is.null(args$tooltipRows)) args$tooltipRows <- list()
  }
  .bloom_command(proxy, "data", args)
}

#' Adjust Bloom size and spacing in a running Shiny map
#'
#' Changes an existing map without rebuilding its geography. Current
#' selections and manually moved positions are preserved. The settings are
#' also available when creating a map with [bloom_map()].
#'
#' @param proxy Result of [bloomProxy()].
#' @param bloom_scale Optional size of expanded areas, from `1` to `1.6`.
#'   `1` keeps the original polygon size; `1.6` makes it 60 percent larger.
#' @param bloom_spread Optional spacing between expanded areas, from `0.5`
#'   to `1.5`. This does not change their shape size.
#' @return Invisibly returns `proxy`.
#' @examples
#' if (interactive()) {
#'   # Inside a Shiny server, after the map has rendered:
#'   # bloom_update_bloom(bloomProxy("map"), bloom_scale = 1.5)
#' }
#' @export
bloom_update_bloom <- function(proxy, bloom_scale = NULL, bloom_spread = NULL) {
  if (is.null(bloom_scale) && is.null(bloom_spread)) {
    stop("Set `bloom_scale` and/or `bloom_spread`.", call. = FALSE)
  }
  check <- function(x, name, lower, upper) {
    if (is.null(x)) return(NULL)
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
        x < lower || x > upper) {
      stop(sprintf("`%s` must be one number from %s to %s.", name, lower, upper),
           call. = FALSE)
    }
    as.numeric(x)
  }
  scale <- check(bloom_scale, "bloom_scale", 1, 1.6)
  spread <- check(bloom_spread, "bloom_spread", 0.5, 1.5)
  args <- list()
  if (!is.null(scale)) args$bloomScale <- scale
  if (!is.null(spread)) args$bloomSpread <- spread
  .bloom_command(proxy, "bloom", args)
}

#' Return a Bloom map to its initial state
#' @param proxy Result of `bloomProxy()`.
#' @return Invisibly returns `proxy` after sending the reset command.
#' @export
bloom_reset <- function(proxy) .bloom_command(proxy, "reset")

#' Run the bundled Shiny integration example
#' @return The value of [shiny::runApp()] after the app closes, normally `NULL`.
#' @export
run_bloom_example <- function() {
  shiny::runApp(system.file("examples", "shiny", package = "bloomr"))
}
