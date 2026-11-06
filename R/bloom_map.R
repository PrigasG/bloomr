#' Create an interactive hierarchical Bloom map
#'
#' Spread geographic areas apart while keeping their original locations visible.
#' Dots and dotted connector lines link each expanded area back to its parent map.
#' Includes ready-to-use New Jersey and Texas geography and accepts numeric
#' indicator data. Works in R, Shiny, and HTML reports.
#'
#' @param geography `"nj"`, `"tx"`, an `sf` polygon object, or a path to a GeoJSON file. For custom boundaries, set `parent` and `id`.
#' @param view `"full"` (default), `"state_county"` to stop after counties,
#'   or `"county_local"` to start at one county and bloom its local areas.
#' @param county County ID or GEOID for `view = "county_local"`, such as
#'   `"bergen"` or `"34003"`. This view uses the bundled NJ or TX geography.
#' @param bloom_areas Optional character vector of area IDs or GEOIDs to move.
#'   In the full or state-to-county view these identify counties; in the
#'   county-to-local view they identify municipalities or subdivisions. Other
#'   areas remain in place on the parent map. `NULL` (default) blooms all areas.
#' @param bloom_color Optional hexadecimal fill color, such as `"#F97316"`, for
#'   areas chosen to bloom. Other areas retain their usual data or default colors.
#' @param data Optional data frame with geographic identifiers and measured values. For an `sf` input, a value column may also be read from `geography`.
#' @param key Name of the identifier column, such as `"geoid"`.
#' @param value Name of the numeric indicator column. Optional when `data` is `NULL`.
#' @param theme One of `"light"` (default), `"dark"`, or `"auto"`.
#' @param preset One of `"dashboard"`, `"viewer"`, or `"studio"`. All three
#'   retain origin dots and dotted connectors.
#' @param appearance `"seamless"` (default) has no card border or background.
#'   `"card"` places the map in a bordered card. The seamless map blends into
#'   its surrounding Shiny dashboard or HTML page. The map itself stays visible.
#' @param controls Show the full map toolbar (default `FALSE`). With the default,
#'   click the map or press Enter to bloom, select an area, then double-click
#'   or press Enter again to explore it. Small contextual buttons provide
#'   Explore and Back actions. Set `TRUE` to show the full toolbar.
#'   Ctrl+mouse wheel zooms while ordinary scrolling remains available.
#' @param dots,connectors Whether to show original geographic anchors and
#'   connecting guide lines. Both default to `TRUE`.
#' @param overview_boundaries Show county outlines in the original state map.
#'   Default `TRUE`.
#' @param local_boundaries Show municipality/subdivision outlines inside the
#'   selected county. Default `TRUE`.
#' @param local_origin Where smaller areas bloom from: `"original"` (default)
#'   uses the parent's geographic location; `"expanded"` uses its current
#'   expanded or dragged position. Origin dots, reference lines, and connectors
#'   stay with the chosen starting location. Change this in the Display menu too.
#' @param labels Label mode: `"none"` (default), `"selected"`, `"all"`, or
#'   `"custom"`. Tooltips work in every mode. `"all"` hides overlapping labels.
#' @param label_areas Character vector of area identifiers to label when
#'   `labels = "custom"`. Viewers can also Shift+click an area or press L on a
#'   focused area to add or remove its label.
#' @param parent Column identifying the parent region for each custom polygon. Required for custom geography.
#' @param id Column with unique child-area identifiers in custom geography. Default `"id"`.
#' @param label Column with readable child names. Default `"name"`.
#' @param value_label Title of a numeric legend; defaults to the value column name.
#' @param show_legend Show the numeric color legend when indicator values are
#'   available (default `TRUE`). Set `FALSE` to hide it. A fixed `bloom_color`
#'   is not represented by this numeric legend.
#' @param value_suffix Text added after displayed values, such as a percentage sign.
#' @param portable Include all needed geometry inside the widget for saving standalone HTML files. Defaults to `FALSE` for smaller Shiny updates.
#' @param tooltip_fields Optional character vector of column names to show below
#'   the area name and indicator on hover. Use a named vector to give the fields
#'   readable labels, e.g. `c("Population" = "population")`. By default, the
#'   tooltip only shows the area name and indicator.
#' @param tooltip_data Optional separate data frame for tooltip fields. Uses
#'   the same identifier column as `key`. Only columns chosen in
#'   `tooltip_fields` are included. If omitted, fields come from `data`, or
#'   from the attributes of a custom `sf` geography when `data` is absent.
#' @param draggable Whether expanded regions can be dragged. Default `TRUE`.
#' @param duration Bloom/unbloom duration in milliseconds, default 470.
#' @param height,width Widget dimensions. Accepts pixel sizes or percentage-based widths.
#' @param map_zoom Initial map magnification, from `0.65` to `3.5` (default `1`).
#'   Values above `1` make the parent map and bloomed areas larger together.
#'   With `controls = TRUE`, the Fit button returns to this view; viewers can
#'   also zoom interactively.
#' @param bloom_spread How far regions separate when they bloom, from `0.5` to
#'   `1.5` (default `1`). This changes spacing without distorting polygon shapes.
#' @param bloom_scale Size of moved areas relative to their original shapes,
#'   from `1` to `1.6` (default `1`). The parent map and areas left in place
#'   retain their original size. Larger values may need a taller widget.
#' @return An `htmlwidget` suitable for Shiny, Quarto HTML, and R Markdown HTML.
#' @examples
#' bloom_map("nj")
#' bloom_map("nj", labels = "custom", label_areas = c("bergen", "essex"))
#' bloom_map("nj", view = "state_county", bloom_areas = "bergen")
#' bloom_map("tx", theme = "dark")
#' @export
bloom_map <- function(geography = "nj", data = NULL, key = "geoid", value = NULL,
                      view = c("full", "state_county", "county_local"), county = NULL,
                      bloom_areas = NULL, bloom_color = NULL,
                      theme = c("light", "dark", "auto"),
                      preset = c("dashboard", "viewer", "studio"),
                      appearance = c("seamless", "card"), controls = FALSE,
                      dots = TRUE, connectors = TRUE,
                      overview_boundaries = TRUE, local_boundaries = TRUE,
                      labels = c("none", "selected", "all", "custom"),
                      label_areas = character(), draggable = TRUE,
                      duration = 470, width = NULL, height = "520px",
                      map_zoom = 1, bloom_spread = 1,
                      parent = NULL, id = "id", label = "name",
                      value_label = NULL, value_suffix = "", show_legend = TRUE,
                      portable = FALSE,
                      tooltip_fields = NULL, tooltip_data = NULL,
                      local_origin = c("original", "expanded"),
                      bloom_scale = 1) {
  if (!is.null(tooltip_data) && is.null(tooltip_fields)) {
    stop("Set `tooltip_fields` to choose which tooltip columns to show.", call. = FALSE)
  }
  # Validate fields even if no data is available, so mistakes are visible.
  .bloom_tooltip_field_spec(tooltip_fields)
  view <- match.arg(view)
  if (view == "county_local" && (is.null(county) || !is.character(county) ||
      length(county) != 1L || is.na(county) || !nzchar(trimws(county)))) {
    stop("Set `county` to one county ID or GEOID for `view = 'county_local'`.", call. = FALSE)
  }
  if (view != "county_local" && !is.null(county)) {
    stop("`county` is only used with `view = 'county_local'`.", call. = FALSE)
  }
  if (!is.null(bloom_areas) && (!is.character(bloom_areas) || !length(bloom_areas) ||
      anyNA(bloom_areas) || any(!nzchar(trimws(bloom_areas))))) {
    stop("`bloom_areas` must be a nonempty character vector of area IDs or GEOIDs.", call. = FALSE)
  }
  if (!is.null(bloom_areas)) bloom_areas <- unique(trimws(bloom_areas))
  if (!is.null(bloom_color) && (!is.character(bloom_color) || length(bloom_color) != 1L ||
      is.na(bloom_color) || !grepl("^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$", bloom_color))) {
    stop("`bloom_color` must be a hexadecimal color such as '#F97316'.", call. = FALSE)
  }
  custom_attributes <- if (inherits(geography, "sf")) sf::st_drop_geometry(geography) else NULL
  custom <- inherits(geography, "sf") ||
    (is.character(geography) && length(geography) == 1L &&
       !is.na(geography) && grepl("\\.geojson$", geography, ignore.case = TRUE))
  if (custom) {
    if (view == "county_local") stop("`county_local` requires bundled NJ or TX geography.", call. = FALSE)
    if (is.character(geography) && is.null(data) &&
        (!is.null(value) || (!is.null(tooltip_fields) && is.null(tooltip_data)))) {
      if (!requireNamespace("sf", quietly = TRUE)) {
        stop("Install the optional 'sf' package to read custom GeoJSON.", call. = FALSE)
      }
      if (!file.exists(geography)) stop("GeoJSON file not found: ", geography, call. = FALSE)
      geography <- sf::st_read(geography, quiet = TRUE)
      custom_attributes <- sf::st_drop_geometry(geography)
    }
    if (is.null(parent) || length(parent) != 1L || !is.character(parent)) {
      stop("Set `parent` to the parent-area column for custom boundaries.", call. = FALSE)
    }
    if (is.null(data) && !is.null(value) && inherits(geography, "sf") && value %in% names(geography)) {
      data <- sf::st_drop_geometry(geography)
      key <- id
    }
    prepared <- .bloom_prepare_custom(geography, parent, id, label)
    geography <- "custom"
  } else {
    geography <- tolower(as.character(geography))
    if (length(geography) != 1L || is.na(geography) || !geography %in% c("nj", "tx")) {
      stop("`geography` must be 'nj', 'tx', an sf object, or a GeoJSON file.", call. = FALSE)
    }
    prepared <- if (isTRUE(portable) && view != "county_local") .bloom_builtin_geometry(geography) else NULL
  }
  if (!is.logical(portable) || length(portable) != 1L || is.na(portable)) {
    stop("`portable` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.null(value_label) && (!is.character(value_label) || length(value_label) != 1L || is.na(value_label))) {
    stop("`value_label` must be one text string.", call. = FALSE)
  }
  if (!is.character(value_suffix) || length(value_suffix) != 1L || is.na(value_suffix)) {
    stop("`value_suffix` must be one text string.", call. = FALSE)
  }
  theme <- match.arg(theme)
  preset <- match.arg(preset)
  appearance <- match.arg(appearance)
  local_origin <- match.arg(local_origin)
  labels <- match.arg(labels)
  if (!is.character(label_areas) || anyNA(label_areas)) {
    stop("`label_areas` must be a character vector without missing values.", call. = FALSE)
  }
  if (!is.numeric(duration) || length(duration) != 1L || !is.finite(duration) || duration < 0) {
    stop("`duration` must be one nonnegative number.", call. = FALSE)
  }
  if (!is.numeric(map_zoom) || length(map_zoom) != 1L || !is.finite(map_zoom) ||
      map_zoom < 0.65 || map_zoom > 3.5) {
    stop("`map_zoom` must be one number from 0.65 to 3.5.", call. = FALSE)
  }
  if (!is.numeric(bloom_spread) || length(bloom_spread) != 1L || !is.finite(bloom_spread) ||
      bloom_spread < 0.5 || bloom_spread > 1.5) {
    stop("`bloom_spread` must be one number from 0.5 to 1.5.", call. = FALSE)
  }
  if (!is.numeric(bloom_scale) || length(bloom_scale) != 1L || !is.finite(bloom_scale) ||
      bloom_scale < 1 || bloom_scale > 1.6) {
    stop("`bloom_scale` must be one number from 1 to 1.6.", call. = FALSE)
  }
  flags <- list(controls = controls, dots = dots, connectors = connectors, draggable = draggable,
                show_legend = show_legend,
                overview_boundaries = overview_boundaries,
                local_boundaries = local_boundaries)
  for (name in names(flags)) {
    flag <- flags[[name]]
    if (!is.logical(flag) || length(flag) != 1L || is.na(flag)) {
      stop(sprintf("`%s` must be TRUE or FALSE.", name), call. = FALSE)
    }
  }
  rows <- .bloom_rows(data, key, value)
  tooltip_source <- tooltip_data
  tooltip_source_key <- key
  if (is.null(tooltip_source)) {
    tooltip_source <- data
    if (is.null(tooltip_source) && !is.null(custom_attributes)) {
      tooltip_source <- custom_attributes
      tooltip_source_key <- id
    }
  }
  tooltip_rows <- .bloom_tooltip_rows(tooltip_source, tooltip_source_key, tooltip_fields)
  if (!is.null(rows) || !is.null(tooltip_rows)) {
    allowed <- if (geography == "custom") .bloom_custom_ids(prepared) else .bloom_allowed_ids(geography)
    if (!is.null(rows)) .bloom_match_report(rows, allowed, warn = TRUE, stop_if_none = TRUE)
    if (length(tooltip_rows)) {
      tooltip_ids <- vapply(tooltip_rows, `[[`, character(1), "id")
      unmatched <- tooltip_ids[!tooltip_ids %in% allowed]
      if (length(unmatched) == length(tooltip_ids)) {
        stop("None of the tooltip IDs match the map. Check the identifier column.", call. = FALSE)
      }
      if (length(unmatched)) {
        warning(sprintf("%d tooltip geographic IDs were not found on the map.", length(unmatched)),
                call. = FALSE)
      }
    }
  }
  view_meta <- NULL
  if (view == "county_local") {
    focused <- .bloom_county_geometry(geography, county)
    prepared <- focused$geometry
    view_meta <- focused$meta
  }
  if (!is.null(bloom_areas)) {
    allowed_bloom <- if (view == "county_local" || geography == "custom") {
      .bloom_feature_ids(prepared$counties)
    } else {
      index <- jsonlite::read_json(system.file("extdata", "area-ids.json", package = "bloomr"), simplifyVector = TRUE)[[geography]]
      names(index)[index == "overview"]
    }
    unknown <- bloom_areas[!bloom_areas %in% allowed_bloom]
    if (length(unknown)) {
      stop("`bloom_areas` not found in this view: ", paste(unknown, collapse = ", "), call. = FALSE)
    }
  }
  htmlwidgets::createWidget(
    name = "bloom_map",
    x = list(geography = geography,
             theme = theme, preset = preset, appearance = appearance, controls = controls,
             dots = dots, connectors = connectors,
             overviewBoundaries = overview_boundaries, localBoundaries = local_boundaries,
             localOrigin = local_origin, labels = labels, labelAreas = as.character(label_areas),
             bloomAreas = if (is.null(bloom_areas)) NULL else as.list(bloom_areas), bloomColor = bloom_color,
             draggable = draggable, duration = as.numeric(duration),
             mapZoom = as.numeric(map_zoom), bloomSpread = as.numeric(bloom_spread),
             bloomScale = as.numeric(bloom_scale),
             data = rows, tooltipRows = tooltip_rows, inlineGeometry = prepared,
             maxLevel = if (view == "full") "local" else "county",
             customMeta = if (!is.null(view_meta)) view_meta else if (geography == "custom") attr(prepared, "meta") else NULL,
             valueLabel = value_label %||b% value %||b% "Indicator value",
             showLegend = show_legend,
             valueSuffix = value_suffix),
    width = width, height = height, package = "bloomr"
  )
}

.bloom_feature_ids <- function(raw) {
  features <- jsonlite::fromJSON(raw, simplifyVector = FALSE)$features
  unique(unlist(lapply(features, function(f) {
    c(f$properties$id, f$properties$geoid)
  }), use.names = FALSE))
}

.bloom_county_geometry <- function(geography, county) {
  base <- system.file("htmlwidgets", "lib", "bloomr-geo", "data", package = "bloomr")
  folder <- if (geography == "tx") file.path(base, "tx") else base
  counties <- jsonlite::fromJSON(file.path(folder,
    if (geography == "tx") "counties.geojson" else "nj_counties.geojson"), simplifyVector = FALSE)$features
  match_id <- function(f) identical(f$properties$id, county) || identical(f$properties$geoid, county)
  matches <- Filter(match_id, counties)
  if (length(matches) != 1L) stop("County ID was not found in the bundled map.", call. = FALSE)
  feature <- matches[[1L]]
  local_path <- file.path(folder, "municipalities", paste0(feature$properties$id, ".geojson"))
  if (!file.exists(local_path)) stop("Bundled local geography is missing.", call. = FALSE)
  read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  list(geometry = list(state = jsonlite::toJSON(feature, auto_unbox = TRUE, digits = NA),
                       counties = read_text(local_path), local = list()),
       meta = list(name = feature$properties$name,
                   countyLabel = if (geography == "tx") "subdivisions" else "municipalities",
                   localLabel = "areas", root = "", state = "", counties = ""))
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
  if (grepl("geoid|fips", key, ignore.case = TRUE) &&
      any(grepl("^[0-9]+$", keys) & nchar(keys) < 5L)) {
    warning("Short numeric GEOIDs detected. Read GEOIDs as character to retain leading zeros.", call. = FALSE)
  }
  lapply(seq_along(keys), function(i) {
    v <- data[[value]][i]
    list(id = keys[i], value = if (is.finite(v)) as.numeric(v) else NULL)
  })
}



# Only explicitly selected tooltip columns leave R. No user HTML is evaluated.
.bloom_tooltip_field_spec <- function(fields) {
  if (is.null(fields)) return(NULL)
  if (!is.character(fields) || anyNA(fields) || any(!nzchar(trimws(fields))) ||
      anyDuplicated(fields)) {
    stop("`tooltip_fields` must be distinct, nonempty column names.", call. = FALSE)
  }
  labels <- names(fields)
  if (is.null(labels)) labels <- rep("", length(fields))
  labels[is.na(labels) | !nzchar(trimws(labels))] <- fields[is.na(labels) | !nzchar(trimws(labels))]
  stats::setNames(fields, labels)
}

.bloom_tooltip_rows <- function(source, key, fields) {
  fields <- .bloom_tooltip_field_spec(fields)
  if (is.null(fields) || !length(fields)) return(NULL)
  if (is.null(source)) {
    stop("Provide `data` or `tooltip_data` with the columns in `tooltip_fields`.", call. = FALSE)
  }
  if (!is.data.frame(source)) stop("`tooltip_data` must be a data frame.", call. = FALSE)
  if (length(key) != 1L || !is.character(key) || !key %in% names(source)) {
    stop("The tooltip identifier column was not found in the data.", call. = FALSE)
  }
  if (any(!fields %in% names(source))) {
    stop(paste0("Tooltip column(s) not found: ",
      paste(unique(unname(fields)[!fields %in% names(source)]), collapse = ", ")), call. = FALSE)
  }
  ids <- trimws(as.character(source[[key]]))
  if (anyNA(source[[key]]) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("Tooltip identifiers must be unique and nonempty.", call. = FALSE)
  }
  # Preserve dates and text as entered. Suppress missing and blank fields.
  lapply(seq_along(ids), function(i) {
    details <- lapply(seq_along(fields), function(j) {
      column <- source[[fields[[j]]]]
      entry <- column[i]
      if (length(entry) != 1L || is.na(entry)) return(NULL)
      text <- if (is.numeric(entry) && !inherits(entry, c("Date", "POSIXt"))) {
        format(entry, big.mark = ",", scientific = FALSE, trim = TRUE)
      } else {
        as.character(entry)
      }
      if (!nzchar(trimws(text))) return(NULL)
      list(label = names(fields)[j], value = text)
    })
    list(id = ids[i], fields = Filter(Negate(is.null), details))
  })
}

# Small internal fallback for optional text settings.
`%||b%` <- function(x, y) if (is.null(x) || !length(x)) y else x

.bloom_allowed_ids <- function(geography) {
  path <- system.file("extdata", "area-ids.json", package = "bloomr")
  if (!nzchar(path)) stop("Installed geography index is missing.", call. = FALSE)
  names(jsonlite::read_json(path, simplifyVector = FALSE)[[geography]])
}

.bloom_custom_ids <- function(prepared) {
  parents <- jsonlite::fromJSON(prepared$counties, simplifyVector = FALSE)$features
  children <- unlist(lapply(prepared$local, function(raw) {
    jsonlite::fromJSON(raw, simplifyVector = FALSE)$features
  }), recursive = FALSE)
  all <- c(parents, children)
  unique(as.character(unlist(lapply(all, function(f) c(f$properties$id, f$properties$geoid, f$id)), use.names = FALSE)))
}

.bloom_match_report <- function(rows, allowed, warn = FALSE, stop_if_none = FALSE) {
  supplied <- vapply(rows, `[[`, character(1), "id")
  missing <- supplied[!supplied %in% allowed]
  report <- list(valid = !length(missing), rows = length(rows),
    missing_values = sum(vapply(rows, function(x) is.null(x$value), logical(1))),
    matched = length(supplied) - length(missing), unmatched = length(missing),
    unmatched_ids = missing)
  if (stop_if_none && length(rows) && report$matched == 0L) {
    stop("None of the geographic IDs match the map. Check `geography` and the `key` column.", call. = FALSE)
  }
  if (warn && length(missing)) {
    warning(sprintf("%d of %d geographic IDs were not found on the map (e.g. %s).",
      length(missing), length(supplied), paste(utils::head(missing, 3), collapse = ", ")), call. = FALSE)
  }
  report
}

.bloom_builtin_geometry <- function(geography) {
  base <- system.file("htmlwidgets", "lib", "bloomr-geo", "data", package = "bloomr")
  if (!nzchar(base)) stop("Bundled geography files are missing.", call. = FALSE)
  folder <- if (geography == "tx") file.path(base, "tx") else base
  state <- if (geography == "tx") "state.geojson" else "nj_state.geojson"
  counties <- if (geography == "tx") "counties.geojson" else "nj_counties.geojson"
  local_dir <- file.path(folder, "municipalities")
  read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  locations <- list()
  for (file in list.files(local_dir, pattern = "\\.geojson$", full.names = TRUE)) {
    locations[[tools::file_path_sans_ext(basename(file))]] <- read_text(file)
  }
  list(state = read_text(file.path(folder, state)),
       counties = read_text(file.path(folder, counties)), local = locations)
}

#' Check numeric data and geographic identifiers
#' @param data Data frame with geographic identifiers and values.
#' @param key Identifier column name.
#' @param value Numeric column name.
#' @param geography Optional `"nj"` or `"tx"` for checking ID matches.
#' @return A list with `valid`, `rows`, `missing_values`, and, when
#'   geography is given, `matched`, `unmatched`, and `unmatched_ids`.
#' @examples
#' bloom_check_data(data.frame(geoid = "34003", rate = 12), value = "rate", geography = "nj")
#' @export
bloom_check_data <- function(data, key = "geoid", value, geography = NULL) {
  rows <- .bloom_rows(data, key, value)
  if (is.null(geography)) {
    return(list(valid = TRUE, rows = length(rows),
      missing_values = sum(vapply(rows, function(x) is.null(x$value), logical(1)))))
  }
  if (!is.character(geography) || length(geography) != 1L || is.na(geography) ||
      !tolower(geography) %in% c("nj", "tx")) {
    stop("`geography` must be 'nj' or 'tx' for ID checking.", call. = FALSE)
  }
  .bloom_match_report(rows, .bloom_allowed_ids(tolower(geography)))
}
