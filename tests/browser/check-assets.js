/* Run from package source: node tests/browser/check-assets.js */
const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../inst/htmlwidgets/lib/bloomr-geo/data');
for (const [slug, counties, state, localPath, expected] of [
  ['nj', 'nj_counties.geojson', 'nj_state.geojson', 'municipalities/index.json', 21],
  ['tx', 'tx/counties.geojson', 'tx/state.geojson', 'tx/municipalities/index.json', 254]
]) {
  const countyJson = JSON.parse(fs.readFileSync(path.join(root, counties), 'utf8'));
  assert.equal(countyJson.features.length, expected);
  const stateJson = JSON.parse(fs.readFileSync(path.join(root, state), 'utf8'));
  assert.ok(stateJson.type === 'Feature' || stateJson.features?.length);
  const index = JSON.parse(fs.readFileSync(path.join(root, localPath), 'utf8'));
  assert.equal(index.counties.length, expected);
  for (const c of index.counties) {
    const file = path.join(root, slug === 'nj' ? 'municipalities' : 'tx/municipalities', c.file);
    assert.ok(fs.existsSync(file), `missing ${file}`);
  }
  process.stdout.write(`${slug}: ${expected} counties, ${index.counties.length} local geography shards verified\n`);
}
const solver = fs.readFileSync(path.resolve(__dirname, '../../inst/htmlwidgets/lib/bloomr/bloom-core.js'), 'utf8');
assert.match(solver, /function computeGeographicExpansion/);
assert.match(solver, /bloomr:command/);
assert.match(solver, /bloomr:selection/);
assert.match(solver, /curvedTrail/);
assert.match(solver, /prefers-reduced-motion/);
process.stdout.write('Browser engine API contract found\n');
