#' Create an interactive hierarchical Bloom map
#'
#' A light-first, self-contained widget with parent-origin dots, curved dotted
#' connectors, animated county and local-area blooms, dragging, and selection.
#' New Jersey and Texas are bundled; no external geography service is required.
#' Direct geography rendering is available without supplying data.
#'
#' @param geography Either `"nj"` or `"tx"` (case-insensitive).
#' @param data Optional data frame with geographic identifiers and measured values.
#' @param key Name of the identifier column, such as `"geoid"`.
#' @param value Name of the numeric indicator column. Optional when `data` is `NULL`.
#' @param theme One of `"light"` (default), `"dark"`, or `"auto"`.
#' @param preset One of `"dashboard"`, `"viewer"`, or `"studio"`. All three
#'   retain origin dots and dotted connectors.
#' @param dots,connectors Whether to show original geographic anchors and
#'   connecting guide lines. Both default to `TRUE`.
#' @param overview_boundaries Show county outlines in the original state map.
#'   Default `TRUE`.
#' @param local_boundaries Show municipality/subdivision outlines inside the
#'   selected county. Default `TRUE`.
#' @param labels Label mode: `"none"` (default), `"selected"`, `"all"`, or
#'   `"custom"`. Tooltips work in every mode. `"all"` hides overlapping labels.
#' @param label_areas Character vector of area identifiers to label when
#'   `labels = "custom"`. Viewers can also Shift+click an area or press L on a
#'   focused area to add or remove its label.
#' @param draggable Whether expanded regions can be dragged. Default `TRUE`.
#' @param duration Bloom/unbloom duration in milliseconds, default 470.
#' @param height,width htmlwidget size, e.g. `"520px"`, `"100%"`.
#' @return An `htmlwidget` suitable for Shiny, Quarto HTML, and R Markdown HTML.
#' @examples
#' bloom_map("nj")
#' bloom_map("nj", labels = "custom", label_areas = c("bergen", "essex"))
#' bloom_map("tx", theme = "dark")
#' @export
bloom_map <- function(geography = "nj", data = NULL, key = "geoid", value = NULL,
                      theme = c("light", "dark", "auto"),
                      preset = c("dashboard", "viewer", "studio"),
                      dots = TRUE, connectors = TRUE,
                      overview_boundaries = TRUE, local_boundaries = TRUE,
                      labels = c("none", "selected", "all", "custom"),
                      label_areas = character(), draggable = TRUE,
                      duration = 470, width = NULL, height = "520px") {
  geography <- tolower(as.character(geography))
  if (length(geography) != 1L || is.na(geography) || !geography %in% c("nj", "tx")) {
    stop("`geography` must be 'nj' or 'tx'.", call. = FALSE)
  }
  theme <- match.arg(theme)
  preset <- match.arg(preset)
  labels <- match.arg(labels)
  if (!is.character(label_areas) || anyNA(label_areas)) {
    stop("`label_areas` must be a character vector without missing values.", call. = FALSE)
  }
  if (!is.numeric(duration) || length(duration) != 1L || !is.finite(duration) || duration < 0) {
    stop("`duration` must be one nonnegative number.", call. = FALSE)
  }
  flags <- list(dots = dots, connectors = connectors, draggable = draggable,
                overview_boundaries = overview_boundaries,
                local_boundaries = local_boundaries)
  for (name in names(flags)) {
    flag <- flags[[name]]
    if (!is.logical(flag) || length(flag) != 1L || is.na(flag)) {
      stop(sprintf("`%s` must be TRUE or FALSE.", name), call. = FALSE)
    }
  }
  rows <- .bloom_rows(data, key, value)
  htmlwidgets::createWidget(
    name = "bloom_map",
    x = list(geography = geography,
             theme = theme, preset = preset, dots = dots, connectors = connectors,
             overviewBoundaries = overview_boundaries, localBoundaries = local_boundaries,
             labels = labels, labelAreas = as.character(label_areas),
             draggable = draggable, duration = as.numeric(duration),
             data = rows),
    width = width, height = height, package = "bloomr"
  )
}

.bloom_rows <- function(data, key, value) {
  if (is.null(data)) return(NULL)
  if (!is.data.frame(data)) stop("`data` must be a data.frame or tibble.", call. = FALSE)
  if (!is.character(key) || length(key) != 1L || !key %in% names(data)) {
    stop(sprintf("Identifier column '%s' was not found in `data`.", paste(key, collapse = ", ")), call. = FALSE)
  }
  if (is.null(value) || !is.character(value) || length(value) != 1L || !value %in% names(data)) {
    stop("Set `value` to the name of a numeric column in `data`.", call. = FALSE)
  }
  if (!is.numeric(data[[value]])) stop("`value` must identify a numeric column.", call. = FALSE)
  keys <- trimws(as.character(data[[key]]))
  if (anyNA(data[[key]]) || any(!nzchar(keys))) {
    stop("`key` contains missing or blank identifiers.", call. = FALSE)
  }
  if (anyDuplicated(keys)) stop("`key` must contain unique geography identifiers.", call. = FALSE)
  if (any(grepl("^[0-9]+$", keys) & nchar(keys) < 5L)) {
    warning("Short numeric GEOIDs detected. Read GEOIDs as character to retain leading zeros.", call. = FALSE)
  }
  lapply(seq_along(keys), function(i) {
    v <- data[[value]][i]
    list(id = keys[i], value = if (is.finite(v)) as.numeric(v) else NULL)
  })
}

#' Check data before displaying a Bloom map
#' @param data A data frame.
#' @param key Identifier column.
#' @param value Numeric value column.
#' @return A named list with validation and row count.
#' @export
bloom_check_data <- function(data, key = "geoid", value) {
  rows <- .bloom_rows(data, key, value)
  list(valid = TRUE, rows = length(rows), missing_values = sum(vapply(rows, function(x) is.null(x$value), logical(1))))
}
