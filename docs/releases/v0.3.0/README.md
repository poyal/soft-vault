# Soft Vault 0.3.0

Windows x64·Apple Silicon Mac용 0.3.0+4입니다. 자동 검사와 EXE·DMG 설치 검증 후 [정식 공개](https://github.com/poyal/soft-vault/releases/tag/v0.3.0)했습니다. 공개 파일 8개의 재다운로드 크기·해시도 확인했습니다. [검증 기록](VERIFICATION.md)

## 변경 사항

- 글자 크기와 대비를 높이고 왼쪽 목록 카드의 경계·선택 표시를 개선했습니다.
- 설정·조회조건·메타데이터 등 화면을 공통 테마와 버튼 규칙으로 정리했습니다. 클릭 동작은 버튼·아이콘과 상태 표시로 구분합니다.
- 전체 폴더 새로고침을 설정 옆 아이콘으로 옮기고 필터·정렬 영역을 정리했습니다.
- 재생 중 방향키 탐색이 포커스 이동과 음량 변경을 함께 일으키는 문제를 수정했습니다.
- 설정의 메타데이터에서 영상정보를 내보내고 AI 반환 정보를 검토할 수 있습니다. AI가 제공한 배우 이미지도 미리보기·선택 후 로컬에 저장할 수 있습니다.
- Windows 디버그 테스트에서 재사용된 프로세스 ID의 오래된 미디어 캐시로 발생하던 충돌을 방지했습니다.

## 설치와 업데이트

- [Windows x64 설치 EXE](https://github.com/poyal/soft-vault/releases/download/v0.3.0/SoftVault-0.3.0-Windows-x64-Setup.exe)를 실행합니다.
- [Apple Silicon Mac DMG](https://github.com/poyal/soft-vault/releases/download/v0.3.0/SoftVault-0.3.0-macOS-arm64.dmg)를 열고 앱을 Applications로 복사합니다.
- 기존 사용자는 앱의 업데이트 기능을 사용할 수 있습니다. 두 플랫폼 업데이트를 기존 키로 서명했고, 검증한 설치용 ZIP과 동일한 바이트를 사용합니다.
- Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않습니다. Mac 앱은 ad-hoc 서명입니다. OS의 첫 실행 경고가 표시될 수 있습니다.

## 검증 범위

양쪽 정적 분석·일반 회귀 101개(각 플랫폼에서 다른 OS 전용 1개 제외), UI 시나리오 19개, 사생활 보호 3개, 재생·코덱·정보 교환·배우 이미지·스트레스·성능 검사를 통과했습니다. 종료 18회와 업데이트 교체·복구 5개, 최종 ZIP 설치 사본 및 EXE·DMG도 확인했습니다.

실제 한글 IME·OS 선택기의 모든 조작, 물리 HDR·스피커 출력, 수시간 재생, 사용자 카탈로그를 이용한 구 배포본 전체 업그레이드는 별도 미검증 범위입니다. [검증 기록](VERIFICATION.md)에서 초기 실패와 수정·재실행 근거를 확인할 수 있습니다.

## 배포 파일

| 파일 | 크기(byte) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.3.0-macOS-arm64.dmg | 94974765 | `e62a77584f19933f8d578f5a73ec011b279bd02eea49de6238630a0914100365` |
| SoftVault-0.3.0-macOS-arm64.dmg.sha256 | 98 | `944ec9772020060b6bc5829d41f006b64443db2f11e852d7aa75140fa601f44f` |
| SoftVault-0.3.0-Windows-x64-Setup.exe | 89084930 | `9df2d4a8f293e9ebd1d57efe8ba45ac76a69453c75a985097758c5e9e52bbb75` |
| SoftVault-0.3.0-Windows-x64-Setup.exe.sha256 | 105 | `00af1da33684a54a10a44bc84715190c51110c4c3db0ac42751468f253b98af1` |
| SoftVault-macOS-arm64.svupdate | 86665272 | `5d9c929e7447a3eccc7058b484e6b2f7f67f956e07fb2810eff22ba2d069ed7c` |
| SoftVault-Windows.svupdate | 117167076 | `f5d48ada32a6f35f959ff562d9f6fa97cfcee9f20507f66db9771095c9bfb167` |
| update.json | 446 | `1da6353a44756c89d24f614a27a1db50ef97ead4e67f284875860a6ad1105d27` |
| update.json.sig | 88 | `8e6639b66561b42bb0d6278e66fa0f0fa0c91f09fe0c08113c1e461526f3034c` |

내부 ZIP과 개인키는 공개 자산에 포함하지 않습니다. [사용자 매뉴얼](../../../README.md)
