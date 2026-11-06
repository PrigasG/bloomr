"""Test seamless, toolbar-free maps and retain the ordinary card behavior."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[2]
assets = root / 'inst/htmlwidgets/lib/bloomr-geo/data'
js = (root / 'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css = (root / 'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()
def load(name): return json.loads((assets/name).read_text())
geometry = {'state':load('nj_state.geojson'), 'counties':load('nj_counties.geojson'),
            'local':{'bergen':load('municipalities/bergen.geojson')}}
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
    page = browser.new_page(viewport={'width':1250,'height':850})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.set_content('''<style>body{margin:20px;background:#f6f8fb}
        #seamless{height:500px;width:800px}#card{height:300px;width:360px}</style>
        <div id="seamless"></div><div id="card"></div>''')
    page.add_style_tag(content=css)
    page.add_script_tag(content=js)
    page.evaluate('''(g) => {
       new Bloomr.Map(document.getElementById('seamless'),{
          geography:'nj',inlineGeometry:g,appearance:'seamless',controls:false,duration:0
       });
       new Bloomr.Map(document.getElementById('card'),{
          geography:'nj',inlineGeometry:g,duration:0
       });
    }''',geometry)
    page.wait_for_function('Bloomr.instances.get("seamless").ready && Bloomr.instances.get("card").ready')
    assert page.locator('#seamless .bloomr-toolbar').is_hidden()
    assert page.locator('#card .bloomr-toolbar').is_visible()
    assert page.locator('#seamless').get_attribute('data-bloom-appearance') == 'seamless'
    assert page.locator('#card').get_attribute('data-bloom-appearance') == 'card'
    style = page.evaluate('''() => {
      const e=document.querySelector('#seamless');
      return {border:getComputedStyle(e).borderTopWidth,
              background:getComputedStyle(e.querySelector('.bloomr-stage')).backgroundColor};
    }''')
    assert style['border']=='0px',style
    assert style['background'] in ('rgba(0, 0, 0, 0)','transparent'),style
    page.locator('#seamless .bloomr-svg').click(position={'x':5,'y':5})
    page.wait_for_function('Bloomr.instances.get("seamless").countyExpanded && !Bloomr.instances.get("seamless").busy')
    assert page.locator('#seamless .bloomr-minimal-nav').is_visible()
    assert page.locator('#seamless .bloomr-connector').count()==21
    assert page.locator('#seamless .bloomr-origin-dot').count()==21
    page.evaluate('Bloomr.instances.get("seamless").select("bergen")')
    assert page.get_by_role('button',name='Explore selected region').is_visible()
    page.get_by_role('button',name='Explore selected region').click()
    page.wait_for_function('Bloomr.instances.get("seamless").localExpanded && !Bloomr.instances.get("seamless").busy')
    assert page.locator('#seamless .bloomr-local').count()==70
    page.locator('#seamless .bloomr-minimal-nav button[aria-label="Return to parent geography"]').click()
    page.wait_for_function('!Bloomr.instances.get("seamless").localExpanded && !Bloomr.instances.get("seamless").busy')
    assert page.locator('#seamless .bloomr-local').count()==0
    assert page.locator('#seamless .bloomr-minimal-nav').is_visible()
    # Ctrl+wheel zoom changes the camera. Regular wheel does not intercept scrolling/zoom.
    page.evaluate('''() => {
        const m=Bloomr.instances.get('seamless'); const r=m.svg.getBoundingClientRect();
        m.svg.dispatchEvent(new WheelEvent('wheel',{bubbles:true,cancelable:true,ctrlKey:true,
          clientX:r.left+r.width/2,clientY:r.top+r.height/2,deltaY:-100}));
    }''')
    assert page.evaluate('Bloomr.instances.get("seamless").camera.k')>1
    # Default card untouched by seamless configuration or navigation.
    assert page.evaluate('Bloomr.instances.get("card").countyExpanded') is False
    page.screenshot(path=str(root.parent/'bloomr_seamless_preview.png'))
    assert errors==[],errors
    print('PASS: seamless styling, toolbar hidden, click bloom, origin guides, local view, Back, Ctrl+wheel, independent card')
    browser.close()
