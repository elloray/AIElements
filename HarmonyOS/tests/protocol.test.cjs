const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const build = process.env.AI_ELEMENTS_TEST_BUILD;
const { shadcnTableRows } = require(path.join(build, 'shadcn/TableRows.js'));
test('shadcn email filtering, ordering and row identities survive host data changes', () => {
  const a = ['Paid', 'a@site.test'], b = ['Open', 'b@site.test'];
  assert.deepEqual(shadcnTableRows([a, b], ['a','b'], 'Paid', -1, true, 1), []);
  assert.deepEqual(shadcnTableRows([b, a], ['b','a'], 'A@SITE', 1, true, 1),
    [{ id: 'a', index: 1, cells: a }]);
  assert.deepEqual(shadcnTableRows([b, [], a], ['b','empty','a'], '', 1, true).map(r => r.id), ['empty','a','b']);
  assert.deepEqual(shadcnTableRows([a, a], ['same','same'], '', 1, false).map(r => r.id), ['0','1']);
});
const { AIUIComponentCatalog } = require(path.join(build, 'protocol/Models.js'));
const { AIUISession, AIUIStreamDecoder, decodeDocument } = require(path.join(build, 'protocol/Streaming.js'));
const { AIUIStore } = require(path.join(build, 'protocol/Store.js'));
const { displaySurface } = require(path.join(build, 'ui/Surface.js'));
const { messageBlocks } = require(path.join(build, 'ui/Markdown.js'));
const { chartDomain, naturalDerivatives } = require(path.join(build, 'ui/ChartGeometry.js'));
const fixtures = path.resolve(__dirname, '../../Sources/AIElementsUIProtocol/Resources');
const fixture = name => fs.readFileSync(path.join(fixtures, name));
const frame = fields => ({ version: '1.0', surfaceID: 'report', revision: 0, ...fields });

test('all 15 node types and the dashboard decode from the shared static fixtures', () => {
  const names = fs.readdirSync(fixtures).filter(file => file.endsWith('.json') && file !== 'schema.json');
  const covered = new Set();
  for (const name of names) {
    const doc = decodeDocument(fixture(name));
    for (const node of Object.values(doc.nodes)) covered.add(node.type);
    assert.equal(displaySurface(doc).id, doc.root);
  }
  assert.deepEqual([...covered].sort(), Object.keys(AIUIComponentCatalog).sort());
});

test('streaming dashboard emits revisions and retains valid local input through independent patches', () => {
  const store = new AIUIStore();
  const revisions = [];
  const unsubscribe = store.subscribe(() => revisions.push(store.document?.revision));
  for (const byte of fixture('dashboard.jsonl')) {
    store.receive(Uint8Array.of(byte));
    if (store.document?.revision === 5 && store.document.state.period === 'six-months') {
      assert.equal(store.setValue('period', 'three-months'), true);
    }
  }
  unsubscribe();
  store.finish();
  assert.deepEqual([...new Set(revisions)], Array.from({ length: 16 }, (_, i) => i));
  assert.equal(store.phase, 'complete');
  assert.equal(store.document.state.period, 'three-months');
  assert.equal(store.setValue('period', 'unlisted'), false);
  assert.match(store.errorMessage, /absent from options/);
  assert.equal(store.document.state.period, 'three-months');
  assert.equal(store.setValue('compare', true), true);
  assert.equal(store.errorMessage, undefined);
  const event = store.event('submit', 'press');
  assert.equal(event.name, 'save_report');
  assert.equal(event.revision, 15);
  assert.deepEqual({ ...event.state }, { reportName: 'Visitors report', period: 'three-months', compare: true });
  assert.deepEqual(Object.keys(store.event('period', 'change', 'three-months').state), ['period']);
  const chart = displaySurface(store.document).children.find(node => node.id === 'report').children[0];
  assert.deepEqual({ ...chart.chartSelection(chart.chartRows()[0]) }, { label: 'January', desktop: 186 });
});

test('split UTF-8 and a final line without LF are decoded strictly', () => {
  const decoder = new AIUIStreamDecoder();
  const input = Buffer.from(JSON.stringify(frame({ kind: 'surface.error', message: '中文 🪁' })));
  const events = [];
  input.forEach(byte => decoder.append(Uint8Array.of(byte), event => events.push(event)));
  assert.equal(events.length, 0);
  decoder.finish(event => events.push(event));
  assert.equal(events[0].message, '中文 🪁');
  assert.throws(() => decoder.append(Uint8Array.of(0xed, 0xa0, 0x80, 10), assert.fail), /Invalid UTF-8/);
  assert.throws(() => new AIUIStreamDecoder(2).append(Uint8Array.of(65, 65, 65), assert.fail), /size limit/);
});

test('bad patches are atomic and the store retains the last valid frame on disconnect', () => {
  const store = new AIUIStore();
  store.receiveLine(fixture('dashboard.jsonl').toString().split('\n')[0]);
  const previous = store.document;
  assert.throws(() => store.receiveLine(JSON.stringify(frame({ kind: 'surface.update', revision: 2, baseRevision: 0 }))),
    /Out-of-order/);
  assert.equal(store.document, previous);
  assert.equal(store.phase, 'failed');
  store.reset();
  store.receiveLine(fixture('dashboard.jsonl').toString().split('\n')[0]);
  store.finish();
  assert.equal(store.phase, 'failed');
  assert.match(store.errorMessage, /interrupted/);
  assert.equal(store.document.revision, 0);
});

test('staged roots may be incomplete until completion and detached cycles are rejected', () => {
  const session = new AIUISession();
  session.apply(frame({ kind: 'surface.begin', root: 'a' }));
  assert.throws(() => session.apply(frame({ kind: 'surface.complete', revision: 1, baseRevision: 0 })), /Missing/);
  assert.equal(session.document.revision, 0);
  assert.throws(() => session.apply(frame({ kind: 'surface.update', revision: 1, baseRevision: 0,
    nodes: { x: { type: 'Stack', children: ['y'] }, y: { type: 'Card', children: ['x'] } } })), /Cycle/);
  session.apply(frame({ kind: 'surface.complete', revision: 1, baseRevision: 0, nodes: { a: { type: 'Text' } } }));
  assert.equal(session.phase, 'complete');
  session.apply(frame({ kind: 'surface.remove', revision: 2, baseRevision: 1 }));
  assert.equal(session.phase, 'removed');
  assert.equal(session.document, undefined);
});

test('state and node keys use JSON dictionary semantics across patches and events', () => {
  const session = new AIUISession();
  session.apply(JSON.parse('{"kind":"surface.begin","surfaceID":"s","revision":0,"root":"__proto__",'
    + '"nodes":{"__proto__":{"type":"Button","events":{"press":{"name":"save","stateKeys":["__proto__","constructor"]}}}},'
    + '"state":{"__proto__":"kept","private":"hidden"}}'));
  session.apply({ kind: 'surface.complete', surfaceID: 's', baseRevision: 0, revision: 1 });
  const output = session.event('__proto__', 'press');
  assert.equal(JSON.stringify(output.state), '{"__proto__":"kept"}');
  assert.equal(displaySurface(session.document).type, 'Button');
  assert.throws(() => decodeDocument('{"id":"x","root":"constructor","nodes":{}}'), /Missing/);
});

test('response formatting preserves incomplete streaming code and only opens web Markdown links', () => {
  const input = '# Report\n\n**Done** [reference](https://example.org) [invalid](file:///tmp/name)\n\n'
    + '```arkts\nconst a = 1;';
  const blocks = messageBlocks(input);
  assert.deepEqual(blocks.map(block => block.kind), ['title', 'paragraph', 'code']);
  assert.deepEqual(blocks[1].runs.filter(run => run.url).map(run => run.url), ['https://example.org']);
  assert.equal(blocks[2].code, 'const a = 1;');
});

test('chart geometry includes zero and preserves linear splines and singleton data', () => {
  assert.deepEqual(chartDomain([-11, 42, NaN, Infinity]), [-20, 60]);
  assert.ok(Math.abs(chartDomain([0, 0])[1] - 0.3) < 1e-12);
  assert.deepEqual(naturalDerivatives([4]), [0]);
  assert.ok(naturalDerivatives([0, 5, 10, 15]).every(value => Math.abs(value - 5) < 1e-12));
});
