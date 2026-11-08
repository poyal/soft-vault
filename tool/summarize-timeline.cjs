// Usage: node tool/summarize-timeline.cjs [timeline.json]
// Durations are inclusive; nested spans must not be summed as exclusive CPU time.
const fs = require('node:fs');
const source = process.argv[2] || 'build/e2e/bottleneck-timeline.json';
const timeline = JSON.parse(fs.readFileSync(source, 'utf8'));
const events = timeline.traceEvents || [];
const stacks = new Map(), spans = [], threads = new Map();
for (const e of events) {
  const key = `${e.pid}:${e.tid}`;
  if (e.ph === 'M' && e.name === 'thread_name') threads.set(key, e.args?.name);
  if (e.ph === 'X') spans.push({...e, durationMs: e.dur / 1000});
  if (e.ph === 'B') {
    if (!stacks.has(key)) stacks.set(key, []);
    stacks.get(key).push(e);
  }
  if (e.ph === 'E') {
    const start = stacks.get(key)?.pop();
    if (start) spans.push({...start, durationMs: (e.ts - start.ts) / 1000});
  }
}
const grouped = new Map();
for (const span of spans) {
  if (!Number.isFinite(span.durationMs) || span.durationMs < 0) continue;
  const key = `${span.tid}:${span.name}`;
  if (!grouped.has(key)) grouped.set(key, {
    name: span.name, thread: threads.get(`${span.pid}:${span.tid}`) || span.tid,
    durations: [],
  });
  grouped.get(key).durations.push(span.durationMs);
}
const rows = [...grouped.values()].map(({name, thread, durations: d}) => {
  d.sort((a, b) => a - b);
  return {name, thread, count: d.length, medianMs: d[Math.floor(d.length / 2)],
    p95Ms: d[Math.min(d.length - 1, Math.floor(d.length * .95))],
    maxMs: d[d.length - 1], totalMs: d.reduce((a, b) => a + b, 0)};
}).sort((a, b) => b.totalMs - a.totalMs);
const result = {source, eventCount: events.length, note: 'Inclusive nested durations, not exclusive CPU usage.', spans: rows};
fs.writeFileSync('build/e2e/bottleneck-timeline-summary.json', JSON.stringify(result, null, 2));
console.log(JSON.stringify({...result, spans: rows.slice(0, 45)}, null, 2));
