# Run after installing bloomr.
library(bloomr)

# With no indicator data, this displays the original county geometry.
bloom_map("nj")

# Light mode is the default. Parent origin dots and dotted connectors are on.
bloom_map("tx", theme = "dark", duration = 470)

# Full Shiny example:
run_bloom_example()
