# Explore the map and add numeric indicators.
library(bloomr)

bloom_map()

rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3)
)

bloom_check_data(rates, value = "rate")
bloom_map(data = rates, key = "geoid", value = "rate")
