test_that("bloom size proxy updates validate without touching geography", {
  seen <- new.env(parent = emptyenv())
  proxy <- structure(list(
    id = "test_map",
    session = list(sendCustomMessage = function(type, payload) {
      seen$type <- type
      seen$payload <- payload
    })
  ), class = "bloomr_proxy")

  expect_invisible(bloom_update_bloom(proxy, bloom_scale = 1.5, bloom_spread = 1.2))
  expect_identical(seen$type, "bloomr:command")
  expect_identical(seen$payload$id, "test_map")
  expect_identical(seen$payload$command, "bloom")
  expect_identical(seen$payload$args$bloomScale, 1.5)
  expect_identical(seen$payload$args$bloomSpread, 1.2)

  bloom_update_bloom(proxy, bloom_scale = 1.35)
  expect_identical(seen$payload$args, list(bloomScale = 1.35))
  expect_error(bloom_update_bloom(proxy), "Set")
  expect_error(bloom_update_bloom(proxy, bloom_scale = NA_real_), "bloom_scale")
  expect_error(bloom_update_bloom(proxy, bloom_scale = 2), "bloom_scale")
  expect_error(bloom_update_bloom(proxy, bloom_spread = 0.4), "bloom_spread")
})

test_that("indicator proxy can update legend title and units", {
  seen <- new.env(parent = emptyenv())
  proxy <- structure(list(id = "map", session = list(
    sendCustomMessage = function(type, payload) seen$payload <- payload
  )), class = "bloomr_proxy")
  d <- data.frame(geoid = "34003", density = 3985.04)
  bloom_update_data(proxy, d, value = "density",
    value_label = "Population density", value_suffix = " per sq mi")
  expect_identical(seen$payload$args$valueLabel, "Population density")
  expect_identical(seen$payload$args$valueSuffix, " per sq mi")
  expect_identical(seen$payload$args$rows[[1]]$id, "34003")
  expect_error(bloom_update_data(proxy, d, value = "density", value_label = NA_character_), "value_label")
})
