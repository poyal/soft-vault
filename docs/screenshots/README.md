# 사용자 매뉴얼 스크린샷

README의 이미지는 합성 카탈로그·샘플 영상을 사용하는 실제 Windows·Mac Flutter 앱에서 캡처했습니다. HTML 시안을 앱 실행 화면으로 사용하지 않았습니다. 2026-11-11, 0.3.0+4 후보의 1280 × 800 클라이언트 영역이며 창 테두리는 포함하지 않습니다. 파일별 촬영 시각·원본 경로·소스 커밋·SHA-256은 [manifest.json](manifest.json)에 기록합니다.

| 파일 | 화면 | 생성 테스트 |
| --- | --- | --- |
| library.png | 영상 목록과 미리보기 | design_parity_test |
| settings-library.png | 라이브러리 설정 | design_parity_test |
| actors.png | 배우 전체와 목록 | design_parity_test |
| playback.png | Windows 영상 재생 | app_playback_test |
| macos-playback.png | Mac mini M4 영상 재생 | app_playback_test |
| details.png | 상세정보 읽기 화면 | design_parity_test |
| scenes.png | 장면 북마크 | extended_flow_test |
| privacy.png | 사생활 보호 설정 | privacy_flow_test |
| backup.png | 카탈로그 백업과 복원 | design_parity_test |

모든 이미지는 debug 모드의 네이티브 통합 검사에서 촬영했습니다. 소스 4493ead 이후 1ece9fb에서는 메뉴 위치와 스크롤을 반영하는 시나리오 테스트만 바뀌었고 앱 코드는 동일합니다.

화면의 제목·배우·태그·설명은 합성 자료입니다. 디자인 비교용 썸네일과 4K·HEVC 표시는 해당 코덱 재생 증거가 아닙니다. 재생 화면은 샘플 영상의 실제 디코딩 결과입니다. [외부 구성 요소 고지](../../THIRD_PARTY_NOTICES.txt)와 [후보 검증 기록](../releases/v0.3.0/VERIFICATION.md)을 함께 확인하세요.

0.3.1: `library.png`와 `details.png`는 `integration_test/redesign_flow_test.dart`의 Windows profile 실제 실행 캡처로 갱신했습니다. 합성 카탈로그의 태그, 즉시 평점 저장, 재생 대기 화면을 표시합니다. 나머지 이미지는 이전 버전 캡처입니다.
