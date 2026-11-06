"""Check optional visual styling and the unchanged defaults in a browser."""
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

style = {
    "parent_outline_color": "#64748B", "parent_outline_width": 2,
    "bloom_outline_color": "#1D4ED8", "bloom_outline_width": 2.5,
    "reference_color": "#94A3B8", "reference_width": 1,
    "connector_color": "#3B82F6", "connector_width": 2,
    "connector_pattern": "dashed", "connector_opacity": 0.6,
    "dot_color": "#2563EB", "dot_size": 4,
    "selected_outline_color": "#F59E0B", "selected_outline_width": 3,
}

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=chrome)
    page = browser.new_page(viewport={"width": 1100, "height": 650}, accept_downloads=True)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.set_content('''<div id="custom" style="width:520px;height:600px"></div>
                        <div id="default" style="width:520px;height:600px"></div>''')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate("""({geometry, style}) => {
      window.custom = new Bloomr.Map(document.getElementById('custom'), {
        geography: 'nj', inlineGeometry: geometry, duration: 0,
        bloomAreas: ['bergen'], localOrigin: 'expanded', style
      });
      window.standard = new Bloomr.Map(document.getElementById('default'), {
        geography: 'nj', inlineGeometry: geometry, duration: 0, theme: 'dark'
      });
    }""", {"geometry": geometry, "style": style})
    page.wait_for_function("custom.ready && standard.ready")
    page.evaluate("custom.expandCounties(); standard.expandCounties()")
    appearance = page.evaluate("""() => {
      const bergen = custom.counties.find(f => f.__id === 'bergen');
      const essex = custom.counties.find(f => f.__id === 'essex');
      const css = element => getComputedStyle(element);
      return {
        parent: css(custom.statePath).stroke,
        parentWidth: css(custom.statePath).strokeWidth,
        moved: css(bergen.pathEl).stroke,
        movedWidth: css(bergen.pathEl).strokeWidth,
        stationary: css(essex.pathEl).stroke,
        stationaryMoved: essex.pathEl.classList.contains('bloomr-moved'),
        reference: css(custom.refLayer.querySelector('path')).stroke,
        referenceWidth: css(custom.refLayer.querySelector('path')).strokeWidth,
        connector: css(bergen.trail).stroke,
        connectorWidth: css(bergen.trail).strokeWidth,
        dash: css(bergen.trail).strokeDasharray,
        opacity: bergen.trail.getAttribute('opacity'),
        dot: css(bergen.dot).fill,
        dotSize: bergen.dot.getAttribute('r'),
        darkParent: css(standard.statePath).stroke,
        darkMoved: css(standard.counties[0].pathEl).stroke,
        independent: standard.el.style.getPropertyValue('--bloom-bloom-outline-color')
      };
    }""")
    assert appearance == {
        "parent": "rgb(100, 116, 139)", "parentWidth": "2px",
        "moved": "rgb(29, 78, 216)", "movedWidth": "2.5px",
        "stationary": "rgb(69, 107, 146)", "stationaryMoved": False,
        "reference": "rgb(148, 163, 184)", "referenceWidth": "1px",
        "connector": "rgb(59, 130, 246)", "connectorWidth": "2px",
        "dash": "8px, 5px", "opacity": "0.6",
        "dot": "rgb(37, 99, 235)", "dotSize": "4",
        "darkParent": "rgb(176, 196, 223)",
        "darkMoved": "rgb(69, 107, 146)", "independent": "",
    }, appearance

    page.evaluate("custom.select('bergen')")
    selected = page.evaluate("getComputedStyle(custom.selected.pathEl).stroke")
    assert selected == "rgb(245, 158, 11)", selected
    with page.expect_download() as download_info:
        page.evaluate("custom.exportSvg()")
    exported = Path(download_info.value.path()).read_text(encoding="utf-8")
    assert "rgb(245, 158, 11)" in exported and "rgb(59, 130, 246)" in exported
    assert "stroke-dasharray: 8px, 5px" in exported, exported[:500]

    page.evaluate("""() => {
      custom.manualCounty.set('bergen', {x: 18, y: -9});
      custom._renderNode(custom.selected, 1);
      custom.expandLocal();
    }""")
    page.wait_for_function("custom.locals.length > 0 && !custom.busy")
    page.evaluate("custom.command('bloom', {bloomScale: 1.3, bloomSpread: 1.2}); custom.zoom(1.3)")
    local = page.evaluate("""() => ({
      parent: getComputedStyle(custom.selected.pathEl).stroke,
      child: getComputedStyle(custom.locals[0].pathEl).stroke,
      reference: getComputedStyle(custom.localRefLayer.querySelector('path')).stroke,
      origin: custom.localBaseShift,
      expectedOrigin: custom._offset(custom.selected),
      width: getComputedStyle(custom.locals[0].pathEl).strokeWidth
    })""")
    assert local["parent"] == "rgb(100, 116, 139)" and local["child"] == "rgb(29, 78, 216)", local
    assert local["reference"] == "rgb(148, 163, 184)" and local["origin"] == local["expectedOrigin"], local
    assert local["width"] == "2.5px", local
    page.evaluate("custom.back()")
    restored = page.evaluate("""() => ({
      selected: getComputedStyle(custom.selected.pathEl).stroke,
      parentContext: custom.selected.pathEl.classList.contains('bloomr-parent-context')
    })""")
    assert restored == {"selected": "rgb(245, 158, 11)", "parentContext": False}, restored
    page.evaluate("custom.reset()")
    assert page.evaluate("custom.counties.some(f => f.pathEl.classList.contains('bloomr-moved'))") is False
    assert not errors, errors
    browser.close()
    print("Default and custom styles, selective bloom, local context, return, reset, and SVG: PASS")
