# Fixed parent boundaries and chosen map labels.
# All origin dots and dotted connectors still appear by default.
library(bloomr)

# No arguments are needed for the two sets of original boundary lines.
bloom_map("nj")

# Label a few counties while keeping hover tooltips for the rest.
bloom_map("nj", labels = "custom", label_areas = c("bergen", "essex"))

# Hide only the local outlines, leaving overview outlines visible.
bloom_map("nj", local_boundaries = FALSE)

# Or show only the currently selected region's name.
bloom_map("tx", labels = "selected", theme = "dark")
