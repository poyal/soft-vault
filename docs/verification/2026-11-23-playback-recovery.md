# 연속 구간 이동과 재생 중 종료 검증

2026년 11월 23~24일에 Windows와 Mac 실기에서 검증했습니다. Dart·Flutter 공통 앱을 유지하고, 같은 위치 재탐색, 이동 완료 판정, 종료 시 이어보기 저장을 수정했습니다. Windows UHD 630의 4K HEVC에서 가장 큰 속도 차이를 낸 요소는 GPU에서 디코딩한 프레임을 화면에 전달하는 방식이었습니다. [시행별 수치와 빌드 식별값](2026-11-23-playback-results.json)

## 검증한 질문

Soft Vault 0.3.4의 화면과 입력 처리는 Dart·Flutter로 작성되어 있습니다. 영상의 압축 해제와 재생 시계는 media_kit이 연결한 네이티브 libmpv가 담당합니다. Windows에서는 D3D11VA, Mac에서는 VideoToolbox를 사용합니다. FFmpeg 별도 프로세스는 썸네일 등 미디어 분석에 쓰입니다. 그래서 언어 변경, 화면 출력 경로 변경, 앱 분리를 각각 다른 실험으로 다뤘습니다.

기존판은 커밋 `81780a4` 당시의 제품 코드입니다. 첫 후보에서는 80ms 간격의 키 누름과 클릭을 150ms 동안 묶었습니다. Mac 긴 GOP 영상에서 마지막 정밀 이동이 늦어져 이 방식을 제외했습니다. Windows에서는 3840×2160 텍스처를 실제 표시 영역인 753×424로 줄이는 실험도 했습니다. UHD 630에서 키 연타 후 정지 시간의 파일별 P95가 1.65초여서 이 설정을 제품에 적용할 근거를 얻지 못했습니다.

## 다른 플레이어는 어떻게 처리하는지

| 구현 | 확인한 동작과 Soft Vault에 주는 의미 |
| --- | --- |
| mpv | 재생기는 키프레임 이동과 정밀 이동을 구분합니다. 번들 0.36의 연속 `seek`는 이전 프레임을 표시할 시간을 줄 수 있고, `time-pos` 쓰기는 절대 이동을 직접 예약합니다. [명령 구현](https://github.com/mpv-player/mpv/blob/v0.36.0/player/command.c) · [재생 루프](https://github.com/mpv-player/mpv/blob/v0.36.0/player/playloop.c) |
| VLC | Qt 타임라인은 드래그 도중 발생하는 이벤트를 제한하고 놓을 때 마지막 위치를 전달합니다. 단발 클릭, 키 입력, 드래그 종료의 비용은 다르게 측정해야 합니다. [Qt 입력 슬라이더](https://github.com/videolan/vlc/blob/3.0.23/modules/gui/qt/util/input_slider.cpp) |
| IINA | Swift UI에서 mpv를 제어하며, 자동 모드는 실제 탐색의 비용을 보고 정밀 탐색 여부를 정합니다. macOS 전용 UI도 같은 계열의 디코더를 사용할 수 있습니다. [PlayerCore](https://github.com/iina/iina/blob/v1.5.1/iina/PlayerCore.swift) |
| Apple AVPlayer | 연속 요청이 진행 중인 탐색을 계속 취소하면 목표 프레임이 거의 표시되지 않을 수 있습니다. Apple 예제는 최신 목적지를 기억하고 진행 중인 탐색의 완료 시점에 다시 요청합니다. [Apple QA1820](https://developer.apple.com/library/archive/qa/qa1820/_index.html) |
| Android Media3 | 정확한 위치와 주변 동기화 지점 사이에서 허용 오차를 명시할 수 있습니다. 미리보기의 속도와 최종 위치의 정확도를 독립적으로 검증할 이유입니다. [ExoPlayer SeekParameters](https://developer.android.com/reference/androidx/media3/exoplayer/SeekParameters) |
| GStreamer | 정확한 위치를 표시하려면 보통 앞선 키프레임에서 디코딩을 시작해야 합니다. 같은 해상도여도 키프레임 간격과 목표 위치에 따라 재생 재개 시간이 달라집니다. [탐색 설계](https://gstreamer.freedesktop.org/documentation/additional/design/seeking.html) |
| Chromium | 진행 중인 이동, 마지막으로 요청한 이동, 재생 재개 상태를 구분합니다. 같은 목표의 중복 요청을 제거하고 필요할 때 진행 중인 demux 요청을 취소합니다. [PipelineController](https://github.com/chromium/chromium/blob/main/media/filters/pipeline_controller.cc) |
| MPC Video Renderer | DirectShow용 Windows 렌더러는 DXVA2와 D3D11 하드웨어 디코더를 지원합니다. Windows 전용 출력과 공유 UI의 비용을 분리해서 시험한 근거입니다. [MPC Video Renderer](https://github.com/Aleksoid1978/VideoRenderer) |
| Jellyfin | 클라이언트의 코덱·해상도·비트레이트 제약에 따라 서버가 트랜스코딩 설정을 선택합니다. 이번 비교에서는 로컬 원본 파일을 고정했습니다. [Jellyfin 트랜스코딩](https://jellyfin.org/docs/general/post-install/transcoding/) |

기존 6종 자료에서 Windows mpv, VLC와 Mac mpv, IINA를 실제로 실행한 결과도 있습니다. Mac mpv 0.40의 정지 탐색 P95는 파일에 따라 116~474ms, IINA 1.5.1은 68~451ms였습니다. 두 결과는 디코더 재시작 시점입니다. 이번 시험은 입력 후 화면에서 처음 읽힌 프레임을 사용합니다. [기존 측정 조건과 원자료](2026-11-15-playback-quality.md)

Windows에서는 같은 번호 영상으로 libVLC 3.0.23을 별도 창에 임베드해 5초 전진 요청을 80ms 간격으로 10번 보냈습니다. 각 칸은 정지 P95 / 첫 목표 프레임 P95입니다. libVLC는 파일당 30회, 앱의 기본 화면은 파일당 8회입니다. 두 엔진의 탐색 API와 화면 표본 읽기 경로가 달라 엔진만의 속도 차이로 환산할 수는 없습니다.

| 자료 | libVLC 시험 창 | Soft Vault 수정판 기본 화면 |
| --- | ---: | ---: |
| 1080p60 H.264 | 101 / 160ms | 442 / 449ms |
| 4K60 HEVC 10비트 | 350 / 574ms | 1,344 / 1,536ms |

Mac의 mpv 0.40.0·VideoToolbox도 같은 자료에서 일시정지 상태의 정확한 탐색을 파일당 30회 실행했습니다. 디코더가 재생을 재개할 준비를 마친 시점의 P95는 1080p60 318ms, 긴 GOP 604ms, 4K60 263ms였습니다. 이 검사는 연속 입력 후 화면을 읽은 위 표와 관측 시점이 다릅니다.

## 측정 방법

- Windows 11 Home 빌드 26300, i7-8700B, Intel UHD 630 드라이버 31.0.101.2140, 데스크톱 1920×1080·59Hz와 macOS 27.2.1 빌드 26B131, Mac mini M4 16GB, 5120×2880·60Hz를 사용했습니다. 앞선 보고서의 RTX 4070 Ti Windows 수치는 이 장비의 기준값으로 사용하지 않았습니다.
- Flutter 3.47.9, Dart 3.13.7, media_kit 1.2.6과 media_kit_video 2.0.1로 빌드했습니다. 앱에 포함된 mpv 버전은 Windows `v0.36.0-403-g652a1dd907`, Mac `0.36.0`입니다. 플랫폼별 비교에서는 같은 번들의 libmpv를 사용했습니다.
- 72초짜리 1080p60 H.264, 키프레임 간격 10초인 1080p24 H.264, 15/30fps 가변 프레임레이트, 4K60 HEVC 10비트 영상을 사용했습니다. 양쪽에 같은 파일을 복사했습니다. 가변 프레임레이트 영상은 프레임을 제거하기 전에 소스 번호를 기록하므로 번호에서 원래 시각을 복원할 수 있습니다.
- Release 앱에서 실제 키 핸들러와 슬라이더 콜백을 호출했습니다. 오른쪽 키 연타, 키를 누른 채 반복, 좌우 번갈아 누름, 서로 다른 위치 클릭, 드래그를 시험했습니다. 조작별로 영상당 8회, 총 32회입니다. 로컬 파일 캐시는 비우지 않았습니다. OS 키보드 이벤트 전달 지연은 이 수치에 포함되지 않습니다.
- 앱 소유 영상의 중앙에 인코딩한 프레임 번호를 읽었습니다. 표의 정지 시간은 마지막 입력 후 2초 동안 같은 번호가 연속 관측된 가장 긴 시간입니다. 첫 목표 시간은 재생 중 시계 진행을 허용한 목표 구간에 처음 진입한 시점입니다. 2초 안에 관측하지 못한 시행은 누락 수에 포함했습니다. 화면 합성 결과를 읽는 비용과 표본 사이 간격이 포함되며, 모니터의 물리 출력과 스피커 립싱크는 측정하지 않았습니다.
- P95는 정렬 후 `ceil(0.95 × n)`번째 값입니다. 자료별 8회에서 P95는 최댓값이므로 자료별 경향과 네 파일을 동등하게 섞은 32회 결과를 함께 기록합니다. 사전 개선 기준은 정지 P95 25% 이상 및 50ms 이상 단축, 종료 P95 25% 이상 및 200ms 이상 단축입니다. 종료는 2초 이내 정상 종료와 이어보기 위치 보존도 검사했습니다.

## 언어와 OS별 앱

1080p60에서 같은 프로세스의 같은 libmpv 핸들에 같은 시점·같은 인자로 명령을 보냈습니다. Dart FFI와 최적화 C++ 순서를 번갈아 각각 30회 실행했습니다. 아래 값은 밀리초입니다. 명령 제출에는 네이티브 호출이 돌아오기까지의 대기도 포함됩니다.

| 장비·명령 경로 | 명령 제출 P95 | 화면 정지 P95 | 첫 목표 프레임 P95 |
| --- | ---: | ---: | ---: |
| Windows Dart | 4.57 | 403 | 572 |
| Windows C++ | 4.44 | 430 | 587 |
| Mac Dart | 3.65 | 321 | 492 |
| Mac C++ | 3.49 | 316 | 490 |

같은 네이티브 출력 창, 같은 디코더와 명령을 사용해 Flutter 호스트와 각 OS의 독립 재생기를 각각 30회 비교했습니다. Windows에서는 Win32와 C++를, Mac에서는 AppKit과 Swift·C++를 사용했습니다. 두 방식 모두 자기 창의 같은 바코드 위치를 같은 함수로 읽었습니다.

| 1080p60·네이티브 출력 | Flutter 호스트 정지 P95 | 독립 재생기 정지 P95 | 첫 목표 P95 (Flutter / 독립) |
| --- | ---: | ---: | ---: |
| Windows · D3D11VA 복사 | 350ms | 369ms | 547 / 549ms |
| Mac · VideoToolbox | 311ms | 299ms | 491 / 499ms |

언어 교체와 독립 앱 모두 사전 개선 기준에 미달했습니다. 두 운영체제에 공통인 탐색·카탈로그·UI 코드를 유지하기로 했습니다. 독립 재생기는 입력 스케줄러와 화면 표본 읽기를 한 루프에서 처리하므로 스케줄링 오차가 있습니다. 독립 재생기 시험 범위는 영상 재생이며, 파일 관리·잠금·설치·업데이트는 포함하지 않습니다. AVPlayer나 Media Foundation으로 재생 엔진까지 교체한 경우의 성능은 이번 실험의 범위 밖입니다.

## Windows 4K에서 정지 시간이 길어진 원인

Intel UHD 630에서 4K60 HEVC 10비트 파일의 56초 키프레임 직전으로 이동하면 이전 키프레임부터 영상을 풀어야 합니다. 기존 앱의 키 연타 시험에서 55.75~55.93초로 이동할 때 정지 시간은 약 1.38~1.53초였습니다. 목표가 56.03~56.23초인 시행에서는 약 0.19초였습니다. 같은 영상의 키프레임을 `ffprobe`로 확인했습니다.

같은 Flutter 앱에서 같은 Win32 시험 창으로 출력하면서 GPU 디코딩 방식을 바꿨습니다. 아래는 조작별 8회 중 P95이며, 디코더는 각각 libmpv의 `hwdec-current`로 확인했습니다.

| 4K60 HEVC·마지막 입력 후 최장 정지 | `d3d11va-copy` | `d3d11va` |
| --- | ---: | ---: |
| 오른쪽 키 연타 | 1,677ms | 388ms |
| 서로 다른 위치 연속 클릭 | 1,615ms | 537ms |
| 좌우 번갈아 누름 | 1,461ms | 682ms |

키 연타 후 첫 목표 프레임 P95도 1,677ms에서 731ms로, libmpv가 보고한 오디오·비디오 시계 차의 절댓값 P95는 411ms에서 6ms로 줄었습니다. 이 장비에서 가장 큰 개선은 디코딩한 프레임을 시스템 메모리로 복사하는 경로를 피했을 때 나타났습니다. [mpv 하드웨어 디코딩 옵션](https://mpv.io/manual/stable/#options-hwdec)

제품의 Flutter 텍스처에 `d3d11va`를 강제하는 시험에서는 `hwdec-current=no`가 기록됐습니다. 기존 화면에 이 옵션만 적용하면 이 장비에서는 소프트웨어 디코딩으로 전환됩니다. 따라서 제품 기본값은 자동 선택을 유지했습니다. 직접 출력의 성능을 제품에 적용할 범위는 Windows 영상 표면입니다. 자막·컨트롤 겹침, 전체 화면, 창 크기 및 DPI 변경, 잠금 시 영상 차폐, 다른 GPU의 폴백을 실제 기본 화면에서 검증해야 합니다.

기존 화면에서도 사용할 수 있는 설정은 **설정 → 재생 → 음성 · 자막 · 디코더 → 소프트웨어 디코딩**입니다. 동일한 UHD 630 장비와 4K 파일에서 수정판의 자동 선택과 이 옵션에 해당하는 설정을 조작별로 각각 8회 비교했습니다. 소프트웨어 디코딩 측정에서는 설정 적용 후 같은 파일을 다시 열고 실제 디코더가 변경됐는지 확인했습니다. 키 연타의 정지 P95는 **1,344 → 596ms**, 연속 클릭은 **1,416 → 586ms**, 좌우 교대는 **1,446 → 614ms**였습니다. CPU 디코딩은 이 장비에서 시도할 수 있는 대안입니다. 다른 GPU와 코덱에서의 지속 재생 품질, 전력 소비는 이번 수치로 판단할 수 없습니다.

## 제품에 적용한 변경

- 재생 중 예전에 클릭했던 시간을 다시 클릭하면 이전 요청의 완료 상태 때문에 이동을 건너뛰던 오류를 수정했습니다. 새 조작을 시작하면 해당 완료 상태를 지웁니다. A로 이동 중 B를 거쳐 다시 A를 요청하면 진행 중인 A의 정확한 이동을 재사용합니다. [탐색 제어기](../../lib/seek_controller.dart)
- Windows 초기 검사에서는 10초에서 5초 전진 네 번의 목표가 20초가 된 사례가 있었습니다. 이 검사는 파일 열기 완료를 기다리지 않아 첫 이동이 접수됐는지 단정할 수 없었습니다. 파일 열기와 탐색 활성화를 기다리도록 고친 대조군에서도 드래그 후 30초로 되돌리기가 완료됐을 때 앱이 33.125초를 보고한 시행이 있었습니다. 최종판은 libmpv의 디코딩 시각과 media_kit이 앱에 발행한 시각이 모두 목표 범위에 들어올 때 정밀 이동을 완료합니다. 통합 검사는 입력의 시작 위치와 계산된 목표, 실제 재생 시각, 되돌리기 위치를 각각 확인합니다. [재생 시각 확인](../../lib/native_playback.dart) · [통합 검사](../../integration_test/seek_flow_test.dart)
- 종료 시 탐색이 끝나기 전이면 마지막으로 확인한 위치를 저장합니다. 주기적인 저장과 마지막 저장을 순서대로 실행해 오래된 쓰기가 마지막 값을 덮는 경우를 막았습니다. [이어보기 저장](../../lib/extended_features.dart)
- 종료 요청에서 음소거, 일시정지, 이어보기 저장, 폴더 감시와 백그라운드 분석 정리를 함께 시작합니다. 열린 파일 전환 요청도 정리가 끝날 때까지 기다립니다. Windows는 창을 먼저 숨기고, Mac은 영상 텍스처가 해제될 때까지 창을 유지합니다. Mac의 앱 종료 요청도 같은 정리 작업을 기다립니다. [종료 처리](../../lib/main.dart)
- 연속 입력에 고정 150ms 대기를 추가하는 방식과, libmpv의 비동기 위치 명령 및 짧은 완료 대기를 조합하는 방식도 비교했습니다. 두 방식 모두 전체 재생 조건의 채택 기준을 충족하지 못해 제외했습니다.

실제 앱에서 20초로 이동해 재생 시계가 20.9초를 넘도록 기다렸다가, 타임라인의 20초 지점을 다시 클릭했습니다. 목표 프레임이 2초 안에 관측된 횟수는 Windows에서 **0/30 → 30/30**, Mac에서 **2/30 → 30/30**이었습니다. 수정판에서 다시 클릭한 뒤 목표 프레임이 보이기까지의 P95는 각각 97ms, 452ms였습니다. 이전 버전은 클릭을 건너뛰어도 계속 재생하므로 화면 정지 시간만으로는 이 오류를 알아낼 수 없습니다.

## 기본 화면의 연속 이동 실측

각 칸은 네 영상을 합친 32회에서 마지막 입력 직후의 정지 P95와 첫 목표 프레임 P95 순서입니다. 단위는 ms입니다.

| 조작 | Windows 기존 | Windows 수정 | Mac 기존 | Mac 수정 |
| --- | ---: | ---: | ---: | ---: |
| 오른쪽 키 연타 | 1,464 / 1,662 | 1,306 / 1,498 | 444 / 517 | 651 / 659 |
| 오른쪽 키 길게 누름 | 1,388 / 1,601 | 1,279 / 1,492 | 314 / 564 | 470 / 695 |
| 좌우 번갈아 누름 | 1,700 / 459 | 1,323 / 317 | 422 / 300 | 501 / 425 |
| 서로 다른 위치 연속 클릭 | 1,483 / 1,686 | 1,379 / 1,552 | 510 / 510 | 440 / 442 |
| 슬라이더 드래그 | 1,591 / 1,699 | 1,469 / 1,488 | 304 / 316 | 489 / 525 |

수정판은 각 OS에서 160회 모두 2초 안에 목표 프레임을 표시했습니다. 기존판은 Windows 연속 클릭에서 한 번 놓쳤습니다. 첫 목표 프레임 이후에도 화면이 다시 멈출 수 있어 두 수치를 따로 기록했습니다. Windows에서 4K60 키 연타의 정지 P95는 기본 화면 기준 1,527ms에서 1,344ms로 줄었습니다. 네 파일을 합친 Windows 정지 P95는 다섯 조작에서 모두 낮아졌지만 사전 개선 기준에는 미달했습니다. Mac은 연속 클릭에서 빨라졌고, 키 연타·길게 누름·교대 입력·드래그에서는 더 긴 정지를 관측했습니다.

앱 발행 시각 확인을 추가하기 전의 수정판은 Mac 긴 GOP 영상에서 기준판과 실행 순서까지 교차해 재측정했습니다. 각 8회에서는 키 연타 정지 P95가 434 → 562ms, 길게 누름은 595 → 587ms, 좌우 교대는 655 → 840ms였습니다. 순서를 뒤집어 수동 키 입력을 조건별 **30회** 측정하자 연타는 **662 → 625ms**, 교대는 **712 → 640ms**였습니다. 교대 입력의 첫 목표 프레임 P95는 498 → 643ms로 늘었습니다. 정지 시간 차이의 방향이 반복 실험에서 바뀌었으므로 Mac 키 조작에 속도 개선을 보장할 수 없습니다.

## 재생 중 종료

종료 요청부터 OS 프로세스가 끝날 때까지 별도의 부모 프로세스에서 측정했습니다. 이어보기는 종료한 프로세스의 SQLite 파일을 다시 열어 확인했습니다. 재생 중, 연속 이동 중, FFmpeg 분석 프로세스 동작 중을 각각 30회씩 실행했습니다. Windows에서는 창 숨김 호출의 완료 시점, Mac에서는 영상을 덮는 Flutter 프레임의 완료 콜백 시점을 기록했습니다.

Mac에서도 창을 즉시 숨긴 시험판은 재생 중 30회 중 13회, 이동 중 30회 중 16회 비정상 종료했습니다. 수정판은 Mac에서 먼저 재생 화면을 가리고 영상 표면을 해제한 뒤 창을 닫습니다. Windows에서는 정리를 시작할 때 창을 숨깁니다.

| 닫기 요청 시점 | Windows 완전 종료 P95 (기존 → 수정) | 수정판 창 숨김 P95 | Mac 완전 종료 P95 (기존 → 수정) | 수정판 차폐 프레임 P95 |
| --- | ---: | ---: | ---: | ---: |
| 재생 중 | 452 → 381ms | 20ms | 117 → 112ms | 18ms |
| 연속 이동 중 | 338 → 345ms | 16ms | 142 → 124ms | 21ms |
| FFmpeg 분석 중 | 545 → 335ms | 16ms | 270 → 263ms | 17ms |

두 장비 모두 수정판 90/90회가 2초 이내에 정상 종료했고 이어보기 위치도 유지했습니다. **연속 이동 중 닫기의 위치 보존은 양쪽 모두 0/30에서 30/30으로 개선됐습니다.** Windows에서 FFmpeg 분석 중 완전 종료가 약 210ms(38%) 빨라져 사전 기준을 충족했습니다. Windows에서 이동 중 닫을 때의 완전 종료는 약 7ms 더 걸렸습니다. 이번 기준판과 수정판의 창 닫기 실험에서 수초 이상 걸리는 현상은 재현되지 않았습니다.

Mac의 앱 전체 종료는 Cmd+Q와 Dock 종료가 사용하는 AppKit의 `NSApp.terminate`를 호출했습니다. 최초 30회 중 한 번은 호출 직전에 기록한 위치보다 5.017초 뒤의 값이 저장됐습니다. 요청 전달 중 마지막 탐색이 끝날 가능성을 구분하기 위해 Flutter가 종료 요청을 받은 순간의 시각도 기록했습니다. 전달 시각을 추가로 기록한 중간판의 30회와 최종판의 30회는 위치 보존 검사를 모두 통과했습니다. 최종판의 완전 종료 P95는 134ms였습니다. 별도의 통합 검사에서도 12초에서 40초로 이동을 시작한 직후 종료해 12초가 저장되는지 검증했습니다.

## 재현

Windows와 Mac에서 단위·위젯 검사 134개가 각각 통과했고, 플랫폼 전용 또는 외부 네트워크 입력이 필요한 검사 2개가 각 장비에서 건너뛰어졌습니다. 양쪽 정적 분석도 통과했습니다. Windows에서는 파일 준비를 기다리는 최종 프로필 통합 검사를 다섯 번 실행했고, 매번 탐색·되돌리기·종료 저장 시나리오를 통과했습니다. Mac에서도 같은 최종 통합 검사와 일반 Release 앱 빌드를 확인했습니다.

1. `dart tool/seek_recovery_media.dart <ffmpeg> <자료 폴더>`로 번호가 있는 테스트 영상을 생성합니다. 기존 파일을 덮어쓰지 않습니다.
2. 각 소스에서 `flutter build windows --release --no-pub -t tool/seek_recovery_probe.dart` 또는 `flutter build macos --release --no-pub -t tool/seek_recovery_probe.dart`로 재생 측정용 앱을 만듭니다. 기준판에도 동일한 테스트 진입점과 보조 테스트 파일을 둡니다.
3. `dart run tool/run_seek_recovery.dart <기준 앱> <후보 앱> <자료 폴더> <새 결과 폴더> 8`을 실행합니다. `node tool/summarize-seek-recovery.cjs <동일 장비·버전의 JSON 파일들>`로 표본 수, 목표 미관측 횟수, P50/P95와 해시를 얻습니다.
4. 종료는 별도의 `tool/shutdown_probe.dart` 진입점으로 빌드한 뒤 `dart run tool/measure_shutdown.dart <앱> <4K 파일> normal playing,seeking,extracting 30 <결과 이름>`을 실행합니다. 매번 임시 카탈로그를 새로 만들고, 프로세스가 끝난 뒤 SQLite를 다시 열어 이어보기 위치를 확인합니다.
5. 일반 앱을 빌드할 때는 `flutter build windows --release` 또는 `flutter build macos --release`를 사용합니다. 위 측정용 진입점은 개발 전용입니다.

기준 커밋의 종료 측정용 진입점에서는 `VaultHome` 생성자의 `onCloseStage` 인자를 생략하고 예상 위치로 당시 제공되던 `home.player.state.position`을 기록합니다. 수정판은 진행 중 이동의 마지막 확인 위치를 기록합니다. 독립 통합 검사에서는 12초에 일시정지한 실제 플레이어 시각을 먼저 읽고, 40초 이동 직후 종료 처리를 시작해 저장값을 그 시각과 대조합니다. `integration_test/seek_flow_test.dart`를 실행할 때 `--dart-define=VIDEO_FIXTURE=<trailer.mp4 절대 경로>`를 전달합니다.

Windows의 x64 Native Tools 환경에서 테스트 모듈과 독립 재생기는 다음처럼 빌드할 수 있습니다.

```bat
cl /nologo /O2 /EHsc /LD tool\native\seek_trial.cpp tool\native\trial_window_win.cpp user32.lib gdi32.lib /link /out:seek_trial.dll
cl /nologo /O2 /EHsc tool\native\standalone_trial.cpp tool\native\seek_trial.cpp tool\native\trial_window_win.cpp user32.lib gdi32.lib /Fe:standalone_trial.exe
```

Mac에서는 같은 C++ 명령 구현과 AppKit 시험 창을 빌드합니다. `frameworks`는 이 앱의 `Contents/Frameworks` 절대 경로입니다.

```sh
clang++ -O2 -std=c++17 -fobjc-arc -dynamiclib tool/native/seek_trial.cpp tool/native/trial_window_mac.mm -framework AppKit -framework CoreGraphics -o libseek_trial.dylib
clang++ -O2 -std=c++17 -c tool/native/standalone_trial.cpp -o standalone.o
swiftc -O tool/native/standalone_mac.swift standalone.o -L . -lseek_trial -lc++ -framework AppKit -Xlinker -rpath -Xlinker @executable_path -Xlinker -rpath -Xlinker "$frameworks" -o standalone
```

언어 비교는 측정용 앱에 `<1080p60.mkv> <결과.json> 30 dart,cpp <테스트 DLL 또는 dylib 절대 경로>`를 전달합니다. 같은 명령을 직접 출력 창에서 재생하려면 `30 cpp <모듈> native-window`를 사용합니다. 독립 실행 파일에는 `<번들 libmpv> <1080p60.mkv> <결과.json> 30 <창 너비> <창 높이>`를 전달합니다. 창 크기는 같은 앱 시험의 `windowSize`에서 가져옵니다.

Windows 디코더 비교는 측정용 앱에 `<4k60.mkv> <결과.json> 8 taps,clicks,alternate <테스트 DLL> <출력 모드>`를 전달합니다. `native-window`는 직접 출력 창에 `d3d11va-copy`, `native-hw`는 같은 창에 `d3d11va`를 요청합니다. `texture-hw`와 `texture-software`는 기본 Flutter 영상 표면에 각각 `d3d11va`, `no`를 요청합니다. 결과의 `initial.hwdec-current`에서 실제 디코더를 확인합니다. 같은 위치를 다시 클릭하는 검사는 `<1080p60.mkv> <결과.json> 30 revisit`입니다.

VLC 시험은 Windows에서 `python tool/benchmark-vlc.py --vlc <VLC 설치 폴더> --fixtures <자료 폴더> --output <결과.json> --seeks 30 --filter 4k60 --frame-window <테스트 DLL>`로 실행합니다. `--filter 1080p60`으로 1080p도 측정할 수 있습니다. libVLC API로 80ms 간격 이동을 전송하며 VLC Qt의 키보드 입력 처리 시간은 포함되지 않습니다.
