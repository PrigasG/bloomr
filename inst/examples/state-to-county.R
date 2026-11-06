# Bloom a state into counties and stop there.
library(bloomr)

county_rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3)
)

bloom_map("nj", view = "state_county", data = county_rates, value = "rate",
          value_label = "Example county rate", value_suffix = "%")

# Move only Bergen County; the other counties keep the state map intact.
bloom_map("nj", view = "state_county", bloom_areas = "bergen",
          bloom_color = "#F97316")

# Hide the built-in numeric legend when displaying indicator data.
bloom_map("nj", view = "state_county", data = county_rates, value = "rate",
          show_legend = FALSE)
