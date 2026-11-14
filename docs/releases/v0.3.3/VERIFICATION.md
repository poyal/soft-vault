# 0.3.3 Windows·Mac 검증

실행 ID: release-033-20261114 / resume-033. 2026-11-14(KST)에 중단된 동일 후보 검증을 사용자 릴리즈 요청으로 재개했다. 이전 중단 상태는 [인계 기록](HANDOFF.md)에 보존한다.

## 출처

- 앱·검사 소스 커밋: `083f7b2f1b6b3c2be886de2f80394cd1963fba5d`. 재개 시 `main`의 `98d6280d001018e9f21bf0a9a344c5c5f79f4bea`까지 원격 푸시를 확인했다. 후속 문서 변경은 바이너리 입력과 구분한다.
- Windows·Mac 시작과 종료 소스 지문: `b6c7bf8897fa0a2f5a3d174b2872c40d901bc4fea63ccff40d91be2b27aeeb30`. 앱 소스·테스트·플랫폼 설정은 재개 중 변경하지 않았다.
- 양쪽 Flutter 3.47.9 / `c197ca5199e9ee5661e865596c9c07294dfab51c`, Dart 3.13.7. 잠금 파일 SHA-256: `db8d9a4c009d183fe1b82606a93cd13baa74500ba02ae6ded35c5a00e7b04a92`.
- 시험 영상 SHA-256: `b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254`.
- Windows 11 Pro 10.0.26300 x64와 macOS 27.2.1 / 26B131 arm64에서 빌드·검사했다. Inno Setup 7.1.1로 EXE를 만들었다.
- 원시 로그·패키지: Windows 후보 `.tools/release-0.3.3/build/`, Mac 후보 `/Users/poyal/Workspace/personal/soft-vault-release-033-20261114/build/`. 취합·서명·추가 EXE 검사 기록은 게시 PC의 `build/release-033/`에 있다.

## 실행 결과

| 범위 | Windows | Mac |
| --- | --- | --- |
| 정적 분석 | PASS | PASS |
| 일반 회귀 | 107개 PASS, 조건부 2개 생략 | 107개 PASS, 조건부 2개 생략 |
| 실제 HTTPS 이미지 다운로드·디코딩 | 별도 1개 PASS | 별도 1개 PASS |
| 라이브러리·카탈로그·재생·확장·디자인·코덱·사생활 보호 | PASS | PASS |
| UI 사용자 흐름 | 19개 PASS | 19개 PASS |
| 필터·이력·설정·창 크기·메타데이터 교환 profile | PASS | PASS |
| 스트레스·대량 데이터·profile | PASS | PASS |
| 종료·재생 위치 보존 | 18회 PASS | 18회 PASS |
| 업데이트 교체·복구·잘못된 패키지 거부 | 5개 PASS | 5개 PASS |
| 최종 Release·격리 ZIP 설치 진단 | PASS | PASS |
| EXE/DMG 설치 진단 | 별도 게시 PC에서 PASS | PASS |
| 기존 키로 manifest 서명·패키지 해시 검증 | PASS | PASS |
| 공개 재다운로드 | 8개 파일 크기·해시 PASS | 8개 파일 크기·해시 PASS |

일반 회귀의 선택 실행 HTTPS 검사는 별도 실행해 생략 없이 통과했다. 각 플랫폼의 검사 묶음 21개와 로그 해시는 [Windows 감사](windows-final-audit.json), [Mac 감사](macos-final-audit.json)에 있다. 이 숫자는 테스트 개수나 반복 횟수와 다르다. 대량 검사는 합성 파일 1만 개·카탈로그 5만 건이며 실제 영상 1만 개 동시 디코딩을 뜻하지 않는다.

원격 Windows 후보의 기존 사용자 바로가기는 변경하지 않았다. 같은 EXE를 게시 PC로 가져와 [새 설치·재설치·시작 메뉴·제거 등록·실제 재생·제거·시험 데이터 보존](windows-installer-results.json)을 확인했다. EXE 해시가 원격 감사와 일치하며 개발 SQLite DLL 복원과 시험 설치 제거를 확인했다. 따라서 원격 감사의 `registeredInstallUninstall: NOT_RUN`은 이 별도 검사와 구분한다.

Mac은 최종 DMG 마운트·앱 복사·Applications 링크·파일 해시·로컬 서명과 설치된 앱 진단을 통과했다. 시험 LaunchAgent를 해제했으며 후보 앱 프로세스와 DMG 마운트가 남지 않았음을 확인했다.

## 중단과 재개

최초 실행에서 Windows 종료 검사와 Mac 설정 profile 검사가 사용자 요청으로 중단됐다. 중단 전 같은 소스 지문에서 완료된 결과는 보존하고, 미완료 범위부터 재실행했다. Mac 설정 로그에 창 크기 변경 시간 초과 메시지가 있으나 재개한 검사 자체는 종료 코드 0과 모든 테스트 통과를 기록했다. 물리 마우스 드래그 실측과 구분한다.

Windows 재개 시 이전 실행이 만든 도구·플러그인 연결을 SSH 세션에서 읽지 못해 경로 조회·CMake가 실패했다. 후보 내부의 생성 링크를 동일 SDK·패키지의 직접 경로로 연결하고 검사를 재실행했다. 설치 컴파일러도 실제 경로를 지정했다. 기존 실패 로그와 종료 상태는 보존했다. Python 기본 버전 미설정은 설치된 3.13.7 실행기를 직접 사용해 해결했다. 기존 UTF-8 로그와 새 PowerShell UTF-16 로그를 구분해 읽는 감사로 최종 결과를 확인했으며 검사 조건은 완화하지 않았다.

최초 인계 시 찾지 못했던 기존 자동 업데이트 개인키를 게시 PC에서 확보했다. 키 내용은 기록하거나 배포하지 않았고 앱 공개키와의 일치, Ed25519 서명, 설치 검증 ZIP과 `.svupdate`의 동일 바이트를 [서명 기록](signing-verification.json)으로 확인했다. 원격 감사의 서명·게시 대기 상태는 이 후속 단계와 구분한다.

## 배포와 제한

배포할 8개 파일의 이름·크기·SHA-256은 [파일 고정값](release-assets.json)에 있다. EXE·DMG와 각각의 체크섬, 두 `.svupdate`, `update.json`, `update.json.sig`만 게시한다. 내부 ZIP은 게시하지 않는다.

최종 판정: **PASS**. 사용자 요청에 따라 `main`과 `v0.3.3` 태그를 푸시하고 [정식 릴리즈](https://github.com/poyal/soft-vault/releases/tag/v0.3.3)를 공개했다. 태그 커밋은 `0ea86f27709b9a6d3be18baa78d30a87a73f5271`이다. 초안 다운로드에서 8개 파일의 크기·SHA-256을 검증한 뒤 2026-11-14T10:53:01Z에 공개했다. 인증 없는 공개 재다운로드도 8개 모두 일치했다. [공개 검증 증거](publication-verification.json)를 보존한다. 게시 후 문서 갱신은 후속 커밋이며 태그와 바이너리는 변경하지 않는다.

실제 사용자 라이브러리 전체의 이전 버전 업그레이드, 물리 HDR·스피커 출력, 장시간 재생, 깨끗한 OS의 첫 실행 경고는 별도 검증 대상이다. Windows 코드 서명과 Apple Developer ID 서명·공증은 없다. 이번 수정은 네트워크 연결 처리이며 새 화면 수동 검수는 수행하지 않았다.
