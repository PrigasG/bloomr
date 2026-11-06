// Run with: node tests/browser/test_core_node.js
// Pure JavaScript unit checks. Interactive browser tests are separate.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const source = fs.readFileSync(path.join(__dirname, '../../inst/htmlwidgets/lib/bloomr/bloom-core.js'), 'utf8');
const exposed = source.replace('})(window);', 'global.__bloomTests = { geometryInfo, computeGeographicExpansion, makeProjection }; })(window);');
const window = {};
const context = { window, document: { addEventListener() {} }, console, Map, URL, Set, Number, Math, performance };
vm.runInNewContext(exposed, context);
const f = (id, x, y) => ({
  type: 'Feature', properties: { id, geoid: id, name: id },
  geometry: { type: 'Polygon', coordinates: [[[x,y],[x+1,y],[x+1,y+1],[x,y+1],[x,y]]] }
});
const fsample = [f('n1',0,0), f('n2',2,0), f('n3',0,2)];
const project = context.window.__bloomTests.makeProjection(fsample);
const prepared = fsample.map(x => {
  const info = context.window.__bloomTests.geometryInfo(x, project);
  return { __centroid: info.center, __bounds: info.bounds };
});
const expand = () => {
  const nodes = prepared.map(x => ({ __centroid: x.__centroid, __bounds: x.__bounds }));
  context.window.__bloomTests.computeGeographicExpansion(nodes, [500,360], {
    scale:1.5, radialKick:10, gap:5, iterations:8, cleanupIterations:3, offsetProperty:'__baseCountyOffset'
  });
  return nodes.map(x => x.__baseCountyOffset);
};
assert.deepEqual(expand(), expand(), 'geographic expansion remains deterministic');
const map = Object.create(context.window.Bloomr.Map.prototype);
map.counties = [{ __id:'north', __geoid:'north' }, { __id:'south', __geoid:'south' }];
map.locals = [{ __id:'N1', __geoid:'N1' }, { __id:'N2', __geoid:'N2' }];
map.values = new Map([['north',100],['south',200],['N1',10],['N2',20]]);
map.config = { valueSuffix:'%' };
map.localExpanded = false;
assert.deepEqual(Array.from(map._legendValues()),[100,200]);
map.localExpanded = true;
assert.deepEqual(Array.from(map._legendValues()),[10,20]);
assert.strictEqual(map._formatValue(10),'10%');
const json = JSON.stringify({ type:'FeatureCollection', features:[fsample[0]] });
assert.strictEqual(map._readGeometry(json).features.length,1);
const county = map.counties[0];
let selected = 0, expanded = 0;
map.busy = false;
map.countyExpanded = true;
map.localExpanded = false;
map.config.maxLevel = 'local';
map.selected = null;
map.select = () => { map.selected = county; selected += 1; };
map.expandLocal = () => { expanded += 1; };
const key = { key: 'Enter', preventDefault() {} };
map._regionKeydown(key, county, 'county');
map._regionKeydown(key, county, 'county');
assert.strictEqual(selected, 1, 'first Enter selects the focused county');
assert.strictEqual(expanded, 1, 'second Enter blooms its local geography');
const attrs = {};
const node = { __id: 'north', __level: 'county', __centroid: [20, 30],
  __baseCountyOffset: { x: 80, y: 40 }, __bloom: false,
  pathEl: { setAttribute(k, v) { attrs[`path.${k}`] = v; } },
  trail: { setAttribute(k, v) { attrs[`trail.${k}`] = v; }, style: {} },
  dot: { setAttribute(k, v) { attrs[`dot.${k}`] = v; }, style: {} }
};
map.config.dots = map.config.connectors = true;
map.manualCounty = new Map();
map.project = project;
map.config.bloomAreas = ['3400352320'];
const stray = { ...fsample[0], properties: { id: '320', geoid: '3400347700', name: 'Other area' } };
const picked = { ...fsample[0], properties: { id: '302', geoid: '3400352320', name: 'Chosen area' } };
assert.strictEqual(map._prepare(stray, 'county').__bloom, false, 'other GEOIDs do not match by substring');
assert.strictEqual(map._prepare(picked, 'county').__bloom, true, 'chosen GEOID matches exactly');
map.config.bloomColor = '#F97316';
assert.strictEqual(map._color(picked, 'county', 0), '#F97316', 'chosen area uses its fixed color');
assert.notStrictEqual(map._color(stray, 'county', 0), '#F97316', 'other areas retain their data color');
map._renderNode(node, 1);
assert.strictEqual(attrs['path.transform'], 'translate(0,0)', 'unselected area remains on the parent map');
assert.strictEqual(attrs['path.opacity'], 1, 'unselected area stays visible');
assert.strictEqual(attrs['trail.opacity'], 0, 'unselected area has no connector');
assert.strictEqual(attrs['dot.opacity'], 0, 'unselected area has no origin dot');
node.__bloom = true;
map._renderNode(node, 1);
assert.strictEqual(attrs['path.transform'], 'translate(80,40)', 'chosen area blooms');
assert.strictEqual(attrs['trail.opacity'], .75);
assert.strictEqual(attrs['dot.opacity'], .85);
console.log('PASS: deterministic layout, legends, tooltips, keyboard and selective bloom');
