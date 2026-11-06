library(bloomr)

# Your normal indicator data can also supply optional tooltip details.
rates <- data.frame(
  geoid = c("34003", "34013", "34021"),
  rate = c(12.5, 18.2, 9.3),
  population = c(953819, 863728, 523053),
  note = c("Bergen County", "Essex County", "Mercer County")
)

bloom_map(
  data = rates, value = "rate", value_suffix = "%",
  tooltip_fields = c("Population" = "population", "Note" = "note")
)

# Or keep tooltip details in a separate table, independent of the indicator.
details <- rates[c("geoid", "population", "note")]
bloom_map(
  data = rates[c("geoid", "rate")], value = "rate",
  tooltip_data = details,
  tooltip_fields = c("Population" = "population", "Note" = "note")
)
