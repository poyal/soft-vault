# Soft Vault 0.2.1

폴더를 처음 연결할 때 영상 전체를 검사하느라 목록이 오랫동안 비어 있던 문제를 수정했다.

- 폴더 연결과 자동 재검색은 파일명·경로·크기·수정 시각만 읽고 목록을 표시한다.
- 썸네일은 목록 표시 후 별도로 만든다. 진행 개수를 확인하고 중지·계속할 수 있다.
- 중복 비교의 동일 크기 후보와 파일 이동의 무결성 검사에서만 필요한 전체 내용 검사를 수행한다.
- 썸네일 생성 도중 변경한 대표 이미지·파일 경로를 이전 작업이 덮어쓰지 않도록 했다.
- 동일한 실패 영상의 썸네일 작업을 한 세션에서 반복하지 않는다.
- Mac에서 창 크기 변경 중 발생한 Impeller 그래픽 엔진 충돌을 피하도록 Skia 렌더러를 사용한다.

Windows x64 설치 EXE와 Apple Silicon Mac DMG를 제공한다. 앱 내 업데이트용 파일은 `.svupdate`이며 수동 설치에는 EXE·DMG를 사용한다. Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않는다.

원본 영상·카탈로그·앱 잠금 설정을 유지한다. 앱 밖에서 이동한 미검증 파일은 기존 항목을 오프라인으로 보존하며 필요하면 파일 재연결을 사용한다. 앱 내부 이동은 ID와 분류를 유지한다.

[검증 기록](VERIFICATION.md) · [사용자 매뉴얼](../../../README.md)

## 배포 파일

| 파일 | 크기(byte) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.2.1-macOS-arm64.dmg | 95025686 | `fd9d9bf419322a3e74786605c4bee0973fb2efde1d38f4593c6508b8ac5afba3` |
| SoftVault-0.2.1-macOS-arm64.dmg.sha256 | 98 | `609abb696d8835455402048cde440b509f015d5a236699860383919d987ab27f` |
| SoftVault-0.2.1-Windows-x64-Setup.exe | 89098768 | `1027ba2e6d8d491987beb38fd7e9c64340a3bbddd152928dec8ccb1890f9108a` |
| SoftVault-0.2.1-Windows-x64-Setup.exe.sha256 | 105 | `f3dab3d8b35880742b24cf1247f41ee8e446471a602f285bdf66987feb70e897` |
| SoftVault-macOS-arm64.svupdate | 86695190 | `3f1196eecc1865fbdab7e42a9c04265464fa6a42715c9cc94806a0eb6cd053cf` |
| SoftVault-Windows.svupdate | 117175832 | `b5ff6040c06bfd895f69919784167c64b59761b5d8bef081cffb059d4f27a11c` |
| update.json | 446 | `4972c45a3c198d81a66eafce8287e9f8243245c7a388e817abd85a9f1dbed5e1` |
| update.json.sig | 88 | `f81c3063f74f888a5565d05213cc4db33ea71c873fa1be6d8d804f51b6964c8a` |
