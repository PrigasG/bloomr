# Package roadmap

## 0.1.0 development preview: included now

- Real R htmlwidget and Shiny output / render functions.
- One-line NJ and TX maps with self-contained browser dependencies.
- The deterministic geographic collision solver from Hierarchical Bloom Lab 17.5.12.
- County and local-area expansion, default origin dots and dotted connectors.
- Drag individual shapes and maintain original anchors; compact toolbar.
- Light-first scoped CSS, optional dark and automatic themes, responsive viewBox.
- Programmatic selection / expansion and value-only updates through a Shiny proxy.
- Lazy reading of local-area assets per selected county.
- Complete starter README and working Shiny integration example.

## 0.2.0: visual parity and interaction parity

- Compare default screenshots, county positions and motion against v17.5.12.
- Reuse the exact D3 projection and visual renderer where practical.
- Expose drag frames and frame dragging from the laboratory.
- Persist, export and restore versioned layouts; undo/redo support.
- Local reference outlines, smart labels, visual guide customizations.
- Finish pointer gestures and keyboard interactions, and automated browser tests.
- Verify multiple maps including map controls in hidden/revealed Shiny tabs.

## 0.3.0: open-data adapter and release hardening

- `sf`/GeoJSON user-supplied hierarchies with explicit parent-child contracts.
- Integrate geometry preparation, caching and spatial validation.
- Linked categorical data, status values and user-controlled legends.
- R package unit tests, full R CMD check, browser CI, documentation website.
- Source license/attribution audits and installation-from-clean-library tests.

Design constraints: no global CSS, no mandatory sf for prebundled geographies,
no per-frame Shiny message traffic, dots and connectors on by default, light
mode first, and no silent resetting of manual geographic offsets on value changes.
