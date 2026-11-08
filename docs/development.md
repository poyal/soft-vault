# 개발 가이드

## 환경과 디렉터리

현재 검증 기준은 Flutter 3.47.9 / Dart 3.13.7이다. [pubspec.lock](../pubspec.lock)으로 Dart 의존성을 유지한다. Windows 소스 빌드는 Visual Studio C++ Build Tools·Windows SDK·개발자 모드가 필요하다. 배포 앱 사용자는 Flutter·Visual Studio·별도 FFmpeg를 설치하지 않는다.

| 경로 | 역할 |
| --- | --- |
| `lib/` | Flutter UI, SQLite, 파일 작업, 재생, 앱 잠금 |
| `windows/`, `macos/` | 네이티브 실행기와 플랫폼 프로젝트 |
| `test/` | 서비스·회귀·부하 검사 |
| `integration_test/` | 실제 Flutter Windows·macOS 창과 재생을 사용하는 검사 |
| `scripts/`, `tool/` | 실행·패키징·측정 도구 |
| `design/` | 확정 HTML 시안·원본 SVG·아이콘·참고 캡처 |
| `docs/` | 공통 절차·검증 요약·기록 템플릿 |
| `.tools/`, `.dart_tool/`, `build/` | 로컬 도구·캐시·생성물, Git 제외 |

프로젝트 루트의 PowerShell에서 실행한다. `.tools/flutter`는 이 작업 공간에 준비된 SDK 경로이며 새 기기에 자동 생성되는 것은 아니다.

```powershell
& .tools/flutter/bin/flutter.bat --version
& .tools/flutter/bin/flutter.bat doctor -v
& .tools/flutter/bin/flutter.bat pub get
```

미디어 도구가 없을 때 [prepare-media.ps1](../scripts/prepare-media.ps1), 코덱 자료가 없을 때 [create-codec-fixtures.ps1](../scripts/create-codec-fixtures.ps1)을 실행한다. 이 도구들은 다운로드·파일 생성을 포함한다. 준비된 동일 자료를 매번 다시 만들 필요는 없다. `VIDEO_FIXTURE`에는 재배포 가능한 시험 영상의 실제 절대 경로를 사용한다.

## 변경에 맞는 검사

| 변경 | 우선 확인 | 후보 확정 시 추가 |
| --- | --- | --- |
| 문서만 수정 | 링크·명령·코드와 문구의 일치 | 앱 재빌드 불필요 |
| 카탈로그·파일 이동 | 관련 `test/` 회귀·실패 재현 | 해당 UI, 데이터 보존, 부하 |
| 재생·네이티브 실행기 | playback 단위·앱 재생·코덱 | 설치 사본, profile, 플랫폼 실기 |
| 화면·아이콘·크기 | 관련 UI·design parity | 창 크기·DPI·성능 비교 |
| 비밀번호 | privacy 단위·UI | 설치 사본, 재시작·데이터 보존 |
| 패키징·의존성 | analyze·관련 서비스 검사 | 새 ZIP 설치 사본·번들 무결성 |

변경 원인을 좁히는 동안 관련 검사를 먼저 실행한다. 통과한 동일 후보를 이유 없이 전체 재검사하지 않으며, 새 변경·실패·환경 차이가 있으면 필요한 범위를 다시 정한다.

```powershell
New-Item -ItemType Directory -Force build/verification | Out-Null
. .\scripts\flutter-check.ps1
Invoke-FlutterCheck 'analyze' @('analyze', '--no-pub')
Invoke-FlutterCheck 'unit' @('test', '--no-pub', '--exclude-tags', 'load || stress')
```

집중 UI 검사 예시다. 경로는 실제 시험 영상으로 바꾼다.

```powershell
$fixture = (Resolve-Path -LiteralPath '.tools/fixtures/trailer.mp4').Path
Invoke-FlutterCheck 'privacy-e2e' @('test', 'integration_test/privacy_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixture")
```

`Invoke-FlutterCheck`는 종료 코드를 검사하고 로그를 남긴다. 네이티브 통합 검사마다 TEMP/TMP를 분리해 media_kit 디버그 포인터 캐시가 재사용된 PID와 충돌하지 않게 한다. 이 래퍼를 우회해 같은 프로세스·임시 폴더로 여러 UI 검사를 묶지 않는다.

## 작업 격리와 증거 보존

같은 checkout의 Flutter 빌드·테스트·설치 검증은 순차 실행한다. 설치 검증은 개발 SQLite DLL을 잠시 옮기므로 다른 Flutter 실행과 겹치면 안 된다. CPU·GPU 측정 중에도 빌드나 다른 부하 검사를 동시에 돌리지 않는다.

현재 로그 이름은 고정되어 다음 실행이 덮어쓴다. 재현 실패나 후보 결과를 보존하려면 다음 실행 전에 `build/runs/<새 실행 ID>/`로 관련 로그·JSON·필요한 캡처를 복사하고 소스·명령·해시를 기록한다. 이 실행별 보존은 현재 **수동 절차**이며 자동 불변 기록 도구는 없다.

사용자 카탈로그·원본 영상을 시험 자료로 사용하지 않는다. 개발 중 미커밋 변경을 되돌리거나 다른 작업자의 앱을 일괄 종료하지 않는다. 바이너리·시험 DB·개인 경로·SSH 키는 저장소에 넣지 않는다. 정리할 때는 실행 중인 앱 경로와 복구에 필요한 자료를 먼저 확인한다.

전체 후보 검증과 패키징 순서는 [릴리즈 가이드](release.md), Mac 준비 상태는 [원격 실기 검증](remote-testing.md)을 따른다.
