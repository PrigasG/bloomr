# The local bloom can start at either the original or expanded parent.
# Dots and connector lines keep showing where areas belong.

library(bloomr)

# Original geographic location (default)
bloom_map("nj", local_origin = "original")

# Current expanded or dragged location of the selected parent
bloom_map("nj", local_origin = "expanded")

# Also available for custom geography
# bloom_map(my_areas, parent = "district", id = "area_id",
#           local_origin = "expanded")
