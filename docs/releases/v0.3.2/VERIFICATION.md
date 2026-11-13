# 0.3.2 Windows·Mac 검증

실행 ID: release-032-20261113. 이전 개발 검증은 [UI 감사](../../verification/2026-11-13-ui-audit.md)에서 구분한다. 새 후보는 같은 소스의 Windows x64와 macOS arm64를 대상으로 한다.

## 출처

후보 커밋·소스 지문·도구·fixture 해시는 이번 실행 결과로 기록한다. 사용자 데이터 대신 시험 영상과 임시 DB를 사용한다. 원시 근거는 `build/release-032/`와 Mac의 별도 후보 폴더에 보존한다.

## 실행 결과

| 범위 | Windows | Mac |
| --- | --- | --- |
| 정적 분석·일반 회귀 | NOT_RUN | NOT_RUN |
| UI·코덱·사생활 보호·파일 작업 | NOT_RUN | NOT_RUN |
| UI 개편·평점 저장·상세정보 편집 회귀 | NOT_RUN | NOT_RUN |
| profile·스트레스·대량 성능 | NOT_RUN | NOT_RUN |
| 종료·업데이트 교체 및 복구 | NOT_RUN | NOT_RUN |
| Release·ZIP 설치 진단 | NOT_RUN | NOT_RUN |
| EXE/DMG 설치 진단 | NOT_RUN | NOT_RUN |
| 설치 파일·업데이트 서명·公開 해시 | NOT_RUN | NOT_RUN |

## 게시와 제한

게시·재다운로드 검증: NOT_RUN. 최종 판정: **NOT_RUN**.

실제 사용자 데이터 전체의 이전 버전 업그레이드, 물리 HDR·스피커 출력, 수시간 재생, 깨끗한 OS 첫 실행 경고는 별도 검증 대상이다. Windows 코드 서명과 Apple Developer ID 서명·공증은 없다.
