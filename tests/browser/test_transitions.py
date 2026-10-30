"""Browser regression checks for smooth back navigation and keyboard controls.
Run from package source: python tests/browser/test_transitions.py
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
geo = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
js = (root / 'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css = (root / 'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()
read = lambda name: json.loads((geo/name).read_text())
fixture = {
    'state': read('nj_state.geojson'),
    'counties': read('nj_counties.geojson'),
    'local': {'bergen': read('municipalities/bergen.geojson')}
}

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=['--no-sandbox','--disable-dev-shm-usage'])
    page = browser.new_page(viewport={'width': 1140, 'height': 820}, reduced_motion='no-preference')
    failures = []
    page.on('pageerror', lambda e: failures.append(str(e)))
    page.set_content('<div id="map" style="width:900px;height:620px"></div>')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate('''(geometry) => new Bloomr.Map(document.querySelector('#map'), {
      geography: 'nj', inlineGeometry: geometry, duration: 560
    })''', fixture)
    page.wait_for_function('Bloomr.instances.get("map").ready')
    page.evaluate('Bloomr.instances.get("map").expandCounties()')
    page.wait_for_function('!Bloomr.instances.get("map").busy && Bloomr.instances.get("map").countyExpanded')
    page.evaluate('Bloomr.instances.get("map").select("bergen")')
    page.evaluate('Bloomr.instances.get("map").expandLocal()')
    page.wait_for_function('Bloomr.instances.get("map").localExpanded && Bloomr.instances.get("map").locals.length === 70 && !Bloomr.instances.get("map").busy', timeout=30000)
    before = page.evaluate('''() => {
      const m = Bloomr.instances.get('map');
      return {camera:{...m.camera}, county:{...m.countyCamera}};
    }''')
    assert abs(before['camera']['k'] - before['county']['k']) > .2, before
    page.evaluate('Bloomr.instances.get("map").back()')
    page.wait_for_timeout(260)
    middle = page.evaluate('''() => {
      const m = Bloomr.instances.get('map');
      return {busy:m.busy, localExpanded:m.localExpanded, camera:{...m.camera},
        opacity:Number(m.selected.pathEl.style.opacity), localOpacity:Number(m.locals[0].pathEl.style.opacity),
        localCount: m.locals.length};
    }''')
    assert middle['busy'] and middle['localExpanded'] and middle['localCount'] == 70, middle
    assert before['county']['k'] < middle['camera']['k'] < before['camera']['k'], (before,middle)
    assert .12 < middle['opacity'] < 1, middle
    assert 0 <= middle['localOpacity'] <= 1, middle
    page.wait_for_function('!Bloomr.instances.get("map").busy && !Bloomr.instances.get("map").localExpanded')
    after = page.evaluate('''() => {
      const m = Bloomr.instances.get('map');
      return {camera:{...m.camera}, countyOpacity:m.selected.pathEl.style.opacity,
        countyPointer:m.selected.pathEl.style.pointerEvents,
        stateOpacity:m.statePath.style.opacity,
        referenceOpacity:m.localRefLayer.style.opacity,
        localCount: m.locals.length};
    }''')
    assert after['camera'] == before['county'], (after, before)
    assert after['countyOpacity'] == '' and after['stateOpacity'] == '' and after['countyPointer'] == ''
    assert after['referenceOpacity'] == '' and after['localCount'] == 0
    print('Animated local return, county fade, reference fade, and previous camera PASS')

    # Arrow keys move focus, Enter selects, Escape returns. Only one county is in Tab order.
    page.evaluate('Bloomr.instances.get("map").selected.pathEl.focus()')
    assert page.evaluate('document.activeElement.getAttribute("tabindex")') == '0'
    assert page.locator('.bloomr-county[tabindex="0"]').count() == 1
    first = page.evaluate('document.activeElement.getAttribute("aria-label")')
    page.keyboard.press('ArrowRight')
    moved = page.evaluate('document.activeElement.getAttribute("aria-label")')
    assert first != moved, (first, moved)
    page.keyboard.press('Enter')
    assert 'Selected' in page.locator('.bloomr-status').inner_text()
    page.keyboard.press('Escape')
    page.wait_for_function('!Bloomr.instances.get("map").busy && !Bloomr.instances.get("map").countyExpanded')
    assert page.locator('.bloomr-county[tabindex="0"]').count() == 0
    assert page.locator('.bloomr-parent[tabindex="0"]').count() == 1
    assert page.evaluate('document.activeElement.classList.contains("bloomr-parent")')
    print('Arrow keys, Enter, Escape, focus restoration, and one Tab stop PASS')

    # Reset must clear the dimmed layer and disabled pointer events from local mode.
    page.emulate_media(reduced_motion='reduce')
    page.evaluate('Bloomr.instances.get("map").expandCounties()')
    page.evaluate('Bloomr.instances.get("map").select("bergen")')
    page.evaluate('Bloomr.instances.get("map").expandLocal()')
    page.wait_for_function('Bloomr.instances.get("map").localExpanded && Bloomr.instances.get("map").locals.length===70')
    page.evaluate('Bloomr.instances.get("map").reset()')
    assert page.evaluate('''() => {
      const m=Bloomr.instances.get('map');
      return !m.localExpanded && !m.countyExpanded && m.statePath.style.opacity === '' &&
        m.counties.every(c => c.pathEl.style.pointerEvents === '' && c.pathEl.style.opacity === '');
    }''')
    assert not failures, failures
    print('Reduced motion and reset after municipality view PASS')
    page.close()
    browser.close()
