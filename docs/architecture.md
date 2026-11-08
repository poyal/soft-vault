# 구현 구조와 변경 경계

## 시작과 화면

[main.dart](../lib/main.dart)는 Flutter·media_kit·window_manager를 초기화한다. 정상 시작은 `PrivacyGate`가 잠금 설정을 읽고 인증하거나 첫 설정 선택을 마친 뒤 라이브러리를 연다. 인증 전에는 `VaultHome`·플레이어·목록·앱 기능 단축키를 만들지 않는다. `--verify-install`은 별도의 임시 데이터로 설치 사본을 검사하는 진입점이다.

| 책임 | 구현 |
| --- | --- |
| 화면 상태·재생기 수명 | `main.dart`, `home_features.dart`, `extended_features.dart` |
| 화면 배치·공통 스타일 | `deck.dart`, `design.dart`, `design_icons.dart` |
| 목록·배우·태그·상세 | `file_list.dart`, `catalog_panels.dart`, `detail_dialog.dart` |
| 통합 설정·키 설정 | `settings_panel.dart`, `key_bindings.dart` |
| 잠금 저장·인증·UI | `privacy_lock.dart`, `privacy_crypto_windows.dart`, `privacy_ui.dart` |
| 폴더·스캔·SQLite | `library.dart`, `catalog_scan.dart`, `catalog_schema.dart` |
| 검증 이동·복구 이력 | `file_jobs.dart` |
| 재생 계약·네이티브 연결 | `playback.dart`, `native_playback.dart`, `player_controls.dart` |
| 메타데이터·장면·미리보기 | `media_tools.dart`, `hover_preview.dart` |
| 스마트 조건·장면·규칙·NFO | `advanced_catalog.dart`, `rule_runner.dart`, `nfo_service.dart` 및 관련 대화상자 |

## 데이터와 불변 조건

현재 카탈로그 SQLite 스키마는 3이다. 초기 생성·v2 이전과 기존 백업 호환성을 함께 유지한다. 영상의 ID가 배우·태그·장면·이어보기·이동 이력 연결의 기준이며, 이동 뒤 새 영상으로 재등록해서 기록을 잃어서는 안 된다.

폴더 스캔과 파일 변경은 `Library.fileOperation`을 통해 같은 라이브러리 인스턴스 안에서 직렬화한다. 이 장치가 여러 앱 프로세스나 다른 컴퓨터까지 잠그는 분산 잠금이라고 설명하지 않는다. 일괄 편집·백업·복원은 SQLite 트랜잭션 경계와 참조 무결성을 확인한다.

파일 이동은 작업 이력·목적지 충돌·검증 복사·재시도·중단 복구를 다룬다. 취소·실패 뒤 원본과 기록이 어떤 상태인지 명시해야 한다. 사용자 파일의 삭제·덮어쓰기를 오류 복구의 임의 기본값으로 삼지 않는다.

`privacy.sqlite`는 카탈로그와 분리되어 있다. JSON 카탈로그 복원으로 기존 잠금이 해제되거나 검증값이 내보내지지 않아야 한다. 원본 영상·썸네일 캐시·비밀번호 저장소는 각각 다른 수명과 백업 범위를 갖는다. 상세 경계는 [사생활 보호와 데이터](privacy-and-data.md)를 따른다.

## 재생과 네이티브 경계

새 영상을 열 때 음량 0%, Esc의 음량 0% 적용 후 최소화, 복원 시 음량 유지가 재생 계약이다. 화면 클릭의 재생·일시정지는 현재 음량과 위치를 보존한다. 지금 잠그기는 화면을 가리고 음량을 0으로 만든 뒤 재생을 멈추고 잠금 화면으로 전환한다.

FFmpeg·ffprobe는 메타데이터·썸네일·장면·무음 미리보기를 담당하고 media_kit/libmpv는 실제 재생을 담당한다. 영상이 디코딩된 사실과 OS 디스플레이의 HDR 출력은 별개의 검증 경계다.

현재 Windows 실행기는 Skia를 명시적으로 선택한다. `DesignIcon`은 SVG에 색을 직접 지정해 아이콘별 런타임 색상 필터의 추가 합성을 줄인다. 이 구현을 다른 GPU·Mac에서도 더 빠르다고 일반화하지 않는다.

## 테스트를 바꿀 때

테스트용 `VaultApp(library: ...)`는 개별 화면을 바로 구성할 수 있다. 이 경로가 운영 시작의 비밀번호 검사를 검증하는 것은 아니다. 잠금은 `privacy_flow_test.dart`의 실제 gate 경로를 함께 검사한다.

OS 파일 선택기의 반환값 대체, 보안 입력 컨트롤러 주입, 프로세스 장애 주입은 각각의 검사 범위다. 실제 OS 선택기·키보드·물리 장치 검사를 수행한 것처럼 합치지 않는다. 기능별 연결은 [E2E 기준](e2e.md)에 둔다.
