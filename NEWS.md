# bloomr 0.1.0

- Explore hierarchical geographic maps with smooth bloom, drag, zoom, and return animations.
- Keep original boundaries, origin dots, and dotted connectors visible by default.
- Use the included New Jersey and Texas examples, or supply custom `sf` or GeoJSON polygons.
- Display numeric indicators with configurable legend titles and units, and check geographic IDs before mapping.
- Embed maps in Shiny, update values without resetting positions, and save portable HTML reports.
- Use light styling by default, with optional dark mode, labels, and keyboard controls.
- Add optional tooltip details from indicator data or a separate table, without writing HTML.
- Try custom geography with an included GeoJSON spatial file and a short example.
- Browse the package reference and guides through the pkgdown website.
- Use a seamless, toolbar-free map by default; request the bordered card and full toolbar when needed.
- Explore a linked Shiny dashboard showing Bloom beside ggplot2 and Plotly, with shared county selection.
- Choose whether local regions bloom from the original geographic location or the expanded parent position (`local_origin`).
- Use `view = "state_county"` to stop at counties or `view = "county_local"` to start with one county and bloom its municipalities or subdivisions.
