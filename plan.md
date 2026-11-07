# Soft Vault — 통합 기획·디자인·구현 계획

마지막 정리: 2026-11-02

## 1. 현재 단계와 작업 순서

**기획·벤치마킹 → 디자인 검토·확정 → 앱 구현 → Windows·Mac 검증** 순서로 진행한다.

- 현재 단계: **D · Side Deck + 03 · Quiet Folder 확정**. 선택한 조합으로 대표 시안과 화면별 자료를 정리했다.
- 현재 요청 범위는 확정 아이콘 적용과 디자인 시안 정리다. Flutter 앱·DB·실제 파일 작업·네이티브 재생 엔진은 이번 작업에 포함하지 않는다.
- 다음 구현 단계는 이 확정 조합을 기준으로 진행한다. 이미 선택한 디자인 방향·아이콘을 다시 선택할 필요는 없다.
- 조사와 결정 사항은 이 `plan.md` 한 파일에 관리한다.
- `design/index.html`은 예시 데이터만 사용하는 로컬 디자인 시안이다. 앱 구현물이 아니며, 실제 파일 이동·코덱 재생·운영체제 최소화를 실행하지 않는다.
- 시안에서 사용하는 인물·파일·폴더 정보는 설명을 위한 예시다. 시안 편집 내용은 새로고침하면 초기화된다.

## 2. 제품 목표와 확정 요구사항

여러 실제 폴더에 있는 영상·이미지를 한곳에서 탐색하고, 평점·배우·태그·설명을 붙이며 실제 파일을 폴더 사이에서 이동하는 개인용 Windows·Mac 앱을 만든다. 가칭은 **Soft Vault**다.

| 항목 | 확정 내용 |
|---|---|
| 플랫폼 | Windows·Mac 데스크톱 앱 |
| 기본 화면 | **사이드 뷰는 유지**. 싫은 것은 상시 3분할이며 사이드바 자체가 아님. 하나의 사이드 영역과 본문으로 구성 |
| 검색 | 큰 검색바 상시 노출 대신 버튼과 Ctrl/Cmd+K로 호출 |
| 제외 기능 | 아카이브 상태·버튼·진행률 |
| 폴더 | 여러 실제 폴더 연결, 통합 탐색, 폴더 간 실제 이동 |
| 분류 | 1~5점과 미평가, 배우, 태그, 설명, 다중 선택 편집 |
| 재생 | 별도 코덱팩 설치 없는 폭넓은 영상·음성·자막 지원 |
| 시작 음량 | 매 영상을 열 때 **항상 0%** |
| Esc | **볼륨 0% 적용 → 앱 최소화**, 복원 후에도 0% 유지 |
| 키 배치 | **표준키 + 왼손 보조키**, 사용자 지정과 충돌 안내 |
| 진행 방식 | 기획 후 디자인 확정, 그다음 앱 구현 |

## 3. 벤치마킹 조사

공식 문서에서 확인한 기능과 Soft Vault에 제안하는 동작을 구분한다. 설치 실행이나 성능 실측으로 확인한 결과는 아니다. Falcon은 사용자가 제공한 v3.0.134 화면에서 확인한 기능만 기록한다.

| 대상·출처 | 확인한 기능 | 적용할 아이디어 |
|---|---|---|
| Falcon — 사용자 제공 화면 | 여러 워크스페이스, 평점, 배우·태그·장르, 최근 항목, 단축키·보조키 | 분류 기능을 유지하면서 고정 3분할과 여러 줄 도구 모음을 재설계 |
| [Stash](https://stashapp.cc/) | 배우·태그·평점, 장면 마커, 이미지 관리 | 배우별 모아보기, 재생 시점 메모·태그 |
| [Eagle](https://eagle.cool/support/desktop/organize) | 스마트 폴더, 태그, 별점, 영상 메모, 일괄 정리 | 빠른 분류, 저장된 조건 보기 |
| [digiKam](https://www.digikam.org/about/features/) | 로컬·외장·네트워크 컬렉션, 계층 태그, 평점, 중복 탐색 | 여러 저장장치 통합 관리 |
| [TagSpaces](https://www.tagspaces.org/filemanagement/) | 실제 파일 이동·이름 변경, 기본 앱으로 열기 | 기존 폴더 구조를 유지하는 파일 관리 |
| [Hydrus](https://hydrusnetwork.github.io/hydrus/gettingStartedOverview.html) | 태그 동의어, 평점, 중복 후보 비교 | 배우·태그 표기 통합, 중복 후보 수동 검토 |
| [Adobe Bridge](https://helpx.adobe.com/au/bridge/desktop/organize-and-find-files/tag-and-find-files/label-and-rate-files.html) | 별점과 색상 라벨 | 여러 파일에 빠르게 평점 부여 |
| [Jellyfin](https://jellyfin.org/docs/general/server/libraries/) | 한 라이브러리에 복수 경로 연결 | 실제 폴더가 달라도 한 목록에서 탐색 |
| [Plex](https://support.plex.tv/articles/200288926-creating-libraries/) | 여러 원본 폴더를 라이브러리에 연결 | 연결 폴더 설정 흐름 |
| [Kodi](https://kodi.wiki/view/Smart_playlists/Rules_and_groupings) | 배우·태그 등 조건을 조합하는 스마트 재생목록 | 배우 A + 4점 이상 같은 저장된 보기 |
| [tinyMediaManager](https://www.tinymediamanager.org/docs/versions) | 메타데이터 편집, NFO 가져오기·내보내기, 이름 변경 | 데이터 이식성과 파일명 정리 |
| [IINA](https://iina.io/) | 재생 중심 화면, 제스처, 화면 속 화면 | 집중 재생 화면 |
| [mpv](https://mpv.io/manual/stable/) | 이어보기, 자막·트랙 제어, 외부 프로그램 연동 | 독립 재생 엔진 |
| [Everything](https://voidtools.com/support/everything/searching/) | 입력에 따른 결과 갱신, 필터, 검색 북마크 | 호출형 빠른 검색과 조건 저장 |
| [Dolphin](https://docs.kde.org/stable_kf6/en/dolphin/dolphin/dolphin-view.html) | 드래그 이동·복사, 다중 선택, 보기 전환 | 파일 여러 개를 목적지로 이동 |
| [Raycast](https://manual.raycast.com/quickstart) | 단축키 호출, 명령 검색, 상황별 작업 | 검색·이동·태그 편집 명령창 |
| [Apple Photos](https://support.apple.com/guide/photos/create-smart-albums-pht6d60ca71/mac) | 조건에 따라 자동 갱신되는 스마트 앨범 | 반복해서 찾는 조건을 클릭으로 열기 |
| [Hazel](https://www.noodlesoft.com/manual/hazel/attributes-actions/action-reference/) | 조건별 이동·복사와 이름 충돌 처리 | 후속 규칙 기반 정리 |

### 폴더·메타데이터 관련 발견

- 통합 목록과 실제 파일 이동은 서로 다른 기능이며 둘 다 필요하다.
- [Stash 스캔](https://docs.stashapp.cc/in-app-manual/tasks/)은 파일 지문으로 연결 경로 안의 외부 이동·이름 변경을 추적한다. 동일 내용 복사본을 생략하는 정책은 그대로 가져오지 않는다.
- [TagSpaces의 별도 메타데이터 파일](https://docs.tagspaces.org/tagging/)은 앱 밖에서 원본을 이동할 때 함께 관리해야 한다. Soft Vault는 중앙 데이터베이스와 파일 재연결로 이 단절을 줄인다.
- [digiKam 컬렉션](https://docs.digikam.org/en/setup_application/collections_settings.html)은 이동식 저장장치와 네트워크 경로를 별도로 취급한다. 연결 해제를 삭제로 판단하면 안 된다.
- [tinyMediaManager 이름 변경](https://www.tinymediamanager.org/docs/movies/renamer)은 데이터 소스 범위에 제약이 있다. Soft Vault는 연결한 서로 다른 원본 폴더 사이의 이동을 명시적으로 지원한다.
- Windows·Mac 앱 지원과 두 기기 사이 데이터 동기화는 별도 기능이다.

## 4. 기능 범위

### 첫 구현

- 여러 폴더 연결, 하위 폴더 스캔, 전체·폴더별 보기, 변경 감지와 재검색.
- 썸네일·목록 보기, 최근 추가순 기본 정렬, 평점·이름·길이 정렬.
- 파일명·제목·설명·배우·태그 검색과 평점·유형·폴더 필터.
- 1~5점 정수 평점과 미평가 구분. 선택한 여러 파일에 일괄 적용.
- 배우 이름·별칭·대표 이미지·설명과 연결 파일 목록.
- 태그 생성·이름 변경·병합, 다중 태그 지정, 일괄 추가·제거.
- 표시 제목·설명·개인 메모 편집. 첫 버전의 설명은 여러 줄 일반 텍스트.
- 파일 이동·이름 변경, 진행 상황·실패 항목·재시도.
- 내부 영상 재생, 이미지 보기, 외부 앱으로 열기.
- 메타데이터 백업·복원·내보내기.
- 단축키 변경, 보조키, 충돌 안내, 기본값 복원, 프리셋 저장.

### 후속 기능

장면 북마크·메모, 이어보기, 스마트 컬렉션, 짧은 영상 미리보기, 대표 썸네일 선택, 중복 후보 비교, 규칙 기반 이동, NFO 연동을 순차 검토한다.

자동 메타데이터 수집, AI 분류, 기기 간 자동 동기화는 초기 범위에서 제외한다. Falcon 데이터 가져오기는 실제 저장 형식을 확인한 뒤 별도로 결정한다.

## 5. 디자인 방향과 확정 항목

### 확정 조합 — Side Deck + Quiet Folder

- 화면: **D · Side Deck**. 왼쪽은 미리보기·재생·상세 내용, 오른쪽은 분류·연결 폴더·파일 목록을 합친 사이드 영역이다.
- 아이콘: **03 · Quiet Folder**. 사용자가 03번을 명시적으로 확정했다. 기존 생성 원본을 수정 없이 채택한다.
- 확정 아이콘 원본은 [app-icon.png](design/assets/app-icon.png) 하나로 관리한다.
- 기본 진입: [직접 조작하는 확정 시안](design/index.html). URL에 옵션을 붙이지 않아도 Side Deck과 03번 아이콘이 열린다.
- 디자인 정리: [확정 디자인 페이지](design/review.html). 라이브러리·재생·상세·배우·태그·이동·검색·단축키를 같은 기준으로 확인한다.
- 색상: 본문 `#15191E`, 사이드 `#1C2229`, 강조 `#87B8D8`, 주요 글자 `#E3EAF1`. 차콜·슬레이트·아이스 블루 톤을 유지한다.
- 사이드는 기본 약 370px, 1280px 창에서는 약 340px로 표시한다. 폭은 구현 시 창 크기와 가독성에 맞게 조정할 수 있다.
- 재생 중에도 오른쪽 목록을 유지하고, F 전체 화면 배치에서만 사이드를 숨긴다. 상세 편집·검색·필터는 호출식 창으로 연다.
- 첫 실행 화면·사이드바·브라우저 탭·디자인 정리 페이지에 같은 아이콘을 적용한다. 재생·볼륨 등의 기능 아이콘은 기존 의미를 유지한다.

### 화면 구성 기준

- 사용자가 2026-11-02에 재확인: **팔콘처럼 옆에 탐색·목록을 두는 방식은 좋다. 사이드 영역 자체를 제거하라는 뜻이 아니다.**
- 사이드 영역 하나와 콘텐츠 영역 하나를 기본으로 한다. 비교 결과 오른쪽 목록과 왼쪽 콘텐츠의 Side Deck을 채택했다.
- 기본 탐색: 전체 파일, 최근 추가, 미평가, 배우, 태그, 연결 폴더.
- 카드 썸네일은 16:9를 기본으로 하며 제목·평점·폴더를 간결하게 표시.
- 검색은 상단의 작은 버튼으로 호출. 적용한 조건은 해제 가능한 표시로 남긴다.
- 상세 편집은 겹쳐 열리는 화면으로 제공해 상시 3분할을 만들지 않는다.
- 다중 선택 시 하단 작업 막대를 표시해 평점·태그·폴더 이동에 집중한다.
- 재생 중 오른쪽 목록을 유지하고, 전체 화면 모드에서만 접는다.
- 설정·단축키는 전용 화면에 배치한다.

### 시각 기준

한국어 시스템 글꼴, 명확한 선택 상태와 키보드 포커스를 적용한다. Side Deck의 차콜·블루 톤과 목록 중심 배치를 기준으로 한다. 확정 디자인 하나만 유지한다.

### 디자인 확정에 필요한 화면

1. 첫 실행과 폴더 연결.
2. 라이브러리 썸네일·목록 보기.
3. 검색·필터·다중 선택.
4. 파일 상세와 배우·태그 편집.
5. 폴더 이동과 충돌·실패 처리.
6. 재생·전체 화면·음량·최소화 상태.
7. 단축키 설정.

1440×900, 1280×800에서 검토한다. 빈 목록, 검색 결과 없음, 연결 끊김, 긴 파일명, 다중 선택 상태도 포함한다.

디자인 시안은 실제 영상 재생과 파일 작업을 검증하지 않는다. 시안의 재생 진행, 파일 위치 변경, 최소화 화면은 상태 전환을 검토하기 위한 모의 동작으로 명확히 표시한다.

## 6. 기술 비교와 우선안

| 기술 | 적합성 판단 | 검증할 부분 |
|---|---|---|
| **Dart + Flutter** | 자유로운 공통 UI와 내부 재생을 함께 고려한 우선안 | 네이티브 재생 플러그인, 대량 목록, 드래그, 패키징 |
| Rust + TypeScript + Tauri | 파일 처리와 웹 UI를 분리하는 유력 대안 | OS별 WebView 차이, 네이티브 재생 화면 결합 |
| C++ + Qt/QML | 재생·데스크톱 동작을 직접 제어할 때 대안 | 개발 복잡도와 배포 구성 |
| TypeScript + Electron | 웹 UI 중심 대안 | 실행 자원 사용량과 재생 엔진 결합 |
| C# + Avalonia | .NET 중심 대안 | 영상 엔진 결합과 OS별 동작 |

근거: [Flutter 데스크톱](https://docs.flutter.dev/platform-integration/desktop), [Tauri WebView](https://v2.tauri.app/reference/webview-versions/), [Tauri 외부 바이너리](https://v2.tauri.app/develop/sidecar/), [Qt Multimedia](https://doc.qt.io/qt-6/qtmultimedia-index.html), [Electron 구조](https://www.electronjs.org/docs/latest/tutorial/process-model), [Avalonia 지원 플랫폼](https://docs.avaloniaui.net/docs/supported-platforms).

우선 구성은 **Flutter/Dart + SQLite + media_kit/libmpv + FFmpeg·ffprobe**다. [media_kit](https://github.com/media-kit/media-kit#implementation)은 libmpv를 사용하며 Windows·Mac 재생을 제공한다. 디코더를 포함한 실제 배포본의 재생 검증을 통과한 후 기술안을 확정한다.

초기 검증 대상은 Windows 11 x64와 Apple Silicon Mac으로 가정한다. Intel Mac과 추가 OS 버전은 지원 범위를 확장하는 방식으로 검토한다. [Flutter 플랫폼 지원](https://docs.flutter.dev/reference/supported-platforms)의 Intel Mac 지원 변화도 확인한다.

## 7. 데이터·파일 작업 설계

- 원본은 연결한 폴더에 그대로 두며 최초 스캔으로 별도 라이브러리에 복사하지 않는다.
- SQLite 데이터베이스와 썸네일 캐시는 로컬 앱 데이터 경로에 둔다.
- 파일 고유 ID와 현재 경로를 분리한다. 이동·이름 변경 시 ID와 메타데이터는 유지한다.
- 폴더 연결 정보, 미디어 항목, 실제 파일 위치, 배우, 태그, 재생 상태, 파일 작업 기록을 분리한다.
- 배우와 태그는 여러 파일과 연결할 수 있다.
- 실제 복사본은 각각의 위치를 표시하며 지문이 같다는 이유로 자동 삭제·병합하지 않는다.
- 외장 드라이브 분리를 삭제와 구분한다. 연결되지 않은 항목도 메타데이터를 유지한다.
- 외부 이동은 파일 식별 정보와 지문으로 재연결한다. 빠른 지문은 후보 탐색용이며, 모호한 경우 검증하거나 사용자가 선택한다.
- 같은 드라이브 이동은 이름 변경 기반으로 처리한다. 다른 드라이브 이동은 임시 복사·내용 검증·목적지 확정 후 원본 제거 순서를 따른다.
- 이름 충돌 기본 동작은 건너뛰기다. 자동 이름 변경을 선택할 수 있고 조용히 덮어쓰지 않는다.
- 이동 취소는 미완료 작업을 중단한다. 이미 완료한 항목을 실패로 되돌려 표시하지 않는다.
- 파일시스템 작업과 DB 갱신 사이의 장애를 복구하도록 작업 기록을 유지한다.
- 초기에는 외부 공개 API가 없다. 내부 인터페이스는 스캔·검색·메타데이터·파일 작업·재생·단축키 서비스로 나눈다.

## 8. 재생과 코덱 합격 기준

사용자가 별도 코덱팩·플레이어·개발 도구를 설치하지 않아도 재생할 수 있도록 필요한 엔진과 디코더를 앱에 포함한다.

| 구분 | 지원·검증 목표 |
|---|---|
| 파일 형식 | MP4, MKV, AVI, MOV, WebM, WMV, TS |
| 영상 코덱 | H.264, HEVC·10bit, AV1, VP9, MPEG-4, VC-1 |
| 음성 코덱 | AAC, MP3, AC-3, E-AC-3, DTS, FLAC, Opus |
| 자막 | SRT, ASS/SSA, SMI, 내장·외부 자막 |

이는 지원 목표이며 아직 검증된 호환성 목록이 아니다. 실제 설치본에 포함된 디코더와 테스트 파일로 확정한다. 손상 파일이나 DRM 콘텐츠의 보편적 재생을 보장하지 않는다.

- Windows·Mac 실제 설치본에서 영상과 소리를 모두 검증한다.
- 하드웨어 가속 실패 시 소프트웨어 디코딩 전환을 제공한다.
- 코덱 호환성과 4K·고프레임 영상의 재생 성능은 별도로 검증한다.
- 4K HEVC 10bit, HDR 색상 처리, 빠른 탐색, 배속, 자막·음성 트랙 전환, 싱크를 확인한다.
- OS별 가속 방식과 제약은 [mpv 문서](https://mpv.io/manual/stable/)를 기준으로 검토한다.

### 음량·최소화 상태 규칙 — 사용자 확정

1. 새 파일 열기, 이전·다음 파일 전환, 같은 파일 다시 열기는 항상 볼륨 0%로 시작한다.
2. 소리 출력이 시작되기 전에 0%를 적용한다.
3. 일시정지·이어재생·탐색은 현재 음량을 유지한다.
4. M은 설정 음량을 보존하며 음소거만 전환한다. 0%에서 음소거를 해제해도 음량이 올라가지 않는다.
5. 사용자가 직접 음량을 올리는 동작은 음소거를 해제한다.
6. Esc는 모든 앱 재생 인스턴스의 음량을 0%로 만든 뒤 앱을 최소화한다.
7. 최소화·복원은 재생·일시정지 상태를 바꾸지 않는다. 복원 후에도 0%를 유지한다.
8. 썸네일 미리보기는 항상 무음이다.

## 9. 단축키 벤치마킹과 확정 기본안

| 출처 | 참고 내용 |
|---|---|
| [mpv 키보드 조작](https://mpv.io/manual/stable/#keyboard-control) | 정밀 탐색, 배속 초기화, 직전 탐색 되돌리기 |
| [VLC](https://docs.videolan.me/vlc-user/desktop/3.0/en/basic/hotkeys.html) | Space 재생·일시정지, M 음소거, F 전체 화면 |
| [IINA](https://github.com/iina/iina/wiki/Manage-Key-Bindings) | 프리셋 복제·전환, 한 기능에 여러 키 지정 |
| [Eagle 작업 묶음](https://eagle.cool/blog/post/eagle-3.0) | 태그·평점·분류를 하나의 단축 작업으로 묶기 |
| [Eagle 빠른 조작](https://eagle.cool/blog/post/11-productive-tips-to-make-the-best-use-of-eagle) | T 태그 편집, Space 미리보기 |
| [Bridge 설정](https://helpx.adobe.com/bridge/desktop/get-started/keyboard-shortcuts-panel.html) | 기능 검색, 충돌 표시, 앱·패널 범위 구분 |
| [Dolphin](https://docs.kde.org/stable_kf6/en/dolphin/dolphin/command-reference.html) | 다중 선택, 파일 작업, 실행 취소 |

기본 배치는 사용자가 선택한 **표준키 + 왼손 보조키**다.

| 기능 | 기본키 | 보조키 |
|---|---|---|
| **볼륨 0% → 최소화** | **Esc** | — |
| 즉시 볼륨 0% | 0 | — |
| 음소거 전환 | M | — |
| 재생·일시정지 | Space | — |
| 5초 뒤로·앞으로 | ← / → | A / D |
| 1초 정밀 이동 | Shift+← / Shift+→ | Shift+A / Shift+D |
| 음량 5% 올리기·내리기 | ↑ / ↓ | W / S |
| 이전·다음 파일 | PageUp / PageDown | Q / E |
| 전체 화면 전환·해제 | F | — |
| 배속 낮추기·높이기 | [ / ] | — |
| 배속 1배로 초기화 | Backspace | — |
| 직전 탐색 위치 복귀 | Shift+Backspace | — |
| 평점 1~5점 지정 | 1~5 | — |
| 평점 초기화 | Shift+0 | — |
| 태그 편집 | T | — |
| 배우 편집 | P | — |
| 설명·상세 정보 | I | — |
| 이동 목적지 선택 | Ctrl/Cmd+Shift+M | — |
| 검색·명령창 | Ctrl/Cmd+K | — |
| 단축키 안내 | ? | — |

### 적용 규칙

- Esc와 0은 예약한다. 다른 키는 기본키·보조키를 편집할 수 있다.
- 입력창과 글자 조합 중에는 일반 재생·분류 단축키를 실행하지 않는다.
- Esc는 앱이 키 이벤트를 받는 내부 화면에서 최우선 처리하며, 편집 내용을 버리지 않는다. OS가 처리하는 네이티브 대화상자와 운영체제 전역 키 가로채기는 별도 범위다.
- 일반 명령은 현재 화면과 선택 대상에만 적용한다. 숨겨진 플레이어에 음량 키를 전달하지 않는다.
- 길게 누르기는 탐색·음량 조절에 적용한다. 파일 전환·음소거·평점 변경 등은 한 번씩 처리한다.
- 한글 입력 모드, 키보드 배열, 숫자열·숫자패드, Windows Ctrl·Mac Cmd 차이를 검증한다.
- 프리셋을 바꾸어도 예약한 Esc·0의 의미는 유지한다.
- mpv의 기본 0은 음량 올리기이고 Eagle의 F는 분류창 열기다. 엔진 기본키와 앱 키를 동시에 실행하지 않는다.

## 10. 구현 순서와 검증

디자인 확정 이후 다음 순서로 구현한다.

1. Windows·Mac 네이티브 재생, 0% 시작, Esc 최소화, 배포 패키징 검증.
2. 폴더 연결, DB, 검색, 스캔과 변경 감지.
3. 확정된 라이브러리 화면, 배우·태그·설명과 일괄 편집.
4. 파일 이동·충돌·작업 기록·복구.
5. 단축키 설정, 접근성, 설치본 검증.
6. 후속 기능을 우선순위에 따라 추가.

### 필수 시나리오

- 첫 재생·연속 재생·파일 전환 때 순간적인 소리 출력이 없는지.
- 일반 화면·전체 화면·편집 중 Esc와 복원 후 0% 유지.
- 텍스트 입력, 키 반복, 사용자 지정 키, 보조키와 충돌 처리.
- 코덱별 정상 재생, 4K HEVC 10bit, HDR, 자막·음성 전환과 싱크.
- 이동·이름 변경 이후 ID·평점·배우·태그·설명 유지.
- 같은 이름, 용량 부족, 권한 부족, 이동 취소, 드라이브 분리, 강제 종료 후 복구.
- 외부 이동 재연결, 외장 드라이브 재연결, 동일 내용 복사본 구분.
- 한글·일본어·이모지·긴 경로와 대량 파일 탐색.
- 별도 코덱팩과 개발 도구가 없는 환경에서 설치본 실행.

### 디자인 검수와 앱 검증의 구분

디자인 단계에서는 화면 크기, 가독성, 탐색·선택·편집·이동 화면의 흐름, 키보드 조작의 모의 상태 전환을 검사한다. 코덱, 네이티브 최소화, 파일 무결성, OS 접근 권한은 앱 구현 단계에서 검증한다.

## 11. 디자인 자료와 확인 기록

### 확정 디자인 자료

- **[확정 디자인 정리 페이지](design/review.html)** — 화면별 탭, 확정 아이콘, 색상·배치·재생 정책을 한곳에서 확인한다.
- **[직접 조작하는 확정 시안](design/index.html)** — 기본값은 Side Deck + Quiet Folder다.
- [디자인 정리 이미지](design/previews/selected/00-design-overview.png) · [확정 아이콘](design/assets/app-icon.png).

| 화면 | 직접 조작 | 최신 캡처 |
|---|---|---|
| 라이브러리 | [열기](design/index.html) | [1440px](design/previews/selected/01-library.png) · [1280px](design/previews/selected/01-library-1280.png) |
| 재생 | [열기](design/index.html?screen=player) | [1440px](design/previews/selected/02-player.png) · [1280px](design/previews/selected/02-player-1280.png) |
| 상세 편집 | [열기](design/index.html?screen=detail) | [캡처](design/previews/selected/03-detail.png) |
| 배우 | [열기](design/index.html?screen=actors) | [캡처](design/previews/selected/04-actors.png) |
| 태그 | [열기](design/index.html?screen=tags) | [캡처](design/previews/selected/05-tags.png) |
| 폴더 연결 | [열기](design/index.html?screen=folders) | [캡처](design/previews/selected/06-folders.png) |
| 폴더 이동 | [열기](design/index.html?screen=move) | [캡처](design/previews/selected/07-move.png) |
| 검색 | [열기](design/index.html?screen=search) | [캡처](design/previews/selected/08-search.png) |
| 단축키 | [열기](design/index.html?screen=shortcuts) | [캡처](design/previews/selected/09-shortcuts.png) |
| 첫 실행 | [열기](design/index.html?screen=intro) | [캡처](design/previews/selected/10-intro.png) |
| 최소화 상태 | [열기](design/index.html?screen=minimized) | [캡처](design/previews/selected/11-minimized.png) |

### 시안에서 확인할 흐름

1. 썸네일을 눌러 재생 화면으로 들어간다. W/S로 음량, A/D로 재생 위치, Q/E로 파일 전환을 확인한다.
2. Esc로 최소화 상태 미리보기를 열고 복원한다. 볼륨 표시가 0%로 유지되는지 확인한다.
3. 오른쪽 목록 제목으로 왼쪽 미리보기를 고른다. 정보·편집 버튼에서 배우·태그·설명을 편집한다. 편집 중 Esc를 눌렀다가 복원해도 작성 내용이 유지된다.
4. 오른쪽 파일 행의 선택 버튼으로 파일 여러 개를 선택한다. 하단 작업 막대에서 평점·태그·이동을 확인한다.
5. 이동 창의 ‘다른 이동 상황 미리보기’에서 이름 충돌·일부 실패 사례를 선택한다. 실패 항목만 다시 시도할 수 있다.
6. Ctrl/Cmd+K로 검색한다. 작은 검색 버튼을 제외한 상시 검색 입력창은 없다.
7. 설정의 단축키를 눌러 새 키를 지정한다. 같은 키가 이미 쓰이고 있으면 적용하지 않고 충돌을 알린다.
8. 연결 폴더 관리의 상태 표시를 눌러 오프라인을 시험한다. 파일 정보는 남고, 해당 폴더의 재생 화면 진입은 막는다.
9. 확정 디자인 페이지 아래 ‘첫 실행’ 링크에서 폴더를 연결하는 시작 화면을 볼 수 있다.

### 검증 기록 — 2026-11-02

- 프로젝트의 디자인은 **Side Deck + Quiet Folder 하나**다. 대표 아이콘·기본 진입·화면별 링크 모두 같은 디자인을 사용한다.
- 주요 화면 11개의 직접 진입 링크와 최신 캡처, 정리 페이지의 8개 탭·조작 링크를 확인했다.
- 1440×900·1280×800에서 본문·사이드 목록·재생 조작부를 검수했다.
- 정리 후 새 영상 0%, Esc 0%·복원, 편집 내용 보존, 평점 키, 검색, 폴더 이동 시 정보 유지, 전체 화면과 사이드 복원을 확인했다. 런타임 예외는 없었다.
- 이전 후보 파일 61개(약 31.87MiB), 비교 페이지와 전환 코드를 제거했다. 프로젝트의 앱 아이콘 PNG는 1개이며, 남은 문서·화면의 로컬 링크가 모두 연결된다.
- 모든 검증은 로컬 디자인 시안에 대한 검사다. 실제 코덱 재생, 음성 출력, 파일 무결성, OS 최소화, Mac 실행은 아직 검증하지 않았다.
- 실제 앱 구현은 아직 시작하지 않았다.

### 예시 이미지 출처

[Unsplash 사용 조건](https://unsplash.com/license)에 따라 디자인 검토용 풍경 사진을 로컬 썸네일로 사용했다. 실제 사용자 미디어는 포함하지 않았다.

| 로컬 파일 | 이미지 원본 |
|---|---|
| `design/assets/alpine.jpg` | [photo-1469474968028-56623f02e42e](https://images.unsplash.com/photo-1469474968028-56623f02e42e) |
| `design/assets/lake.jpg` | [photo-1470770841072-f978cf4d019e](https://images.unsplash.com/photo-1470770841072-f978cf4d019e) |
| `design/assets/forest.jpg` | [photo-1448375240586-882707db888b](https://images.unsplash.com/photo-1448375240586-882707db888b) |
| `design/assets/coast.jpg` | [photo-1518837695005-2083093ee35b](https://images.unsplash.com/photo-1518837695005-2083093ee35b) |
| `design/assets/desert.jpg` | [photo-1509316785289-025f5b846b35](https://images.unsplash.com/photo-1509316785289-025f5b846b35) |
| `design/assets/night.jpg` | [photo-1519608487953-e999c86e7455](https://images.unsplash.com/photo-1519608487953-e999c86e7455) |
| `design/assets/road.jpg` | [photo-1500534623283-312aade485b7](https://images.unsplash.com/photo-1500534623283-312aade485b7) |
| `design/assets/ridge.jpg` | [photo-1519681393784-d120267933ba](https://images.unsplash.com/photo-1519681393784-d120267933ba) |

## 12. 확정 앱 아이콘 — Quiet Folder

- 사용자 확정: **03 · Quiet Folder**. Side Deck의 폴더·영상 재생 기능을 상징하는 아이콘이다.
- 유일한 프로젝트 아이콘 원본: [app-icon.png](design/assets/app-icon.png). **1254×1254 PNG**, 바깥 모서리 알파 0. 선택한 생성 원본과 동일한 파일이다.
- 사이드바·첫 실행 화면·브라우저 탭·디자인 정리 페이지가 이 파일을 사용한다. ICO·ICNS는 실제 앱 패키징 단계에서 제작한다.
- 다른 디자인·아이콘 후보, 비교 페이지, 이전 캡처, 후보 전환 코드는 프로젝트에서 제거했다. 기존 후보용 URL 옵션도 디자인이나 아이콘을 바꾸지 않는다.
- 앱 이름은 Soft Vault 가칭을 유지한다. Side Deck은 확정된 화면 디자인의 이름이다.
- 생성 방식: 내장 image_gen. 아래는 선택한 아이콘에 사용한 공통 프롬프트와 개별 프롬프트다.

```text
Use case: logo-brand.
Asset type: one original Windows and macOS desktop application launcher icon concept for Soft Vault, a personal local video/image library with a large viewing area and one right-side file-list panel. Its chosen UI direction is called Side Deck.
Primary request: create ONE finished square app icon, not a contact sheet. This is a distinct concept in a 10-icon exploration.
Composition: one centered navy rounded-square/squircle tile occupying about 88% of the square canvas; the foreground symbol sits optically centered within the tile with generous padding, large enough to remain legible at 32px. Straight-on composition, beautifully crisp edges, balanced visual weight. Outside the rounded tile must be truly transparent.
Palette: deep slate navy tile (#17222d to #233545), glacial blue/cyan highlights and restrained complementary colors as specified.
Lighting: subtle soft studio light from upper left if dimensional, no external cast shadow beyond the tile.
Constraints: original symbol, polished desktop application identity, not a generic document icon. No words, numbers, captions, UI mockup, device, hands, watermark, border surrounding the entire canvas, lock, padlock, shield, archive box, or bird. Do not depict a three-pane application. Do not add extra mini icons.
Concept: 03 / Quiet Folder.
Subject: One sculpted soft-blue file folder with a folded tab at upper left and a large triangular play cutout in its front face. A small darker file leaf peeks from the right. The folder itself is the dominant shape.
Style/medium: Soft-touch ceramic and matte rubber material, rounded precise edges, restrained three-dimensional Apple desktop-app craft.
```
