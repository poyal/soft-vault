# 릴리즈와 설치 검증 가이드

Windows x64 설치 EXE와 Apple Silicon Mac DMG를 배포한다. 내부 ZIP은 설치 파일 제작·업데이트 payload 검증에만 사용하고 공개 릴리즈에는 올리지 않는다. 실제 통과와 게시 상태는 후보별 검증 기록으로 판단한다. GitHub 게시와 두 OS 결과 취합은 수동 절차이며 버전별 실행 잠금은 아직 없다.

## 1. 후보와 출처

`0.2.1+3`의 최신 상태는 [Windows·Mac 검증 기록](releases/v0.2.1/VERIFICATION.md)에 있다. 이전 0.2.0 결과는 [두 PC 검증 기록](releases/v0.2.0/VERIFICATION.md)과 [로컬 검증 기록](verification/2026-11-09-windows-0.2.0.md)에 보존한다. 아래 기능별 초기 측정은 해당 작업 당시의 기록이며 새 후보의 전체 검사 결과와 구분한다.

버전은 [pubspec.yaml](../pubspec.yaml)을 기준으로 한다. 배포 후보에는 소스 커밋, 미커밋·미추적 변경, 의존성, 대상 OS, 도구 버전을 기록한다. 깨끗한 후보 커밋을 기본으로 하며 사용자 변경을 정리하려고 reset·삭제하지 않는다. dirty 상태의 개발 검증은 그 상태를 기록하고 재현 가능한 정식 후보로 승격하지 않는다.

새 기록은 [검증 템플릿](templates/verification.md)에서 `NOT_RUN`으로 시작한다. 이전 버전의 성공 표시를 복사하지 않는다. 같은 버전을 여러 컴퓨터에서 동시에 패키징·게시하지 않도록 작업 순서를 정한다. 현재 스크립트에 이를 자동 조정하는 잠금은 없다.

```powershell
git status --short
git rev-parse HEAD
& .tools/flutter/bin/flutter.bat --version
```

Mac과 Windows를 같은 릴리즈로 낼 때는 같은 소스 기준으로 각 네이티브 환경에서 빌드·검증한다. 한 플랫폼만 통과했으면 그 플랫폼만 통과로 적는다. 문서만 수정한 후속 커밋은 바이너리의 빌드 커밋과 구분한다.

## 2. Windows 후보 검사

프로젝트 루트에서 필요한 도구·코덱 fixture를 먼저 준비한다. 시험 영상은 실제 절대 경로로 지정한다.

```powershell
$fixture = (Resolve-Path -LiteralPath '.tools/fixtures/trailer.mp4').Path
& .\scripts\verify-windows.ps1 -VideoFixture $fixture
& .\scripts\build-review.ps1
& .\scripts\compare-design.ps1
```

`verify-windows.ps1`은 의존성·정적 분석·일반 회귀·Windows 통합·스트레스·대량 성능·profile·18회 종료·업데이트 교체/복구 검사 뒤 Release를 빌드하고 집계한다. 필터·재생 이력·설정·크기 변경·AI 정보 교환의 네이티브 회귀도 포함한다. 의존성은 준비된 로컬 캐시를 사용한다. **ZIP 패키징과 설치 사본 검증은 이 명령에 포함되지 않는다.**

필수 검사가 실패·중단되거나 결과가 없으면 해당 후보의 검증 완료로 기록하지 않는다. 검사 개수뿐 아니라 예상 시나리오와 실제 실행 결과, 오류·누락·생략을 대조한다. 현재 집계 도구는 로그 성공 요약과 일부 JSON을 읽으며, 전체 테스트 ID와 소스 지문을 자동으로 대조하지 않는다. 후보 기록에서 수동으로 보완해야 한다.

결과는 고정 경로를 사용한다. 다음 실행 전에 필요한 근거를 `build/runs/<실행 ID>/`로 보존한다. 이전 실행의 JSON이 남았다는 이유로 실패한 최신 실행을 통과 처리하지 않는다.

## 3. 같은 파일로 패키징·설치 확인

```powershell
& .\scripts\package-windows.ps1
& .\scripts\verify-install-windows.ps1 -VideoFixture $fixture
Get-FileHash -LiteralPath build/package/SoftVault-Windows.zip -Algorithm SHA256
```

패키징은 현재 `build/windows/x64/runner/Release`를 복사하며 앱을 재빌드하지 않는다. Flutter·libmpv·SQLite·미디어 도구·C++ 런타임·라이선스 고지·사용자 안내·설치 스크립트와 파일별 manifest를 묶는다. 개발용 절대 경로가 있는 루트 `native_assets.json`은 배포에서 제외한다.

현재 패키징 대상 폴더는 재사용된다. 오래된 잔여 파일이 없는지 목록을 대조하고, 사용 중인 패키지 앱을 먼저 정상 종료해야 한다. 소스·버전·Release 폴더의 대응을 자동 검증하는 기능은 아직 없다.

설치 검증은 ZIP 해시 목록을 확인하고 새 `build/install-smoke/<ID>/` 아래에 `Install.ps1 -NoShortcut`으로 복사 설치한다. 개발 도구를 제외한 PATH와 개발 SQLite DLL 격리 상태에서 배포 실행 파일을 실행한다. 임시 DB로 비밀번호·카탈로그·이동·확장 기능·재생·코덱을 확인하고 `installed-results.json`에 ZIP 해시를 남긴다. 완료 후 개발 SQLite DLL이 복원됐는지도 확인한다. 다른 빌드·테스트와 동시에 실행하지 않는다.

이 검사는 최종 Release 앱의 설치 사본 진단이다. 전체 UI E2E가 모두 최종 ZIP을 대상으로 수행된다는 뜻은 아니다. 이어서 Inno Setup 7.1.1로 실제 설치 EXE를 만들고 검증한다. 컴파일러는 공식 배포본의 서명을 확인한 뒤 `.tools/inno`에 준비한다.

```powershell
& .\scripts\package-installer-windows.ps1
& .\scripts\verify-installer-windows.ps1 -SetupExe build/package/SoftVault-0.2.0-Windows-x64-Setup.exe -VideoFixture $fixture
```

EXE 검사는 기존 등록 설치본과 같은 이름의 바로가기가 없는 시험 계정에서 실행한다. 새 설치·재설치·시작 메뉴·제거 등록·파일 해시·실제 재생·제거 및 시험 데이터 보존을 확인한다. 앱은 `bin`, 제거 프로그램은 형제 `uninstall` 폴더에 설치하여 업데이트의 `bin` 교체 이후에도 제거 등록을 유지한다. 깨끗한 계정의 설치 경고와 실제 구 배포본 전체 업그레이드는 별도 검사다.

## 4. 데이터 보존과 업그레이드

직전 배포본이 존재하면 격리 시험 계정·자료에서 아래를 확인한다. 현재 이 전체 절차의 자동화와 최종 패키지 간 업그레이드 실행 증거는 없다.

1. 구버전 파일·해시·소스를 확인하고 시험 영상을 등록한다. 폴더·배우·태그·평점·메모·이어보기·장면·컬렉션·규칙·설정·잠금 상태를 채운다.
2. 원본 파일 해시와 일관된 DB/백업 상태를 기록한다. 행 수뿐 아니라 ID와 기존 필드 값을 비교할 준비를 한다.
3. 앱을 정상 종료하고 앱 폴더만 후보로 교체한다. 데이터 폴더를 지우지 않는다.
4. 정상 앱을 실행해 실제 스키마 이전·인증·재생·이동·새 백업을 확인한다. 의도한 새 기본값과 기존 데이터 손실을 구분한다.
5. 실패하면 근거와 복구 사본을 보존한다. 구 실행 파일을 덮는 것만으로 DB 스키마가 되돌아간다고 안내하지 않는다.

## 5. 파일 고정과 게시

검증한 ZIP과 SHA-256 파일을 실행별 후보 경로에 복사해 고정한다. 게시 전 그 ZIP 해시와 설치 검증의 `packageSHA256`이 같은지 확인한다. 게시용 파일을 다시 압축하거나 재빌드했다면 다른 바이트의 새 후보이므로 영향받는 검증을 다시 한다.

공개 설치 파일은 `SoftVault-<버전>-Windows-x64-Setup.exe`, `SoftVault-<버전>-macOS-arm64.dmg`와 각 `.sha256`이다. 업데이트 payload는 검증한 ZIP과 동일한 바이트를 `.svupdate` 이름으로 복사한다. 공개 파일 이름·크기·해시·서명 상태를 [릴리즈 노트](templates/release-notes.md)에 기록한다. 현재 Windows 서명 절차는 없으며 서명·SmartScreen 승인을 주장하지 않는다.

게시가 요청된 작업에서는 실제 저장소·태그·기존 자산을 조회한 뒤 검증한 동일 파일을 게시한다. 기존 태그를 옮기거나 같은 이름의 다른 파일로 교체하지 않는다. 릴리즈에서 재다운로드하여 크기·SHA-256을 확인한 뒤에만 게시 완료로 기록한다. 비공개 저장소의 릴리즈는 접근 권한이 필요하며 저장소 공개 전환을 의미하지 않는다. 통신 실패는 동일 파일로 재개하고, 로컬 설치 성공을 배포 성공으로 바꾸지 않는다.

## Apple Silicon Mac

전체 Xcode 초기 설정과 CocoaPods가 필요하다. 영상 플러그인의 CocoaPods 연결을 위해 `macos/Podfile`과 lock 파일을 유지한다. 실행 명령은 Mac 저장소 루트 기준이다.

```bash
bash scripts/prepare-media-macos.sh
bash scripts/verify-macos.sh "$PWD/.tools/fixtures/trailer.mp4"
bash scripts/package-macos.sh
bash scripts/verify-install-macos.sh "$PWD/.tools/fixtures/trailer.mp4"
bash scripts/package-dmg-macos.sh
bash scripts/verify-dmg-macos.sh "$PWD/build/package/SoftVault-0.2.0-macOS-arm64.dmg" "$PWD/.tools/fixtures/trailer.mp4"
```

동일 코덱 fixture 묶음을 `.tools/fixtures/codecs`에 먼저 준비한다. `prepare-media-macos.sh`는 고정 공급처 커밋의 ZIP 체크섬을 검사한다. 공급처 경로 이름은 v8.0이지만 실제 바이너리가 보고하는 FFmpeg 버전은 7.0이다.

패키지는 새 임시 staging 폴더에서 만들며 `.app/Contents/MacOS/tools`에 FFmpeg·ffprobe를 포함한다. 파일별 manifest, 라이선스, 설치 안내를 ZIP에 넣는다. 로컬 서명은 무결성 검사 목적이며 Apple Developer ID 서명·공증과 다르다. 설치 검사는 새 폴더에 압축을 풀어 해시와 서명을 검사한 뒤 개발 도구를 제외한 PATH에서 임시 데이터로 실행한다. 일반 사용자의 Gatekeeper 첫 실행 확인과 실제 HDR 출력 측정을 대신하지 않는다.

소스 대응은 양쪽에서 `dart tool/source_manifest.dart build/verification/source-before.json`으로 기록한다. 검사 뒤 다시 실행해 지문이 유지되는지 확인한다. 이 지문은 명시한 앱·플랫폼·검사 파일을 대상으로 하며 문서·생성 로그 전체의 해시는 아니다.

## 6. 중단·정리와 미구현 항목

작업 중에는 실패 근거·후보 파일·복구 자료를 유지한다. 종료 시 최종 요약을 `docs/verification/` 또는 버전 문서에 남기고, 소유가 명확한 시험 생성물만 정리한다. 실행 중인 앱, 사용자 원본·DB·잠금 정보, 개발 SDK, 전역 SSH 설정은 정리 대상이 아니다. 현재 공개 파일을 다시 받을 수 있다는 근거 없이 유일한 검증 ZIP을 삭제하지 않는다.

후속 자동화 후보는 실행 ID·fixture 해시·결과 신선도 검사, 예상 테스트 ID 검증, Windows 후보별 깨끗한 패키징, 업그레이드 검사, Apple Developer ID 서명·공증, 두 OS 결과 취합·게시 도구다. 소스 지문과 Mac 번들·설치 검사 도구는 위 명령으로 실행하며, 검사 결과와 도구 존재 여부를 구분한다.

## 앱 내 업데이트 배포

설정 → 앱 정보 · 업데이트에서 자동 확인, 지금 확인, 다운로드, 업데이트 후 재시작을 제공한다. 공개 `poyal/soft-vault` Releases를 사용한다. 자동 확인은 기본으로 켜져 있으며 하루 한 번 실행한다. 첫 업데이트 지원 버전은 직접 설치해야 한다.

빌드 전에 `.tools/flutter/bin/dart run tool/prepare_update.dart --prepare`로 pubspec 버전을 업데이트 설정에 반영한다. 두 플랫폼을 같은 소스와 공개키로 빌드하고 기존 package 스크립트로 ZIP을 만든다. 패키징은 플랫폼별 업데이트 도우미를 컴파일하여 포함한다.

검증한 ZIP을 `build/package`에 모은 다음 대상 플랫폼을 명시한다. Windows만 검증했다면 `--platform=windows-x64`만 지정한다. 아래 두 플랫폼 명령은 양쪽 모두 같은 후보로 검증했을 때만 사용한다. 폴더에 남은 이전 Mac ZIP을 자동으로 포함하지 않는다.

```powershell
& .tools/flutter/bin/dart.bat run tool/prepare_update.dart --platform=windows-x64 --platform=macos-arm64
$env:SOFT_VAULT_UPDATE_KEY = '안전하게 보관한 개인키 파일 경로'
& .tools/flutter/bin/dart.bat run tool/sign_update.dart sign build/package/update.json
```

prepare_update는 플랫폼별 `.svupdate`를 만들고 그 URL·크기·SHA-256을 manifest에 기록한다. 릴리즈에는 EXE·DMG와 각 체크섬, 두 `.svupdate`, `update.json`, `update.json.sig`를 올린다. ZIP과 ZIP 체크섬은 공개하지 않는다. 모든 파일 검증 후 정식 릴리즈로 공개한다. 사전 공개 버전은 앱에서 설치하지 않는다. 서명 키와 앱 공개키가 일치하지 않으면 서명이 실패한다.

기존 앱은 서명된 manifest의 URL을 사용하며 확장자를 제한하지 않는다. 따라서 `.svupdate`도 기존 ZIP 내용·서명·해시·교체·복구 절차로 처리한다. 자동 확인과 사용자 승인 후 적용 방식은 그대로다. EXE·DMG를 앱 내 업데이트 payload로 직접 전달하지 않는다. 게시 중인 릴리즈의 형식 변경을 사용자가 요청한 경우에는 새 payload 업로드·공개 해시 확인 → manifest와 서명 변경·검증 → 이전 ZIP 자산 제거 순서로 진행하고 기존 파일과 게시 기록을 보존한다.

초기 개인키는 Git에서 제외된 `build/update-keys/private.key`에 생성했다. 배포 담당자는 빌드 폴더를 정리하기 전에 이 파일을 안전한 별도 저장소에 백업하고 CI 비밀로 제공해야 한다. 공개키는 `assets/update-config.json`에 포함한다. 배포 후 키를 임의로 재생성하면 기존 앱이 새 업데이트를 검증하지 못한다. 개인키를 릴리즈나 Git에 포함하지 않는다.

복구 사본은 앱 데이터의 `updates/database-backup`, 이전 앱은 설치 폴더 옆 `.previous` 폴더에 남는다. 복구 사본에는 잠금 DB도 포함되므로 카탈로그 내보내기와 달리 외부 공유하지 않는다. 읽기 전용 설치 위치에서는 수동 설치를 사용한다.

도우미 검사(Windows):

```powershell
& .tools/flutter/bin/dart.bat compile exe tool/update_fixture.dart -o build/update_fixture.exe
& .tools/flutter/bin/dart.bat compile exe tool/update_helper.dart -o build/soft_vault_updater.exe
& .tools/flutter/bin/dart.bat run tool/update_helper_smoke.dart
```

이 검사는 격리된 테스트 앱으로 교체와 실패 복원을 확인한다. 실제 배포본의 UI·코덱·DB 이전 검증 및 Mac에서의 번들 교체 검증을 대체하지 않는다. 교체 중 전원 차단으로 원래 실행 경로가 사라진 경우 `updates`의 도우미를 통한 복구 또는 `.previous` 복원으로 실행 경로를 먼저 복구해야 한다.

## 설정 개편과 크기 변경 성능 검사

설정은 전용 화면으로 표시하며 `SettingsSection`, `SettingsRow`, `SettingsStatus`와 설정 전용 테마를 공유한다. 설정 표시 중 영상 목록은 레이아웃하지 않으며 목록 스크롤 위치는 PageStorage로 유지한다. 목록과 재생 컨트롤의 반응형 분기는 창 전체 MediaQuery 대신 자신의 LayoutBuilder 제약을 사용한다.

검증 진입점은 `test/settings_layout_test.dart`, `integration_test/resize_profile_test.dart`, `integration_test/settings_native_review_test.dart`다. 네이티브 검사는 `flutter drive -d windows --profile --no-pub --driver=integration_test/performance_driver.dart --target=integration_test/resize_profile_test.dart --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false --dart-define=RUN_LABEL=after --dart-define=VIDEO_FIXTURE=<실제 영상 경로>`로 실행한다. native review 검사도 같은 driver와 VIDEO_FIXTURE를 사용한다.

측정은 네이티브 창 크기를 연속 변경하며 각 화면을 3회 반복한다. 결과는 `build/verification/resize-before.json`, `resize-after.json`, `playback-resize.json`에 기록하고 실제 앱 화면 캡처는 `build/settings-native-review`에 둔다. 자동 크기 변경은 실제 마우스 가장자리 드래그나 다른 GPU·모니터 배율의 결과를 대신하지 않는다. Mac 실기, Windows 150% 배율, 실제 가장자리 드래그는 별도 확인 대상이다.

이번 Windows profile 측정의 각 회차 p95 평균(ms):

| 화면 | build 이전 → 이후 | raster 이전 → 이후 |
| --- | --- | --- |
| 영상 목록 | 5.62 → 4.32 | 19.75 → 15.32 |
| 라이브러리 설정 | 6.42 → 2.13 | 20.28 → 11.60 |
| 재생 설정 | 4.60 → 5.19 | 19.59 → 19.26 |
| 단축키 | 9.04 → 7.20 | 18.90 → 19.19 |
| 사생활 보호 | 6.37 → 1.76 | 19.79 → 10.92 |
| 백업 | 4.82 → 1.79 | 18.45 → 9.00 |
| 앱 정보·업데이트 | 5.07 → 1.32 | 19.70 → 8.70 |

후속 실제 영상 재생 검사에서 raster p95는 13.30/18.52/20.21ms, 일시정지는 20.14/13.48/19.38ms였다. UI 계산보다 raster 구간이 더 오래 걸리는 경향은 확인했지만 GPU/드라이버/네이티브 surface 재생성 중 어느 것이 주원인인지는 이 수치만으로 단정하지 않는다. 재생 설정·단축키·영상 화면은 모든 회차 16.7ms 이하 목표를 충족하지 못했다. 테스트 간 시스템 부하가 달라질 수 있으므로 각 수치의 변화가 개별 코드 변경만의 효과라고 해석하지 않는다.

일반 회귀 61개 통과·1개 건너뛰기, 설정 레이아웃 및 업데이트 위젯 검사 통과, 네이티브 설정 분류 전환·선택 보존·플레이어 동일성·일시정지 위치 보존 검사 통과. 앱 UI 실제 캡처에서 왼쪽 메뉴와 공통 행 배치를 확인했다. 이 결과를 전원 차단 업데이트 복구나 Mac 검증 결과로 사용하지 않는다.

## 라이브러리 필터 검사

`LibraryFilter`는 평점 비교 방식·미평가·배우/태그 ID·각 그룹의 ANY/ALL을 보관한다. 일반 목록과 컬렉션 조회에서 동일한 바인딩 SQL 조건을 사용한다. 새 컬렉션은 `MediaCriteria.filters`에 조건을 저장하며 기존 JSON에서 이 필드가 없으면 빈 조건 목록으로 읽는다. 기존 문자열 배우·태그와 최소 평점 조건은 유지한다. DB 스키마 변경은 없다.

검증: `test/library_filter_test.dart`는 평점 경계·ANY/ALL·그룹 교차·중복·이름 변경·삭제·컬렉션·백업 복원을 검사한다. `test/library_filter_dialog_test.dart`는 1,000개 목록의 지연 생성·별칭 검색·임시 선택·취소·초기화·긴 이름·최소 창을 검사한다. `integration_test/library_filter_flow_test.dart`는 Windows profile 실제 UI에서 적용 결과·창 크기 변경·취소·조건 칩 해제를 검사한다. 기존 performance driver와 VIDEO_FIXTURE를 사용하며 캡처는 `build/filter-review/filter.png`에 저장한다.

## Windows 종료 지연·충돌 검사

2026-11-09 기존 배포본의 Windows Application Error 기록에서 `flutter_windows.dll`의 `0xc0000005` 및 `0xc000041d`를 확인했다. 격리된 기존 종료 코드 검사에서는 6회 모두 종료 요청 후 약 25~27초가 지나도 종료되지 않았다(프로세스 시작 30초 제한). 플레이어·DB만 먼저 정리한 비교군도 지연 또는 같은 콜백 예외로 실패했다.

`window_manager` 0.5.2의 Windows `destroy()`는 창을 닫지 않고 `PostQuitMessage`를 호출한다. 이제 플레이어와 영상 텍스처를 해제한 뒤 닫기 차단을 해제하고 `close()`로 WM_CLOSE를 처리한다. Flutter 컨트롤러 정리가 메시지 루프 종료 및 COM 해제 전에 실행되도록 한다. 중복 종료 요청을 무시하고 플레이어 해제 Future를 공유하며, 종료 중 타이머·감시·키보드 동작과 새 스캔을 막는다. 잠금 화면의 종료 버튼에도 정상 창 닫기 경로를 사용한다. Mac은 기존 애플리케이션 종료 방식을 유지한다.

재현 도구는 사용자 DB 대신 매번 `build/shutdown-probes` 안에 만든 카탈로그와 전달된 테스트 영상을 사용한다. 부모 프로세스가 실제 자식 프로세스 종료까지 측정하고, 재생 위치를 DB에서 다시 읽어 검사한다. 30초 제한을 초과한 경우 자신이 생성한 테스트 프로세스만 종료하며 앱 코드에는 강제 종료 타이머를 넣지 않았다.

```powershell
& .tools/flutter/bin/flutter.bat build windows --profile --no-pub -t tool/shutdown_probe.dart
& .tools/flutter/bin/dart.bat run tool/measure_shutdown.dart build/windows/x64/runner/Profile/soft_vault.exe .tools/fixtures/trailer.mp4 normal,repeated idle,playing,paused 3 fixed
# 배포용 빌드는 반드시 기본 진입점으로 다시 생성한다.
& .tools/flutter/bin/flutter.bat build windows --release --no-pub
```

Windows profile에서 대기·재생·일시정지 × 정상·3회 연속 닫기 × 각 3회, 총 18회 모두 종료 코드 0과 위치 보존을 확인했다. 종료 시간 170~399ms이며 결과는 `build/shutdown-probes/fixed.json`에 저장했다. 기존 비교군은 `results.json`, 창 닫기 경로 비교는 `close-path.json`에 있다. 일반 회귀 68개 통과·1개 건너뛰기, 정적 분석 통과. 장시간 파일 이동·스캔 중 종료, 다른 GPU 및 Mac 실기 종료 시간은 이 검사 범위에 포함하지 않는다.

## 재생 횟수·이력 및 재생 여부 필터

SQLite와 JSON 백업 버전을 4로 올렸다. `media.play_count`와 `playback_history`를 추가하며 횟수 증가와 이력 삽입은 하나의 트랜잭션이다. 기존 DB와 v2/v3 백업은 횟수 0·빈 상세 이력으로 이전하며 기존 재생 시각·위치·완료 상태를 유지한다. 재생 여부 필터는 횟수 또는 기존 기록 중 하나라도 있으면 재생 이력이 있는 것으로 판정한다. 기록을 근거 없이 과거 횟수로 환산하지 않는다.

실제 재생 위치가 진행되었을 때 세션당 한 번 기록한다. 일시정지·재개·탐색은 같은 세션이고 다시 열기·완료 후 재시작은 새 세션이다. 기록 저장 중 반복 이벤트는 동일 Future를 기다린다. 종료·전환 시 진행 중인 이력 저장을 기다리고 재생 위치는 요청 시점의 영상·위치 스냅샷으로 저장한다. 파일 내용 교체 시 횟수·이력을 함께 초기화하고 중복 인덱스 교체 시 삭제되는 항목의 이력을 정리한다.

`LibraryFilter.playback`은 전체/미재생/재생한 적 있음 상태를 JSON에 저장하고 평점·배우·태그 조건과 AND로 결합한다. 초기화·조건 칩 삭제·컬렉션 직렬화에도 반영한다. 상세정보에서 최신 횟수를 조회하고 이력 화면은 50개씩 최신순으로 읽는다.

검증: 일반 회귀 73개 통과·1개 건너뛰기, 정적 분석 통과. `test/playback_history_test.dart`는 v3 이전, 원자적 저장 실패 롤백, 페이지 조회, 이동·재시작·백업 보존, 파일 교체 초기화, 구버전 백업, 잘못된 이력 참조, 복합 필터와 세션 중복 방지를 검사한다. `integration_test/playback_history_flow_test.dart`는 Windows profile 실제 영상 재생·일시정지·탐색·다시 열기·완료 후 재시작, 재생 여부 필터와 상세 이력 UI를 검사했다. 캡처 `build/playback-review/history.png`에서 날짜와 시작 위치, 횟수 표시를 확인했다. 기존 performance driver와 VIDEO_FIXTURE로 실행한다. Mac 실기와 다른 코덱의 재생 콜백 타이밍은 별도 확인 대상이다.

## AI 전체 영상정보 교환

설정 → 메타데이터 → 영상정보 교환에서 내보내기·입력·변경 검토·완료 순서로 진행한다. `MetadataExchange`는 전체 video 행의 허용된 메타데이터만 JSON으로 내보내고 settings에 요청 식별값과 원본 스냅샷을 보관한다. 새 DB 마이그레이션은 없다. 요청문은 앱 안에서 확인·복사할 수 있고 파일 저장과 붙여넣기·JSON 파일 입력을 지원한다.

결과는 요청 식별값과 영상 식별값으로 검증하며 코드 블록 JSON을 허용한다. 누락·빈 값은 유지하고 배우·태그는 선택 시 최종 목록으로 교체한다. 적용은 자동 백업 이후 한 트랜잭션에서 요청 유효성과 원본 메타데이터·지문을 다시 확인한다. 성공 시 요청을 소진하고 목록을 갱신한다. 실패 시 모든 변경을 롤백한다. 기존 NFO 기능은 유지한다.

검증: 정적 분석 통과, 일반 회귀 77개 통과·1개 건너뛰기. `metadata_exchange_test.dart`에서 전체 내보내기의 개인 필드 제외, 동일 파일명 구분, 재시작 후 요청 보존, 선택 적용과 관계 테이블 갱신, 자동 백업 생성, 중복·알 수 없는 ID·누락·이전 요청, 원본 변경 충돌과 SQL 실패의 전체 롤백을 확인했다. 1000×700 위젯 검사에서 가이드, 탭 전환, 비교 및 선택 해제를 확인했다. 외부 AI 서비스의 조사 정확성이나 응답 길이 제한은 이 검사 범위가 아니다.


## 0.3.0 배우 이미지 교환

AI 요청문은 영상의 배우 이름과 일치하는 `actorImages: [{name, imageUrl}]`도 요청한다. 공개 HTTPS 직접 이미지 주소만 받으며 검토 화면에서 사용자가 불러온 뒤 개별 선택한다. 다운로드는 크기·시간·공개 주소를 제한하고 실제 디코딩 후 최대 1024px PNG로 저장한다. 적용 전 자동 백업, 배우 이미지 동시 수정 검사, 실패 시 DB 롤백과 새 이미지 파일 정리를 수행한다. 기존 이미지 파일은 삭제하지 않는다. 이미지 없는 이전 JSON도 사용할 수 있고 이미지 다운로드 실패는 영상정보 적용을 막지 않는다.

`metadata_actor_image_test.dart`는 선택 저장·다운로드 실패·새 배우 선택 누락·동시 수정·잘못된 주소를 검사하고, `metadata_exchange_test.dart`는 확대 글자에서 검토 화면 접근과 미확인 이미지 선택 방지를 검사한다. 실제 후보 통과 여부는 [0.3.0 검증 기록](releases/v0.3.0/VERIFICATION.md)에 기록한다.
