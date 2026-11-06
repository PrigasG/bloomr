# Start with Bergen County and bloom only its municipalities.
library(bloomr)

bloom_map("nj", view = "county_local", county = "bergen")

# A county GEOID works too:
# bloom_map("nj", view = "county_local", county = "34003")
