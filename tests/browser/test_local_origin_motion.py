"""Animated local bloom origin and camera regression checks."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[2]
geo=root/'inst/htmlwidgets/lib/bloomr-geo/data'
load=lambda p: json.loads((geo/p).read_text())
fixture={'state':load('nj_state.geojson'),'counties':load('nj_counties.geojson'),
         'local':{'bergen':load('municipalities/bergen.geojson')}}
js=(root/'inst/htmlwidgets/lib/bloomr/bloom-core.js').read_text()
css=(root/'inst/htmlwidgets/lib/bloomr/bloom.css').read_text()
with sync_playwright() as p:
  browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
  page=browser.new_page(viewport={'width':1150,'height':830},reduced_motion='no-preference')
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.set_content('<div style="padding:10px"><div id="map" style="width:970px;height:740px"></div></div>')
  page.add_style_tag(content=css);page.add_script_tag(content=js)
  page.evaluate('geo=>new Bloomr.Map(document.getElementById("map"),{geography:"nj",duration:650,localOrigin:"expanded",inlineGeometry:geo})',fixture)
  page.wait_for_function('Bloomr.instances.get("map").ready')
  page.evaluate('Bloomr.instances.get("map").expandCounties()')
  page.wait_for_function('!Bloomr.instances.get("map").busy && Bloomr.instances.get("map").countyExpanded')
  page.evaluate('Bloomr.instances.get("map").select("bergen")')
  page.evaluate('Bloomr.instances.get("map").expandLocal()')
  page.wait_for_function('Bloomr.instances.get("map").busy && Bloomr.instances.get("map").locals.length>0')
  page.wait_for_timeout(250)
  during=page.evaluate('''() => {const m=Bloomr.instances.get('map');return {busy:m.busy,shift:m.localBaseShift,localTransform:m.localShapeLayer.getAttribute('transform'),countyOpacity:m.selected.pathEl.style.opacity}}''')
  assert during['busy'] and during['localTransform'] and 0.12 < float(during['countyOpacity']) < 1, during
  page.wait_for_function('!Bloomr.instances.get("map").busy && Bloomr.instances.get("map").localExpanded')
  page.evaluate('Bloomr.instances.get("map").back()')
  page.wait_for_timeout(260)
  returning=page.evaluate('''() => {const m=Bloomr.instances.get('map');return {busy:m.busy,localTransform:m.localShapeLayer.getAttribute('transform'),localOpacity:m.locals[0].pathEl.style.opacity,countyOpacity:m.selected.pathEl.style.opacity}}''')
  assert returning['busy'] and returning['localTransform'] == during['localTransform'] and 0 < float(returning['localOpacity']) <= 1 and 0.12 < float(returning['countyOpacity']) < 1, returning
  page.wait_for_function('!Bloomr.instances.get("map").busy && !Bloomr.instances.get("map").localExpanded')
  page.evaluate('''() => {const m=Bloomr.instances.get('map');m.config.localOrigin='original';m.localOriginOption.control.checked=false}''')
  page.evaluate('Bloomr.instances.get("map").expandLocal()')
  page.wait_for_function('!Bloomr.instances.get("map").busy && Bloomr.instances.get("map").localExpanded')
  original=page.evaluate('''() => {const m=Bloomr.instances.get('map');return {transform:m.localShapeLayer.getAttribute('transform'),shift:m.localBaseShift}}''')
  assert original['transform']=='' and original['shift']=={'x':0,'y':0},original
  assert not errors,errors
  print('Animated expanded-parent bloom and return PASS')
  print('Switch back to original location on next bloom PASS')
  browser.close()
