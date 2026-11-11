# 0.3.0 Windows·Mac 검증

2026-11-11, 버전 0.3.0+4, 실행 ID release-030-20261111. 두 플랫폼 자동 검사·설치 검증을 완료했다. 공개 파일 재다운로드 결과는 게시 후 별도로 기록한다. 시각은 UTC, 한국 시간은 UTC+9이다.

## 출처와 환경

- 앱 구현 기준 커밋: 6f951c681ccd2da2d1c9e29b9c82a213925d8818. 이후 앱·플랫폼 구현 변경은 없으며 테스트 4개와 문서·캡처만 변경했다.
- 최종 테스트 커밋: eea41f9f598741f4f2a803ef9d2d0de7fc2b0ee5. Windows Release는 이 커밋의 깨끗한 소스로 빌드했다. 이후 릴리즈 기록 변경은 문서 전용이다.
- 양쪽 최종 소스 지문: 95ae834f09349fbf2245c4464cf7b9e9b172ce1bf790c03f987a482a3f1d17dd. 파일 목록·개별 해시는 source-before.json/source-after.json에 보존했다. 소스 지문은 앱·플랫폼·검사·도구를 포함하며 문서는 제외한다.
- Mac 패키징 지문: 6d9110af25e10bcc55a7959c6352764ebacc15070bb5b4d671749cf6df1699e2 (d45de25caf7f95250d597fb9a961c98746101389 기준). 패키징 후 stress_flow_test.dart만 강화하여 다시 통과했다. source-transition-stress.json으로 앱 입력이 동일함을 확인했으며 패키지를 다시 만들지 않았다.
- Windows: Microsoft Windows NT 10.0.26300.0, Intel Core i7-8700B, AMD64. 환경 기록 시각 2026-11-11T08:32:51Z, 최종 감사 2026-11-11T09:18:12.8253823Z.
- Mac: Mac mini M4, macOS 27.2.1 / 26B131, arm64, Xcode 27.2 / 27B52. 최종 감사 2026-11-11T09:13:26.008446+00:00.
- 양쪽 Flutter 3.47.9 / c197ca5199, Dart 3.13.7. pubspec.lock SHA-256: db8d9a4c009d183fe1b82606a93cd13baa74500ba02ae6ded35c5a00e7b04a92.
- 양쪽 .tools/fixtures/trailer.mp4 SHA-256: b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254. 사용자 영상·DB는 사용하지 않았다.
- 디자인 캡처는 1280/1440 조건의 실제 네이티브 테스트와 docs/screenshots/manifest.json을 참조한다. Windows 대량 목록 profile의 활성 주사율은 59Hz였다. GPU·드라이버·RAM·모든 검사 시점의 DPI는 이번 릴리즈에서 별도 전수 기록하지 않았다.

## 검사 결과

| 항목 | Windows x64 | macOS arm64 |
| --- | --- | --- |
| 정적 분석·일반 회귀 | PASS, 101개·타 OS 전용 1개 제외 | PASS, 같은 수 |
| 라이브러리·카탈로그·재생·확장 기능·디자인·코덱 | PASS | PASS |
| UI 시나리오·사생활 보호 | PASS, 19개·3개 | PASS, 19개·3개 |
| 필터·재생 이력·설정·크기 변경·정보 교환 | PASS, profile | PASS, profile |
| 스트레스·대량 데이터 | PASS, 9개·파일 1만 개·카탈로그 5만 건 | PASS, 같은 범위 |
| 네이티브 스트레스·UI 반응성 | PASS, debug/profile | PASS, debug/profile |
| 빠른 폴더 등록·썸네일 중지/계속 | PASS | PASS |
| 대기·재생·일시정지 × 정상·연속 닫기 | PASS, 18회 | PASS, 18회 |
| 업데이트 교체·복구·잘못된 패키지 | PASS, 5개 | PASS, 5개 |
| Release·ZIP 설치 사본·EXE/DMG | PASS | PASS |
| 기존 공개키로 업데이트 서명·설치 파일 대응 | PASS | PASS |

Windows profile 스트레스는 40회 연속 파일 열기, 12회 전체화면·긴급 숨김·복원, 1만 건 목록을 확인했다. 최종 목록 profile 프레임 p95는 9.504ms, 검색 p95는 140ms였다. 이 수치는 이번 시험 기기와 합성 데이터의 결과이며 모든 사용자 환경의 보장은 아니다.

종료는 양쪽 모두 코드 0, 재생 위치 보존, 제한 2초 내였다. Windows 159.657~620.035ms, Mac 36.663~101.255ms였다. Mac 설치 앱의 Impeller 비활성 설정도 확인했고 최종 감사까지 새 Soft Vault 충돌 기록은 없었다.

## 초기 실패와 테스트 수정

실패 로그는 삭제하지 않았다. 전체 검사를 매번 새로 통과한 것으로 합산하지 않고, 통과한 동일 앱 소스의 검사와 수정 후 재실행을 결합했다.

1. 일반 회귀의 필터 별점 버튼이 Ahem 테스트 폰트에서 화면 밖으로 밀려 탭하지 못했다. 4493ead에서 스크롤 후 조작하도록 수정하고 양쪽 일반 회귀를 다시 통과했다.
2. UI 시나리오가 NFO의 이전 설정 경로와 화면 밖 그리드 카드를 사용했다. 1ece9fb에서 현재 메타데이터 진입 경로·스크롤을 반영하고 UI 시나리오를 다시 통과했다.
3. profile 정보 교환 테스트의 논리 Space 키만 지정한 이벤트가 물리 키 조회에서 실패했다. d45de25에서 PhysicalKeyboardKey.space를 지정하고 양쪽 profile 검사를 다시 통과했다.
4. 연속 파일 열기 검사가 중간 playlist URI만 보고 완료를 판단해 Windows profile에서 선택 ID가 아직 이전 값이었다. eea41f9에서 마지막 URI·선택 ID·음량 0이 10회 연속 일치하는 안정 상태를 기다리도록 강화했다. Windows 전체 native-profile 및 Mac stress_flow-profile 재실행이 통과했다. 앱 재생 구현을 변경한 것은 아니다.

지문 전환은 초기 2bd59d3f… → 4493ead의 733ec986… → 1ece9fb의 50652851… → d45de25의 6d9110af… → eea41f9의 95ae834f…이다. 원시 manifest와 전환 JSON에 전체 값·변경 파일을 보존했다. Windows 마지막 검사·빌드·패키징 구간에서는 시작/종료 지문이 동일했다.

Windows Flutter AXTree 접근성 로그와 Mac 일부 Resize timed out 로그는 보존했다. 최종 테스트 종료 결과와 설치 진단은 통과했지만 스크린리더 동작까지 통과한 것으로 해석하지 않는다. 최초 테스트 실행 중 사용자에게 나타난 Windows 메모리 오류와 관련한 오래된 PID 캐시 방어는 앱 기준 커밋에 포함되며, stale PID·다른 PID·경로 부재·잠긴 파일의 별도 캐시 검사를 통과했다.

## 설치·데이터 보존·서명

- Windows ZIP: 45개 파일 해시, 개발 SQLite 격리·최소 PATH, 임시 DB·잠금·재시작·오입력·인증 해제·이동·정보 교환·재생 이력·확장 기능·11개 코덱 영상·최소화/복원 통과.
- Windows EXE: 격리 경로 신규 설치·재설치, 시작 메뉴·제거 등록, 앱 파일 42개 해시, 실제 재생, 제거·시험 사용자 데이터 보존 통과. 개발 SQLite 복원 및 시험 설치 등록 부재를 최종 감사했다.
- Mac ZIP·DMG: 설치 사본 진단·11개 영상, Applications 링크, ZIP 대비 앱 파일 해시, ad-hoc 서명 통과. 실제 사용자 라이브러리를 교체하지 않았다.
- 백업·복원·마이그레이션·파일 이동/복구·관계 데이터의 보존은 합성 fixture 회귀 검사 범위다. 구 배포본과 사용자 카탈로그 전체의 전후 필드 비교는 NOT_RUN이며 위 통과와 구분한다.
- 검증 ZIP과 동일한 바이트의 .svupdate를 기존 키로 서명했다. 실제 Windows 배포 번들의 공개키로 manifest Ed25519 서명·버전·URL·크기·SHA-256 및 양쪽 설치 진단의 ZIP 해시와 일치를 확인했다.
- Windows ZIP/업데이트 SHA-256: f5d48ada32a6f35f959ff562d9f6fa97cfcee9f20507f66db9771095c9bfb167.
- Mac ZIP/업데이트 SHA-256: 5d9c929e7447a3eccc7058b484e6b2f7f67f956e07fb2810eff22ba2d069ed7c.
- 배포 8개 파일의 크기·해시는 [배포 파일 표](README.md#배포-파일)에 기록했다. 내부 ZIP·개인키는 공개 자산에서 제외한다.

## 명령과 원시 근거

Windows는 scripts/verify-windows.ps1을 시작으로 실패 단계 수정 후 해당 단계부터 재개했다. 최종 native-profile, verify-profile-windows.ps1 -NormalUi, verify-lifecycle-windows.ps1, Release 빌드, fast_folder_flow_test.dart, build-review.ps1, compare-design.ps1, package-windows.ps1, verify-install-windows.ps1, package-installer-windows.ps1, verify-installer-windows.ps1을 수행했다.

Mac은 승인된 별도 폴더 soft-vault-release-030-20261111에서 GUI LaunchAgent를 통해 verify-macos.sh 및 수정 단계 재실행, package-macos.sh, verify-install-macos.sh, package-dmg-macos.sh, verify-dmg-macos.sh를 수행했다. 강화된 스트레스 검사는 별도 LaunchAgent로 재실행했다.

로컬 build/release-030에 Windows 실행·실패·재개 로그, windows-evidence, windows-final-audit.json, Mac의 release-030-evidence.tar.gz·mac-evidence·mac-final-audit.json, source-*.json, 고정 assets·release-assets.json을 보존했다. build/는 Git에 포함하지 않는 실행 근거다. 이전 버전의 성공 결과를 이번 버전 결과로 복사하지 않았다.

## 미검증 범위와 게시 상태

실제 한글 IME·OS 파일 선택기의 모든 조작, 물리 HDR/광색역·스피커 출력, 수시간 재생, 구 배포본과 사용자 카탈로그를 사용하는 전체 업그레이드, 깨끗한 OS의 첫 실행 경고는 NOT_RUN이다. 업데이트 도우미 검사는 격리 fixture 앱을 사용한다. Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않는다.

자동 검사·설치·업데이트 서명 검증: **PASS**. 초안 업로드·공개 재다운로드: **NOT_RUN**. 원격 시험 LaunchAgent 정리는 게시 완료 시 별도로 확인한다.
