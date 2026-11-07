/* Design prototype only. All media, playback and file operations are simulated in memory. */
'use strict';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const icon = (name, extra = '') => `<svg class="icon ${extra}" aria-hidden="true"><use href="#i-${name}"></use></svg>`;
const button = (action, label, glyph, extra = '', attrs = '') => `<button type="button" class="button ${extra}" data-action="${action}" ${attrs}>${glyph ? icon(glyph) : ''}${label}</button>`;
const iconButton = (action, label, glyph, attrs = '') => `<button type="button" class="icon-button" data-action="${action}" aria-label="${esc(label)}" title="${esc(label)}" ${attrs}>${icon(glyph)}</button>`;
const time = seconds => `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${Math.floor(seconds % 60).toString().padStart(2, '0')}`;
const folders = [
  {id:'films', name:'작업 폴더', path:'D:\\Media\\Films', online:true, color:'blue'},
  {id:'selected', name:'외장 SSD', path:'E:\\Media\\Selected', online:true, color:'green'}
];
const people = [
  {name:'이서윤', alias:'Seoyun Lee', description:'차분한 시선으로 담아낸 여행과 일상.'},
  {name:'김도현', alias:'Dohyun Kim', description:'자연과 도시 사이를 기록하는 사람.'},
  {name:'박지우', alias:'Jiwoo Park', description:'빛이 머무는 순간을 찾아서.'}
];
const media = [
  {id:'m1', title:'북쪽으로 향하는 길', file:'northbound_2026_4k.mkv', image:'alpine', folder:'films', duration:1122, resolution:'4K', codec:'HEVC · 10bit', size:'3.24 GB', rating:5, actors:['이서윤'], tags:['여행','자연','시네마틱'], note:'아침 안개가 걷히고, 산맥 위로 빛이 들어오는 순간.\n다시 보고 싶은 장면들을 담았습니다.', type:'video'},
  {id:'m2', title:'고요를 따라', file:'a_quiet_morning.mp4', image:'lake', folder:'films', duration:1498, resolution:'4K', codec:'H.264', size:'2.81 GB', rating:4, actors:['김도현'], tags:['자연','여행'], note:'물 위에 비친 산과 느리게 흘러가는 아침.', type:'video'},
  {id:'m3', title:'숲이 건네는 이야기', file:'the_forest_speaks.mkv', image:'forest', folder:'selected', duration:824, resolution:'1080p', codec:'AV1', size:'1.12 GB', rating:null, actors:['박지우'], tags:['자연','기록'], note:'초록 사이로 들어오는 빛과 바람.', type:'video'},
  {id:'m4', title:'파도가 지나간 자리', file:'after_the_waves.mov', image:'coast', folder:'films', duration:1285, resolution:'4K', codec:'HEVC', size:'3.08 GB', rating:5, actors:['이서윤','김도현'], tags:['여행','시네마틱'], note:'한적한 해안에서 보낸 오후의 기록.', type:'video'},
  {id:'m5', title:'모래 위의 느린 시간', file:'slow_days_in_the_desert.mp4', image:'desert', folder:'selected', duration:1002, resolution:'4K', codec:'H.264', size:'2.40 GB', rating:3, actors:['박지우'], tags:['여행','기록'], note:'끝없는 모래의 곡선과 해 질 무렵의 색.', type:'video'},
  {id:'m6', title:'도시가 잠든 밤', file:'when_the_city_sleeps.mkv', image:'night', folder:'films', duration:1892, resolution:'4K', codec:'HEVC · 10bit', size:'4.62 GB', rating:4, actors:['김도현'], tags:['야경','시네마틱'], note:'도시의 불빛 사이를 천천히 걷는 시간.', type:'video'},
  {id:'m7', title:'길 위에서 만난 오후', file:'afternoon_on_the_road.mp4', image:'road', folder:'selected', duration:678, resolution:'1080p', codec:'H.264', size:'0.92 GB', rating:null, actors:['이서윤'], tags:['여행','일상'], note:'계획 없이 떠난 길에서.', type:'video'},
  {id:'m8', title:'다시, 산의 품으로', file:'back_to_the_mountains.mkv', image:'ridge', folder:'films', duration:1564, resolution:'4K', codec:'VP9', size:'3.78 GB', rating:5, actors:['박지우','김도현'], tags:['자연','시네마틱'], note:'높은 곳에서 내려다본 풍경.', type:'video'},
  {id:'m9', title:'초록의 깊이', file:'green_study_03.jpg', image:'forest', folder:'selected', duration:0, resolution:'6000 × 4000', codec:'JPEG', size:'8.4 MB', rating:4, actors:['박지우'], tags:['자연','사진'], note:'숲의 색을 모은 이미지.', type:'image'},
  {id:'m10', title:'새벽의 호수', file:'lake_at_dawn.jpg', image:'lake', folder:'films', duration:0, resolution:'6000 × 4000', codec:'JPEG', size:'7.2 MB', rating:null, actors:[], tags:['자연','사진'], note:'아직 아무도 없는 호숫가.', type:'image'},
  {id:'m11', title:'바람이 불어오는 곳', file:'where_the_wind_blows.mp4', image:'road', folder:'selected', duration:1351, resolution:'4K', codec:'H.264', size:'2.89 GB', rating:3, actors:['이서윤'], tags:['일상','기록'], note:'평범한 하루 속에서 찾은 장면들.', type:'video'},
  {id:'m12', title:'수평선 너머', file:'beyond_the_horizon.mkv', image:'coast', folder:'films', duration:923, resolution:'4K', codec:'HEVC', size:'2.14 GB', rating:4, actors:['김도현'], tags:['여행','자연'], note:'바다와 하늘의 경계.', type:'video'}
].map((item, index) => ({...item, added:100-index}));

const defaults = [
  ['minimize','볼륨 0% 후 최소화','Escape','', 'app',true],
  ['zero','즉시 볼륨 0%','Digit0','', 'media',true],
  ['pause','재생 · 일시정지','Space','', 'player'],
  ['mute','음소거 켜기 · 끄기','KeyM','', 'player'],
  ['back','5초 뒤로','ArrowLeft','KeyA','player'],
  ['forward','5초 앞으로','ArrowRight','KeyD','player'],
  ['fineBack','1초 뒤로','Shift+ArrowLeft','Shift+KeyA','player'],
  ['fineForward','1초 앞으로','Shift+ArrowRight','Shift+KeyD','player'],
  ['volumeUp','볼륨 5% 올리기','ArrowUp','KeyW','player'],
  ['volumeDown','볼륨 5% 내리기','ArrowDown','KeyS','player'],
  ['previous','이전 파일','PageUp','KeyQ','player'],
  ['next','다음 파일','PageDown','KeyE','player'],
  ['fullscreen','전체 화면 전환','KeyF','', 'player'],
  ['slower','배속 낮추기','BracketLeft','', 'player'],
  ['faster','배속 높이기','BracketRight','', 'player'],
  ['normalSpeed','배속 1배로','Backspace','', 'player'],
  ['undoSeek','직전 탐색 위치로','Shift+Backspace','', 'player'],
  ...[1,2,3,4,5].map(n => [`rating${n}`,`평점 ${n}점`,`Digit${n}`,'','media']),
  ['clearRating','평점 초기화','Shift+Digit0','', 'media'],
  ['tags','태그 편집','KeyT','', 'media'],
  ['actors','배우 편집','KeyP','', 'media'],
  ['detail','설명 · 상세 정보','KeyI','', 'media'],
  ['move','이동할 폴더 선택','Mod+Shift+KeyM','', 'media'],
  ['search','검색 · 명령창','Mod+KeyK','', 'app'],
  ['help','단축키 안내','Shift+Slash','', 'app']
].map(([id,label,primary,secondary,scope,locked=false])=>({id,label,primary,secondary,scope,locked}));
const state = {
  view:'library', section:'all', sectionValue:'', type:'all', sort:'recent', collapsed:false,
  query:'', filters:{rating:'all',actor:'all',tag:'all'}, selected:new Set(), modal:null, draft:null,
  player:null, minimized:false, settingsTab:'shortcuts', shortcuts:structuredClone(defaults), recording:null,
  search:'', searchIndex:0, moveTarget:'selected', conflict:'skip', moveScenario:'normal', moveReport:null, minimizedForm:null
};
let restoreFocus = null;
let toastTimer;
let osdTimer;
const getItem = id => media.find(item=>item.id===id);
const folderOf = item => folders.find(folder=>folder.id===item.folder);
const allTags = () => [...new Set(media.flatMap(item=>item.tags))].sort((a,b)=>a.localeCompare(b,'ko'));
const normalize = value => String(value).normalize('NFKC').toLocaleLowerCase();
const tagsFrom = value => [...new Set(String(value).split(',').map(x=>x.trim()).filter(Boolean))];
const targetIds = () => state.view==='player' && state.player ? [state.player.id] : [...state.selected];

function toast(message) {
  const element = $('#toast'); element.textContent=message; element.classList.add('visible');
  clearTimeout(toastTimer); toastTimer=setTimeout(()=>element.classList.remove('visible'),2700);
}
function stars(item, large=false, mode='rate') {
  return `<span class="stars ${large?'large':''}" aria-label="${item.rating?item.rating+'점':'미평가'}">${[1,2,3,4,5].map(n=>`<button type="button" class="star-button ${n<=(item.rating||0)?'on':''}" data-action="${mode}" data-id="${esc(item.id||'')}" data-rating="${n}" aria-label="${n}점" title="${n}점">★</button>`).join('')}</span>`;
}
function visibleItems(ignoreType=false) {
  let result = media.filter(item=>{
    if(state.section==='unrated' && item.rating!==null) return false;
    if(state.section==='recent' && item.added<95) return false;
    if(state.section==='folder' && item.folder!==state.sectionValue) return false;
    if(state.section==='actor' && !item.actors.includes(state.sectionValue)) return false;
    if(state.section==='tag' && !item.tags.includes(state.sectionValue)) return false;
    if(!ignoreType && state.type!=='all' && item.type!==state.type) return false;
    if(state.filters.rating==='unrated' && item.rating!==null) return false;
    if(!['all','unrated'].includes(state.filters.rating) && (item.rating||0)<Number(state.filters.rating)) return false;
    if(state.filters.actor!=='all' && !item.actors.includes(state.filters.actor)) return false;
    if(state.filters.tag!=='all' && !item.tags.includes(state.filters.tag)) return false;
    if(state.query && !normalize([item.title,item.file,item.note,...item.actors,...item.tags].join(' ')).includes(normalize(state.query))) return false;
    return true;
  });
  return result.sort((a,b)=>state.sort==='name'?a.title.localeCompare(b.title,'ko'):state.sort==='rating'?(b.rating||0)-(a.rating||0):state.sort==='duration'?b.duration-a.duration:b.added-a.added);
}
function sectionTitle() {
  if(state.section==='folder') return folders.find(f=>f.id===state.sectionValue)?.name||'연결 폴더';
  return {all:'전체 파일',recent:'최근 추가',unrated:'미평가',actor:state.sectionValue,tag:state.sectionValue}[state.section];
}

function sidebar() { return deckSidebar(); }
function topbar() {
  const titles={library:sectionTitle(),actors:'배우',tags:'태그',settings:'설정'};
  return `<header class="topbar"><div class="row">${iconButton('collapse','탐색 메뉴 접기·펼치기','panel')}<div class="breadcrumb"><span>라이브러리</span>${icon('chevron')}<strong>${esc(titles[state.view]||'전체 파일')}</strong></div></div><div class="top-actions"><button class="icon-button search-trigger" data-action="search" title="검색·명령창 (Ctrl/Cmd+K)" aria-label="검색·명령창">${icon('search')}<kbd>Ctrl K</kbd></button><div class="divider"></div>${iconButton('folders','연결 폴더 관리','folder')}</div></header>`;
}
function library() { return deckPreview(visibleItems()); }


function selectionBar() {
  if(!state.selected.size) return '';
  return `<div class="selection-bar" role="toolbar" aria-label="선택한 파일 작업"><span class="selection-count">${state.selected.size}개 선택</span><span class="bar-divider"></span>${stars({rating:null},false,'batch-rate')}<span class="bar-divider"></span>${button('batch-tags','태그','tag','small')}${button('move','이동','move','small')}${iconButton('clear-selection','선택 해제','close')}</div>`;
}
function actorPage() {
  return `<div class="content"><div class="heading"><div><h1>배우<span>${people.length}</span></h1><p>이름 하나로, 연결된 모든 장면을 만나보세요.</p></div><span class="pill">예시 인물</span></div><div class="person-grid">${people.map(person=>{const files=media.filter(x=>x.actors.includes(person.name));return `<article class="person-card"><div class="spread"><div class="person-avatar">${esc(person.name.slice(1))}</div>${iconButton('edit-person',`${person.name} 정보 편집`,'more',`data-name="${esc(person.name)}"`)}</div><button data-action="actor-filter" data-name="${esc(person.name)}" style="padding:0;text-align:left"><h3>${esc(person.name)}</h3><p>${esc(person.alias)} · ${files.length}개 파일</p></button><div class="person-films">${files.slice(0,3).map(x=>`<img src="assets/${x.image}.jpg" alt="${esc(x.title)}">`).join('')}</div></article>`;}).join('')}</div></div>`;
}
function tagPage() {
  return `<div class="content"><div class="heading"><div><h1>태그<span>${allTags().length}</span></h1><p>하나의 파일에 여러 가지 이야기를 붙여보세요.</p></div>${button('manage-tags','태그 관리','tag')}</div><div class="tag-board">${allTags().map(tag=>`<button class="tag-tile" data-action="tag-filter" data-name="${esc(tag)}">${icon('tag')}<span><strong>${esc(tag)}</strong><small>${media.filter(item=>item.tags.includes(tag)).length}개 파일</small></span>${icon('chevron')}</button>`).join('')}</div></div>`;
}
const keyNames = {Escape:'Esc',Space:'Space',ArrowLeft:'←',ArrowRight:'→',ArrowUp:'↑',ArrowDown:'↓',BracketLeft:'[',BracketRight:']',Backspace:'Backspace',PageUp:'PageUp',PageDown:'PageDown',Slash:'/',Mod:navigator.platform.includes('Mac')?'⌘':'Ctrl',Shift:'Shift',Alt:'Alt'};
function keyLabel(key) { return key.split('+').map(part=>keyNames[part]||part.replace(/^(Key|Digit|Numpad)/,'')).join(' + '); }
function keyCaps(key) { return key?key.split('+').map(part=>`<kbd>${esc(keyNames[part]||part.replace(/^(Key|Digit|Numpad)/,''))}</kbd>`).join(''):'<span class="empty-key">지정 안 됨</span>'; }
function settingsPage() {
  const groups=[['player','재생 조작'],['media','파일 정리'],['app','앱 공통']];
  return `<div class="content settings-layout"><div class="heading"><div><h1>내 손에 맞는 단축키</h1><p>익숙한 기본키에, 한 손으로 쓰기 좋은 보조키를 더했어요.</p></div><div class="row">${button('reset-shortcuts','기본값','','ghost')}${button('apply-shortcuts','적용','','primary')}</div></div><div class="settings-tabs"><button class="settings-tab ${state.settingsTab==='shortcuts'?'active':''}" data-action="settings-tab" data-tab="shortcuts">단축키</button><button class="settings-tab ${state.settingsTab==='playback'?'active':''}" data-action="settings-tab" data-tab="playback">재생</button><button class="settings-tab ${state.settingsTab==='folders'?'active':''}" data-action="settings-tab" data-tab="folders">폴더</button></div>
    ${state.settingsTab==='shortcuts'?`<div class="shortcut-callout"><kbd>Esc</kbd><div><strong>소리를 끄고, 바로 최소화</strong><p>볼륨을 0%로 만든 뒤 창을 최소화합니다. 다시 열어도 소리는 켜지지 않아요.</p></div><span class="pill green">고정 단축키</span></div><div class="spread" style="margin-bottom:22px"><div class="row"><span class="eyebrow">PRESET</span><span class="pill">표준 + 왼손 보조</span></div><span class="muted" style="font-size:11px">키를 클릭하고 새 조합을 눌러보세요</span></div><table class="shortcut-table"><thead><tr><th>기능</th><th>기본키</th><th>보조키</th></tr></thead><tbody>${groups.map(([scope,label])=>`<tr class="shortcut-group"><td colspan="3">${label}</td></tr>${state.shortcuts.filter(binding=>binding.scope===scope).map(binding=>`<tr><td>${esc(binding.label)}${binding.locked?' <span class="muted" style="font-size:9px">고정</span>':''}</td>${['primary','secondary'].map(slot=>`<td><button class="key-edit ${state.recording?.id===binding.id&&state.recording?.slot===slot?'recording':''}" data-action="record-key" data-id="${binding.id}" data-slot="${slot}" ${binding.locked?'disabled':''} aria-label="${esc(binding.label)} ${slot==='primary'?'기본키':'보조키'} 변경">${state.recording?.id===binding.id&&state.recording?.slot===slot?'새 키를 눌러주세요':keyCaps(binding[slot])}</button></td>`).join('')}</tr>`).join('')}`).join('')}</tbody></table><p class="shortcut-caption">설명이나 태그를 입력하는 동안 일반 단축키는 쉬어갑니다. Esc는 앱 내부에서 항상 우선합니다.<br>이 시안의 설정은 현재 미리보기에서만 적용됩니다.</p>`:
    state.settingsTab==='playback'?`<div class="setting-card"><div class="spread"><h3>모든 영상을 0%로 시작</h3><span class="pill green">항상 사용</span></div><p>이전·다음 파일로 이동하거나 같은 파일을 다시 열 때도 0%로 시작합니다.<br>일시정지와 구간 이동은 직접 조절한 음량을 유지합니다.</p></div><div class="setting-card"><h3>최소화 후에도 조용하게</h3><p>Esc를 누르면 먼저 소리를 0%로 바꾸고 최소화합니다. 재생·일시정지 상태는 유지합니다.</p></div><div class="setting-card"><h3>재생 품질 확인</h3><p>코덱 호환성, 자막, 하드웨어 가속은 디자인 확정 후 실제 Windows·Mac 앱에서 검증합니다. 현재 화면은 재생 UI 시안입니다.</p></div>`:
    `<div class="setting-card"><h3>내 폴더 그대로 연결</h3><p>파일을 별도 보관 위치로 복사하지 않고 연결한 폴더에서 관리합니다.</p><div style="margin-top:20px">${button('folders','연결 폴더 관리','folder')}</div></div>`}
  </div>`;
}

function openPlayer(id) {
  const item=getItem(id); if(!item) return;
  if(!folderOf(item)?.online) { toast('연결되지 않은 폴더입니다. 폴더 관리에서 다시 연결해 주세요.'); return; }
  if(item.type==='image') { openDetail(id); return; }
  const previousQueue=state.player?.queue;
  const queue=state.view==='player'&&previousQueue?previousQueue:visibleItems().filter(x=>x.type==='video').map(x=>x.id);
  state.player={id,queue:queue.includes(id)?queue:media.filter(x=>x.type==='video').map(x=>x.id),volume:0,muted:false,playing:false,position:0,speed:1,expanded:false,previousSeek:0};
  state.view='player';state.modal=null;state.recording=null;state.minimized=false;render();
  $('.deck-file.current')?.scrollIntoView({block:'nearest'});
}
function playerPage() {
  const p=state.player,item=getItem(p.id),silent=p.muted||p.volume===0;
  return deckPlayer(p,item,silent);
}
function minimizedPage() {
  return `<main class="minimized-view"><section class="minimized-card">${icon('muted')}<h2>조용히, 잠시 내려두기</h2><p>볼륨을 0%로 낮추고<br>앱을 최소화한 상태입니다.</p><span class="pill green">볼륨 0% · ${state.player?.playing?'재생 상태 유지':'일시정지 상태 유지'}</span>${button('restore','미리보기로 돌아가기','back','primary')}<div class="design-disclaimer">최소화 동작을 보여주는 디자인 시안입니다.<br>실제 브라우저 창은 최소화되지 않습니다.</div></section></main>`;
}
function render() {
  const scroll=$('.main')?.scrollTop||0;
  const sideScroll=$('.deck-file-list')?.scrollTop||0;
  $('#app').innerHTML=state.minimized?minimizedPage():state.view==='player'?playerPage():`<div class="shell ${state.collapsed?'collapsed':''}">${sidebar()}<main class="main">${topbar()}${state.view==='library'?library():state.view==='actors'?actorPage():state.view==='tags'?tagPage():settingsPage()}</main></div>`;
  if($('.main')) $('.main').scrollTop=scroll;
  if($('.deck-file-list')) $('.deck-file-list').scrollTop=sideScroll;
  renderModal();
}
function modalShell(title,subtitle,body,footer='',extra='') {
  return `<div class="overlay"><section class="dialog ${extra}" role="dialog" aria-modal="true" aria-labelledby="dialog-title" tabindex="-1"><header class="dialog-head"><div><h2 id="dialog-title">${title}</h2>${subtitle?`<p>${subtitle}</p>`:''}</div>${iconButton('close-modal','닫기','close')}</header>${body}${footer?`<footer class="dialog-foot">${footer}</footer>`:''}</section></div>`;
}
function openModal(name) {
  restoreFocus=document.activeElement;state.modal=name;state.recording=null;renderModal();
}
function closeModal() {
  state.modal=null;$('#overlay-root').innerHTML=''; if(restoreFocus?.isConnected) restoreFocus.focus();
}
function openDetail(id,focus='title') {
  const item=getItem(id);if(!item) return;
  state.draft=structuredClone(item);state.draft.focus=focus;openModal('detail');
}
function searchEntries() {
  const term=normalize(state.search.trim());
  if(!term) return [{kind:'command',action:'apply-search',label:'라이브러리에서 찾기',sub:'파일명, 배우, 태그, 설명',glyph:'search'},...media.slice(0,3).map(item=>({kind:'media',item})),{kind:'command',action:'folders',label:'폴더 연결 관리',sub:'내 폴더를 라이브러리에 연결',glyph:'folder'},{kind:'command',action:'go-shortcuts',label:'단축키 설정',sub:'기본키와 보조키 변경',glyph:'keyboard'}];
  const results=media.filter(item=>normalize([item.title,item.file,item.note,...item.actors,...item.tags].join(' ')).includes(term));
  return [{kind:'command',action:'apply-search',label:`“${state.search}” 검색 결과 보기`,sub:`${results.length}개 파일 · 라이브러리에서 필터링`,glyph:'search'},...results.map(item=>({kind:'media',item}))];
}
function searchRows() {
  return `<div class="command-label">${state.search?'검색 결과':'빠르게 찾아보기'}</div>${searchEntries().map((entry,index)=>entry.kind==='media'?`<button class="command-row ${index===state.searchIndex?'highlighted':''}" data-action="open" data-id="${entry.item.id}"><img src="assets/${entry.item.image}.jpg" alt=""><span>${esc(entry.item.title)}<small>${esc(folderOf(entry.item)?.name)} · ${entry.item.type==='video'?time(entry.item.duration):'이미지'}</small></span><span class="key-hint">↵</span></button>`:`<button class="command-row ${index===state.searchIndex?'highlighted':''}" data-action="${entry.action}">${icon(entry.glyph)}<span>${esc(entry.label)}<small>${esc(entry.sub)}</small></span><span class="key-hint">↵</span></button>`).join('')}`;
}
function renderModal() {
  const root=$('#overlay-root');if(!state.modal||state.minimized){root.innerHTML='';return;}
  const footer=(action,label='저장')=>`<span class="foot-note">예시 데이터에만 적용됩니다.</span>${button('close-modal','취소','','ghost')}${button(action,label,'','primary')}`;
  let html='';
  if(state.modal==='detail') {
    const d=state.draft;
    html=modalShell('파일 정보','원하는 만큼 기록하고, 쉽게 다시 찾아보세요.',`<div class="detail-layout"><div class="detail-preview"><img src="assets/${d.image}.jpg" alt="${esc(d.title)}"><h3>${esc(d.title)}</h3><div class="filename">${esc(d.file)}</div>${d.type==='video'?button('open','재생 화면 열기','play','',`data-id="${d.id}"`):'<span class="pill" style="margin-top:20px">이미지 미리보기</span>'}<div class="file-properties"><div><span>폴더</span><strong>${esc(folderOf(d)?.name)}</strong></div><div><span>크기</span><strong>${d.size}</strong></div><div><span>해상도</span><strong>${d.resolution}</strong></div><div><span>코덱</span><strong>${d.codec}</strong></div></div><div class="divider"></div><small style="font-size:10px;line-height:1.8">파일을 다른 연결 폴더로 옮겨도<br>평점과 기록은 그대로 따라갑니다.</small></div><div class="detail-edit"><div class="field"><label for="detail-title">제목</label><input id="detail-title" data-draft="title" value="${esc(d.title)}" ${d.focus==='title'?'autofocus':''}></div><div class="field"><label>평점</label><div class="row">${stars(d,true,'draft-rate')}<button class="text-link" data-action="draft-clear-rating">초기화</button></div></div><div class="field"><label for="detail-actors">배우 <span class="muted">· 쉼표로 구분</span></label><input id="detail-actors" data-draft="actors" value="${esc(d.actors.join(', '))}" placeholder="배우 이름 추가" ${d.focus==='actors'?'autofocus':''}></div><div class="field"><label for="detail-tags">태그 <span class="muted">· 쉼표로 구분</span></label><input id="detail-tags" data-draft="tags" value="${esc(d.tags.join(', '))}" ${d.focus==='tags'?'autofocus':''}><div class="chips">${d.tags.map(tag=>`<span class="tag-chip">${esc(tag)}</span>`).join('')}</div></div><div class="field"><label for="detail-note">설명 · 메모</label><textarea id="detail-note" data-draft="note">${esc(d.note)}</textarea></div></div></div>`,footer('save-detail'),'detail-dialog');
  } else if(state.modal==='search') {
    html=`<div class="overlay"><section class="dialog search-dialog" role="dialog" aria-modal="true" aria-label="검색·명령창"><div class="command-input">${icon('search')}<input id="command-search" aria-label="파일·배우·태그 검색" placeholder="어떤 장면을 찾고 있나요?" value="${esc(state.search)}" autofocus>${iconButton('close-modal','검색 닫기','close')}</div><div id="command-results" class="command-results">${searchRows()}</div><div class="command-footer"><span>↑ ↓ 선택 · Enter 열기</span><span>Esc 소리 0% · 최소화</span></div></section></div>`;
  } else if(state.modal==='filters') {
    html=modalShell('필터','기억나는 단서로 파일을 좁혀보세요.',`<div class="dialog-body"><div class="filter-grid"><div class="field"><label for="filter-rating">평점</label><select id="filter-rating">${[['all','모든 평점'],['unrated','미평가'],['5','5점'],['4','4점 이상'],['3','3점 이상']].map(([value,label])=>`<option value="${value}" ${state.filters.rating===value?'selected':''}>${label}</option>`).join('')}</select></div><div class="field"><label for="filter-actor">배우</label><select id="filter-actor"><option value="all">모든 배우</option>${people.map(p=>`<option ${state.filters.actor===p.name?'selected':''}>${esc(p.name)}</option>`).join('')}</select></div><div class="field"><label for="filter-tag">태그</label><select id="filter-tag"><option value="all">모든 태그</option>${allTags().map(tag=>`<option ${state.filters.tag===tag?'selected':''}>${esc(tag)}</option>`).join('')}</select></div></div></div>`,button('close-modal','닫기','','ghost')+button('apply-filters','적용','','primary'));
  } else if(state.modal==='folders') {
    html=modalShell('연결된 폴더','파일은 원래 위치에, 라이브러리는 한곳에.',`<div class="dialog-body">${folders.map(f=>`<div class="folder-choice">${icon('folder')}<span><strong>${esc(f.name)}</strong><small>${esc(f.path)} · ${media.filter(x=>x.folder===f.id).length}개 파일</small></span><button class="pill ${f.online?'green':''}" style="margin-left:auto" data-action="folder-status" data-id="${f.id}" title="연결 상태 시안 전환">${f.online?'연결됨':'연결 안 됨'}</button></div>`).join('')}<p class="move-note">연결이 끊어져도 평점과 태그는 유지됩니다.<br>이 시안에서는 상태 표시를 눌러 연결 해제를 미리 볼 수 있습니다.</p></div>`,`<span class="foot-note">실제 폴더에는 접근하지 않습니다.</span>${button('add-sample-folder','예시 폴더 추가','plus')}${button('close-modal','완료','','primary')}`);
  } else if(state.modal==='move') {
    const ids=targetIds();const valid=folders.find(f=>f.id===state.moveTarget)?.online;
    html=modalShell('어디로 옮길까요?','평점, 배우, 태그와 설명도 함께 유지됩니다.',`<div class="dialog-body"><div class="move-summary">${icon('film')}<span>${ids.length}개 파일 선택</span><span class="muted" style="margin-left:auto">이동 미리보기</span></div>${folders.map(f=>`<button class="folder-choice ${state.moveTarget===f.id?'selected':''}" data-action="move-target" data-id="${f.id}" ${!f.online?'disabled':''}>${icon('folder')}<span><strong>${esc(f.name)}${!f.online?' · 연결 안 됨':''}</strong><small>${esc(f.path)}</small></span><span class="check-ring"></span></button>`).join('')}<div class="field" style="margin-top:24px;margin-bottom:0"><label for="move-conflict">같은 이름의 파일이 있으면</label><select id="move-conflict"><option value="skip" ${state.conflict==='skip'?'selected':''}>건너뛰기</option><option value="rename" ${state.conflict==='rename'?'selected':''}>이름에 번호 붙이기</option></select></div><p class="move-note">선택한 파일이 이미 목적지에 있으면 건너뜁니다.<br>실제 이동은 디자인 확정 후 구현합니다.</p><details class="demo-scenarios"><summary>다른 이동 상황 미리보기</summary><div class="field"><label for="move-scenario">예시 상황</label><select id="move-scenario"><option value="normal" ${state.moveScenario==='normal'?'selected':''}>정상 이동</option><option value="conflict" ${state.moveScenario==='conflict'?'selected':''}>첫 파일의 이름이 같은 경우</option><option value="failure" ${state.moveScenario==='failure'?'selected':''}>첫 파일 이동이 실패한 경우</option></select></div></details></div>`,`<span class="foot-note">예시 파일의 위치 표시만 바뀝니다.</span>${button('close-modal','취소','','ghost')}${button('apply-move','이동 미리보기','move','primary',!valid?'disabled':'')}`);
  } else if(state.modal==='move-result') {
    const report=state.moveReport,failed=report.filter(x=>x.status==='failed').length,done=report.filter(x=>x.status==='done').length,skipped=report.filter(x=>x.status==='skipped').length;
    html=modalShell('이동 결과 시안',failed?'이동하지 못한 파일은 원래 폴더에 남아 있습니다.':'평점과 기록은 그대로 유지했습니다.',`<div class="dialog-body"><div class="report-counts"><span><strong>${done}</strong> 완료</span><span><strong>${skipped}</strong> 건너뜀</span><span class="${failed?'warning':''}"><strong>${failed}</strong> 실패</span></div>${report.map(row=>`<div class="report-row"><div><strong>${esc(getItem(row.id).title)}</strong><small>${esc(row.note)}</small></div><span class="pill ${row.status==='done'?'green':''}">${{done:'완료',skipped:'건너뜀',failed:'원본 유지'}[row.status]}</span></div>`).join('')}<p class="move-note">예시 데이터의 이동 결과입니다. 실제 파일은 이동하지 않았습니다.</p></div>`,`${failed?button('retry-move','실패 항목만 다시 시도','move'):''}${button('close-modal','확인','','primary')}`);
  } else if(state.modal==='batch-tags') {
    html=modalShell('태그 일괄 편집',`${targetIds().length}개 파일의 태그를 함께 정리합니다.`,`<div class="dialog-body"><div class="field"><label for="batch-tag-input">태그 · 쉼표로 구분</label><input id="batch-tag-input" placeholder="여행, 자연, 다시 볼 장면" autofocus></div><div class="field"><label for="tag-operation">작업</label><select id="tag-operation"><option value="add">기존 태그에 추가</option><option value="remove">입력한 태그 제거</option></select></div></div>`,footer('apply-batch-tags','적용'));
  } else if(state.modal==='person') {
    html=modalShell('배우 정보','이름과 별칭을 함께 기록하세요.',`<div class="dialog-body"><div class="field"><label for="person-name">이름</label><input id="person-name" value="${esc(state.draft.name)}" autofocus></div><div class="field"><label for="person-alias">별칭</label><input id="person-alias" value="${esc(state.draft.alias)}"></div><div class="field"><label for="person-note">설명</label><textarea id="person-note">${esc(state.draft.description)}</textarea></div></div>`,footer('save-person'));
  } else if(state.modal==='manage-tags') {
    html=modalShell('태그 관리','표기가 다른 태그를 하나로 정리하세요.',`<div class="dialog-body"><div class="field"><label for="old-tag">변경할 태그</label><select id="old-tag">${allTags().map(tag=>`<option>${esc(tag)}</option>`).join('')}</select></div><div class="field"><label for="new-tag">새 이름</label><input id="new-tag" placeholder="태그 이름" autofocus></div><p class="move-note">이미 있는 이름으로 바꾸면 해당 태그로 합쳐집니다.<br>같은 파일의 중복 태그는 하나로 정리됩니다.</p></div>`,footer('save-tag'));
  } else if(state.modal==='help') {
    html=modalShell('손에 익으면, 더 간편하게','표준키 + 왼손 보조키',`<div class="dialog-body"><div class="shortcut-callout" style="margin-bottom:18px"><kbd>Esc</kbd><div><strong>볼륨 0% · 최소화</strong><p>다시 돌아와도 소리는 꺼져 있어요.</p></div></div><table class="shortcut-table"><tbody>${state.shortcuts.filter(x=>['pause','back','forward','volumeUp','volumeDown','previous','next','mute','fullscreen','tags','detail','search'].includes(x.id)).map(x=>`<tr><td>${x.label}</td><td>${keyCaps(x.primary)}</td><td>${keyCaps(x.secondary)}</td></tr>`).join('')}</tbody></table></div>`,button('go-shortcuts','전체 단축키 설정','keyboard','primary'));
  } else if(state.modal==='intro') {
    html=`<div class="overlay"><section class="dialog intro-dialog" role="dialog" aria-modal="true" aria-label="처음 시작 화면"><div class="spread" style="margin:-20px -25px 15px"><span class="eyebrow">SOFT VAULT</span>${iconButton('close-modal','닫기','close')}</div><div class="intro-visual"><img class="onboarding-app-icon" src="${appIconPath}" alt="Quiet Folder 앱 아이콘"></div><h2>흩어진 장면들,<br>나만의 라이브러리로.</h2><p>영상을 담아둔 폴더를 연결해 보세요.<br>파일은 원래 자리에 두고, 여기서 함께 정리할 수 있어요.</p><div class="intro-features"><span>${icon('check')} 여러 폴더 연결</span><span>${icon('check')} 평점 · 배우 · 태그</span><span>${icon('check')} 항상 무음 시작</span></div>${button('connect-sample','폴더 연결하고 시작하기','plus','primary')}<p class="small-note">첫 실행 화면의 디자인 시안입니다.<br>버튼을 누르면 예시 라이브러리가 열립니다.</p></section></div>`;
  }
  root.innerHTML=html;
  const snapshot=state.minimizedForm?.modal===state.modal?state.minimizedForm:null;
  if(snapshot) {
    snapshot.fields.forEach(field=>{const element=document.getElementById(field.id);if(element)element.value=field.value;});
    state.minimizedForm=null;
  }
  requestAnimationFrame(()=>{
    const focus=(snapshot?.focused?document.getElementById(snapshot.focused):null)||$('[autofocus]',root)||$('button:not([disabled])',root)||$('.dialog',root);
    focus?.focus();
    const saved=snapshot?.fields.find(field=>field.id===snapshot.focused);
    if(saved&&typeof saved.start==='number'&&focus?.setSelectionRange)focus.setSelectionRange(saved.start,saved.end);
  });
}

function go(view) {
  if(state.player) {state.player.playing=false;state.player.volume=0;}
  state.view=view;state.modal=null;state.recording=null;state.selected.clear();render();if($('.main'))$('.main').scrollTop=0;
}
function playerFeedback(label) {
  if(state.view!=='player'||state.minimized) return;
  $('.player-osd')?.remove();const div=document.createElement('div');div.className='player-osd';div.textContent=label;$('.player')?.append(div);
  clearTimeout(osdTimer);osdTimer=setTimeout(()=>div.remove(),1100);
}
function setVolume(value) { if(!state.player)return;state.player.volume=Math.min(100,Math.max(0,Math.round(value)));if(state.player.volume>0)state.player.muted=false; }
function seek(delta) {const p=state.player;if(!p)return;p.previousSeek=p.position;p.position=Math.max(0,Math.min(getItem(p.id).duration,p.position+delta));}
function minimize() {
  if(state.player)state.player.volume=0;
  if(state.modal)state.minimizedForm={modal:state.modal,focused:document.activeElement?.id,fields:$$('input[id],textarea[id],select[id]',$('#overlay-root')).map(element=>({id:element.id,value:element.value,start:element.selectionStart,end:element.selectionEnd}))};
  state.minimized=true;$('#toast').classList.remove('visible');render();
}
function dispatch(action, data={}) {
  const p=state.player;
  switch(action) {
    case 'section': state.section=data.section;state.sectionValue='';state.query='';state.filters={rating:'all',actor:'all',tag:'all'};state.type='all';go('library');break;
    case 'navigate': go(data.view);break;
    case 'preview': state.previewId=data.id;state.selected=new Set([data.id]);render();break;
    case 'rating-filter': state.filters.rating=data.rating;state.selected.clear();go('library');break;
    case 'folder': state.section='folder';state.sectionValue=data.id;state.query='';state.filters={rating:'all',actor:'all',tag:'all'};go('library');break;
    case 'actor-filter': case 'tag-filter':state.section=action==='actor-filter'?'actor':'tag';state.sectionValue=data.name;state.query='';state.filters={rating:'all',actor:'all',tag:'all'};state.type='all';go('library');break;
    case 'collapse':state.collapsed=!state.collapsed;render();break;
    case 'type':state.type=data.type;state.selected.clear();render();break;
    case 'select':state.selected.has(data.id)?state.selected.delete(data.id):state.selected.add(data.id);render();break;
    case 'clear-selection':state.selected.clear();render();break;
    case 'open':openPlayer(data.id);break;
    case 'back-library':go('library');break;
    case 'detail':{const id=data.id||targetIds()[0];if(id)openDetail(id);else toast('먼저 파일을 선택해 주세요.');break;}
    case 'tags':case 'actors':{const ids=targetIds();if(!ids.length){toast('먼저 파일을 선택해 주세요.');break;}if(action==='tags'&&ids.length>1)openModal('batch-tags');else openDetail(ids[0],action);break;}
    case 'rate':{const item=getItem(data.id);if(item)item.rating=Number(data.rating);render();break;}
    case 'batch-rate':{targetIds().forEach(id=>getItem(id).rating=Number(data.rating));render();toast(`${targetIds().length}개 파일에 ${data.rating}점을 적용했습니다.`);break;}
    case 'draft-rate':state.draft.rating=Number(data.rating);state.draft.focus='rating';renderModal();break;
    case 'draft-clear-rating':state.draft.rating=null;state.draft.focus='rating';renderModal();break;
    case 'save-detail':{const d=state.draft;if(!d.title.trim()){toast('제목을 입력해 주세요.');return;}const item=getItem(d.id);Object.assign(item,{title:d.title.trim(),rating:d.rating,actors:[...d.actors],tags:[...d.tags],note:d.note});d.actors.forEach(name=>{if(!people.some(x=>x.name===name))people.push({name,alias:'',description:''});});state.modal=null;render();toast('예시 파일의 정보를 저장했습니다.');break;}
    case 'search':state.search='';state.searchIndex=0;openModal('search');break;
    case 'apply-search':state.query=state.search.trim();state.section='all';state.sectionValue='';state.type='all';state.filters={rating:'all',actor:'all',tag:'all'};go('library');break;
    case 'filters':case 'folders':case 'intro':case 'help':case 'manage-tags':openModal(action);break;
    case 'close-modal':closeModal();break;
    case 'apply-filters':state.filters={rating:$('#filter-rating').value,actor:$('#filter-actor').value,tag:$('#filter-tag').value};state.selected.clear();state.modal=null;render();break;
    case 'clear-filter':if(data.key==='query')state.query='';else state.filters[data.key]='all';state.selected.clear();render();break;
    case 'reset-filters':state.filters={rating:'all',actor:'all',tag:'all'};state.query='';state.type='all';state.selected.clear();render();break;
    case 'folder-status':{const f=folders.find(x=>x.id===data.id);f.online=!f.online;render();break;}
    case 'add-sample-folder':{const n=folders.length+1;folders.push({id:`folder${n}`,name:`추가 폴더 ${n}`,path:`F:\\Media\\Folder${n}`,online:true,color:'green'});render();toast('빈 예시 폴더를 추가했습니다.');break;}
    case 'connect-sample':state.section='all';state.type='all';state.query='';go('library');toast('예시 라이브러리가 연결되었습니다.');break;
    case 'move':{const ids=targetIds();if(!ids.length){toast('이동할 파일을 먼저 선택해 주세요.');return;}const destination=folders.find(f=>f.online&&f.id!==getItem(ids[0]).folder)||folders.find(f=>f.online);if(!destination){toast('연결된 목적지 폴더가 없습니다.');return;}state.moveTarget=destination.id;state.moveScenario='normal';openModal('move');break;}
    case 'move-target':state.moveTarget=data.id;renderModal();break;
    case 'apply-move':{
      const destination=folders.find(f=>f.id===state.moveTarget);
      if(!destination?.online){toast('목적지 폴더가 연결되지 않았습니다.');return;}
      state.moveReport=targetIds().map((id,index)=>{
        const item=getItem(id);
        if(item.folder===destination.id)return {id,status:'skipped',note:'이미 목적지 폴더에 있습니다.'};
        if(index===0&&state.moveScenario==='failure')return {id,status:'failed',note:'예시: 파일에 접근할 수 없습니다. 원본은 그대로 유지합니다.'};
        if(index===0&&state.moveScenario==='conflict'&&state.conflict==='skip')return {id,status:'skipped',note:'같은 이름의 파일이 있어 건너뛰었습니다.'};
        if(index===0&&state.moveScenario==='conflict')item.file=item.file.replace(/(\.[^.]+)$/,' (1)$1');
        item.folder=destination.id;return {id,status:'done',note:destination.name+' · 평점과 정보 유지'};
      });
      state.selected.clear();state.modal='move-result';render();break;
    }
    case 'retry-move':{
      state.selected=new Set(state.moveReport.filter(row=>row.status==='failed').map(row=>row.id));
      state.moveScenario='normal';state.modal='move';renderModal();break;
    }
    case 'batch-tags':if(targetIds().length)openModal('batch-tags');else toast('파일을 먼저 선택해 주세요.');break;
    case 'apply-batch-tags':{const tags=tagsFrom($('#batch-tag-input').value),remove=$('#tag-operation').value==='remove';if(!tags.length){toast('태그를 입력해 주세요.');return;}targetIds().forEach(id=>{const item=getItem(id);item.tags=remove?item.tags.filter(t=>!tags.includes(t)):[...new Set([...item.tags,...tags])];});state.modal=null;render();toast('예시 파일의 태그를 변경했습니다.');break;}
    case 'edit-person':state.draft=structuredClone(people.find(x=>x.name===data.name));openModal('person');break;
    case 'save-person':{const name=$('#person-name').value.trim();if(!name){toast('배우 이름을 입력해 주세요.');return;}if(people.some(x=>x.name===name&&x.name!==state.draft.name)){toast('이미 있는 이름입니다. 다른 이름을 입력해 주세요.');return;}const person=people.find(x=>x.name===state.draft.name);media.forEach(x=>x.actors=x.actors.map(a=>a===person.name?name:a));Object.assign(person,{name,alias:$('#person-alias').value.trim(),description:$('#person-note').value});state.modal=null;render();toast('예시 배우 정보를 저장했습니다.');break;}
    case 'save-tag':{const old=$('#old-tag').value,name=$('#new-tag').value.trim();if(!name){toast('새 태그 이름을 입력해 주세요.');return;}media.forEach(x=>x.tags=[...new Set(x.tags.map(tag=>tag===old?name:tag))]);state.modal=null;render();toast('태그 이름을 변경했습니다.');break;}
    case 'go-shortcuts':state.settingsTab='shortcuts';go('settings');break;
    case 'settings-tab':state.settingsTab=data.tab;state.recording=null;render();break;
    case 'record-key':state.recording=state.recording?.id===data.id&&state.recording?.slot===data.slot?null:{id:data.id,slot:data.slot};render();break;
    case 'reset-shortcuts':state.shortcuts=structuredClone(defaults);state.recording=null;render();toast('기본 단축키로 되돌렸습니다.');break;
    case 'apply-shortcuts':state.recording=null;render();toast('시안에 적용했습니다. 새로고침하면 기본값으로 돌아갑니다.');break;
    case 'minimize':minimize();break;
    case 'restore':state.minimized=false;render();break;
    case 'zero':if(p){p.volume=0;render();playerFeedback('볼륨 0%');}else toast('볼륨 0%');break;
    case 'pause':if(p){p.playing=!p.playing;render();}break;
    case 'mute':if(p){p.muted=!p.muted;render();playerFeedback(p.muted?'음소거':`볼륨 ${p.volume}%`);}break;
    case 'back':case 'forward':case 'fineBack':case 'fineForward':if(p){const delta={back:-5,forward:5,fineBack:-1,fineForward:1}[action];seek(delta);render();playerFeedback(`${delta>0?'+':''}${delta}초`);}break;
    case 'volumeUp':case 'volumeDown':if(p){setVolume(p.volume+(action==='volumeUp'?5:-5));render();playerFeedback(`볼륨 ${p.volume}%`);}break;
    case 'previous':case 'next':if(p){const index=p.queue.indexOf(p.id)+(action==='next'?1:-1);if(index>=0&&index<p.queue.length)openPlayer(p.queue[index]);else playerFeedback(action==='next'?'마지막 파일입니다':'첫 번째 파일입니다');}break;
    case 'fullscreen':if(p){p.expanded=!p.expanded;render();playerFeedback(p.expanded?'전체 화면 배치':'기본 재생 배치');}break;
    case 'slower':case 'faster':case 'normalSpeed':case 'cycle-speed':if(p){p.speed=action==='normalSpeed'?1:action==='cycle-speed'?(p.speed>=2?.5:p.speed+.5):Math.max(.25,Math.min(3,Math.round((p.speed+(action==='faster'?.1:-.1))*10)/10));render();playerFeedback(`${p.speed.toFixed(1)}배속`);}break;
    case 'undoSeek':if(p){[p.position,p.previousSeek]=[p.previousSeek,p.position];render();playerFeedback('직전 탐색 위치');}break;
    case 'clearRating':{const ids=targetIds();if(!ids.length){toast('파일을 먼저 선택해 주세요.');break;}ids.forEach(id=>getItem(id).rating=null);render();toast('평점을 초기화했습니다.');break;}
    default:if(/^rating[1-5]$/.test(action)){const ids=targetIds();if(!ids.length){toast('평가할 파일을 먼저 선택해 주세요.');return;}const value=Number(action.slice(-1));ids.forEach(id=>getItem(id).rating=value);render();toast(`${value}점을 적용했습니다.`);}
  }
}

document.addEventListener('click',event=>{const target=event.target.closest('[data-action]');if(!target||target.disabled)return;dispatch(target.dataset.action,target.dataset);});
document.addEventListener('input',event=>{
  const target=event.target;
  if(target.matches('[data-draft]')) {const name=target.dataset.draft;state.draft[name]=['actors','tags'].includes(name)?tagsFrom(target.value):target.value;}
  if(target.id==='command-search') {state.search=target.value;state.searchIndex=0;$('#command-results').innerHTML=searchRows();}
  if(target.id==='volume') {setVolume(Number(target.value));$('#volume-value').textContent=state.player.volume+'%';$('#silent-pill').innerHTML=icon(state.player.volume?'volume':'muted')+`<span>${state.player.volume?state.player.volume+'%':'소리 꺼짐'}</span>`;}
  if(target.id==='timeline') {state.player.previousSeek=state.player.position;state.player.position=Number(target.value);$('#current-time').textContent=time(state.player.position);}
});
document.addEventListener('change',event=>{if(event.target.id==='sort-select'){state.sort=event.target.value;render();}if(event.target.id==='move-conflict')state.conflict=event.target.value;if(event.target.id==='move-scenario')state.moveScenario=event.target.value;if(event.target.id==='volume')render();});
document.addEventListener('dragstart',event=>{if(state.view==='player'){event.preventDefault();return;}const card=event.target.closest('[data-item]');if(!card)return;if(!state.selected.has(card.dataset.item)){state.selected.clear();state.selected.add(card.dataset.item);}event.dataTransfer.setData('application/x-soft-vault-preview',JSON.stringify([...state.selected]));event.dataTransfer.effectAllowed='move';});
document.addEventListener('dragover',event=>{if(event.target.closest('[data-drop-folder]')&&[...event.dataTransfer.types].includes('application/x-soft-vault-preview'))event.preventDefault();});
document.addEventListener('drop',event=>{const target=event.target.closest('[data-drop-folder]');if(!target)return;const raw=event.dataTransfer.getData('application/x-soft-vault-preview');if(!raw)return;event.preventDefault();try{const ids=JSON.parse(raw).filter(id=>getItem(id));if(!ids.length)return;state.selected=new Set(ids);state.moveTarget=target.dataset.dropFolder;openModal('move');}catch{toast('시안 안의 파일을 선택해서 이동해 주세요.');}});

function pressedKey(event) {
  const parts=[];if(event.ctrlKey||event.metaKey)parts.push('Mod');if(event.altKey)parts.push('Alt');if(event.shiftKey)parts.push('Shift');
  parts.push(event.code.startsWith('Numpad')&&/^Numpad\d$/.test(event.code)?event.code.replace('Numpad','Digit'):event.code);return parts.join('+');
}
document.addEventListener('keydown',event=>{
  if(event.key==='Escape') {event.preventDefault();event.stopImmediatePropagation();if(!event.repeat&&!state.minimized)minimize();return;}
  if(state.minimized)return;
  const key=pressedKey(event);
  if(state.recording&&!state.modal) {
    if(['ShiftLeft','ShiftRight','ControlLeft','ControlRight','MetaLeft','MetaRight','AltLeft','AltRight'].includes(event.code))return;
    event.preventDefault();const collision=state.shortcuts.find(x=>(x.primary===key||x.secondary===key)&&!(x.id===state.recording.id&&x[state.recording.slot]===key));
    if(collision){toast(`이미 “${collision.label}”에 지정된 키입니다.`);return;}
    const binding=state.shortcuts.find(x=>x.id===state.recording.id);binding[state.recording.slot]=key;state.recording=null;render();toast('단축키를 변경했습니다.');return;
  }
  if(state.modal) {
    if(event.key==='Tab') {
      const focusables=$$('button:not([disabled]),input,select,textarea,[tabindex="0"]',$('#overlay-root')).filter(x=>x.getClientRects().length);
      const first=focusables[0],last=focusables.at(-1);
      if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}
    }
    if(state.modal==='search'&&!event.isComposing) {
      if(event.key==='ArrowDown'||event.key==='ArrowUp'){event.preventDefault();const entries=searchEntries();state.searchIndex=(state.searchIndex+(event.key==='ArrowDown'?1:-1)+entries.length)%entries.length;$('#command-results').innerHTML=searchRows();$('.command-row.highlighted')?.scrollIntoView({block:'nearest'});}
      if(event.key==='Enter'){event.preventDefault();const entry=searchEntries()[state.searchIndex];if(entry.kind==='media')openPlayer(entry.item.id);else dispatch(entry.action);}
    }
    return;
  }
  const editing=event.target.matches('input,textarea,select,[contenteditable="true"]');
  if(editing||event.isComposing||event.keyCode===229)return;
  const binding=state.shortcuts.find(x=>(x.primary===key||x.secondary===key)&&(x.scope==='app'||x.scope==='player'&&state.view==='player'||x.scope==='media'&&['library','player'].includes(state.view)));
  if(binding){event.preventDefault();if(event.repeat&&!['back','forward','fineBack','fineForward','volumeUp','volumeDown'].includes(binding.id))return;dispatch(binding.id);return;}
  if((event.ctrlKey||event.metaKey)&&event.code==='KeyA'&&state.view==='library'){event.preventDefault();state.selected=new Set(visibleItems().map(x=>x.id));render();}
},true);

setInterval(()=>{
  const p=state.player;if(!p?.playing)return;
  p.position=Math.min(getItem(p.id).duration,p.position+.5*p.speed);
  if(p.position>=getItem(p.id).duration){p.playing=false;if(state.view==='player'&&!state.minimized)render();}
  if($('#timeline'))$('#timeline').value=p.position;
  if($('#current-time'))$('#current-time').textContent=time(p.position);
},500);

// Review links open the same screens used by the interactive prototype.
const initialScreen = new URLSearchParams(location.search).get('screen');
render();
if(initialScreen==='player')openPlayer('m1');
else if(initialScreen==='detail')openDetail('m1');
else if(['actors','tags'].includes(initialScreen))go(initialScreen);
else if(initialScreen==='shortcuts')dispatch('go-shortcuts');
else if(['folders','search','intro'].includes(initialScreen))dispatch(initialScreen);
else if(initialScreen==='move'){state.selected=new Set(['m1','m2']);render();dispatch('move');}
else if(initialScreen==='minimized'){openPlayer('m1');minimize();}
