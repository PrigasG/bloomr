/* Run from package source: node tests/browser/check-assets.js */
const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../inst/htmlwidgets/lib/bloomr-geo/data');
for (const [slug, counties, state, localDir, expected] of [
  ['nj', 'nj_counties.geojson', 'nj_state.geojson', 'municipalities', 21],
  ['tx', 'tx/counties.geojson', 'tx/state.geojson', 'tx/municipalities', 254]
]) {
  const countyJson = JSON.parse(fs.readFileSync(path.join(root, counties), 'utf8'));
  assert.equal(countyJson.features.length, expected);
  const stateJson = JSON.parse(fs.readFileSync(path.join(root, state), 'utf8'));
  assert.ok(stateJson.type === 'Feature' || stateJson.features?.length);
  for (const county of countyJson.features) {
    const id = county.properties.id;
    assert.ok(id, `missing county ID in ${counties}`);
    const file = path.join(root, localDir, `${id}.geojson`);
    assert.ok(fs.existsSync(file), `missing ${file}`);
    const local = JSON.parse(fs.readFileSync(file, 'utf8'));
    assert.ok(local.features?.length, `empty ${file}`);
  }
  const shards = fs.readdirSync(path.join(root, localDir)).filter(file => file.endsWith('.geojson'));
  assert.equal(shards.length, expected);
  process.stdout.write(`${slug}: ${expected} counties, ${shards.length} local geography shards verified\n`);
}
const solver = fs.readFileSync(path.resolve(__dirname, '../../inst/htmlwidgets/lib/bloomr/bloom-core.js'), 'utf8');
assert.match(solver, /function computeGeographicExpansion/);
assert.match(solver, /bloomr:command/);
assert.match(solver, /bloomr:selection/);
assert.match(solver, /curvedTrail/);
assert.match(solver, /prefers-reduced-motion/);
process.stdout.write('Browser engine API contract found\n');
