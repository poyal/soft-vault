# 기능·실패·복구 E2E 기준

## 검사의 구분

| 계층 | 실제로 확인하는 경계 | 대신하지 못하는 것 |
| --- | --- | --- |
| `test/` | 임시 SQLite·파일·서비스 계약, 일부 주입 장애 | 실제 창·OS 입력·물리 출력 |
| `integration_test/` | Flutter 네이티브 창·UI·실제 영상 디코더 | 대체한 파일 선택기·OS IME |
| profile 실행 | 최적화된 앱의 프레임·UI 작업 | 모든 기기·Release 설치본의 FPS |
| `--verify-install` | ZIP 설치 사본·번들 런타임·실제 디코더 | 최종 ZIP의 전체 외부 UI E2E |
| 별도 실기 | OS 선택기·물리 키보드·HDR·스피커·업그레이드 | 미실행 기기까지의 일반화 |

각 시나리오는 준비 상태, 조작, 기대 결과, 보존할 데이터, 실행 근거를 갖는다. 아래 ID는 문서의 분류이며 테스트 케이스 수를 늘리는 항목이 아니다.

## 핵심 시나리오

| ID | 준비·조작 | 기대 결과와 불변 조건 | 연결된 검사 |
| --- | --- | --- | --- |
| SV-01 | 빈 카탈로그에서 폴더 연결·취소·스캔 | 취소는 변경 없음, 영상만 표시, 원본 보존 | `library_test`, `scenario_flow_test` |
| SV-02 | 한글·특수문자 검색, 폴더·컬렉션 필터 뒤 배우/태그 전체 선택 | `%`·`_`는 문자 검색, 전체 선택은 기존 필터 해제 | `scenario_regression_test`, `scenario_flow_test` |
| SV-03 | 여러 영상의 배우·태그·평점 수정, 상세정보 보기→정보 편집 | 읽기와 편집 구분, 동시 변경 보존, 실패한 일괄 편집 롤백 | `library_flow_test`, `catalog_flow_test`, `scenario_flow_test` |
| SV-04 | 재생·화면 클릭·탐색·Q/E 전환·Esc 최소화·복원 | 새 영상 0%, 클릭은 현재 음량 유지, Esc 뒤 0%, 화면 복원 | `playback_test`, `playback_flow_test`, `app_playback_test` |
| SV-05 | 음성/자막 트랙·외부 자막·배속·소프트웨어 디코더·손상 영상 | 설정 반영, 손상 후 다음 정상 영상 사용 가능 | `codec_matrix_test`, `app_playback_test`, `scenario_flow_test` |
| SV-06 | 이동·충돌·검증 복사·취소·실패·프로세스 중단 후 복구 | ID·메타데이터 유지, 원본/목적지 무결성, 부분 완료 명시 | `file_jobs_test`, `stress_scenarios_test`, `catalog_flow_test` |
| SV-07 | 오프라인 폴더·재연결·파일 교체·중첩 폴더 | 목록 기록 유지, 오프라인 재생 중단, 다른 내용은 옛 장면 재사용 금지 | `scenario_regression_test`, `scenario_flow_test` |
| SV-08 | 이어보기·장면 메모·썸네일 선택·무음 미리보기·이동 후 재열기 | 위치·연결 ID 유지, 미리보기 소리 없음, 대표 썸네일 보존 | `advanced_features_test`, `extended_flow_test` |
| SV-09 | 스마트 컬렉션·중복 비교·규칙 검토/실행·NFO 가져오기 취소 | 조건 일치, 실행 전 원본 재검증, 취소는 변경 없음, NFO 보호 사본 | `advanced_features_test`, `extended_flow_test`, `scenario_flow_test` |
| SV-10 | 백업·손상 JSON·없는 참조·구버전 복원 | 정상 왕복, 실패 시 기존 카탈로그 유지, 잠금 정보 독립 | `library_test`, `scenario_regression_test`, `privacy_lock_test` |
| SV-11 | 첫 비밀번호 설정·틀린 확인·재시작·오입력·변경·해제·지금 잠그기 | 인증 전 목록/플레이어 없음, 대기 영속, 현재 암호 확인, 재생 정지·0% | `privacy_lock_test`, `privacy_flow_test` |
| SV-12 | 통합 설정 탐색·단축키 변경·작은 창·전체화면·복원 | 입력·설정 유지, 버튼 접근 가능, 앱 바깥 검은 띠 없음 | `key_bindings_test`, `scenario_flow_test`, `design_parity_test` |
| SV-13 | 1만 목록·빠른 영상 전환·반복 최소화·동시 파일 작업 | 상한 충족, 데이터 무결성, 종료 후 잔류 작업 확인 | `stress_flow_test`, `stress_scenarios_test`, 부하 검사 |

서비스 파일은 `test/<이름>.dart`, UI 파일은 `integration_test/<이름>.dart`에 있다. 현재 코덱 자료는 11개 파일이며 한 테스트 안에서 여러 코덱을 확인한다. 이를 11개의 독립 E2E로 집계하지 않는다.

## 실행과 판정

전체 Windows 실행은 [verify-windows.ps1](../scripts/verify-windows.ps1), 집중 실행은 [개발 가이드](development.md)를 따른다. 앱 시작·대기·조작·결과를 단계별로 확인한다. 명령 종료 코드와 성공 요약, 해당 JSON의 결과를 함께 읽는다.

결과는 `PASS`, `FAIL`, `NOT_RUN`, `BLOCKED`, `N/A`로 구분한다. 환경 미준비는 `BLOCKED`, 미실행은 `NOT_RUN`이다. `N/A`에는 대상 플랫폼에 적용되지 않는 이유가 있어야 한다. 필수 항목이 완료되지 않았으면 전체 완료로 표시하지 않는다.

파일 수·테스트 메서드 수·시나리오 단계 수·fixture 수·스크린샷 수는 서로 다르다. profile의 반복 4개나 원인 조사 A/B 실행은 기존 독립 케이스에 더하지 않는다. 숫자는 해당 실행 결과에서 다시 계산한다.

## 실패 근거와 실제 경계

- 실패 시 소스·명령·시간·단계·오류·기기·로그·캡처를 남긴다. 이전 실패 파일을 새 성공 파일로 덮기 전에 별도 실행 폴더로 보존한다.
- OS 파일 선택기는 일부 검사에서 반환값을 대체한다. 개인정보 입력은 시험용 값만 사용하며 비밀번호 UI 테스트는 컨트롤러에 값을 넣는다. OS 키보드·IME 실입력은 별도 항목이다.
- 디스크 부족은 오류 주입이고, 파일 이동 중단 복구는 별도 실제 프로세스 종료를 사용한다. 둘을 실제 디스크 가득 참·물리 드라이브 분리로 표시하지 않는다.
- `PrivacyGate` 재구성에 의한 재시작 시나리오와 운영 EXE 프로세스 종료·재실행을 구분한다. 전체 콜드 스타트 잠금 UI의 외부 실기 검증은 추가로 기록한다.
- 네이티브 창의 논리·물리 크기와 변환을 검사한다. 캡처가 정상이어도 사용자가 보는 창이 검으면 성공으로 결론 내리지 않는다.

HDR·스피커·깨끗한 OS 계정·장시간 부하·Mac은 [실기 계획](remote-testing.md)과 [성능 문서](performance.md)의 별도 결과가 필요하다.
