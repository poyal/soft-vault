# Soft Vault 문서 안내

Soft Vault의 구현·검증·배포 절차를 정리한다. 요구사항과 사용자 결정은 [계획서](../plan.md), 설치와 기본 사용법은 [루트 README](../README.md)를 기준으로 한다. 마지막 갱신일은 2026-11-09이다.

## 작업별 입구

| 하려는 일 | 문서 |
| --- | --- |
| 개발 환경 준비, 변경에 맞는 검사 선택 | [개발 가이드](development.md) |
| 화면·저장소·파일 작업의 책임 파악 | [구현 구조](architecture.md) |
| 후보 확정, Windows 패키징, 설치 검증, 게시 준비 | [릴리즈 가이드](release.md) |
| 기능·실패·복구 시나리오 확인 | [E2E 기준](e2e.md) |
| 디자인 대조, 창 가장자리 여백 확인 | [디자인 검수](design-review.md) |
| CPU·GPU·프레임·부하 측정 | [성능과 스트레스 검사](performance.md) |
| 앱 잠금, 원본 보존, 백업 범위 확인 | [사생활 보호와 데이터](privacy-and-data.md) |
| Mac·Windows 원격 환경과 HDR 검증 준비 | [원격 실기 검증](remote-testing.md) |
| 문서 갱신, 다른 프로젝트에서 채택한 원칙 확인 | [문서 운영과 참고 검토](documentation.md) |
| 새 후보 기록 만들기 | [검증 기록 템플릿](templates/verification.md), [사용자 릴리즈 노트 템플릿](templates/release-notes.md) |

## 현재 확인된 범위

- `0.2.0+2`는 별도 Windows와 Mac의 필수 자동 검사·설치 검증 후 [정식 공개](https://github.com/poyal/soft-vault/releases/tag/v0.2.0)했다. 보류했던 Windows 클립보드 검사도 통과했고 공개 파일 6개의 재다운로드 해시가 일치한다. [두 PC 결과와 검증 제한](releases/v0.2.0/VERIFICATION.md), [배포 안내](releases/v0.2.0/README.md), [이전 로컬 기록](verification/2026-11-09-windows-0.2.0.md)을 참고한다.
- `0.1.0+1`의 실제 RTX Windows·Mac M4 검증 결과와 배포 안내는 [0.1.0](releases/v0.1.0/README.md)에 있다.
- Windows 99개, Mac 100개 검사와 각각 별도 profile 4개, 최종 ZIP 설치 사본 검증이 통과했다. [소스 대응·수치·검증 제한](releases/v0.1.0/VERIFICATION.md)을 함께 확인한다.
- 두 플랫폼의 디자인·코덱·잠금·파일 장애·대량 데이터 검사를 실행했다. HDR 파일 디코딩과 물리 HDR 출력은 구분하며 후자는 미검증이다.
- Windows는 코드 서명이 없고 Mac은 로컬 서명이며 Apple Developer ID 서명·공증은 없다. 비공개 저장소의 릴리즈에는 접근 권한이 필요하다.

이전 개발 PC의 결과는 [2026-11-08 Windows 검증 기록](verification/2026-11-08-windows.md)에 보존한다. 새 후보는 템플릿의 모든 항목을 `NOT_RUN`에서 시작한다.

## 문서의 지위

공통 가이드는 운영 기준이며 그 자체가 검사 통과 증거는 아니다. `현재 구현`, `수동 절차`, `미구현`, `미검증`을 구분한다. 다른 프로젝트의 도구·테스트 수·게시 예외를 Soft Vault의 구현이나 권한으로 가져오지 않는다. 후속 빌드·원격 검증·게시 결과는 별도 검증 기록에 남긴다.

`build/`의 로그·캡처·ZIP은 로컬 생성물이다. 해당 링크는 결과를 생성한 작업 공간에서만 열리며, 나중에 파일이 바뀌면 문서에 기록한 해시와 시각을 먼저 대조한다.
