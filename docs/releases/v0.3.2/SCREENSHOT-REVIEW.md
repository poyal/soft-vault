# 0.3.2 화면 검수

2026-11-13, 앱 소스 `ddf934b`의 Windows x64·Mac M4 debug 네이티브 테스트에서 생성된 1280×800 클라이언트 화면을 확인했다. 후속 `3dcc84d`는 테스트만 수정했으며 앱 코드는 같다. 시험 영상과 합성 카탈로그를 사용했고 HTML 시안이나 사용자 라이브러리를 캡처하지 않았다.

| 화면 | Windows | Mac | 확인한 내용 |
| --- | --- | --- | --- |
| 목록 | [목록](../../screenshots/library.png) | [목록](screenshots/macos-library.png) | 세 줄 카드, 확대된 썸네일, 배우·태그 왼쪽 및 시간·별점 오른쪽 정렬, 정렬·필터 배치 |
| 재생 | [재생](../../screenshots/playback.png) | [재생](../../screenshots/macos-playback.png) | 테두리 없는 컨트롤, 하단 단축키 안내 제거, 타임라인·음량·평점 배치 |
| 상세정보 | [상세정보](../../screenshots/details.png) | [상세정보](screenshots/macos-detail.png) | 읽기 화면과 정보 편집 진입, 평점·배우·태그 표시 |

위 6장에 대한 직접 확인과 자동 레이아웃·크기 변경 검사를 구분한다. 모든 생성 캡처를 개별로 전수 검수했다는 뜻은 아니다. 플랫폼별 글꼴 렌더링 차이는 있으며, 화면 밖 상세정보는 스크롤로 접근한다. 원본은 Windows `build/e2e/`, Mac 후보 폴더의 `build/e2e/`에 있다. 매뉴얼 캡처의 해시와 촬영 시각은 [manifest](../../screenshots/manifest.json)에 기록했다.

`build-review.ps1`과 `compare-design.ps1`도 실행했다. 이전 HTML 시안과 현재 UI는 의도적으로 달라 픽셀 차이를 무결점·동일성 판정으로 사용하지 않는다. 이전 실행의 다중 선택 화면은 이번 검수 근거에서 제외했다.
