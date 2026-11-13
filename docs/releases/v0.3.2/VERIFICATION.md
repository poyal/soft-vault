# 0.3.2 Windows·Mac 검증

실행 ID: release-032-20261113. 이전 개발 검증은 [UI 감사](../../verification/2026-11-13-ui-audit.md)에서 구분한다. 새 후보는 같은 소스의 Windows x64와 macOS arm64를 대상으로 한다.

## 출처

- 앱 후보 커밋: `ddf934ba96b84a36ef83f53386f35bc8973e6abf`. 이후 테스트만 수정한 최종 후보는 `3dcc84d30a39dfeeb7427fe12e4628c57ed0377b`이며 앱 코드는 같다. 문서 변경은 바이너리 입력과 구분한다.
- 초기 양쪽 소스 지문: `9cacb5dfc08fc23fc3167820643c4a3f40a6f1ccb67c541b4dccdf4f1fb408cc`. 테스트 수정 후 최종 지문: `6f8abd8337fed501e0f921f7c0f71e1b7a553462fe531309ded5ddec86505ddf`.
- Flutter 3.47.9 / `c197ca5199`, Dart 3.13.7. 잠금 파일 SHA-256: `db8d9a4c009d183fe1b82606a93cd13baa74500ba02ae6ded35c5a00e7b04a92`.
- 시험 영상 SHA-256: `b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254`.
- Windows NT 10.0.26300 x64, Intel Core i7-8700B, RAM 64GiB와 Apple Silicon Mac mini M4, RAM 16GiB, macOS 27.2.1 / 26B131, Xcode 27.2 / 27B52에서 검사했다.

사용자 데이터 대신 시험 영상과 임시 DB를 사용한다. 원시 근거는 로컬 `build/release-032/`, `build/verification/`와 Mac의 `soft-vault-release-032-20261113` 후보 폴더에 보존한다. Mac 시험은 로그인된 사용자의 작업 전용 LaunchAgent로 실행하며 사용자 설치본은 변경하지 않는다.

## 실행 결과

| 범위 | Windows | Mac |
| --- | --- | --- |
| 정적 분석·일반 회귀 107개, 타 OS 전용 1개 제외 | PASS | PASS |
| UI·코덱·사생활 보호·파일 작업 | PASS | PASS |
| UI 개편·평점 저장·상세정보 편집 회귀 | PASS | PASS |
| profile·스트레스·대량 성능 | PASS | PASS |
| 종료 18회·업데이트 교체 및 복구 5개 | PASS | PASS |
| Release·ZIP 설치 진단 | PASS | PASS |
| EXE/DMG 설치 진단 | PASS | PASS |
| 업데이트 manifest 서명·검증한 ZIP과의 대응 | PASS | PASS |
| 공개 재다운로드 | NOT_RUN | NOT_RUN |

Mac은 [최종 감사](mac-final-audit.json)를 통과했다. 전송한 ZIP·DMG 해시가 원격 설치 검증과 일치한다. 종료는 37.703~100.192ms였으며 18회 모두 코드 0·2초 이내·재생 위치 보존을 확인했다. 새 Mac 충돌 보고서는 없고 시험 LaunchAgent 제거·앱 종료·DMG 마운트 해제를 확인했다.

Windows는 [독립적인 최종 감사](windows-final-audit.json)를 통과했다. EXE 새 설치·재설치·시작 메뉴·제거 등록·실제 재생·제거·시험 데이터 보존을 확인했고 개발 SQLite DLL 복원과 시험 설치 등록 제거를 확인했다. 종료는 163.975~316.115ms였으며 18회 모두 코드 0·2초 이내·재생 위치 보존을 확인했다. 아래 실행기 기록 오류는 이 감사와 구분해 보존한다.

직접 확인한 Windows·Mac 화면 6장과 자동 화면 검사를 [화면 검수](SCREENSHOT-REVIEW.md)에 구분했다. 대량 검사는 작은 합성 파일 1만 개와 카탈로그 5만 건이며, 실제 영상 1만 개 동시 디코딩 검사나 사용자 라이브러리 전체 실측이 아니다.

## 게시와 제한

배포 후보 8개의 이름·크기·SHA-256은 [파일 고정값](release-assets.json)에 있다. `.svupdate`는 설치 검증을 통과한 ZIP과 같은 바이트다. 기존 키로 서명한 manifest를 각 플랫폼 패키지 해시 및 앱 공개키로 검증했다. 내부 ZIP은 게시 대상에서 제외한다.

후보 검증: **PASS**. 게시·재다운로드 검증: **NOT_RUN**. `git push origin main`은 기본 브랜치 소스 게시의 명시적 승인이 필요하다는 자동 승인 검토에 의해 차단됐다. 원격 main과 기존 릴리즈·태그는 변경하지 않았으며 게시 승인 대기 상태다.

실제 사용자 데이터 전체의 이전 버전 업그레이드, 물리 HDR·스피커 출력, 수시간 재생, 깨끗한 OS 첫 실행 경고는 별도 검증 대상이다. Windows 코드 서명과 Apple Developer ID 서명·공증은 없다.

## 실패와 재실행

양쪽 UI-17 검사는 제거된 `file-actors-*`·`file-tags-*` 키와 ‘지정된 태그 없음’ 문구를 가정해 실패했다. 실제 배우·태그 텍스트, 미등록 배우, 빈 태그 상태와 선택 보존을 검사하도록 테스트만 수정했다. 초기 실패 로그를 보존하고 정적 분석·사용자 흐름부터 재실행한다. 이미 통과한 동일 앱 코드의 일반·라이브러리·카탈로그·재생·확장·디자인·코덱 검사는 이 후보의 근거로 유지한다.

재실행에서 양쪽 사용자 흐름 19개가 통과했다. [소스 전환 기록](source-transition.json)은 변경 파일이 해당 테스트 하나뿐임을 확인한다.

Windows 실행기는 모든 설치 검사를 통과한 뒤 `dart run tool/source_manifest.dart`의 `Running build hooks` stderr를 PowerShell의 종료 오류로 처리했다. 원래 `windows-status.txt`의 FAIL과 로그는 유지했다. 별도 실행에서 실제 종료 코드 0과 최종 소스 지문 일치를 확인하고, 모든 필수 로그·종료 결과·설치 해시·정리 상태를 독립적으로 감사했다. 최종 감사 JSON에도 원래 FAIL과 별도 확인 결과를 함께 기록했다. 실패 상태를 PASS로 덮어쓰려던 명령은 자동 승인 검토에서 차단됐으며 실행하지 않았다.
