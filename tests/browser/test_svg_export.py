"""Test the SVG's standalone styles without requiring an R server.
Run: python tests/browser/test_svg_export.py
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
geo = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
read = lambda name: json.loads((geo/name).read_text())
fixture = {
    'state': read('nj_state.geojson'),
    'counties': read('nj_counties.geojson'),
    'local': {'bergen': read('municipalities/bergen.geojson')}
}
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=['--no-sandbox','--disable-dev-shm-usage'])
    page = browser.new_page(accept_downloads=True, viewport={'width': 1024, 'height': 780})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.set_content('<div id="map" style="width:900px;height:620px"></div>')
    page.add_style_tag(content=(root/'inst/htmlwidgets/lib/bloomr/bloom.css').read_text())
    page.add_script_tag(content=(root/'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text())
    page.evaluate('''(geometry) => new Bloomr.Map(document.querySelector('#map'), {
       inlineGeometry:geometry, geography:'nj', duration:0
    })''',fixture)
    page.wait_for_function('Bloomr.instances.get("map").ready')
    page.evaluate('Bloomr.instances.get("map").expandCounties()')
    page.evaluate('Bloomr.instances.get("map").select("bergen")')
    page.evaluate('Bloomr.instances.get("map").expandLocal()')
    page.wait_for_function('Bloomr.instances.get("map").locals.length === 70')
    with page.expect_download() as task:
        page.get_by_role('button', name='Export visible map as SVG').click()
    output = root.parent/'bloom_export_test.svg'
    task.value.save_as(str(output))
    contents = output.read_text()
    assert contents.startswith('<svg')
    assert 'stroke-dasharray' in contents and 'stroke-width' in contents
    assert 'bloomr-origin-dot' in contents and 'bloomr-local-connector' in contents
    assert 'fill: rgb(' in contents or 'fill: #' in contents
    assert not errors, errors
    print('SVG export retains independent background, origin dots and connector styles PASS')
    page.close(); browser.close()
