test_that("default widget is light and has geographical anchors", {
  widget <- bloom_map("nj")
  expect_s3_class(widget, "htmlwidget")
  expect_identical(widget$x$theme, "light")
  expect_true(widget$x$dots)
  expect_true(widget$x$connectors)
})

test_that("geography and data contracts reject unsafe values", {
  expect_error(bloom_map("ca"), "geography")
  expect_error(bloom_map("nj", data = data.frame(geoid = "34003")), "value")
  expect_error(bloom_map("nj", duration = -1), "duration")
  expect_error(bloom_map("nj", dots = NA), "dots")
  expect_error(bloom_map("nj", data = data.frame(geoid = c("34003", "34003"), rate = c(1, 2)), value = "rate"), "unique")
})

test_that("input serialization keeps geography identifiers as character", {
  rows <- bloomr::bloom_map("nj", data = data.frame(geoid = c("34003", "34021"), rate = c(0, NA_real_)), value = "rate")$x$data
  expect_identical(rows[[1]]$id, "34003")
  expect_identical(rows[[1]]$value, 0)
  expect_null(rows[[2]]$value)
})


test_that("numeric inputs keep zeros and missing values distinct", {
  values <- data.frame(geoid = c("34003", "34013"), value = c(0, NA_real_))
  result <- bloom_check_data(values, value = "value")
  expect_true(result$valid)
  expect_equal(result$rows, 2L)
  expect_equal(result$missing_values, 1L)
  map <- bloom_map("nj", data = values, value = "value")
  expect_identical(map$x$data[[1]]$value, 0)
  expect_null(map$x$data[[2]]$value)
})

test_that("invalid columns and IDs give useful errors", {
  expect_error(bloom_map("nj", data = data.frame(geoid = "34003", rate = "a"), value = "rate"), "numeric")
  expect_error(bloom_map("nj", data = data.frame(geoid = NA_character_, rate = 1), value = "rate"), "missing")
  expect_error(bloom_map("nj", data = data.frame(geoid = "", rate = 1), value = "rate"), "blank")
  expect_error(bloom_map("nj", data = data.frame(geoid = "34003", rate = 1), value = "missing"), "numeric column")
  expect_error(bloom_map("nj", theme = "bright"), "arg")
  expect_error(bloom_map("nj", draggable = 1), "TRUE or FALSE")
})

test_that("theme and guide defaults stay stable", {
  map <- bloom_map("tx", preset = "viewer")
  expect_identical(map$x$geography, "tx")
  expect_true(map$x$dots)
  expect_true(map$x$connectors)
  expect_identical(map$x$theme, "light")
})


test_that("boundary and label options are available with safe defaults", {
  map <- bloom_map("nj")
  expect_true(map$x$overviewBoundaries)
  expect_true(map$x$localBoundaries)
  expect_identical(map$x$labels, "none")
  expect_length(map$x$labelAreas, 0)
  selected <- bloom_map("nj", labels = "custom", label_areas = c("bergen", "essex"),
                        overview_boundaries = FALSE, local_boundaries = TRUE)
  expect_false(selected$x$overviewBoundaries)
  expect_true(selected$x$localBoundaries)
  expect_equal(selected$x$labelAreas, c("bergen", "essex"))
  expect_error(bloom_map("nj", labels = "bad"))
  expect_error(bloom_map("nj", local_boundaries = NA))
  expect_error(bloom_map("nj", label_areas = NA_character_))
})
