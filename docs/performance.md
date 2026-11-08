# 성능·부하·스트레스 검사

## 먼저 구분할 것

일반 UI가 느린 현상, 대량 카탈로그 처리, 영상 디코딩, 파일 복사, 테스트 러너의 대기는 다른 작업이다. 빈 화면이나 레터박스도 성능 문제와 별도로 재현한다. debug의 지연을 Release FPS로 표현하지 않는다.

측정에는 소스·바이너리 해시, 빌드 모드, CPU/GPU·드라이버·RAM, OS, 실제 내부 해상도·DPI·활성 주사율, 전원 상태, fixture·항목 수, 동작 순서, 시작/종료와 원시 표본을 남긴다. 기준·후보는 같은 조건으로 비교한다. 서로 다른 PC의 수치를 개선 배수로 계산하지 않는다.

## 현재 실행 가능한 검사

```powershell
$fixture = (Resolve-Path -LiteralPath '.tools/fixtures/trailer.mp4').Path
& .\scripts\verify-stress-windows.ps1 -VideoFixture $fixture -FileCount 10000
& .\scripts\verify-profile-windows.ps1 -VideoFixture $fixture
& .\scripts\verify-profile-windows.ps1 -VideoFixture $fixture -NormalUi
```

세 명령은 순서대로 실행한다. 전체 후보 검사에 이미 포함된 범위를 같은 후보에서 다시 반복하지 않는다. CPU·GPU 표본은 대상 앱을 확인하고 지정한 사용자 동작을 수행하는 동안 별도로 수집한다.

```powershell
& .\scripts\measure-runtime.ps1 -Label privacy-ui -Seconds 30
```

이 명령은 조작을 자동으로 재생하지 않는다. 여러 `soft_vault` 프로세스가 있으면 경로·PID로 실제 대상만 해석한다. `-Label`은 결과 파일 이름에 사용하므로 실행을 구분하는 이름을 쓴다.

## 시나리오와 해석

| 범위 | 현재 시나리오 | 해석 한계 |
| --- | --- | --- |
| 파일 스캔 | 작은 고유 파일 1만 개, 최초/재스캔·검색·일괄 편집 | 대형 영상 1만 개의 디코딩이 아님 |
| DB | 합성 카탈로그 5만 행, 검색·컬렉션·중복 | 실제 모든 폴더·디스크 환경을 대신하지 않음 |
| 동시 작업 | 편집 200회, 이동 96회, 동시 백업·스캔 | 무제한 동시성과 장시간 안정성을 보장하지 않음 |
| 파일 장애 | 64MiB 복사·취소·디스크 부족 주입·프로세스 종료 복구 | 실제 물리 디스크 부족·분리와 구분 |
| UI | 영상 전환 40회, 전체화면/최소화/복원 12회, 1만 행 스크롤·검색·크기 변경 | 짧은 반복 검사이며 수시간 soak가 아님 |
| 일반 UI profile | 샘플 4영상 탐색·검색·상세·재생, 실제 프레임 수집 | 특정 환경·작업의 표본 |

시간·메모리 상한은 [파일 부하](../test/load_benchmark_test.dart), [DB 부하](../test/catalog_benchmark_test.dart), [UI 스트레스](../integration_test/stress_flow_test.dart)의 assertion을 기준으로 한다. 문서의 옛 수치가 코드와 다르면 먼저 차이를 검토한다. 단순히 느린 실행을 통과시키려고 상한을 올리지 않는다.

CPU는 전체 논리 프로세서 기준 비율, GPU는 수집한 엔진 사용률, 메모리는 해당 지표의 정의를 함께 적는다. GPU shared memory를 추가 전용 VRAM으로 더하지 않는다. build/raster P95는 평균 FPS가 아니다. UI 진입·검색 지연에 포함된 테스트 대기와 프레임 집계의 warm-up 포함 여부도 남긴다.

원시 표본이 적으면 개수와 개별 값을 공개하고 작은 표본의 백분위수를 일반 성능으로 해석하지 않는다. 동일 조건에서 다시 재현할 사유가 생기면 기준·후보 비교 쌍을 반복한다. 프로세스 재시작이 OS 파일 캐시까지 비운 것은 아니다.

## 원인 조사와 다음 실기

[diagnose-ui-windows.ps1](../scripts/diagnose-ui-windows.ps1)은 렌더러·아이콘 합성·팝업 등 원인 분리 검사에 사용한다. `-Trace`의 타임라인은 `tool/summarize-timeline.cjs`로 요약한다. 조사 반복을 독립 회귀 테스트 수에 더하지 않는다.

UHD 630 개발 PC에서 확인한 Skia·SVG 수정의 결과는 [검증 기록](verification/2026-11-08-windows.md)에 있다. RTX Windows와 M4 Mac의 성능은 아직 측정하지 않았다.

장시간 검사는 별도 계획으로 영상 길이·코덱·해상도·전환 횟수·실측 시간을 정하고 시작/중간/종료의 메모리·자원·응답·드롭 프레임을 기록한다. 현재 2시간 전용 자동화나 합격 결과는 없다. 4K HDR 지속 재생은 [원격 실기 검증](remote-testing.md)의 실제 출력 확인과 함께 진행한다.
