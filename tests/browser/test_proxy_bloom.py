"""Exercise live bloom proxy updates and shared geometry in a browser."""
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
    browser = playwright.chromium.launch(headless=True, executable_path=chrome)
    page = browser.new_page(viewport={"width": 1100, "height": 650})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.set_content('''<div id="first" style="width:520px;height:600px"></div>
                        <div id="second" style="width:520px;height:600px"></div>''')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate("""geometry => {
      const base = { geography: 'nj', inlineGeometry: geometry, duration: 0,
        localOrigin: 'expanded' };
      window.first = new Bloomr.Map(document.getElementById('first'), base);
      window.second = new Bloomr.Map(document.getElementById('second'), base);
      first.command('bloom', { bloomScale: 1.5, bloomSpread: 1.25 });
    }""", geometry)
    page.wait_for_function("first.ready && second.ready && first.config.bloomScale === 1.5")
    initial = page.evaluate("""() => ({
      separate: first.counties[0] !== second.counties[0],
      sourceUntouched: first.config.inlineGeometry.counties.features[0].pathEl === undefined,
      otherScale: second.config.bloomScale
    })""")
    assert initial == {"separate": True, "sourceUntouched": True, "otherScale": 1}, initial

    page.evaluate("""() => {
      first.expandCounties();
      first.select('bergen');
      first.manualCounty.set('bergen', {x: 20, y: -10});
      first.command('bloom', { bloomScale: 1.3, bloomSpread: 1.1 });
    }""")
    county = page.evaluate("""() => ({
      selected: first.selected.__id,
      drag: first.manualCounty.get('bergen'),
      scale: first.config.bloomScale,
      spread: first.config.bloomSpread,
      otherScale: second.config.bloomScale,
      transform: first.selected.pathEl.getAttribute('transform')
    })""")
    assert county["selected"] == "bergen" and county["drag"] == {"x": 20, "y": -10}, county
    assert county["scale"] == 1.3 and county["spread"] == 1.1, county
    assert county["otherScale"] == 1 and "scale(1.3)" in county["transform"], county

    page.evaluate("first.expandLocal()")
    page.wait_for_function("first.localExpanded && first.locals.length > 0")
    page.evaluate("first.command('bloom', { bloomScale: 1.4, bloomSpread: 1.2 })")
    local = page.evaluate("""() => ({
      shift: first.localBaseShift,
      parentOffset: first._offset(first.selected),
      localScale: first.locals[0].pathEl.getAttribute('transform'),
      selected: first.selected.__id,
      drag: first.manualCounty.get('bergen')
    })""")
    assert local["shift"] == local["parentOffset"], local
    assert "scale(1.4)" in local["localScale"], local
    assert local["selected"] == "bergen" and local["drag"] == {"x": 20, "y": -10}, local
    assert not errors, errors
    browser.close()
    print("Live size and spread updates, local origin, selection, drags, and shared geometry: PASS")
