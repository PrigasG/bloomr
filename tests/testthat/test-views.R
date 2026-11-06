test_that("state to county view stops at counties", {
  map <- bloom_map("nj", view = "state_county")
  expect_identical(map$x$maxLevel, "county")
  expect_null(map$x$inlineGeometry)
})

test_that("county to local view starts with the selected county", {
  map <- bloom_map("nj", view = "county_local", county = "34003")
  parent <- jsonlite::fromJSON(map$x$inlineGeometry$state, simplifyVector = FALSE)
  children <- jsonlite::fromJSON(map$x$inlineGeometry$counties, simplifyVector = FALSE)
  expect_identical(parent$properties$name, "Bergen County")
  expect_length(children$features, 70L)
  expect_identical(map$x$customMeta$countyLabel, "municipalities")
  expect_identical(map$x$maxLevel, "county")

  texas <- bloom_map("tx", view = "county_local", county = "harris")
  expect_identical(texas$x$customMeta$countyLabel, "subdivisions")
  expect_error(bloom_map("nj", view = "county_local", county = "missing"), "not found")
  expect_error(bloom_map("nj", view = "county_local"), "Set `county`")
})

test_that("chosen areas can bloom while other geography stays in place", {
  county <- bloom_map("nj", view = "state_county", bloom_areas = "34003",
                      bloom_color = "#F97316")
  expect_identical(county$x$bloomAreas, list("34003"))
  expect_identical(county$x$bloomColor, "#F97316")
  two <- bloom_map("nj", bloom_areas = c("bergen", "essex"))
  expect_identical(two$x$bloomAreas, list("bergen", "essex"))
  expect_null(bloom_map("nj")$x$bloomAreas)

  local <- bloom_map("nj", view = "county_local", county = "bergen",
                     bloom_areas = "3400352320")
  expect_identical(local$x$bloomAreas, list("3400352320"))
  expect_error(bloom_map("nj", bloom_areas = "3400352320"), "not found")
  expect_error(bloom_map("nj", view = "county_local", county = "bergen",
                         bloom_areas = "34003"), "not found")
  expect_error(bloom_map("nj", bloom_areas = character()), "nonempty")
  expect_error(bloom_map("nj", bloom_areas = NA_character_), "nonempty")
  expect_error(bloom_map("nj", bloom_color = "orange"), "hexadecimal")

  custom <- bloom_map(system.file("extdata", "demo-service-areas.geojson", package = "bloomr"),
                      parent = "district", id = "area_id", label = "area_name",
                      bloom_areas = "Southwest")
  expect_identical(custom$x$bloomAreas, list("Southwest"))
})
