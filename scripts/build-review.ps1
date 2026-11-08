$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$output = Join-Path $repoRoot 'build/e2e'
$screens = @(
  @('Library','design-library','01-library'),
  @('Player','02-player','02-player'),
  @('Detail','design-detail','03-detail'),
  @('Actors','design-actors','04-actors'),
  @('Tags','design-tags','05-tags'),
  @('Folders','06-folders','06-folders'),
  @('Move','07-move','07-move'),
  @('Search','design-search','08-search'),
  @('Shortcuts','design-settings-shortcuts','09-shortcuts'),
  @('Empty','10-empty','10-intro')
)
$html = [System.Text.StringBuilder]::new()
[void]$html.Append('<!doctype html><html lang="ko"><meta charset="utf-8"><title>Soft Vault design review</title><style>body{background:#15191e;color:#e3eaf1;font:15px system-ui;margin:32px}h1{font-size:28px}a{color:#87b8d8}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0}img{width:100%;border:1px solid #323d49}section{margin:40px 0}figcaption{margin:10px 0;color:#8a9baa}p{max-width:1100px;line-height:1.7}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><h1>Soft Vault · 디자인 대조</h1><p>왼쪽은 이전 HTML 시안, 오른쪽은 Windows Flutter 통합 테스트에서 캡처한 최신 UI입니다. 최신 사용자 지정에 따라 영상 전용 목록, 재생 상단 표시줄 제거, 상세정보 읽기 화면, 배우·태그 전체 항목과 목록의 배우·태그 표시, 하단 바 제거와 상단 설정 버튼·통합 설정 화면을 반영했습니다. 해당 변경은 의도된 차이입니다. 라이브러리·상세·배우·태그·검색·단축키는 시안과 같은 예시 콘텐츠 12개를 사용합니다. 원본 SVG와 글꼴·수치를 적용했으며, 브라우저와 Flutter의 글자 렌더링 및 기능 추가에 따른 차이는 남습니다. 픽셀 완전 동일성을 의미하지 않습니다.</p><p><a href="design-pixel-results.json">픽셀 차이 측정</a> · <a href="codec-results.json">코덱 결과</a> · <a href="installed-results.json">설치본 결과</a></p>')
foreach ($screen in $screens) {
  $name = $screen[0]; $actual = $screen[1]; $reference = $screen[2]
  [void]$html.Append("<section><h2>$name</h2><div class='pair'><figure><figcaption>이전 시안 · 최신 사용자 지정 이전</figcaption><img loading='lazy' src='../../design/previews/selected/$reference.png'></figure><figure><figcaption>Windows 실제 UI · <a href='$actual-1280.png'>1280×800</a></figcaption><a href='$actual-1440.png'><img loading='lazy' src='$actual-1440.png'></a></figure></div></section>")
}
[void]$html.Append('<h2>추가 상태</h2><div class="pair">')
foreach ($name in @('design-settings','design-settings-playback','design-settings-backup','01-grid','02-fullscreen','02-decoder','07-move-complete','11-offline','12-selection','13-no-results','design-selection','14-scenes','15-thumbnails','16-collections','17-duplicates','18-rules','19-hover-preview')) {
  if ($name -eq '02-fullscreen') {
    [void]$html.Append("<figure><figcaption>Fullscreen · actual display resolution</figcaption><a href='02-fullscreen-native.png'><img loading='lazy' src='02-fullscreen-native.png'></a></figure>")
    continue
  }
  [void]$html.Append("<figure><figcaption>$name · <a href='$name-1280.png'>1280×800</a></figcaption><img loading='lazy' src='$name-1440.png'></figure>")
}
[void]$html.Append('</div><h2>사생활 보호 · Windows 실제 UI</h2><div class="pair">')
foreach ($name in @('privacy-setup','privacy-locked','privacy-settings','privacy-cooldown','privacy-storage-error')) {
  [void]$html.Append("<figure><figcaption>$name · 1280×800</figcaption><a href='$name-1280.png'><img loading='lazy' src='$name-1280.png'></a></figure>")
}
[void]$html.Append('</div></html>')
[System.IO.File]::WriteAllText((Join-Path $output 'review.html'), $html.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output (Join-Path $output 'review.html')
