const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'artifacts/ux-v3-comparison');
const rows = [
  [
    "01-library",
    "라이브러리 · 목록",
    "라이브러리",
    "제목 14px, 보조 12px 중심의 조밀한 목록",
    "제목 16px·보조 14px, 명확한 카드 경계와 전체 폴더 새로고침"
  ],
  [
    "02-grid",
    "라이브러리 · 격자",
    "라이브러리",
    "좁은 패널에서도 고정 2열",
    "가용 폭에 맞는 열 수와 충분한 썸네일·정보 영역"
  ],
  [
    "03-detail",
    "영상 상세정보",
    "콘텐츠",
    "작은 보조 글자와 텍스트형 보조 행동",
    "글자 대비 개선, 배경·테두리를 갖춘 행동 버튼"
  ],
  [
    "04-actors",
    "배우 목록",
    "콘텐츠",
    "기존 배우 카드",
    "커진 본문과 명확한 편집 버튼"
  ],
  [
    "05-actor-editor",
    "배우 정보 편집",
    "콘텐츠",
    "기존 이미지 선택 대화상자",
    "공통 대화상자와 44px 버튼 규격"
  ],
  [
    "06-tags",
    "태그 목록",
    "콘텐츠",
    "기존 태그 카드",
    "공통 대비·글자·행동 규격 적용"
  ],
  [
    "07-filter",
    "조회조건",
    "설정",
    "기존 조건 그룹과 작은 텍스트",
    "그룹별 목적 안내, 평점을 포함한 조건 요약, 고정 적용 영역"
  ],
  [
    "08-settings",
    "설정 · 라이브러리",
    "설정",
    "다시 검색이 설정 안에 위치",
    "아이콘 카테고리, 44px 행동 버튼, 새로고침을 폴더 영역으로 이동"
  ],
  [
    "09-shortcuts",
    "설정 · 단축키",
    "설정",
    "작은 키 캡과 조밀한 행",
    "큰 키 캡과 행 간격, 명시적인 설정 버튼"
  ],
  [
    "10-playback-settings",
    "설정 · 재생",
    "설정",
    "작은 설정 행과 설명",
    "제목·설명·행동의 계층 및 공통 대비 적용"
  ],
  [
    "11-metadata-location",
    "메타데이터 작업 공간",
    "메타데이터",
    "설정에서 별도 대화상자를 여는 버튼",
    "설정 안에 영상정보 교환·배우 이미지·NFO 작업 공간"
  ],
  [
    "12-metadata-export",
    "메타데이터 · 내보내기",
    "메타데이터",
    "넓은 빈 목록과 같은 무게의 여러 행동",
    "대상 정보 요약, 보조 도구 메뉴, 하단의 주요 복사 버튼"
  ],
  [
    "13-metadata-input",
    "메타데이터 · 결과 입력",
    "메타데이터",
    "입력·검토·적용이 한 화면에 혼재",
    "입력 전용 단계와 다음 검토 단계, 고정된 변경 비교 버튼"
  ],
  [
    "14-actor-images",
    "배우 이미지 관리",
    "메타데이터",
    "설정 아래 검색 목록",
    "별도 작업 탭의 검색 목록과 편집 안내"
  ],
  [
    "15-image-editor",
    "배우 이미지 편집",
    "메타데이터",
    "추가 대화상자로 이미지 편집",
    "설정 안에서 목록과 미리보기·편집·저장을 함께 제공"
  ]
];
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const guide = JSON.parse(fs.readFileSync(path.join(root,'docs/ui-ux-guide.json'),'utf8').replace(/^\uFEFF/,''));
const images = {};
function asset(mode, id) {
  const key = mode+'/'+id;
  if (!images[key]) {
    const bytes = fs.readFileSync(path.join(out,'assets',mode,id+'.png'));
    if (bytes.readUInt32BE(16)!==1280 || bytes.readUInt32BE(20)!==800) throw new Error('Unexpected screenshot size: '+key);
    images[key] = 'data:image/png;base64,'+bytes.toString('base64');
  }
  return key;
}
const data = rows.map(([id,title,group,before,after,beforeId])=>({id,title,group,before,after,beforeKey:asset('as-is',beforeId||id),afterKey:asset('to-be',id),different:!!beforeId||id==='11-metadata-location'}));
const hash = '직전 작업본';
const html = `<!doctype html>
<html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Soft Vault — AS IS / TO BE 화면 비교</title>
<style>
:root{color-scheme:light;--paper:#f4f3ef;--ink:#182b38;--muted:#61717b;--line:#d9dfdf;--green:#18796d;--orange:#9d6937}
*{box-sizing:border-box}[hidden]{display:none!important}body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.65 'Segoe UI','Malgun Gothic',sans-serif}button,input,select{font:inherit}button,select{cursor:pointer}a{color:inherit}button{color:inherit}header{padding:42px max(24px,calc((100vw - 1440px)/2));background:#152936;color:#f1f5f5;border-bottom:4px solid #8bd1c5}.eyebrow{font:600 12px/1.5 'Segoe UI',sans-serif;letter-spacing:2px;color:#a5c7cf}h1{font-size:clamp(30px,4vw,52px);font-weight:650;line-height:1.2;margin:14px 0 18px;letter-spacing:-1.8px}.intro{max-width:840px;color:#cad9df;margin:0}.facts{display:flex;flex-wrap:wrap;gap:9px;margin-top:24px}.facts span{border:1px solid #4b6471;border-radius:6px;padding:5px 12px;font-size:12px;color:#dce6e9}
main{max-width:1488px;margin:auto;padding:30px 24px 64px}.toolbar{position:sticky;top:0;z-index:5;display:flex;gap:12px;align-items:center;flex-wrap:wrap;background:rgba(244,243,239,.97);padding:14px 0;border-bottom:1px solid var(--line);backdrop-filter:blur(12px)}.toolbar label{font-size:13px;font-weight:600}.toolbar input,.toolbar select{height:40px;padding:0 12px;background:white;border:1px solid #c3cccf;border-radius:7px;color:var(--ink)}.toolbar input{width:240px;max-width:60vw}.toolbar .count{margin-left:auto;color:var(--muted);font-size:13px}.outline{border:1px solid #9eafb7;border-radius:7px;background:white;padding:8px 14px}.outline:hover{background:#e7eeee}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #2b948b;outline-offset:3px}
details{margin:26px 0;background:white;border:1px solid var(--line);border-radius:10px;overflow:hidden}summary{cursor:pointer;padding:16px 20px;font-weight:600}table{width:100%;border-collapse:collapse;font-size:13px}th,td{padding:12px 20px;text-align:left;border-top:1px solid var(--line);vertical-align:top}th{background:#edf1f1;color:var(--muted)}td:first-child{width:23%;font-weight:600}td a{text-decoration:none}td a:hover{text-decoration:underline}.table-wrap{overflow:auto}table{min-width:650px}
.screen{scroll-margin-top:90px;margin:30px 0 38px;background:white;border:1px solid var(--line);border-radius:12px;overflow:hidden}.screen[hidden]{display:none}.section-head{display:flex;align-items:center;gap:16px;padding:20px 24px;border-bottom:1px solid var(--line)}.number{font:500 25px/1 monospace;color:#91a0a8}.section-head h2{font-size:20px;letter-spacing:-.6px;line-height:1.4;margin:0}.tag{display:inline-block;border:1px solid var(--line);border-radius:20px;padding:2px 10px;color:var(--muted);font-size:11px;margin-top:6px}.section-head button{margin-left:auto;white-space:nowrap;font-size:13px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:var(--line)}figure{margin:0;background:white;min-width:0}figcaption{padding:14px 20px;display:flex;gap:10px;align-items:center;font-size:12px;font-weight:600}.pill{display:inline-block;border-radius:4px;padding:3px 8px;font:700 11px/1.5 'Segoe UI',sans-serif;letter-spacing:1px;background:#f3ece3;color:var(--orange)}.after .pill{background:#e5f3ef;color:var(--green)}.shot{display:block;width:100%;padding:0;border:0;background:#15191e;cursor:zoom-in;aspect-ratio:1.6;overflow:hidden}.shot img{display:block;width:100%;height:auto}.description{padding:14px 20px;color:var(--muted);font-size:13px;min-height:72px;margin:0}.note{margin:0;padding:11px 24px;background:#edf4f3;color:#40625f;font-size:12px}.empty{padding:50px;text-align:center;color:var(--muted)}footer{border-top:1px solid var(--line);padding-top:24px;color:var(--muted);font-size:12px}footer p{margin:6px 0}
dialog{width:min(1440px,96vw);max-width:none;max-height:94vh;border:1px solid #536875;border-radius:12px;padding:0;background:#132430;color:#edf4f6;box-shadow:0 30px 120px #0008}dialog::backdrop{background:#061017dc;backdrop-filter:blur(6px)}.modal-head{display:flex;align-items:center;gap:12px;padding:14px 20px;flex-wrap:wrap}.modal-head h2{font-size:17px;margin:0 auto 0 0}.modal-head button{border:1px solid #6a828e;border-radius:6px;background:#263d4b;color:white;padding:6px 12px}.modal-head button[aria-pressed=true]{background:#b4ded5;color:#123b35}.viewer{position:relative;overflow:auto;background:#0a1319}.viewer img{display:block;width:100%;height:auto}.viewer.actual img{width:1280px;max-width:none}.overlay{position:absolute;top:0;left:0;width:100%;height:100%;overflow:hidden;clip-path:inset(0 50% 0 0)}.overlay img{width:100%;max-width:none}.seam{position:absolute;top:0;bottom:0;left:50%;width:2px;background:#80edcb;pointer-events:none}.range-row{display:flex;align-items:center;gap:16px;padding:16px 20px;font-size:13px}.range-row input{flex:1;accent-color:#94ddc9}.hint{padding:0 20px 14px;margin:0;color:#b6cad3;font-size:12px}.toplink{position:fixed;bottom:18px;right:18px;background:var(--ink);color:white;text-decoration:none;padding:10px 16px;border-radius:30px;z-index:6;font-size:12px}
@media(max-width:760px){header{padding:28px 20px}main{padding:16px 12px 40px}.pair{grid-template-columns:1fr}.section-head{padding:16px;gap:10px}.section-head h2{font-size:17px}.section-head button{padding:7px 9px}.description{min-height:0}.toolbar .count{display:none}.toolbar{gap:8px}.toolbar input{width:180px}.modal-head{padding:12px}dialog{width:98vw}.number{font-size:20px}}
@media print{.toolbar,.toplink,.section-head button,dialog{display:none!important}header{background:white;color:black;padding:20px}.intro,.eyebrow,.facts span{color:#333}.screen{break-inside:avoid}main{padding:0}.screen[hidden]{display:block}details{display:none}}
</style>
<header id="top"><div class="eyebrow">SOFT VAULT / UI REVIEW</div><h1>AS IS <span style="color:#8bd1c5">→</span> TO BE<br>화면 개선 비교</h1><p class="intro">변경 전과 변경 후 앱을 직접 실행해 촬영했습니다. 동일한 샘플 영상·메타데이터와 1280 × 800 창 크기로 비교하며, 각 이미지는 원본 크기로 확대할 수 있습니다.</p><div class="facts"><span>비교 항목 ${data.length}개</span><span>Windows · 실제 앱 렌더링</span><span>글자 배율 100%</span><span>AS IS ${hash} / TO BE 현재 작업본</span><span>2026.11.11</span></div></header>
<main><div class="toolbar"><label for="search">화면 찾기</label><input id="search" placeholder="설정, 카드, 메타데이터…" type="search"><select id="category" aria-label="비교 항목 분류"><option value="">전체 항목</option>${[...new Set(data.map(x=>x.group))].map(x=>'<option>'+x+'</option>').join('')}</select><span class="count" id="count"></span><button class="outline" id="print">인쇄 / PDF</button></div>
<details><summary>화면 단위 UI/UX 디자인 가이드</summary><div class="table-wrap"><p>본문 16px · 보조 14px · 버튼 15px / 최소 높이 44px · 아이콘 버튼 40px</p><p>${guide.principles.map(escape).join(" · ")}</p><table><thead><tr><th>단위</th><th>UI/UX 기준</th></tr></thead><tbody>${guide.units.map(u=>"<tr><td>"+escape(u.unit)+"</td><td>"+u.rules.map(escape).join("<br>")+"</td></tr>").join("")}</tbody></table></div></details>
<details open><summary>변경점 요약표</summary><div class="table-wrap"><table><thead><tr><th>화면</th><th>AS IS · 변경 전</th><th>TO BE · 변경 후</th></tr></thead><tbody>${data.map(r=>'<tr><td><a href="#'+r.id+'">'+r.title+'</a></td><td>'+r.before+'</td><td>'+r.after+'</td></tr>').join('')}</tbody></table></div></details>
<div id="screens">${data.map((r,i)=>`<section class="screen" id="${r.id}" data-group="${r.group}" data-search="${escape(r.title+' '+r.before+' '+r.after)}"><div class="section-head"><span class="number">${String(i+1).padStart(2,'0')}</span><div><h2>${r.title}</h2><span class="tag">${r.group}</span></div><button class="outline" data-view="${i}" data-mode="overlay">겹쳐 비교 ↗</button></div><div class="pair"><figure><figcaption><span class="pill">AS IS</span>변경 전</figcaption><button class="shot" data-view="${i}" data-mode="before" aria-label="${r.title} 변경 전 확대"><img data-image="${r.beforeKey}" alt="${r.title} 변경 전 실제 화면" loading="lazy" width="1280" height="800"></button><p class="description">${r.before}</p></figure><figure class="after"><figcaption><span class="pill">TO BE</span>변경 후</figcaption><button class="shot" data-view="${i}" data-mode="after" aria-label="${r.title} 변경 후 확대"><img data-image="${r.afterKey}" alt="${r.title} 변경 후 실제 화면" loading="lazy" width="1280" height="800"></button><p class="description">${r.after}</p></figure></div>${r.different?'<p class="note">기능 이동·추가 비교입니다. 변경 전의 기존 진입점 또는 배우 편집 화면과 변경 후의 설정 화면을 대응시켰습니다.</p>':''}</section>`).join('')}</div><p class="empty" id="empty" hidden>해당하는 비교 항목이 없습니다.</p>
<footer><p>촬영 기준: AS IS는 이번 개편 직전 실제 앱 촬영본을 보존했고, TO BE는 이번 개편 적용 후 다시 촬영했습니다. 동일한 샘플 데이터를 사용했습니다.</p><p>샘플 카탈로그를 사용했으며 개인 라이브러리는 사용하지 않았습니다. 실행별 임시 폴더 경로는 서로 다를 수 있습니다. 정적 화면으로 확인할 수 없는 방향키 동작과 메모리 오류 수정은 이 시각 비교의 대상이 아닙니다.</p><p>PNG 원본을 HTML 안에 포함했습니다. 인터넷 연결 없이 이 파일 하나로 열람할 수 있습니다. 재생 엔진·DB·데이터 수집 코드는 포함되지 않습니다.</p></footer></main>
<a class="toplink" href="#top">맨 위로 ↑</a>
<dialog id="viewerDialog" aria-labelledby="viewerTitle"><div class="modal-head"><h2 id="viewerTitle"></h2><button data-switch="before">AS IS</button><button data-switch="after">TO BE</button><button data-switch="overlay">겹쳐 비교</button><button id="actual">원본 100%</button><button id="close" aria-label="확대 보기 닫기">닫기 ✕</button></div><div class="viewer" id="viewer"><img id="baseImage" alt=""><div class="overlay" id="overlay"><img id="overlayImage" alt=""></div><div class="seam" id="seam"></div></div><label class="range-row" id="rangeRow"><span>TO BE</span><input type="range" min="0" max="100" value="50" id="slider" aria-label="변경 후 화면 표시 비율"><span>AS IS</span></label><p class="hint">겹쳐 비교는 왼쪽 TO BE, 오른쪽 AS IS입니다. 슬라이더로 경계를 이동하세요. Esc 키로 닫을 수 있습니다.</p></dialog>
<script>
const data=${JSON.stringify(data)}, images=${JSON.stringify(images)};
document.querySelectorAll('[data-image]').forEach(img=>img.src=images[img.dataset.image]);
const search=document.getElementById('search'),category=document.getElementById('category');
function filter(){const q=search.value.trim().toLowerCase();let n=0;document.querySelectorAll('.screen').forEach(s=>{s.hidden=!(s.dataset.search.toLowerCase().includes(q)&&(!category.value||s.dataset.group===category.value));if(!s.hidden)n++});document.getElementById('count').textContent=n+' / '+data.length+'개 화면';document.getElementById('empty').hidden=n!==0}
document.querySelectorAll('.table-wrap a').forEach(a=>a.addEventListener('click',()=>{search.value='';category.value='';filter()}));
search.addEventListener('input',filter);category.addEventListener('change',filter);filter();document.getElementById('print').onclick=()=>window.print();
const dialog=document.getElementById('viewerDialog'),viewer=document.getElementById('viewer'),overlay=document.getElementById('overlay'),seam=document.getElementById('seam'),slider=document.getElementById('slider');let selected=0,mode='overlay';
function display(next){mode=next;const r=data[selected];document.getElementById('viewerTitle').textContent=r.title;const base=document.getElementById('baseImage');base.src=images[mode==='after'?r.afterKey:r.beforeKey];base.alt=r.title+(mode==='after'?' 변경 후':' 변경 전');document.getElementById('overlayImage').src=images[r.afterKey];document.getElementById('overlayImage').alt=r.title+' 변경 후';overlay.hidden=seam.hidden=document.getElementById('rangeRow').hidden=mode!=='overlay';document.querySelectorAll('[data-switch]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.switch===mode));if(mode==='overlay'){viewer.classList.remove('actual');document.getElementById('actual').textContent='원본 100%'}document.getElementById('actual').disabled=mode==='overlay';}
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{selected=Number(b.dataset.view);viewer.classList.remove('actual');document.getElementById('actual').textContent='원본 100%';display(b.dataset.mode);dialog.showModal()});document.querySelectorAll('[data-switch]').forEach(b=>b.onclick=()=>display(b.dataset.switch));document.getElementById('close').onclick=()=>dialog.close();dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close()}});slider.oninput=()=>{overlay.style.clipPath='inset(0 '+(100-slider.value)+'% 0 0)';seam.style.left=slider.value+'%'};document.getElementById('actual').onclick=()=>{const on=viewer.classList.toggle('actual');document.getElementById('actual').textContent=on?'화면에 맞춤':'원본 100%'};
</script></html>`;
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'comparison.html'),html);
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({baseline:hash,size:[1280,800],screens:data,images:Object.keys(images)},null,2));
console.log('Created '+path.join(out,'comparison.html')+' ('+(Buffer.byteLength(html)/1048576).toFixed(1)+' MB)');
