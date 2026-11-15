// node tool/summarize-playback.cjs report.json [...]
const fs = require('node:fs');
const path = require('node:path');
const percentile = (values, p) => {
  const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
  return sorted.length ? sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * p) - 1)] : null;
};
const round = v => typeof v === 'number' ? Math.round(v * 1000) / 1000 : v;
const reports = process.argv.slice(2).map(file => {
  const report = JSON.parse(fs.readFileSync(file, 'utf8'));
  return { source: file, label: report.label ?? path.basename(file), mode: report.mode,
    measurement: report.measurement, files: (report.records ?? report.files).map(row => {
      const samples = row.playbackSamples ?? [];
      const first = samples[0] ?? {}, last = samples.at(-1) ?? {};
      const delta = name => {
        if (!samples.length || samples.some(s => !Number.isFinite(s[name]))) return null;
        let total = 0;
        for (let i = 1; i < samples.length; i++) {
          const prior = samples[i - 1], next = samples[i];
          // Loop/reopen boundaries reset backend counters; do not subtract them.
          if (prior.loopIndex === next.loopIndex && next[name] >= prior[name]) {
            total += next[name] - prior[name];
          }
        }
        return total;
      };
      const fps = row.file.includes('-vfr.') ? 22.5 : row.initial?.['container-fps'];
      const seconds = (last.elapsedMs - first.elapsedMs) / 1000;
      const drops = delta('frame-drop-count') ?? delta('lost_pictures');
      const av = samples.map(s => typeof s.avsync === 'number' ? Math.abs(s.avsync) * 1000 : null);
      return Object.fromEntries(Object.entries({
        file: row.file, hwdec: row.initial?.['hwdec-current'],
        seekSamples: row.seeks?.length ?? 0,
        seekP50Ms: percentile((row.seeks ?? []).map(s => s.nativeFrameReadyMs), .5),
        seekP95Ms: percentile((row.seeks ?? []).map(s => s.nativeFrameReadyMs), .95),
        seekMaxMs: percentile((row.seeks ?? []).map(s => s.nativeFrameReadyMs), 1),
        uiP95Ms: percentile((row.seeks ?? []).map(s => s.uiFeedbackMs), .95),
        uiMissingSamples: (row.seeks ?? []).filter(s => s.uiFeedbackMs === null).length,
        dragReleaseMs: row.dragReleaseFrameMs, keyResultSeconds: row.tenKeyStepsFrom10Seconds,
        dragSamples: row.drags?.length ?? (row.dragReleaseFrameMs === undefined ? 0 : 1),
        dragP50Ms: percentile((row.drags ?? []).map(s => s.nativeFrameReadyMs), .5),
        dragP95Ms: percentile((row.drags ?? []).map(s => s.nativeFrameReadyMs), .95),
        continuousSeconds: Number.isFinite(seconds) ? seconds : null,
        playbackSamples: samples.length, renderDrops: drops,
        decoderDrops: delta('decoder-frame-drop-count'),
        delayedFrames: delta('vo-delayed-frame-count'),
        mistimedFrames: delta('mistimed-frame-count'),
        renderDropPercent: drops !== null && fps && seconds > 0 ? 100 * drops / (fps * seconds) : null,
        avsyncP95Ms: percentile(av, .95), avsyncMaxMs: percentile(av, 1),
        cacheStarvedSamples: samples.filter(s => s['paused-for-cache'] === 'yes' || s['paused-for-cache'] === true).length,
        peakRssMiB: samples.length && samples.some(s => Number.isFinite(s.rss)) ? Math.max(...samples.map(s => s.rss ?? 0)) / 1048576 : null,
        applicationError: row.applicationError ?? row.error ?? null,
        completedLoops: row.completedLoops, postSoakSeekMs: row.postSoakSeekMs,
        firstRssMiB: Number.isFinite(first.rss) ? first.rss / 1048576 : null,
        lastRssMiB: Number.isFinite(last.rss) ? last.rss / 1048576 : null,
        flutterTimingSamples: row.flutterFrames?.length ?? 0,
        flutterBuildP95Ms: percentile((row.flutterFrames ?? []).map(f => f[0] / 1000), .95),
        flutterRasterP95Ms: percentile((row.flutterFrames ?? []).map(f => f[1] / 1000), .95),
      }).map(([k, v]) => [k, round(v)]));
    }) };
});
process.stdout.write(JSON.stringify(reports, null, 2) + '\n');
