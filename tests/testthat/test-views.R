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
