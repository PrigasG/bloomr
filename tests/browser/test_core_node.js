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
console.log('PASS: deterministic layout, level-specific legend, value suffix, raw GeoJSON');
