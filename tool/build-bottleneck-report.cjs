const fs = require('node:fs');
const read = name => JSON.parse(fs.readFileSync(`build/e2e/${name}.json`, 'utf8'));
const variants = [
  ['기존 구현 / Impeller', 'bottleneck-baseline'],
  ['다시 그리기 범위 분리 실험', 'bottleneck-paint-boundaries'],
  ['아이콘 합성 제거 / Impeller', 'bottleneck-direct-icons'],
  ['기존 아이콘 / Skia', 'bottleneck-skia'],
  ['최종: 아이콘 합성 제거 / Skia', 'bottleneck-final'],
].map(([label, file]) => ({label, file, result: read(file)}));
const baseline = variants[0].result;
const final = variants.at(-1).result;
const nativeUi = read('ui-profile-results');
const resourcePath = 'build/verification/resources-profile-native-ui-after-render-fix.json';
const resources = fs.existsSync(resourcePath) ? JSON.parse(fs.readFileSync(resourcePath, 'utf8')).Summary : null;
const activeResources = resources?.Applications.find(app => app.Path.includes('\\Profile\\'));
const nav = r => r.phases.find(p => p.phase === 'navigation');
const result = {
  created: new Date().toISOString(),
  hardware: 'i7-8700B / Intel UHD 630, driver 31.0.101.2140 / 59 Hz',
  variants,
  latestNativeUi: nativeUi,
  latestNativeUiResources: resources,
  navigationRasterP95ReductionPercent: 100 * (1 - nav(final).rasterP95Ms / nav(baseline).rasterP95Ms),
  conclusions: [
    'On this Windows PC the Impeller GLES graphics path is the main reproduced bottleneck. Switching only the renderer markedly reduces raster time.',
    'Per-icon runtime color filters introduce offscreen layers. Encoding the SVG stroke color directly also reduces rendering cost.',
    'Disabling backdrop blur only slightly helps; splitting repaint boundaries did not consistently help. These experimental changes were reverted.',
    'Four-video SQLite queries and preview-selection handlers complete in milliseconds. They do not explain the reproduced broad UI slowdown.',
  ],
  limitations: 'Profile fullyLive, native Windows surface, four videos. P95 is not average FPS or input-to-photon latency. Phase wall time includes test waits and real animations. Trace runs add instrumentation overhead. CPU/GPU/driver waiting cannot be separated from these timeline spans. No claim of hardware failure or universal GPU compatibility.',
};
fs.writeFileSync('build/verification/bottleneck-report.json', JSON.stringify(result, null, 2));
const rows = variants.map(v => {
  const n = nav(v.result);
  const range = kind => {
    const p = v.result.phases.filter(p => p.phase.startsWith(`${kind}-blur-true-`)).map(p => p.rasterP95Ms);
    return `${Math.min(...p).toFixed(2)}–${Math.max(...p).toFixed(2)}`;
  };
  return `<tr><td><a href='../e2e/${v.file}.json'>${v.label}</a></td><td>${n.rasterP95Ms.toFixed(2)}</td><td>${range('search')}</td><td>${range('detail')}</td><td>${n.rasterOverBudget}/${n.frames}</td></tr>`;
}).join('\n');
fs.writeFileSync('build/verification/bottleneck-report.html', `<!doctype html><html lang='ko'><meta charset='utf-8'><title>Soft Vault 성능 원인 분석</title>
<style>body{font:16px system-ui;max-width:1100px;margin:40px auto;background:#17222d;color:#d5e1ea;line-height:1.7}table{border-collapse:collapse;width:100%}th,td{padding:10px;border-bottom:1px solid #3b5366;text-align:left}a{color:#87b8d8}code{color:#b9d5e9}</style>
<h1>Soft Vault Windows 성능 원인 분석</h1><p>${result.hardware}</p>
<p>재현된 주원인은 Windows Impeller GLES 렌더링 경로의 높은 처리 비용이며, SVG 아이콘마다 적용하던 색상 필터의 추가 합성이 부담을 더했다. Windows에서 Skia를 명시적으로 선택하고 아이콘 색을 SVG에 직접 지정했다. 배치·색상·팝업 배경 흐림은 유지한다.</p>
<table><tr><th>실험</th><th>전환 raster P95(ms)</th><th>검색 P95 범위(ms)</th><th>상세 P95 범위(ms)</th><th>전환 기준 초과/프레임</th></tr>${rows}</table>
<p>검색·상세는 8회 열기/닫기를 두 묶음 반복했다. 표의 범위는 두 묶음의 P95 최솟값–최댓값이며 전체 프레임을 합친 P95가 아니다. 전환의 렌더링 P95는 기존 대비 ${result.navigationRasterP95ReductionPercent.toFixed(1)}% 감소했다. 59Hz의 프레임 기준은 약 16.95ms다.</p>
<p>앱 경로의 검색 조회 P95 ${final.queryP95Ms}ms, 파일 선택 처리 P95 ${final.selectionHandlerP95Ms}ms. 현재 사용자 DB에는 영상 4개와 기존 이미지 기록 8개가 있으며, 앱은 영상만 표시한다. DB 크기나 CPU·RAM 포화가 현재 재현 증상의 원인이라는 증거는 없다.</p>
<p>기존 타임라인에서 <code>impeller::ReactorGLES::FlushOps</code> 구간에 시간이 집중됐다. 단순 색상 애니메이션은 기존 엔진에서도 raster P95 약 2ms였다. 전체 창 흐림을 끈 비교와 다시 그리기 범위 분리만으로는 지연이 해결되지 않았다.</p>
<p>E2E 가장자리의 검은 띠는 고정 논리 화면과 실제 Windows 내부 화면 비율이 달라 자동 축소·중앙 정렬되던 별도 문제였다. 가상 크기 고정을 제거하고 실제 창 내부 크기를 사용한다. 1000×700 외부 창, 최대화·전체화면·복원에서 논리 크기 일치와 추가 축소·이동 부재를 검증했다.</p>
<p>위 A/B 표는 당시 동일한 뷰포트 조건의 실험이다. 이후 실제 내부 화면 보정 후 최신 일반 UI raster P95: ${nativeUi.phases.map(p => `${p.phase} ${p.rasterP95Ms}ms`).join(', ')}. ${activeResources ? `같은 UI 순서의 30초 측정에서 앱 CPU 평균 ${activeResources.CpuAveragePercent}%, 최대 ${activeResources.CpuPeakPercent}%, GPU 최다 사용 엔진 최대 ${activeResources.GpuPeakEnginePercent}%, 전용 작업 메모리 최대 ${activeResources.PrivateWorkingPeakMiB}MiB. 앱 실행 중 표본은 ${activeResources.Samples}회이며 이전 표본과 시점·내부 화면 크기가 조금 달라 정확한 사용률 배수 비교는 하지 않는다.` : ''}</p>
<p>배우·태그의 항목별 순차 조회 및 30초 주기 전체 스캔은 대규모 라이브러리의 별도 개선 후보다. 현재 4영상 사례의 원인으로 단정하지 않는다.</p>
<p>측정은 이 PC의 단기 프로파일 검사다. P95는 평균 FPS나 입력부터 표시까지의 지연이 아니다. 실제 애니메이션과 테스트 대기는 동작 시간에 포함된다. 원본과 아이콘 실험의 타임라인 수집은 계측 오버헤드를 포함한다. 그래픽 명령 처리 시간만으로 GPU 고장이나 드라이버 결함을 단정하지 않는다.</p>
<p><a href='../e2e/bottleneck-timeline-summary-before.json'>기존 그래픽 타임라인 요약</a> · <a href='../e2e/bottleneck-timeline-summary.json'>아이콘 수정 타임라인 요약</a> · <a href='bottleneck-report.json'>전체 원자료 집계</a> · <a href='test-report.html'>기능 검증</a> · <a href='../e2e/review.html'>화면 검토</a></p></html>`);
console.log(JSON.stringify({navigationBeforeMs: nav(baseline).rasterP95Ms, navigationAfterMs: nav(final).rasterP95Ms, reductionPercent: result.navigationRasterP95ReductionPercent}));
