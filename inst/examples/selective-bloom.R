# Bloom only Bergen County while the other counties remain in New Jersey.
library(bloomr)

bloom_map("nj", view = "state_county", bloom_areas = "bergen",
          bloom_color = "#F97316")

# Bloom only North Arlington Borough from the Bergen County map.
# IDs or GEOIDs can be used in bloom_areas.
bloom_map("nj", view = "county_local", county = "bergen",
          bloom_areas = "3400352320")

# Indicator values and the usual display options still work.
rates <- data.frame(geoid = c("34003", "34013"), rate = c(12.5, 18.2))
bloom_map("nj", view = "state_county", bloom_areas = "bergen",
          data = rates, value = "rate", labels = "selected", theme = "light")
