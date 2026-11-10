# 0.2.1 Windows·Mac 검증

2026-11-10, 버전 0.2.1+3. Windows x64 EXE와 Apple Silicon Mac DMG의 자동 검사·설치 사본 검증을 완료했다. 공개 게시 결과는 문서 마지막에 별도로 기록한다.

## 소스와 환경

- 최종 소스 커밋: ae9ae865eeeec3f2aa154f7ee8fb046f1d7dc292. 초기 인계 기준 26a0585 이후 이번 작업에서 Mac 그래픽 엔진 충돌 회피 설정을 추가했다.
- 최종 양쪽 소스 지문: 42d5a68a6b5090f14a04d5c68a73c1981f9d686bdfc451330c0b2963397f6577.
- Windows 검증 시작 지문: c6603e6b2b173ea0b3e1be3fc5c4e87c0ca7038750d486bb79fb3cdb70e773d1. 실행 중 변경된 지문 대상은 macos/Runner/Info.plist 하나뿐이며 Windows 입력·공통 코드·테스트는 동일하다. Windows Release는 이 변경 후 빌드했다. 실행기의 소스 변경 경고를 보존하고 최종 지문·변경 파일·검사·패키지 해시를 별도 감사해 통과했다.
- Windows 11 Home 10.0.26300, Intel Core i7-8700B, x64.
- Mac mini M4, macOS 27.2 / 26B123, arm64, Xcode 27.2 / 27B52.
- 양쪽 Flutter 3.47.9 / c197ca5199, Dart 3.13.7.
- 양쪽 시험 영상 SHA-256: b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254.

## 검증 결과

| 항목 | Windows x64 | macOS arm64 |
| --- | --- | --- |
| 정적 분석·일반 회귀 | PASS, 90개·다른 플랫폼 전용 1개 제외 | PASS, 90개·다른 플랫폼 전용 1개 제외 |
| 라이브러리·편집·재생·확장 기능·디자인·코덱 | PASS | PASS |
| UI 시나리오·사생활 보호 | PASS, 19개·3개 | PASS, 19개·3개 |
| 필터·재생 이력·설정·연속 크기 변경·정보 교환 | PASS, profile | PASS, profile |
| 스트레스·대량 데이터 | PASS, 9개·파일 1만 개·카탈로그 5만 건 | PASS, 같은 범위 |
| 네이티브 스트레스·UI 반응성 | PASS, debug/profile | PASS, debug/profile |
| 빠른 폴더 등록·썸네일 중지 | PASS | PASS |
| 대기·재생·일시정지 × 정상·연속 닫기 | PASS, 18회 | PASS, 18회 |
| 업데이트 교체·복구·잘못된 패키지 | PASS, 5개 | PASS, 5개 |
| Release·ZIP 설치 사본·EXE/DMG | PASS | PASS |
| 기존 공개키의 업데이트 서명·설치 파일 대응 | PASS | PASS |

정적 분석·일반 회귀 이후의 변경은 Mac plist뿐이다. 렌더러 변경의 영향을 받는 Mac 네이티브 검사 전체와 Release·설치 검사는 다시 실행했다.

빠른 등록 UI 시험은 작은 비영상 파일 173개와 실제 영상 fixture 1개를 사용했다. 목록 174개가 Windows 709ms, Mac 202ms에 나타났으며 당시 썸네일 작업이 계속 진행 중이었다. 중지·계속과 목록 유지도 확인했다. 사용자 영상 632GiB 전체 처리 속도로 해석하지 않는다.

종료 18회 모두 코드 0, 재생 위치 보존, 2초 이내 종료였다. Windows 184.860~535.167ms, Mac 36.918~108.479ms였다.

## Mac 충돌 발견과 조치

최초 Impeller profile 스트레스 실행의 대량 목록·크기 변경 단계에서 2026-11-10 21:42:11 +0900에 실제 EXC_BAD_ACCESS / SIGSEGV가 발생했다. 래스터 스레드의 첫 프레임은 impeller::Canvas::SetupRenderPass()였고 직전 로그에 Metal texture 크기 불일치가 있었다. 이 실행은 실패로 보존했다.

공식 [Flutter 이슈 #185394](https://github.com/flutter/flutter/issues/185394)의 충돌 서명과 일치한다. [공식 macOS 설정](https://docs.flutter.dev/perf/impeller#macos)에 따라 FLTEnableImpeller=false를 앱 plist에 추가해 Skia Metal 경로를 사용한다. 엔진 자체 수정이 아니라 해당 충돌 경로를 피하는 앱 설정이다.

변경 후 이전에 충돌한 profile 스트레스, 연속 크기 변경, 나머지 네이티브 검사와 최종 설치 진단이 통과했다. 설치 사본 plist에서도 설정을 확인했다. 수정 후 검증 시작부터 최종 감사 시점인 2026-11-10T13:08:03Z까지 새 Soft Vault 충돌 기록은 없었다.

초기 Mac 라이브러리 실행에서는 4.8px overflow가 보고됐고, 진단 중 다른 창에 가려진 앱이 hidden 상태로 프레임을 받지 못했다. 원래 테스트 소스로 복원하고 사용자가 허용한 테스트 창 전면 유지 환경에서 재실행해 통과했다. 임시 진단 코드는 배포 소스에 포함하지 않았다. 실패·중단·충돌 로그와 Xcode 플러그인 경고, 일부 Flutter 접근성 트리 오류 로그를 보존했으며 최종 테스트 종료 상태와 설치 진단을 함께 대조했다.

## 설치 파일과 업데이트

- Windows ZIP 사본: 파일별 해시 45개, 개발 SQLite 격리·최소 PATH, 잠금·DB·이동·정보 교환·재생 이력·썸네일·11개 코덱 영상·최소화/복원 통과.
- Windows EXE: 기존 등록 설치본이 없는 계정에서 격리 경로로 신규 설치·재설치, 시작 메뉴·제거 등록·앱 파일 해시·실제 재생·제거·시험 데이터와 원본 영상 보존 통과. 개발 SQLite를 복원했고 시험 설치 등록은 남지 않았다.
- Mac ZIP·DMG: 복사한 앱의 파일 해시·로컬 서명·최소 PATH 설치 진단·11개 영상 통과. DMG Applications 링크와 ZIP 설치 사본 대비 앱 파일 전체 해시 일치를 확인했다.
- 검증한 ZIP과 같은 바이트의 .svupdate를 만들고 기존 개인키로 양쪽 manifest를 서명했다. 실제 Windows 번들 공개키로 Ed25519 서명·버전·URL·크기·SHA-256과 양쪽 설치 진단 해시 일치를 검증했다. 개인키는 변경하거나 공개하지 않았다.
- Windows ZIP/업데이트 SHA-256: b5ff6040c06bfd895f69919784167c64b59761b5d8bef081cffb059d4f27a11c.
- Mac ZIP/업데이트 SHA-256: 3f1196eecc1865fbdab7e42a9c04265464fa6a42715c9cc94806a0eb6cd053cf.
- EXE·DMG·각 체크섬·두 업데이트 파일·manifest·서명 총 8개의 크기·해시는 [배포 파일 표](README.md#배포-파일)에 있다.

Windows 근거는 build/release-021/windows-evidence와 windows-final-audit.json, Mac 최종 근거는 build/release-021/release-021-evidence.tar.gz와 mac-final-audit.json에 보존한다. Mac 원격 build/impeller-evidence에는 실패 당시 로그·캡처·충돌 기록이 있다. 게시 원본은 build/release-021/assets와 release-assets.json이다.

Mac 임시 LaunchAgent·창 전면 유지·절전 방지를 해제했고 시험 앱·DMG 마운트가 남지 않았음을 확인했다. 사용자 원본·DB·기존 설치본·서명 키는 정리하지 않았다.

## 검증 범위의 제한

실제 한글 IME·OS 선택기의 모든 상호작용, 물리 HDR/광색역·스피커 출력, 수시간 재생, 구 배포본과 개인 카탈로그를 사용하는 전체 업그레이드, 깨끗한 OS의 첫 실행 경고는 이번 자동 검사가 대신하지 않는다. 업데이트 도우미 교체·복구 검사는 격리 fixture 앱을 사용한다. Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않는다.

## 게시 결과

공개 게시·재다운로드 검증 전이다. 확인 후 실제 결과로 갱신한다.
