# Bloom a state into counties and stop there.
library(bloomr)

county_rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3)
)

bloom_map("nj", view = "state_county", data = county_rates, value = "rate",
          value_label = "Example county rate", value_suffix = "%")
