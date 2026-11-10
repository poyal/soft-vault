# 0.2.1 Windows·Mac 검증

버전 `0.2.1+3`, 빌드 기준 커밋 `26a0585e53893f7d5e6ae97eff705ca0bf3167f0`. 폴더 등록 지연 수정의 릴리즈 준비 결과다. 사용자가 서명 키가 있는 PC에서 나머지 작업을 진행하겠다고 요청하여 소스 푸시까지만 진행했다. 릴리즈·태그·설치 파일은 게시하지 않았다.

| 항목 | Windows x64 | macOS arm64 |
| --- | --- | --- |
| 동일 소스 지문 | PASS | PASS, 소스 전달·의존성 준비까지만 수행 |
| 정적 분석·일반 회귀 | PASS, 90개 통과·Mac 전용 1개 제외 | NOT_RUN |
| 빠른 폴더 연결·썸네일 중지 UI | 0.2.0 로컬 수정 코드 검사 통과, 버전 변경 전 | NOT_RUN |
| 종료·업데이트 도우미 | NOT_RUN | NOT_RUN |
| Release 빌드 | PASS | NOT_RUN |
| ZIP 설치 사본·재생 | NOT_RUN | NOT_RUN |
| EXE·DMG 내용 검증 | NOT_RUN | NOT_RUN |
| 서명된 업데이트 파일 | NOT_RUN | NOT_RUN |
| 게시 후 공개 다운로드 해시 | NOT_RUN | NOT_RUN |

두 PC의 소스 SHA-256은 `c6603e6b2b173ea0b3e1be3fc5c4e87c0ca7038750d486bb79fb3cdb70e773d1`로 같다. macOS 27.2 arm64에서 기존 Flutter·미디어 도구·fixture를 새 작업 폴더에 연결하고 `flutter pub get --offline` 및 소스 지문 기록을 완료했다. Mac 앱 빌드·UI·설치 검사는 실행하지 않았다.

Windows 로그는 `build/verification/021-analyze.log`, `021-unit.log`, `021-release.log`에 있다. 버전 변경 전 같은 앱 수정 코드의 Windows 네이티브 UI·설치본 복사본 결과는 [폴더 로딩 수정 기록](../../verification/2026-11-10-folder-loading.md)에 보존한다. 이를 0.2.1 배포 패키지의 설치 검증으로 바꿔 쓰지 않는다.

## 이어서 진행할 작업

1. main의 소스와 기존 서명 개인키를 사용한다. `assets/update-config.json`의 공개키를 교체하거나 키를 재생성하지 않는다.
2. Mac 정적 분석·회귀·빠른 폴더 연결 UI·종료 검사를 수행하고 Release를 빌드한다. Windows의 새 패키지 설치 검증도 수행한다.
3. [릴리즈 가이드](../../release.md)에 따라 Windows EXE·Mac DMG·설치 사본을 검증한다. 기존 Windows 설치본이 있는 계정에서는 설치·삭제 시험 스크립트를 실행하지 않는다.
4. 검증한 양쪽 ZIP으로 `.svupdate`와 manifest를 만들고 기존 키로 서명한다. 버전 `0.2.1`의 EXE·DMG·각 체크섬·업데이트 파일·manifest·서명을 새 릴리즈에 게시한다.
5. 공개 다운로드의 크기·해시를 대조하고 이 기록의 미실행 항목을 실제 결과로 갱신한다.
