"""Run browser smoke tests without R or a local web server.
   Requires Python playwright and chromium. Uses bundled actual GeoJSON inline.
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
geo = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
js = (root / 'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css = (root / 'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()

def load(path): return json.loads((geo / path).read_text())

def run_case(browser, state, theme):
    page = browser.new_page(viewport={'width': 1140, 'height': 820})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.set_content('<div style="padding:20px;background:#f4f7fb"><div id="map" style="height:620px;width:900px"></div></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    nj = state == 'nj'
    fixture = {
       'state': load('nj_state.geojson' if nj else 'tx/state.geojson'),
       'counties': load('nj_counties.geojson' if nj else 'tx/counties.geojson'),
       'local': {'bergen':load('municipalities/bergen.geojson')} if nj else {'anderson':load('tx/municipalities/anderson.geojson')}
    }
    page.evaluate('''(p) => {new Bloomr.Map(document.getElementById('map'), {
       geography:p.geography,theme:p.theme,inlineGeometry:p.geometry,duration:0
    });}''', {'geography':state, 'theme':theme, 'geometry': fixture})
    page.wait_for_function('document.querySelector(".bloomr-status").textContent.includes("ready")', timeout=30000)
    assert page.locator('.bloomr-county').count() == (21 if nj else 254)
    assert page.locator('.bloomr-widget').get_attribute('data-bloom-theme') == theme
    page.get_by_role('button',name='Expand counties').first.click()
    assert page.locator('.bloomr-connector[opacity="0.75"]').count() == (21 if nj else 254)
    first = 'bergen' if nj else 'anderson'
    page.evaluate('(id) => Bloomr.instances.get("map").select(id)', first)
    page.get_by_role('button',name='Expand selected county').click()
    page.wait_for_function('Bloomr.instances.get("map").locals.length > 0',timeout=30000)
    assert page.locator('.bloomr-local').count() == (70 if nj else 5)
    assert page.locator('.bloomr-local-connector').count() == (70 if nj else 5)
    page.evaluate('''() => {
       const map = Bloomr.instances.get('map');
       const f = map.locals[0], start = f.trail.getAttribute('d');
       map.manualLocal.set(f.__id,{x:20,y:14}); map._renderNode(f,1);
       if (start===f.trail.getAttribute('d')) throw Error('Connector did not follow moved region');
       const first = map._offset(f);
       map.updateValues([{id:f.__geoid,value:0}]);
       const after = map._offset(f);
       if (first.x!==after.x || first.y!==after.y) throw Error('Data update reset offset');
    }''')
    page.get_by_role('button',name='Return to parent geography').click()
    assert page.locator('.bloomr-local').count() == 0
    print(f'{state} / {theme}: county bloom, local bloom, connectors, selection, data update, back PASS')
    assert not errors, errors
    page.close()

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
    run_case(browser,'nj','light')
    run_case(browser,'tx','dark')
    # Two widgets must not share state or mutate the host page theme.
    page = browser.new_page(viewport={'width':1300,'height':650})
    page.set_content('<div id="map-a" style="height:450px;width:550px;display:inline-block"></div><div id="map-b" style="height:450px;width:550px;display:inline-block"></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    small = {'state':load('nj_state.geojson'),'counties':load('nj_counties.geojson')}
    page.evaluate("""(geometry) => {
      new Bloomr.Map(document.getElementById('map-a'),{inlineGeometry:geometry,geography:'nj',theme:'light',duration:0});
      new Bloomr.Map(document.getElementById('map-b'),{inlineGeometry:geometry,geography:'nj',theme:'dark',duration:0});
    }""",small)
    page.wait_for_function('Bloomr.instances.get("map-a").ready && Bloomr.instances.get("map-b").ready')
    page.evaluate("""() => Bloomr.instances.get('map-a').expandCounties()""")
    assert page.evaluate('Bloomr.instances.get("map-a").countyExpanded')
    assert not page.evaluate('Bloomr.instances.get("map-b").countyExpanded')
    assert page.locator('#map-a').get_attribute('data-bloom-theme') == 'light'
    assert page.locator('#map-b').get_attribute('data-bloom-theme') == 'dark'
    assert page.locator('html').get_attribute('data-theme') is None
    print('Two independent maps and isolated light/dark themes PASS')
    page.close()
    browser.close()
