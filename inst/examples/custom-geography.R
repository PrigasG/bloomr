# Explore a spatial file using the same bloomr defaults.
# Install sf once: install.packages("sf")
library(bloomr)

file <- system.file("extdata", "demo-service-areas.geojson", package = "bloomr")

bloom_map(
  geography = file,
  parent = "district",
  id = "area_id",
  label = "area_name",
  value = "rate",
  value_label = "Example rate",
  value_suffix = "%",
  tooltip_fields = c("Population" = "population", "Notes" = "note")
)

# To save a self-contained HTML file (requires Pandoc):
# htmlwidgets::saveWidget(
#   bloom_map(file, parent = "district", id = "area_id", label = "area_name"),
#   "my-bloom-map.html", selfcontained = TRUE
# )
