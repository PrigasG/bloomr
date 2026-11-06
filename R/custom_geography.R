# Convert user-supplied polygon boundaries into the small internal GeoJSON
# contract. Only sf is needed for this optional path, not for built-in maps.
.bloom_prepare_custom <- function(geography, parent, id, label) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Install the optional 'sf' package to use custom geographic boundaries.", call. = FALSE)
  }
  if (inherits(geography, "sf")) {
    features <- geography
  } else {
    if (!file.exists(geography)) stop("GeoJSON file not found: ", geography, call. = FALSE)
    features <- tryCatch(sf::st_read(geography, quiet = TRUE), error = function(e) {
      stop("Could not read the GeoJSON file: ", conditionMessage(e), call. = FALSE)
    })
  }
  if (!inherits(features, "sf") || !nrow(features)) {
    stop("Custom geography must contain polygon features.", call. = FALSE)
  }
  for (column in c(parent, id, label)) {
    if (!is.character(column) || length(column) != 1L || is.na(column) || !column %in% names(features)) {
      stop(sprintf("Custom geography needs a '%s' column.", paste(column, collapse = ", ")), call. = FALSE)
    }
  }
  parents <- trimws(as.character(features[[parent]]))
  ids <- trimws(as.character(features[[id]]))
  labels <- trimws(as.character(features[[label]]))
  if (anyNA(parents) || any(!nzchar(parents))) stop("Parent identifiers cannot be empty.", call. = FALSE)
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("Child-area IDs must be unique and nonempty.", call. = FALSE)
  }
  if (any(ids %in% parents)) {
    stop("Parent and child IDs must be distinct. Rename any overlapping IDs.", call. = FALSE)
  }
  labels[is.na(labels) | !nzchar(labels)] <- ids[is.na(labels) | !nzchar(labels)]
  if (is.na(sf::st_crs(features))) stop("Set the coordinate reference system (CRS) before using custom geography.", call. = FALSE)
  features <- sf::st_transform(features, 4326)
  features <- sf::st_zm(features, drop = TRUE, what = "ZM")
  types <- as.character(sf::st_geometry_type(features))
  if (any(!types %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("Custom geography supports Polygon and MultiPolygon boundaries only.", call. = FALSE)
  }
  if (any(sf::st_is_empty(features))) stop("Custom geography contains empty polygons.", call. = FALSE)
  if (any(!sf::st_is_valid(features))) {
    features <- sf::st_make_valid(features)
    if (any(!as.character(sf::st_geometry_type(features)) %in% c("POLYGON", "MULTIPOLYGON"))) {
      stop("Some polygon boundaries could not be repaired. Clean those geometries in sf first.", call. = FALSE)
    }
  }
  # Keep the visible area names, and strip all other user data from geometry.
  children <- sf::st_sf(id = ids, geoid = ids, name = labels,
                        parent_id = parents, geometry = sf::st_geometry(features))
  unique_parents <- unique(parents)
  unioned <- lapply(unique_parents, function(p) {
    tryCatch(sf::st_union(sf::st_geometry(features)[which(parents == p)])[[1]],
      error = function(e) stop("Could not combine polygons in parent '", p, "': ", conditionMessage(e), call. = FALSE))
  })
  parent_geom <- sf::st_sfc(unioned, crs = 4326)
  parent_sf <- sf::st_sf(id = unique_parents, geoid = unique_parents,
                         name = unique_parents, geometry = parent_geom)
  all_geom <- tryCatch(sf::st_union(sf::st_geometry(parent_sf))[[1]], error = function(e) {
    stop("Could not create the overall map outline: ", conditionMessage(e), call. = FALSE)
  })
  root_sf <- sf::st_sf(id = "root", name = "Map", geometry = sf::st_sfc(all_geom, crs = 4326))
  # GDAL serializes geometry rings with correct GeoJSON nesting and coordinates.
  as_collection <- function(x) {
    file <- tempfile(fileext = ".geojson")
    on.exit(unlink(file), add = TRUE)
    sf::st_write(x, file, driver = "GeoJSON", quiet = TRUE)
    paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }
  # Keep GeoJSON as text until the browser parses it. This preserves even
  # single-feature arrays and single-ring polygons in htmlwidgets JSON.
  locals <- stats::setNames(lapply(unique_parents, function(p) {
    as_collection(children[which(parents == p), , drop = FALSE])
  }), unique_parents)
  geometry <- list(state = as_collection(root_sf), counties = as_collection(parent_sf), local = locals)
  attr(geometry, "meta") <- list(name = "Custom map", countyLabel = "regions",
                                  localLabel = "areas", root = "", state = "", counties = "")
  geometry
}
