# 릴리즈와 설치 검증 가이드

Windows x64 ZIP과 `Install.ps1`, Apple Silicon Mac ZIP을 위한 준비·검증·패키징 스크립트가 있다. 실제 통과와 게시 상태는 후보별 검증 기록으로 판단한다. GitHub 게시와 두 OS 결과 취합은 수동 절차이며 버전별 실행 잠금은 아직 없다.

## 1. 후보와 출처

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

`verify-windows.ps1`은 의존성·정적 분석·일반 회귀·Windows 통합·스트레스·대량 성능·profile 검사 뒤 Release를 빌드하고 집계한다. **ZIP 패키징과 설치 사본 검증은 이 명령에 포함되지 않는다.**

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

이 검사는 최종 Release 앱의 설치 사본 진단이다. 전체 UI E2E가 모두 최종 ZIP을 대상으로 수행된다는 뜻은 아니다. 일반 바로가기 생성, 깨끗한 Windows 계정의 설치 경고, 실제 구버전 업그레이드, 제거 수명주기는 별도 검사다. 현재 NSIS/MSIX 설치 EXE나 제거 등록은 제공하지 않는다.

## 4. 데이터 보존과 업그레이드

직전 배포본이 존재하면 격리 시험 계정·자료에서 아래를 확인한다. 현재 이 전체 절차의 자동화와 최종 패키지 간 업그레이드 실행 증거는 없다.

1. 구버전 파일·해시·소스를 확인하고 시험 영상을 등록한다. 폴더·배우·태그·평점·메모·이어보기·장면·컬렉션·규칙·설정·잠금 상태를 채운다.
2. 원본 파일 해시와 일관된 DB/백업 상태를 기록한다. 행 수뿐 아니라 ID와 기존 필드 값을 비교할 준비를 한다.
3. 앱을 정상 종료하고 앱 폴더만 후보로 교체한다. 데이터 폴더를 지우지 않는다.
4. 정상 앱을 실행해 실제 스키마 이전·인증·재생·이동·새 백업을 확인한다. 의도한 새 기본값과 기존 데이터 손실을 구분한다.
5. 실패하면 근거와 복구 사본을 보존한다. 구 실행 파일을 덮는 것만으로 DB 스키마가 되돌아간다고 안내하지 않는다.

## 5. 파일 고정과 게시

검증한 ZIP과 SHA-256 파일을 실행별 후보 경로에 복사해 고정한다. 게시 전 그 ZIP 해시와 설치 검증의 `packageSHA256`이 같은지 확인한다. 게시용 파일을 다시 압축하거나 재빌드했다면 다른 바이트의 새 후보이므로 영향받는 검증을 다시 한다.

현재 이름은 `SoftVault-Windows.zip`이다. 공개용 이름에 버전·아키텍처를 넣으려면 압축 내용을 바꾸지 않고 복사하고, 새 파일명을 가리키는 체크섬을 작성한다. 공개 파일 이름·크기·해시·서명 상태를 [릴리즈 노트](templates/release-notes.md)에 기록한다. 현재 Windows 서명 절차는 없으며 서명·SmartScreen 승인을 주장하지 않는다.

게시가 요청된 작업에서는 실제 저장소·태그·기존 자산을 조회한 뒤 검증한 동일 파일을 게시한다. 기존 태그를 옮기거나 같은 이름의 다른 파일로 교체하지 않는다. 릴리즈에서 재다운로드하여 크기·SHA-256을 확인한 뒤에만 게시 완료로 기록한다. 비공개 저장소의 릴리즈는 접근 권한이 필요하며 저장소 공개 전환을 의미하지 않는다. 통신 실패는 동일 파일로 재개하고, 로컬 설치 성공을 배포 성공으로 바꾸지 않는다.

## Apple Silicon Mac

전체 Xcode 초기 설정과 CocoaPods가 필요하다. 영상 플러그인의 CocoaPods 연결을 위해 `macos/Podfile`과 lock 파일을 유지한다. 실행 명령은 Mac 저장소 루트 기준이다.

```bash
bash scripts/prepare-media-macos.sh
bash scripts/verify-macos.sh "$PWD/.tools/fixtures/trailer.mp4"
bash scripts/package-macos.sh
bash scripts/verify-install-macos.sh "$PWD/.tools/fixtures/trailer.mp4"
```

동일 코덱 fixture 묶음을 `.tools/fixtures/codecs`에 먼저 준비한다. `prepare-media-macos.sh`는 고정 공급처 커밋의 ZIP 체크섬을 검사한다. 공급처 경로 이름은 v8.0이지만 실제 바이너리가 보고하는 FFmpeg 버전은 7.0이다.

패키지는 새 임시 staging 폴더에서 만들며 `.app/Contents/MacOS/tools`에 FFmpeg·ffprobe를 포함한다. 파일별 manifest, 라이선스, 설치 안내를 ZIP에 넣는다. 로컬 서명은 무결성 검사 목적이며 Apple Developer ID 서명·공증과 다르다. 설치 검사는 새 폴더에 압축을 풀어 해시와 서명을 검사한 뒤 개발 도구를 제외한 PATH에서 임시 데이터로 실행한다. 일반 사용자의 Gatekeeper 첫 실행 확인과 실제 HDR 출력 측정을 대신하지 않는다.

소스 대응은 양쪽에서 `dart tool/source_manifest.dart build/verification/source-before.json`으로 기록한다. 검사 뒤 다시 실행해 지문이 유지되는지 확인한다. 이 지문은 명시한 앱·플랫폼·검사 파일을 대상으로 하며 문서·생성 로그 전체의 해시는 아니다.

## 6. 중단·정리와 미구현 항목

작업 중에는 실패 근거·후보 파일·복구 자료를 유지한다. 종료 시 최종 요약을 `docs/verification/` 또는 버전 문서에 남기고, 소유가 명확한 시험 생성물만 정리한다. 실행 중인 앱, 사용자 원본·DB·잠금 정보, 개발 SDK, 전역 SSH 설정은 정리 대상이 아니다. 현재 공개 파일을 다시 받을 수 있다는 근거 없이 유일한 검증 ZIP을 삭제하지 않는다.

후속 자동화 후보는 실행 ID·fixture 해시·결과 신선도 검사, 예상 테스트 ID 검증, Windows 후보별 깨끗한 패키징, 업그레이드 검사, Apple Developer ID 서명·공증, 두 OS 결과 취합·게시 도구다. 소스 지문과 Mac 번들·설치 검사 도구는 위 명령으로 실행하며, 검사 결과와 도구 존재 여부를 구분한다.
