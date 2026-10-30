# Roadmap

## 0.1.0: small, useful first release

- One-line NJ and Texas geographic Bloom maps.
- County and local-area expansion and dragging.
- Origin dots and dotted curved connectors enabled by default.
- Fixed overview county lines and local municipality/subdivision lines enabled
  by default, with independent display switches.
- Optional labels are off by default; tooltips remain available. Selected,
  non-overlapping or chosen labels are supported.
- Light-first widget, with optional dark mode.
- Smooth return transitions and basic keyboard navigation.
- Shiny output, selection input and value-only proxy updates.
- Bundled map assets, compact README, three short guides and runnable examples.

## Later, only when there is a clear need

- User-supplied `sf` and GeoJSON geography.
- Saved layouts and lab-level undo/redo.
- Advanced styles and sophisticated label-placement options.
- Additional static export modes and performance tooling.

The laboratory stays separate. Keep the widget small and avoid adding a new
public function when a sensible default already solves the problem.
