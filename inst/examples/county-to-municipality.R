# Start with Bergen County and bloom only its municipalities.
library(bloomr)

bloom_map("nj", view = "county_local", county = "bergen", appearance = "seamless")

# A county GEOID works too:
# bloom_map("nj", view = "county_local", county = "34003")

# Bloom only North Arlington Borough; the rest of Bergen County stays in place.
bloom_map("nj", view = "county_local", county = "bergen",
          bloom_areas = "3400352320", bloom_color = "#F97316", appearance = "card", map_zoom = 2)
