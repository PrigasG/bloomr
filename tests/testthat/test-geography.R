test_that("included geography matches real identifiers", {
  d <- data.frame(geoid = c("34003", "34013", "unknown"), rate = c(1, 0, NA_real_))
  report <- bloom_check_data(d, value = "rate", geography = "nj")
  expect_false(report$valid)
  expect_identical(report$matched, 2L)
  expect_identical(report$unmatched_ids, "unknown")
  expect_identical(bloom_check_data(d[3, ], value = "rate", geography = "nj")$matched, 0L)
  expect_error(bloom_map("nj", data = d[3, ], value = "rate"), "None of the geographic IDs")
  expect_warning(bloom_map("nj", data = d, value = "rate"), "not found")
})

test_that("numeric legend and portability have predictable defaults", {
  data <- data.frame(geoid = "34003", rate = 6.2)
  map <- bloom_map("nj", data = data, value = "rate", value_label = "Rate", value_suffix = "%")
  expect_identical(map$x$valueLabel, "Rate")
  expect_identical(map$x$valueSuffix, "%")
  expect_null(map$x$inlineGeometry)
  expect_error(bloom_map(portable = NA), "portable")
  expect_error(bloom_map(value_suffix = NA_character_), "value_suffix")
})

test_that("portable built-in assets include state, counties, and local regions", {
  map <- bloom_map("nj", portable = TRUE)
  expect_type(map$x$inlineGeometry$state, "character")
  expect_type(map$x$inlineGeometry$counties, "character")
  expect_true("bergen" %in% names(map$x$inlineGeometry$local))
  counties <- jsonlite::fromJSON(map$x$inlineGeometry$counties, simplifyVector = FALSE)$features
  expect_length(counties, 21L)
  county_ids <- vapply(counties, function(feature) feature$properties$id, character(1))
  expect_length(unique(county_ids), 21L)
})

test_that("custom polygons can be embedded without changing the default controls", {
  skip_if_not_installed("sf")
  square <- function(x, y) sf::st_polygon(list(matrix(c(x,y, x+1,y, x+1,y+1, x,y+1, x,y), ncol=2, byrow=TRUE)))
  geo <- sf::st_sf(id=c("a1", "a2", "b1"), name=c("Alpha", "Beta", "Gamma"),
    district=c("north", "north", "south"),
    rate=c(10, 20, 30), geometry=sf::st_sfc(square(0,1), square(1,1), square(0,0), crs=4326))
  map <- bloom_map(geo, parent = "district", id = "id", label = "name", value = "rate")
  expect_identical(map$x$geography, "custom")
  expect_true(map$x$dots && map$x$connectors)
  expect_true(map$x$overviewBoundaries && map$x$localBoundaries)
  expect_equal(length(map$x$data), 3L)
  expect_equal(length(jsonlite::fromJSON(map$x$inlineGeometry$counties, simplifyVector = FALSE)$features), 2L)
  expect_identical(map$x$customMeta$countyLabel, "regions")
})

test_that("custom geography gives informative ID and CRS errors", {
  skip_if_not_installed("sf")
  square <- sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0),ncol=2,byrow=TRUE)))
  geo <- sf::st_sf(id="a1", name="A", group="north", geometry=sf::st_sfc(square,crs=4326))
  expect_error(bloom_map(geo, id="id"), "parent")
  expect_error(bloom_map(geo, parent="group", id="missing"), "column")
  expect_error(bloom_map(sf::st_set_crs(geo, NA),parent="group"), "coordinate reference")
})


test_that("example spatial GeoJSON has the required fields and polygons", {
  skip_if_not_installed("sf")
  f <- system.file("extdata", "demo-service-areas.geojson", package = "bloomr")
  expect_true(nzchar(f) && file.exists(f))
  areas <- sf::st_read(f, quiet = TRUE)
  expect_equal(nrow(areas), 24L)
  expect_equal(length(unique(areas$district)), 4L)
  expect_true(all(c("area_id", "area_name", "district", "rate") %in% names(areas)))
  expect_true(all(sf::st_is_valid(areas)))
  map <- bloom_map(f, parent = "district", id = "area_id",
                   label = "area_name", value = "rate")
  expect_identical(map$x$geography, "custom")
  expect_length(map$x$data, 24L)
  expect_length(map$x$inlineGeometry$local, 4L)
})
