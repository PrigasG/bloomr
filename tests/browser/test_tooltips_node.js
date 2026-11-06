// Run with: node tests/browser/test_tooltips_node.js
const fs = require('fs'), vm = require('vm'), assert = require('assert'), path = require('path');
const source = fs.readFileSync(path.join(__dirname, '../../inst/htmlwidgets/lib/bloomr/bloom-core.js'), 'utf8');
const window = {};
vm.runInNewContext(source, { window, document: { addEventListener() {} }, console });
const instance = Object.create(window.Bloomr.Map.prototype);
instance.tip = { hidden: true };
instance.updateTooltipRows([
  { id: '34003', fields: [{ label: 'Population', value: '12345' }] }
]);
assert.strictEqual(instance.tooltipDetails.get('34003')[0].label, 'Population');
assert.strictEqual(instance.tooltipDetails.get('34003')[0].value, '12345');
instance.updateTooltipRows([]);
assert.strictEqual(instance.tooltipDetails.size, 0);
console.log('PASS: tooltip field serialization and update');
