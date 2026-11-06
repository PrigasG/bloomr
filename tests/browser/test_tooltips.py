"""Tooltips: custom fields, separate data, escaping, updates, default view."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
root = Path(__file__).resolve().parents[2]
base = root/'inst/htmlwidgets/lib/bloomr-geo/data'
fixture = {
    'state': json.loads((base/'nj_state.geojson').read_text()),
    'counties': json.loads((base/'nj_counties.geojson').read_text())
}
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path='/usr/bin/chromium',
        args=['--no-sandbox', '--disable-dev-shm-usage'])
    page = browser.new_page(viewport={'width': 950, 'height': 700})
    errors=[]
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.set_content('<div id="map" style="width:800px;height:520px"></div>')
    page.add_style_tag(content=(root/'inst/htmlwidgets/lib/bloomr/bloom.css').read_text())
    page.add_script_tag(content=(root/'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text())
    page.evaluate('''(geometry) => new Bloomr.Map(document.querySelector('#map'), {
        geography: 'nj', inlineGeometry: geometry, duration: 0,
        data: [{id:'34003', value:10}],
        tooltipRows: [{id:'34003',fields:[
          {label:'Population', value:'12345'},
          {label:'Notes', value:'<img src=x onerror=alert(1)>'}
        ]}]
    })''',fixture)
    page.wait_for_function('Bloomr.instances.get("map").ready',timeout=12000)
    page.evaluate('Bloomr.instances.get("map").expandCounties()')
    page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      const f=m.counties.find(f=>f.__geoid==='34003');
      m._tooltip({clientX:250,clientY:200},f);
    }''')
    tip=page.locator('.bloomr-tooltip')
    assert 'Population' in tip.inner_text()
    assert '12,345' not in tip.inner_text() # raw text is never assumed to be numeric formatting
    assert '12345' in tip.inner_text()
    assert '10' in tip.inner_text()
    assert '<img src=x onerror=alert(1)>' in tip.inner_text()
    assert page.locator('.bloomr-tooltip img').count()==0
    before=page.evaluate('''() => Bloomr.instances.get('map').tip.querySelector('.bloomr-tooltip-heading')''')
    # move pointer: DOM nodes must remain unchanged
    assert page.evaluate('''() => {
       const m=Bloomr.instances.get('map'), f=m.counties.find(f=>f.__geoid==='34003');
       const head=m.tip.querySelector('.bloomr-tooltip-heading');
       m._tooltip({clientX:280,clientY:210},f);
       return m.tip.querySelector('.bloomr-tooltip-heading')===head;
    }''')
    page.evaluate('''() => Bloomr.instances.get('map').command('data',{
        rows:[{id:'34003',value:20}],tooltipRows:[{id:'34003',fields:[{label:'Notes',value:'Updated'}]}]
    })''')
    page.evaluate('''() => {
        const m=Bloomr.instances.get('map'), f=m.counties.find(f=>f.__geoid==='34003');
        m._tooltip({clientX:280,clientY:210},f)
    }''')
    assert 'Updated' in tip.inner_text() and '20' in tip.inner_text()
    assert 'Population' not in tip.inner_text()
    # Current fields are preserved if a later data change only updates values.
    page.evaluate('''() => Bloomr.instances.get('map').command('data',{
        rows:[{id:'34003',value:25}]
    })''')
    assert page.evaluate('Bloomr.instances.get("map").tooltipDetails.get("34003")[0].value') == 'Updated'
    assert not errors, errors
    print('PASS: custom tooltip fields, safe text, hover recycling, Shiny updates and persistence')
    browser.close()
