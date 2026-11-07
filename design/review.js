'use strict';
const reviewScreens={
  library:{file:'01-library',number:'01 / LIBRARY',title:'한쪽에 모은 목록, 넓게 보는 미리보기',description:'파일 제목을 누르면 왼쪽에서 미리보고, 썸네일을 누르면 엽니다. 평점·배우·태그·설명은 미리보기 아래에서 확인합니다.'},
  player:{file:'02-player',number:'02 / PLAYER',title:'영상에 집중하면서 다음 파일도 바로',description:'오른쪽 재생 목록을 유지합니다. 새 파일은 항상 0%로 열리고, F로 전체 화면 배치를 전환합니다. Q/E로 이전·다음 파일을 고릅니다.'},
  detail:{file:'03-detail',number:'03 / DETAILS',title:'기록은 한곳에서, 필요할 때만',description:'제목·평점·배우·태그·설명을 한 창에서 편집합니다. 상시 세 번째 영역을 추가하지 않습니다.'},
  actors:{file:'04-actors',number:'04 / ACTORS',title:'배우별로 다시 찾아보기',description:'배우의 이름·별칭·설명을 관리하고 연결된 파일을 모아 봅니다.'},
  tags:{file:'05-tags',number:'05 / TAGS',title:'나만의 분류로 모으기',description:'태그별로 파일을 모아 보고 이름을 정리합니다. 폴더 위치와 별개로 같은 태그의 파일을 함께 찾습니다.'},
  move:{file:'07-move',number:'06 / MOVE',title:'폴더를 옮겨도 기록은 함께',description:'여러 파일을 선택해 연결된 폴더로 옮깁니다. 이름 충돌·일부 실패를 확인하는 모의 흐름을 포함합니다.'},
  search:{file:'08-search',number:'07 / SEARCH',title:'검색창은 찾을 때만',description:'Ctrl/Cmd+K 또는 검색 버튼으로 호출합니다. 파일명·배우·태그·설명을 검색하고, 결과 조건은 해제할 수 있습니다.'},
  shortcuts:{file:'09-shortcuts',number:'08 / SHORTCUTS',title:'표준키와 왼손 보조키를 함께',description:'기본키와 보조키를 편집하고 충돌을 확인합니다. Esc의 0% 후 최소화와 숫자 0의 즉시 0%는 예약합니다.'}
};
function showReviewScreen(key){
  const screen=reviewScreens[key];if(!screen)return;
  document.querySelectorAll('[data-screen]').forEach(button=>{const active=button.dataset.screen===key;button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));});
  document.querySelector('#screen-number').textContent=screen.number;
  document.querySelector('#screen-title').textContent=screen.title;
  document.querySelector('#screen-description').textContent=screen.description;
  document.querySelector('#screen-image').src='previews/selected/'+screen.file+'.png';
  document.querySelector('#screen-image').alt='Soft Vault · '+screen.title;
  document.querySelector('#screen-original').href='previews/selected/'+screen.file+'.png';
  document.querySelector('#screen-original').setAttribute('aria-label',screen.title+' 크게 보기');
  document.querySelector('#screen-open').href=key==='library'?'index.html':'index.html?screen='+key;
}
document.querySelectorAll('[data-screen]').forEach(button=>button.addEventListener('click',()=>showReviewScreen(button.dataset.screen)));
const initialReviewScreen=new URLSearchParams(location.search).get('screen');
if(reviewScreens[initialReviewScreen])showReviewScreen(initialReviewScreen);
