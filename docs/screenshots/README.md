# 사용자 매뉴얼 스크린샷

README의 이미지는 샘플 자료를 사용하는 실제 Windows 네이티브 Flutter 앱에서 캡처했다. HTML 디자인 시안을 앱 실행 화면으로 사용하지 않았다. 1280 × 800 클라이언트 영역이며 창 테두리는 포함하지 않는다. 촬영 날짜는 2026-11-08이고, 파일별 시각·원본 경로·SHA-256은 [manifest.json](manifest.json)에 보존한다.

| 파일 | 화면 | 생성 테스트 |
| --- | --- | --- |
| library.png | 영상 목록과 미리보기 | design_parity_test |
| settings-library.png | 라이브러리 설정 | design_parity_test |
| actors.png | 배우 전체와 목록 | design_parity_test |
| playback.png | 실제 영상 재생 | app_playback_test |
| details.png | 상세정보 읽기 화면 | design_parity_test |
| scenes.png | 장면 북마크 | extended_flow_test |
| privacy.png | 사생활 보호 설정 | privacy_flow_test |
| backup.png | 카탈로그 백업과 복원 | design_parity_test |

테스트 카탈로그의 제목·배우·태그는 샘플 데이터다. 라이브러리 화면의 영상 설명과 썸네일은 디자인 비교용 fixture이며, 표시된 4K·HEVC 정보만으로 해당 코덱 재생을 증명하지 않는다. 재생 화면은 샘플 영상의 실제 디코딩 결과다. 원본 사진·샘플 미디어의 출처는 [외부 구성 요소 고지](../../THIRD_PARTY_NOTICES.txt)를 함께 확인한다.

변경되지 않은 Windows 화면을 재사용했으며, 이 이미지를 이후 릴리즈 후보나 Mac에서 새로 촬영한 것처럼 표시하지 않는다. 스크린샷은 사용법 설명 자료이고 배포 파일의 검증 증거는 별도의 검증 기록으로 관리한다.

문서 작성 방식은 같은 작업 공간의 perilog·tempos README 작성 가이드에서 설치부터 실제 작업까지 안내하는 순서, 화면 가까이 배치한 이미지, 샘플 데이터 사용, 캡처 출처 기록 원칙을 참고했다. 다른 앱의 화면이나 테스트 결과는 복사하지 않았다.
