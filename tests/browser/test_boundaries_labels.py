"""Focused regression tests for optional fixed outlines and area labels."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
asset = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
js = (root / 'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css = (root / 'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()
read = lambda path: json.loads((asset / path).read_text())
fixture = {
    'state': read('nj_state.geojson'),
    'counties': read('nj_counties.geojson'),
    'local': {'bergen': read('municipalities/bergen.geojson')}
}

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path='/usr/bin/chromium',
        args=['--no-sandbox', '--disable-dev-shm-usage'])
    page = browser.new_page(viewport={'width': 1150, 'height': 800})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.set_content('<div style="padding:12px;background:white"><div id="map" style="height:610px;width:900px"></div></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate('''geo => new Bloomr.Map(document.querySelector('#map'), {
      geography: 'nj', inlineGeometry: geo, duration: 0, labelAreas: ['bergen'], labels: 'none'
    })''', fixture)
    page.wait_for_function('Bloomr.instances.get("map").ready')
    assert page.locator('.bloomr-overview-reference').count() == 21
    assert page.locator('.bloomr-area-label').count() == 21
    assert page.evaluate('getComputedStyle(document.querySelector(".bloomr-reference-layer")).display') != 'none'
    assert page.evaluate("() => Bloomr.instances.get('map').counties.every(f => f.labelEl.style.display === 'none')")
    page.screenshot(path=str(root.parent / 'bloom_overview_boundaries.png'))

    page.get_by_role('button', name='Map display options').click()
    assert page.get_by_label('Overview: county lines').is_checked()
    assert page.get_by_label('Local: municipality lines').is_checked()
    assert page.get_by_label('Map labels').input_value() == 'none'
    page.get_by_label('Overview: county lines').uncheck()
    assert page.evaluate('document.querySelector(".bloomr-reference-layer").style.display') == 'none'
    page.get_by_label('Overview: county lines').check()
    assert page.evaluate('document.querySelector(".bloomr-reference-layer").style.display') == ''
    page.get_by_label('Map labels').select_option('custom')
    page.get_by_role('button', name='Map display options').click()
    page.get_by_role('button', name='Expand counties').click()
    assert page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      return m.counties.filter(f=>f.labelEl.style.display !== 'none').map(f=>f.__id);
    }''') == ['bergen']
    assert page.locator('.bloomr-connector[opacity="0.75"]').count() == 21
    page.screenshot(path=str(root.parent / 'bloom_chosen_county_label.png'))
    # Shift+click is a simple way for viewers to choose other labels, without selection reset.
    page.evaluate('''() => {
      const f=Bloomr.instances.get('map').counties.find(f=>f.__id==='essex');
      f.pathEl.dispatchEvent(new MouseEvent('click',{bubbles:true,shiftKey:true}));
    }''')
    assert sorted(page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      return m.counties.filter(f=>f.labelEl.style.display !== 'none').map(f=>f.__id);
    }''')) == ['bergen','essex']
    page.get_by_role('button', name='Map display options').click()
    page.get_by_label('Map labels').select_option('none')
    page.get_by_label('Map labels').select_option('selected')
    page.get_by_role('button', name='Map display options').click()
    page.evaluate('Bloomr.instances.get("map").select("bergen")')
    assert page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      return m.counties.filter(f=>f.labelEl.style.display!=='none').map(f=>f.__id);
    }''') == ['bergen']
    page.get_by_role('button', name='Expand selected county').click()
    assert page.locator('.bloomr-local-reference').count() == 70
    page.get_by_role('button', name='Map display options').click()
    page.get_by_label('Local: municipality lines').uncheck()
    assert page.evaluate('document.querySelector(".bloomr-local-reference-layer").style.display') == 'none'
    assert page.evaluate('document.querySelector(".bloomr-reference-layer").style.display') == ''
    page.get_by_label('Local: municipality lines').check()
    page.get_by_label('Map labels').select_option('all')
    page.get_by_role('button', name='Map display options').click()
    displayed = page.evaluate('''() => Bloomr.instances.get('map').locals.filter(f=>f.labelEl.style.display!=='none').length''')
    assert 0 < displayed < 70, displayed
    # A selected local label appears in selected-only mode.
    page.get_by_role('button', name='Map display options').click()
    page.get_by_label('Map labels').select_option('selected')
    page.get_by_role('button', name='Map display options').click()
    page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      m.select(m.locals[0].__id,'local');
    }''')
    assert page.evaluate('''() => Bloomr.instances.get('map').locals.filter(f=>f.labelEl.style.display!=='none').length''') == 1
    # Keyboard L pins/unpins only the focused region; it never triggers a full reset.
    page.evaluate('Bloomr.instances.get("map").locals[0].pathEl.focus()')
    page.keyboard.press('l')
    assert page.evaluate('Bloomr.instances.get("map").config.labels') == 'custom'
    assert page.evaluate('Bloomr.instances.get("map").pinnedLabels.size') >= 1
    page.get_by_role('button', name='Return to parent geography').click()
    assert page.locator('.bloomr-local-reference').count() == 0
    assert page.locator('.bloomr-overview-reference').count() == 21
    assert page.evaluate('document.querySelector(".bloomr-reference-layer").style.opacity') == ''
    assert not errors, errors
    print('Overview/local boundary defaults, independent switches, labels and collapse PASS')
    page.close()
    # One-id vectors commonly arrive from R serialized as scalar text.
    page = browser.new_page()
    page.set_content('<div id="single" style="height:500px;width:700px"></div>')
    page.add_style_tag(content=css); page.add_script_tag(content=js)
    page.evaluate('''geo => new Bloomr.Map(document.querySelector('#single'), {
      inlineGeometry: geo, duration: 0, labels: 'custom', labelAreas: 'bergen'
    })''', {'state':fixture['state'],'counties':fixture['counties']})
    page.wait_for_function('Bloomr.instances.get("single").ready')
    page.evaluate('Bloomr.instances.get("single").expandCounties()')
    assert page.evaluate('''() => Bloomr.instances.get('single').counties.filter(f=>f.labelEl.style.display!=='none').map(f=>f.__id)''') == ['bergen']
    print('Single chosen label is accepted PASS')
    # A widget re-render must not accumulate the old Escape listener.
    page.evaluate('''() => {
      const old = Bloomr.instances.get('single');
      old.destroy();
      if (old.el.querySelector('.bloomr-shell')) throw Error('Old widget DOM remained');
    }''')
    assert page.evaluate('document.querySelector("#single").getAttribute("data-bloom-theme")') is None
    browser.close()
