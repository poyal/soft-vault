// node tool/summarize-seek-recovery.cjs <one or more probe JSONs for one build>
// Aggregate only runs from the same device, build and measurement path.
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');

function percentile(values, fraction) {
  const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (!sorted.length) return null;
  return Math.round(sorted[Math.ceil(sorted.length * fraction) - 1] * 100) / 100;
}

function distribution(values) {
  return { n: values.filter(Number.isFinite).length,
    p50: percentile(values, .50), p95: percentile(values, .95) };
}

function seekResults(records) {
  const groups = new Map();
  for (const row of records) {
    const gesture = row.gesture ?? 'standalone';
    if (!groups.has(gesture)) groups.set(gesture, []);
    groups.get(gesture).push(row);
  }
  return Object.fromEntries([...groups].map(([gesture, rows]) => {
    const commands = rows.flatMap(row => (row.submissionUs ?? []).filter((_, i) => i % 2 === 0));
    const missed = rows.filter(row => row.firstTargetMs == null).length;
    return [gesture, {
      trials: rows.length,
      longestUnchangedMs: distribution(rows.map(row => row.longestUnchangedMs)),
      // Right-censored observations sort above all observed hits. A percentile
      // beyond the observation window is reported as null, never as a fast hit.
      firstTargetP95Ms: Math.ceil(.95 * rows.length) > rows.length - missed
        ? null : percentile(rows.map(row => row.firstTargetMs ?? Number.MAX_SAFE_INTEGER), .95),
      targetMissing: missed,
      largestSampleGapMs: distribution(rows.map(row => row.largestSampleGapMs)),
      avsyncAbsMs: distribution(rows.map(row => Number.isFinite(row.avsyncAfter)
        ? Math.abs(row.avsyncAfter) * 1000 : null)),
      ...(commands.length ? { submissionUs: distribution(commands) } : {}),
    }];
  }));
}

function closeResults(rows) {
  const successful = rows.filter(row => row.exitCode === 0 && !row.timeout);
  const stages = new Set(successful.flatMap(row => row.stages.map(event => event.phase)));
  return {
    trials: rows.length,
    processExitMs: distribution(successful.map(row => row.closeMs)),
    validExits: successful.length,
    withinBudget: successful.filter(row => row.withinCloseBudget).length,
    positionPreserved: rows.filter(row => row.positionPreserved).length,
    stages: Object.fromEntries([...stages].map(phase => [phase, distribution(
      successful.map(row => row.stages.find(event => event.phase === phase)?.ms))])),
  };
}

function summarize(files) {
  if (!files.length) throw new Error('Supply completed probe JSON files.');
  const runs = files.map(file => {
    const bytes = fs.readFileSync(file);
    return { name: path.basename(file), sha256: crypto.createHash('sha256').update(bytes).digest('hex'), data: JSON.parse(bytes) };
  });
  const closing = Array.isArray(runs[0].data);
  const results = {}, combined = [];
  for (const { name, sha256, data } of runs) {
    if (closing !== Array.isArray(data) || (!closing && !data.complete)) {
      throw new Error('Incompatible or incomplete run: ' + name);
    }
    const rows = closing ? data : data.records;
    combined.push(...rows);
    results[name] = { sha256, ...(closing ? closeResults(rows) : {
      platform: data.platform, fixture: data.fixture, hwdec: data.initial?.['hwdec-current'] ?? data.hwdec,
      vo: data.vo, windowSize: data.windowSize, textureSize: data.textureSize, gestures: seekResults(rows),
    }) };
  }
  return { files: results, combined: closing ? closeResults(combined) : seekResults(combined) };
}

module.exports = { summarize };
if (require.main === module) console.log(JSON.stringify(summarize(process.argv.slice(2)), null, 2));
