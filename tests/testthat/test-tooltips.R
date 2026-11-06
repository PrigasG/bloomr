test_that("tooltips are unchanged by default", {
  map <- bloom_map("nj", portable = FALSE)
  expect_null(map$x$tooltipRows)
})

test_that("selected tooltip columns have friendly labels and skip blanks", {
  rates <- data.frame(geoid = c("34003", "34013"), rate = c(5.2, 2.1),
                      population = c(12345, NA_real_), note = c("Center", ""))
  map <- bloom_map("nj", data = rates, value = "rate",
                   tooltip_fields = c("Population" = "population", "Notes" = "note"))
  expect_length(map$x$tooltipRows, 2L)
  expect_identical(map$x$tooltipRows[[1]]$fields[[1]], list(label = "Population", value = "12,345"))
  expect_length(map$x$tooltipRows[[1]]$fields, 2L)
  expect_length(map$x$tooltipRows[[2]]$fields, 0L)
})

test_that("tooltip details can come from a separate table without numeric data", {
  info <- data.frame(geoid = c("34003", "34013"), description = c("North", "South"))
  map <- bloom_map("nj", tooltip_data = info,
                   tooltip_fields = c("About" = "description"))
  expect_null(map$x$data)
  expect_identical(map$x$tooltipRows[[2]]$fields[[1]]$value, "South")
})

test_that("tooltip input errors are clear", {
  rates <- data.frame(geoid = c("34003", "34013"), rate = c(1, 2), note = c("A", "B"))
  expect_error(bloom_map("nj", tooltip_fields = "note"), "Provide `data` or `tooltip_data`")
  expect_error(bloom_map("nj", tooltip_data = rates), "tooltip_fields")
  expect_error(bloom_map("nj", data = rates, value = "rate", tooltip_fields = "unknown"), "Tooltip column")
  expect_error(bloom_map("nj", data = rates, value = "rate", tooltip_fields = c("note", "note")), "distinct")
  rates$geoid[2] <- "34003"
  expect_error(bloom_map("nj", tooltip_data = rates, tooltip_fields = "note"), "unique")
  unknown <- data.frame(geoid = "not-on-map", note = "Unknown")
  expect_error(bloom_map("nj", tooltip_data = unknown, tooltip_fields = "note"),
               "None of the tooltip IDs match")
})
