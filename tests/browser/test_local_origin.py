"""Check original and expanded-parent local bloom behavior in Chromium.
Run: python tests/browser/test_local_origin.py
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
geo = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
js = (root / 'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css = (root / 'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()

def read(name): return json.loads((geo / name).read_text())

def run_case(page, state, county, mode, manual=None, via_display=False):
    opts = {"geography": state, "localOrigin": mode, "duration": 0,
        "inlineGeometry": {"state": read('tx/state.geojson' if state == 'tx' else 'nj_state.geojson'),
                           "counties": read('tx/counties.geojson' if state == 'tx' else 'nj_counties.geojson'),
                           "local": {county: read(('tx/' if state == 'tx' else '') + f'municipalities/{county}.geojson')}}}
    page.evaluate('(options) => {document.getElementById("map").replaceChildren();new Bloomr.Map(document.getElementById("map"), options)}',opts)
    page.wait_for_function('Bloomr.instances.get("map").ready')
    page.evaluate('Bloomr.instances.get("map").expandCounties()')
    page.evaluate('(county) => Bloomr.instances.get("map").select(county)',county)
    if manual:
        page.evaluate('(offset) => {const m=Bloomr.instances.get("map");m.manualCounty.set(m.selected.__id,offset);m._renderNode(m.selected,1)}',manual)
    if via_display:
        page.locator('.bloomr-button[aria-label="Map display options"]').click()
        page.locator('.bloomr-display-option').filter(has_text='Bloom from expanded parent').locator('input').check()
        assert page.evaluate('Bloomr.instances.get("map").config.localOrigin') == 'expanded'
    initial = page.evaluate('''() => {const m=Bloomr.instances.get('map');return {offset:m._offset(m.selected),camera:{...m.camera}}}''')
    page.evaluate('Bloomr.instances.get("map").expandLocal()')
    page.wait_for_function('!Bloomr.instances.get("map").busy && Bloomr.instances.get("map").locals.length>0 && Bloomr.instances.get("map").localExpanded',timeout=40000)
    result = page.evaluate('''() => {
      const m=Bloomr.instances.get('map'); const f=m.locals[0];
      const layers=[m.localRefLayer,m.localLineLayer,m.localDotLayer,m.localShapeLayer,m.localLabelLayer];
      return {offset:m.localBaseShift,transforms:layers.map(layer=>layer.getAttribute('transform')),
        countyPosition:m._offset(m.selected),camera:m.camera,countyCamera:m.countyCamera,
        dots:[Number(f.dot.getAttribute('cx')),Number(f.dot.getAttribute('cy'))],
        trail:f.trail.getAttribute('d'),
        regionTransform:f.pathEl.getAttribute('transform'),
        pathTransform:m.localShapeLayer.getAttribute('transform'),
        controlDisabled:m.localOriginOption.control.disabled,
        localCount:m.locals.length,
        selectedId:m.selected.__id}
    }''')
    assert result['localCount'] >= 1, result
    expect = initial['offset'] if mode == 'expanded' else {'x':0,'y':0}
    for k in ('x','y'): assert abs(result['offset'][k] - expect[k]) < 1e-5, (mode,result,initial)
    expectedTransform = f'translate({expect["x"]},{expect["y"]})' if expect['x'] or expect['y'] else ''
    assert result['transforms'] == [expectedTransform]*5, (mode,result['transforms'],expectedTransform)
    assert result['controlDisabled'], result
    # The county camera must remain the camera before opening local geography.
    assert result['countyCamera'] == initial['camera'],(result,initial)
    # Return leaves county at its expanded location and resets all local layer offsets.
    page.evaluate('Bloomr.instances.get("map").back()')
    page.wait_for_function('!Bloomr.instances.get("map").busy && !Bloomr.instances.get("map").localExpanded')
    after=page.evaluate('''() => {const m=Bloomr.instances.get('map');return {
      camera:m.camera,offset:m._offset(m.selected),transforms:[m.localRefLayer,m.localLineLayer,m.localDotLayer,m.localShapeLayer,m.localLabelLayer].map(x=>x.getAttribute('transform')),localCount:m.locals.length,optionDisabled:m.localOriginOption.control.disabled}
    }''')
    assert after['camera'] == initial['camera'], (after,initial)
    assert after['offset'] == initial['offset']
    assert after['transforms'] == ['']*5 and not after['optionDisabled'] and after['localCount']==0,after
    print(state,county,mode,'manual=',bool(manual),'via_display=',via_display,'PASS')

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
    page=browser.new_page(viewport={'width':1120,'height':900},reduced_motion='reduce')
    errors=[]; page.on('pageerror',lambda e: errors.append(str(e)))
    page.set_content('<div id="map" style="width:900px;height:700px"></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    run_case(page,'nj','bergen','original')
    run_case(page,'nj','bergen','expanded')
    run_case(page,'nj','bergen','expanded',manual={'x':45,'y':-30})
    run_case(page,'nj','bergen','expanded',via_display=True)
    run_case(page,'tx','anderson','expanded')
    assert not errors,errors
    print('ALL origin positioning and return checks passed')
    browser.close()
