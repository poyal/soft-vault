# Soft Vault — 통합 기획·디자인·구현 계획

마지막 정리: 2026-11-08

## 1. 현재 단계와 작업 순서

**기획·벤치마킹 → 디자인 검토·확정 → 앱 구현 → Windows·Mac 검증** 순서로 진행한다.

- 현재 단계: **D · Side Deck + 03 · Quiet Folder의 Windows 구현 및 추가 기능 8종 구현 완료**. 아래 구현 현황이 현재 상태이며, 2026-11-02 기록은 과거 HTML 시안 검토 기록이다. 별도 실기 검증 한계와 Mac 후속 범위는 아래에 명시한다.
- 현재 요청 범위는 실제 Flutter 앱 구현과 디자인 대조, 설치본 E2E 검증까지다. 2026-11-08 사용자 지시에 따라 Windows 구현·검증을 먼저 진행하고 Mac 검증은 후속으로 미룬다.
- 다음 구현 단계는 이 확정 조합을 기준으로 진행한다. 이미 선택한 디자인 방향·아이콘을 다시 선택할 필요는 없다.
- 요구사항과 사용자 결정은 이 `plan.md`에 관리한다. 개발·릴리즈·E2E·디자인·성능·원격 검증의 공통 절차와 결과 기록은 [docs 문서 안내](docs/README.md)에서 연결한다.
- `design/index.html`은 예시 데이터만 사용하는 로컬 디자인 시안이다. 앱 구현물이 아니며, 실제 파일 이동·코덱 재생·운영체제 최소화를 실행하지 않는다.
- 시안에서 사용하는 인물·파일·폴더 정보는 설명을 위한 예시다. 시안 편집 내용은 새로고침하면 초기화된다.

### 최신 사용자 지정 — 영상 전용 UI

- 사이드바 하단 바 전체를 제거하고 `soft vault.` 오른쪽에 설정 버튼 하나를 배치한다. 통합 설정은 라이브러리·재생·단축키·사생활 보호·백업으로 구성하며 폴더 관리와 기존 파일·정리 메뉴 기능을 보존한다. 선택 영상이 없으면 영상 관련 작업은 비활성화한다.
- 앱은 **영상 전용**이다. 이미지 파일 수집·검색·독립 뷰어를 제거한다. 대표 썸네일과 배우 프로필 사진은 유지한다. 이전 이미지 카탈로그 기록은 백업에 보존하고 영상 목록·개수에서는 제외하며, 원본 파일은 삭제하지 않는다.
- 재생 화면 상단의 제목·경로·뒤로가기·음소거·최소화 표시줄과 그 표시줄용 여백을 제거한다. 영상 비율에 따른 여백은 영상 영역 안에서만 허용한다.
- 영상 화면을 클릭하면 재생·일시정지를 전환한다. 음량·재생 위치·전체화면 상태는 유지한다. 하단 조작부와 기존 단축키도 계속 사용할 수 있다.
- **상세정보 보기**는 읽기 화면으로 열린다. 대화상자 안의 **정보 편집**을 눌러 제목·배우·태그·평점·메모를 수정한다.
- 배우·태그 화면에는 등록된 항목이 없어도 **전체** 항목이 존재한다. 선택하면 검색·폴더·평점·스마트 컬렉션 조건을 해제하고 미분류 영상을 포함한 전체 영상을 표시한다.
- 오른쪽 영상 목록과 그리드 항목에 배우와 `#태그`를 각각 한 줄로 표시한다. 긴 값은 말줄임표와 전체 내용 툴팁을 사용한다. 빈 값은 ‘배우 미등록’·‘태그 없음’으로 표시하고, 항목 선택·더블클릭 재생 동작은 유지한다.
- 아래의 과거 HTML 시안·픽셀 비교 기록보다 이 사용자 지정이 우선한다. 갱신된 Windows 캡처는 `build/e2e/review.html`에서 확인한다.

### 추가 요청 · 앱 시작 비밀번호 — 2026-11-08

- 첫 실행에서 8~128자 비밀번호를 설정하거나 나중에 설정한다. 활성화 뒤에는 앱 시작 시 인증 전 라이브러리 로드·영상 플레이어·목록·앱 단축키를 생성하지 않는다. 잠금 화면은 기존 색상·글꼴·앱 아이콘을 사용한다.
- 설정 → 사생활 보호에서 현재 비밀번호로 변경·해제한다. 지금 잠그기는 화면을 가리고 재생 중지·음량 0% 후 잠금 화면으로 돌아간다.
- `privacy_lock.dart`는 카탈로그와 분리한 `privacy.sqlite`에 무작위 salt·PBKDF2-HMAC-SHA256 600,000회 검증값만 저장한다. Windows는 `privacy_crypto_windows.dart`의 CNG 호출을 작업 isolate에서 실행한다. 원문 저장·복구 우회는 없다.
- 오입력 5회부터 30초~최대 5분 재시도 제한을 영속화하고 동시 인증을 직렬화한다. 손상된 잠금 정보는 앱을 열지 않는다. 카탈로그 백업·복원으로 잠금이 풀리거나 검증값이 유출되지 않는다.
- 앱 접근 보호 범위다. 원본 영상·카탈로그 암호화나 같은 OS 계정의 파일 변조 방어는 포함하지 않는다.
- 신규 서비스 검사 9개와 Windows UI 검사 3개. 첫 설정·잘못된 확인값·재시작·잘못된 비밀번호·잠금 중 단축키·재생 중 수동 잠금·변경·해제·대기·손상 상태를 확인한다. OS 키보드·IME 대신 보안 입력 컨트롤러에 테스트 값을 주입한다. 캡처와 결과는 `build/e2e/privacy-*.png`, `privacy-results.json`에 남긴다.

### 구현 현황 — 2026-11-08

Flutter 3.47.9 / Dart 3.13.7, SQLite, media_kit/libmpv, 번들 FFmpeg·ffprobe로 첫 구현 범위를 작성했다. 의존성은 `pubspec.lock`으로 고정한다.

| 범위 | 구현 위치와 동작 |
|---|---|
| 폴더·탐색 | `library.dart`, `home_features.dart`: 재귀 스캔, 변경 감지·주기 재검사, 오프라인 유지, 폴더 연결 해제·재연결, 검색·유형·평점 필터·정렬 |
| 미리보기·분류 | `media_tools.dart`, `file_list.dart`, `detail_dialog.dart`: 실제 썸네일, 목록·그리드, 제목·설명·메모·평점, 여러 파일 태그·평점 편집 |
| 배우·태그 | `catalog_panels.dart`: 배우 이름·별칭·이미지·설명, 연결 파일, 태그 생성·이름 변경·병합 |
| 파일 작업 | `file_jobs.dart`: 원본 ID 유지 이동·이름 변경, 충돌 건너뛰기·자동 이름, 복사 SHA-256 검증, 취소·기록·재시도·중단 복구·수동 재연결 |
| 백업 | SQLite 메타데이터 전체 JSON 내보내기·복원, 복원 전 자동 백업, 잘못된 백업 거부·트랜잭션 롤백 |
| 재생 | 실제 영상 열기, 화면 클릭 재생·일시정지, 트랙·자막·배속·탐색·음성/자막 싱크, 소프트웨어 디코더 전환, 외부 앱 열기 |
| 안전한 음량 | 열기 전·후 0%, 음소거와 설정 음량 분리, Esc 0% 적용 후 네이티브 최소화, 복원 상태 유지 |
| 사생활 보호 | `privacy_lock.dart`, `privacy_ui.dart`: 앱 시작 인증, 설정·변경·해제, 재생 중 지금 잠그기, 영속 오입력 제한, 카탈로그와 분리한 검증값 |
| 단축키 | 확정 기본키·보조키, 편집·충돌·예약키 보호·프리셋·초기화, 입력창에서 일반 명령 억제 |
| 배포 | Quiet Folder Windows ICO·Mac 아이콘, FFmpeg·libmpv·C++ 런타임 포함 Windows ZIP, 사용자 폴더 설치 스크립트 |

검증 중 발견한 전체화면 Esc 무시(window_manager 기본 정책), 지연 생성된 영상 컨트롤러로 인한 검은 화면, Esc의 편집창 닫기, 설정 재개 시 디코더 표시 초기화, 비동기 일괄 편집 대기 문제를 수정했다.

E2E 실행 창 전체가 검게 보이던 문제도 별도로 재현했다. 테스트가 실제 Windows 클라이언트 영역(1424×861)과 다른 가짜 물리 크기(1440×900)를 엔진에 전달하고 있었다. `tester.view.physicalSize`·DPI 덮어쓰기를 제거하고, 디자인 크기는 논리 뷰포트로만 설정한다. `integration_test/support/native_surface.dart`가 제출 프레임과 실제 창 크기·DPI의 일치를 검사한다. 수정 전 실패는 `build/verification/native-surface-before.log`에 보존했으며, 수정 후 사용자가 실제 E2E 창에 화면이 보이는 것을 확인했다. 오프스크린 캡처 정상 여부와 실제 창 표시를 구분해서 검증한다.

디버그 재생 라이브러리가 PID로 저장한 네이티브 포인터를 Windows의 PID 재사용 시 다시 읽어 충돌하는 문제도 확인했다. `scripts/flutter-check.ps1`로 E2E마다 별도의 임시 폴더를 사용한다. 릴리스에는 해당 디버그 캐시가 사용되지 않는다.

성능 확인은 최적화 프로파일 모드의 실시간 프레임 정책으로 보완했다. 추가 검사 4개(기존 스트레스 3개 재실행, 일반 4영상 UI 1개)가 통과했다. i7-8700B·RAM 63.8GiB·UHD 630·1080p/59Hz 환경의 일반 UI 30초 측정에서 앱 CPU 평균 4.2%, 측정 최대 6.67%, GPU 엔진 측정 최대 73%, 전용 작업 메모리 최대 464.1MiB였다. CPU·RAM 포화는 없었지만 화면 전환·검색·상세창 raster P95 23.252·22.945·27.054ms로 일부 프레임 지연이 남는다. 영상 재생 raster P95는 10.101ms다. 사용률은 2초 간격의 표본이며, FPS나 모든 작업의 최대 부하를 보장하지 않는다. 자세한 측정·재현 스크립트와 원자료는 README 및 통합 검증 보고서에 기록한다.

### 검증 근거와 한계 — 2026-11-08

- 정적 분석 오류 0, **누적 99개 테스트 통과**: 일반 단위·회귀 56개, 서비스 스트레스 9개, 대량 성능 2개, Windows E2E 32개(10개 파일). 기존 36개에 독립 케이스 63개를 추가했다. 최종 릴리스 빌드와 새 ZIP 설치 사본 진단도 통과했다. ZIP 내부 43개 파일 해시를 확인했고 개발 도구를 제외한 PATH에서 11개 코덱·DB·썸네일·검증 이동·최소화/복원을 확인했다. 개발 경로를 담은 보조 매니페스트를 배포에서 제외하고, 개발용 SQLite DLL을 잠시 격리한 상태에서도 설치본이 통과했다. 검증 후 DLL은 복원했다.
- 결과물: [Windows ZIP](build/package/SoftVault-Windows.zip), [실제 화면 비교](build/e2e/review.html), [설치본 검증 JSON](build/e2e/installed-results.json). 실행 파일은 패키지의 `app/soft_vault.exe`이며 앱 폴더 전체를 유지해야 한다.
- `scripts/verify-windows.ps1`: 정적 분석, 일반 회귀, Windows 통합 테스트 10개 파일을 개별 프로세스로 순차 실행, 서비스 스트레스·대량 성능, 릴리스 빌드와 결과 집계. 결과는 `build/verification/*.log`, `test-report.html`, `test-report.json`에 남는다.
- `library_flow_test.dart`: 영상 선택·상세정보·편집·평점·저장, 편집 중 Esc 최소화·복원 시 입력 유지.
- `catalog_flow_test.dart`: 실제 배우 생성·태그 일괄 편집·다중 파일 이동·검색·설정 충돌 및 주요 화면 1440×900/1280×800 캡처.
- `playback_flow_test.dart`: 네이티브 MP4의 최초·재열기 0%, 탐색 음량 유지, 재생 중 최소화·복원.
- `privacy_flow_test.dart`: 인증 전 라이브러리 미생성, 첫 설정·오입력·재시작·단축키 차단, 재생 중 무음 잠금, 변경·해제, 오입력 대기 유지, 손상 정보 접근 차단. 서비스 9개 검사는 `privacy_lock_test.dart`에 별도로 둔다.
- `app_playback_test.dart`: 앱의 첫 영상 프레임 렌더링, 키 입력·배속·평점·음량·음소거·전체화면·편집 중 Esc, 디코더 설정 유지, 빈 목록·오프라인.
- `codec_matrix_test.dart`: 11개 영상 파일의 실제 디코딩, 4K HEVC 10bit·BT.2020/PQ, 7개 음성 코덱 트랙, 내장 자막·외부 SRT/ASS/SMI, 소프트웨어 디코더. 세부 결과는 `build/e2e/codec-results.json`.
- `extended_flow_test.dart`: 실제 영상의 이어보기·0% 시작, 장면 생성·메모·시간 이동, 장면 썸네일 선택과 재스캔 보존, 마우스 무음 미리보기, 컬렉션 생성·열기, 중복 비교·내용 재검증, 화면에서 이동 규칙 생성·검토·실행, NFO 왕복, 이동 뒤 기록 보존.
- `design_parity_test.dart`: 시안과 같은 12개 콘텐츠로 1440×900·1280×800 주요 화면 캡처. 미리보기 영역의 위치·크기와 340/370px 사이드바를 수치 검증. 1000×700·1920×1080에서도 앱이 창 전체를 채우며 레이아웃 오류가 없는지 확인.
- `advanced_features_test.dart`: SQLite v2→v3 이전, v2 백업 복원, 이어보기·북마크 이동/재열기/복원 보존, 조건 AND·배우 별칭, 규칙 순환·충돌·재실행 억제, 동일/유사 비교, NFO 한글·XML·줄바꿈·백업·중복 가져오기 검증.
- `scripts/verify-install-windows.ps1`: 배포 ZIP 해시 확인 → 별도 폴더 설치 → PATH에서 개발 도구 제거 → 설치 실행 파일의 DB·썸네일·검증 복사 이동·재생·최소화·11개 코덱 검사. 결과는 `build/e2e/installed-results.json`.
- 화면은 `build/e2e/`에 저장한다. 실제 Flutter 렌더링 캡처이며 HTML 시안 캡처와 구분한다. Side Deck의 구조·색상·폭·상세 2열·카드·설정표를 대조한다. 네이티브 글꼴·컨트롤과 실제 데이터 차이가 있어 픽셀 단위 동일성을 주장하지 않는다.
- 원본 SVG 33종과 폰트·치수를 적용한 뒤 같은 콘텐츠의 라이브러리 화면을 픽셀 비교했다. 전체 RGB 채널 평균 절대차는 1280px에서 4.550/255, 1440px에서 4.362/255다. 실제 픽셀 일치율은 각각 66.96%, 63.88%이며, 배경 비중·브라우저/Flutter의 글자·이미지 렌더링 및 실제 기능 차이를 포함한 측정치다. **100% 동일 완료라고 표시하지 않는다.** 세부 수치는 `build/e2e/design-pixel-results.json`, 비교 스크립트는 `scripts/compare-design.ps1`.
- 단위 테스트의 장애는 취소·실패 주입·저널 복구로 재현한다. 실제 디스크 가득 참·장치 강제 분리·두 번째 물리 드라이브 환경 전체를 대신하지 않는다.
- 이 PC에서 설치 사본과 제한 PATH를 검증하는 것이며, 개발 도구가 한 번도 설치되지 않은 별도 Windows VM 검증은 아니다. OS 파일 선택창 직접 조작, 물리 스피커 출력 측정, HDR 모니터 색 정확도·지속 4K 성능, 실제 OS 한글 IME 조합은 별도 실기 검증이 남는다. 대량 목록·검색·스캔과 짧은 반복 스트레스의 측정 범위는 아래 확장 기록을 따른다.
- Mac 빌드·실행·설치 검증은 사용자의 “윈도우 먼저” 지시에 따라 후속으로 남긴다. macOS 소스 프로젝트가 존재하는 것과 검증된 Mac 배포본은 구분한다.

### 후속 Windows UI 지연 원인 분리

- 기존 CPU/GPU 측정과 23–27ms UI 수치는 렌더링 수정 전 기록이다. 프로파일의 실시간 프레임 정책으로 원인을 분리했다.
- 현재 PC의 Impeller GLES 그래픽 명령 처리에 시간이 집중됐다. 동일 탐색에서 기존 raster P95 29.792ms, 아이콘 추가 합성 제거만 18.335ms, Skia 전환만 8.798ms, 두 수정 적용 4.989ms였다. 최종 탐색의 raster 기준 초과는 0회다.
- Windows 실행기에 Skia 선택을 명시했다. SVG 아이콘의 런타임 색상 필터는 stroke 직접 지정으로 대체했다. UI 배치·색·팝업 흐림은 유지한다.
- E2E의 창 가장자리 검은 띠는 가상 논리 크기와 실제 내부 창 비율 불일치가 원인이었다. `setSurfaceSize` 고정을 모두 제거하고 실제 내부 크기로 창을 조정한다. 네이티브 프레임 검사는 논리 크기 일치와 변환 행렬의 추가 축소·이동 부재까지 검증한다. 영상 종횡비에 따른 영상 내부 여백은 그대로 둔다.
- 팝업 흐림 제거와 repaint 범위 분리만으로는 지연이 해결되지 않아 해당 실험은 원복했다. 현재 4영상 라이브러리의 DB 조회·파일 선택 처리도 주원인으로 확인되지 않았다.
- 배우·태그 항목별 순차 조회 및 30초 주기 전체 스캔은 대규모 라이브러리의 별도 개선 후보이며, 현재 증상의 원인이라고 단정하지 않는다.
- `scripts/diagnose-ui-windows.ps1`과 `-Trace`, `tool/summarize-timeline.cjs`로 재측정한다. 실험별 원자료는 `build/e2e/bottleneck-*.json`, 결론 보고서는 `build/verification/bottleneck-report.html`이다. 반복 진단을 독립 회귀 테스트 수로 부풀리지 않는다.

### 시나리오·부하 검사 확장 — 2026-11-08

기존 7개 통합 테스트 파일에 여러 흐름을 넣는 방식에서, 실패 위치가 드러나는 독립 시나리오를 추가했다. 테스트 파일 수와 실행된 케이스 수를 구분한다. 전체 실행은 `scripts/verify-windows.ps1`, 부하 검사만 실행할 때는 `scripts/verify-stress-windows.ps1`, 결과 집계는 `scripts/build-test-report.ps1`을 사용한다.

수정 전 서비스 회귀 검사에서 10개, Windows UI 검사에서 2개 실패 시나리오를 재현했다. 수정 전 로그는 `build/verification/scenario-before.log`, `ui-scenarios-before.log`에 남겼다.

- `%`·`_` 검색이 SQL 와일드카드로 해석되어 엉뚱한 파일을 찾던 문제를 고쳤다.
- 동시 태그 편집의 변경 유실과 중간 실패 시 부분 저장을 트랜잭션으로 해결했다.
- 중첩 폴더는 가장 안쪽 연결 폴더에 귀속한다. 시간만 바뀐 동일 파일은 대표 썸네일·재생 기록을 보존하고, 내용이 교체된 파일은 이전 영상의 장면·이어보기·기술 정보를 초기화한다.
- 이동 작업의 실행 잠금을 첫 비동기 호출 전에 잡고 파일 작업과 스캔을 직렬화한다.
- 백업은 한 트랜잭션의 일관된 스냅샷으로 읽고, 복원 시 존재하지 않는 미디어·배우·태그 참조를 거부한다.
- 배우·태그 탐색 시 이전 스마트 컬렉션 조건을 해제한다. 필터로 목록에서 사라진 현재 파일도 별도로 갱신하여 오프라인 전환 시 재생을 중단한다.

| 검사 묶음 | 케이스 수 | 확인 내용 |
|---|---:|---|
| 일반 단위·회귀 | 56 | 기존 29개 + 검색·동시 편집·스캔·이동·백업·영상 전용 회귀 18개 + 사생활 보호 9개 |
| Windows 기존 통합 | 7 | 디자인·코덱·파일·분류·재생·확장 기능 |
| Windows 사생활 보호 | 3 | 첫 설정·재시작·인증·재생 중 잠금·변경/해제, 오입력 제한 유지, 손상 상태 접근 차단 |
| Windows 독립 기능 시나리오 | 19 | 컬렉션 전환, 오프라인, 손상 영상, NFO 취소·확인·덮어쓰기, 백업, 장면, 중복, 폴더 선택, 통합 설정 탐색·창 크기 변경·프리셋 저장·빈 라이브러리 |
| 서비스 스트레스·장애 복구 | 9 | 동시 편집 200회, 이동 96회, 64MiB 검증 복사, 복사 중 취소·디스크 부족 주입, 별도 프로세스 종료 2지점, 변경 중 스캔, 백업 경합 |
| 대량 서비스 성능 | 2 | 실제 작은 파일 1만 개, 합성 DB 항목 5만 개 |
| Windows UI 스트레스·성능 | 3 | 영상 전환 40회, 전체화면·최소화·복원 12회, 1만 행 스크롤 80회·검색 10회·4개 창 크기 |

SQLite 행별 자동 저장을 200개 단위 스캔 배치와 일괄 편집 트랜잭션으로 바꾸고, 변경 없는 파일은 재저장하지 않는다. 검색창의 즉시 결과는 DB에서 3개만 가져온다.

| 같은 PC의 측정 | 개선 전 | 개선 후 |
|---|---:|---:|
| 1,000파일 최초 스캔 | 70,466ms | 3,367ms |
| 1,000파일 재스캔 | 749ms | 217ms |
| 1,000항목 일괄 편집 | 69,808ms | 1,806ms |

1만 파일: 최초 스캔 11,997ms, 재스캔 1,641ms, 검색 P95 9.583ms. 5만 DB 항목: 검색 P95 47.653ms, 컬렉션 332ms, 중복 그룹 327ms. Windows 디버그 UI의 1만 행 진입은 1,898ms, 검색 P95 186ms였고, 스크롤 중 생성된 썸네일 위젯은 최대 8개였다. 상세 샘플·RSS·시간 기준과 시나리오별 결과는 `build/verification/test-report.html` 및 JSON에 기록한다.

성능 검사는 상한을 넘으면 실패한다. 1만 파일 최초 스캔 60초·재스캔 15초, DB 검색 P95 500ms, 일괄 편집 10초, UI 진입 15초·검색 2초를 기준으로 두었다. 측정은 이 PC의 실행 결과이며, 파일 스캔 픽스처는 작은 고유 내용의 파일이다. 대용량 영상 1만 개 디코딩 성능으로 해석하지 않는다. UI 프레임 수치는 디버그 모드이고 릴리스 FPS를 보증하지 않는다. 반복 검사에서 측정한 RSS 증가도 장시간 누수 부재를 증명하지 않는다.

파일 선택창은 반환 경로만 대체하고 나머지 UI·DB·파일·디코더는 실제로 실행한다. 디스크 부족은 복사 첫 청크 이후 오류 주입이며, 강제 종료는 실제 별도 프로세스가 저널의 복사 완료·발행 완료 지점에서 종료하도록 실행한다. 수시간 연속 재생, 물리 장치 분리, 별도 Windows VM과 Mac은 이 검사에 포함되지 않는다.

## 2. 제품 목표와 확정 요구사항

여러 실제 폴더에 있는 영상을 한곳에서 탐색하고, 평점·배우·태그·설명을 붙이며 실제 영상 파일을 폴더 사이에서 이동하는 개인용 Windows·Mac 앱을 만든다. 가칭은 **Soft Vault**다.

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
- 내부 영상 재생, 화면 클릭 재생·일시정지, 외부 앱으로 열기.
- 메타데이터 백업·복원·내보내기.
- 단축키 변경, 보조키, 충돌 안내, 기본값 복원, 프리셋 저장.

### 추가 구현 기능 — 2026-11-08 사용자 요청 반영

| 기능 | 구현 및 사용 방식 |
|---|---|
| 이어보기 | 3초마다·일시정지·전환·종료 시 위치 저장. 재생 엔진의 파일 로딩 시작 위치로 전달하며 항상 0% 음량으로 연다. 마지막 1초까지 본 영상은 완료 처리. 메뉴에서 처음부터 재생 가능. |
| 장면 북마크·메모 | 시간·제목·메모 저장, 편집·삭제, 클릭으로 해당 위치 재생. 파일 이동 후에도 같은 ID에 보존. |
| 스마트 컬렉션 | 검색어, 모든 지정 태그, 배우 이름·별칭, 폴더, 유형, 평점, 미평가, 이어볼 영상, 온라인 조건을 저장. 열 때마다 현재 카탈로그에 재평가. |
| 짧은 영상 미리보기 | 썸네일 위에 650ms 머물면 FFmpeg로 생성한 3초 무음 WebP 애니메이션 표시. 캐시와 직렬 생성으로 중복 작업 방지. |
| 대표 썸네일 선택 | 현재 위치 및 영상 구간별 장면 6개, 또는 로컬 이미지에서 선택. 앱 캐시에 복사해 스캔·이동 후 보존. 자동 썸네일 복원 지원. |
| 중복 비교 | SHA-256 동일 파일과 길이·해상도 유사 후보를 구분. 두 파일의 경로·크기·썸네일·기록을 나란히 비교하고 실제 파일을 다시 해시 검증. |
| 규칙 기반 이동 | 연결된 출발·목적지와 조건을 저장, 실제 후보 목록을 검토한 뒤 실행. 자동 적용은 명시적으로 켜야 하며 순환 규칙 거부, 재생 중 파일 제외, 같은 실패 반복 방지. 기존 검증 이동 저널 사용. |
| NFO | Kodi movie/episodedetails의 제목·설명·배우·태그·개인 평점·이어보기 가져오기/내보내기. 개인 메모·북마크는 softvault 확장 요소에 저장. 가져오기 전 카탈로그 백업, 덮어쓰기 전 NFO 백업. XML 외부 선언 거부, 10MB 제한. |

구현: `advanced_catalog.dart`, `extended_features.dart`, `scenes_dialog.dart`, `criteria_dialog.dart`, `organize_panel.dart`, `rule_runner.dart`, `thumbnail_dialog.dart`, `hover_preview.dart`, `nfo_service.dart`. SQLite v3로 기존 v2 데이터를 자동 이전하고 v2 JSON 백업도 복원한다. 새 기능은 오른쪽 상단 `soft vault.` 옆 **설정**의 라이브러리·재생 영역에서 연다.

NFO 필드 근거: [Kodi Movie NFO](https://kodi.wiki/view/NFO_files/Movies). Soft Vault 확장 메모·북마크는 다른 프로그램에서 무시할 수 있다. 원본 미디어를 NFO에 포함하지 않는다.

디자인 보완: 원본 SVG 아이콘 33종, Segoe UI/맑은 고딕 폰트, 340/370px 목록 폭, 미리보기 위치·크기, 파일 행, 재생 화면·조작부, 상세창, 배우·태그 카드, 검색창, 단축키 표, 떠 있는 선택 막대를 시안 기준으로 조정했다. 시안의 동일 콘텐츠 12개로 비교 캡처를 별도 생성한다. **앱 일반 화면은 창 전체를 채우고 영상 영역에만 비율 유지 여백을 허용**한다. 고정 16:9 앱 외곽 프레임은 사용하지 않는다.

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
- 사이드바·첫 실행 화면·브라우저 탭·디자인 정리 페이지가 이 파일을 사용한다. Windows 다중 해상도 ICO와 macOS AppIcon 이미지 세트를 `scripts/export-icons.ps1`로 변환·적용했다. Mac 패키지 빌드는 후속이다.
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
