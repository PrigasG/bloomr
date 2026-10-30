# Display original boundaries and add selected map labels.
library(bloomr)

# The default shows original county and municipality lines.
bloom_map()

# Label a few counties; names for other areas remain available on hover.
bloom_map(labels = "custom", label_areas = c("bergen", "essex"))

# Hide local-area boundaries without hiding the overview county lines.
bloom_map(local_boundaries = FALSE)

# Show a label only for the selected area.
bloom_map("tx", labels = "selected")
