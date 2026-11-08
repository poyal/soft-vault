const fs = require('fs');
const vm = require('vm');
const source = fs.readFileSync('design/app.js', 'utf8');
const literal = source.match(/const media = (\[[\s\S]*?\])\.map/)[1];
const rows = vm.runInNewContext(literal, {}, {timeout: 1000});
fs.mkdirSync('test/fixtures', {recursive:true});
fs.writeFileSync('test/fixtures/design-media.json', JSON.stringify(rows, null, 2));
