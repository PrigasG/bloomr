"""Check opt-in scaling of moved shapes in a real browser."""
import json
import shutil
from pathlib import Path
from playwright.sync_api import sync_playwright


root = Path(__file__).resolve().parents[2]
assets = root / "inst/htmlwidgets/lib/bloomr-geo/data"
geometry = {
    "state": json.loads((assets / "nj_state.geojson").read_text()),
    "counties": json.loads((assets / "nj_counties.geojson").read_text()),
    "local": {"bergen": json.loads((assets / "municipalities/bergen.geojson").read_text())},
}
css = (root / "inst/htmlwidgets/lib/bloomr/bloom.css").read_text()
js = (root / "inst/htmlwidgets/lib/bloomr/bloom-core.js").read_text()
chrome = (shutil.which("chromium") or shutil.which("google-chrome") or
          shutil.which("chrome") or
          str(Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")))

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path=chrome,
    )
    page = browser.new_page(viewport={"width": 950, "height": 610})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.set_content('<div id="map" style="width:950px;height:610px"></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate("""geometry => {
      window.map = new Bloomr.Map(document.getElementById('map'), {
        geography: 'nj', inlineGeometry: geometry, duration: 0,
        bloomAreas: ['bergen'], bloomColor: '#F97316', bloomScale: 1.35,
        maxLevel: 'local'
      });
    }""", geometry)
    page.wait_for_function("window.map.ready")
    page.evaluate("window.map.expandCounties()")
    result = page.evaluate("""() => {
      const county = map.counties.find(f => f.__id === 'bergen');
      const other = map.counties.find(f => f.__id === 'essex');
      const shape = county.pathEl.getBoundingClientRect();
      const source = county.__bounds[1][0] - county.__bounds[0][0];
      const svg = map.svg.getBoundingClientRect();
      const pixelsPerUnit = Math.min(svg.width / 1000, svg.height / 720);
      return {
        scale: shape.width / (source * pixelsPerUnit),
        moved: county.pathEl.getAttribute('transform'),
        unmoved: other.pathEl.getAttribute('transform'),
        parent: map.statePath.getAttribute('transform'),
        trail: county.trail.getAttribute('d'),
        selected: county.pathEl.getAttribute('fill')
      };
    }""")
    assert abs(result["scale"] - 1.35) < 0.02, result
    assert "scale(1.35)" in result["moved"], result
    assert "scale(" not in result["unmoved"], result
    assert result["parent"] is None, result
    assert result["trail"].startswith("M"), result
    assert result["selected"] == "#F97316", result
    page.evaluate("window.map.select('bergen')")
    page.evaluate("window.map.expandLocal()")
    page.wait_for_function("window.map.localExpanded && window.map.locals.length > 0")
    local = page.evaluate("""() => ({
      transform: map.locals[0].pathEl.getAttribute('transform'),
      parent: map.statePath.getAttribute('transform')
    })""")
    assert "scale(1.35)" in local["transform"], local
    assert local["parent"] is None, local
    assert not errors, errors
    browser.close()
    print("Moved county and local shape scale; parent, unmoved counties, and guide stay in place: PASS")
