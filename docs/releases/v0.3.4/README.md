# Soft Vault 0.3.4

영상 탐색 입력을 빠르게 반복하거나 재생바를 드래그할 때의 반응을 개선했습니다.

## 변경 사항

- 방향키를 빠르게 여러 번 눌러도 이동 거리가 누락되지 않도록 입력 목표를 누적합니다.
- 재생바를 드래그하는 동안 미리보기 요청을 조절하고, 놓는 순간 선택한 위치로 정밀하게 이동합니다. 1초 단위 이동과 탐색 되돌리기를 유지합니다.
- 다른 영상을 열 때 이전 영상의 대기 중인 탐색 요청을 취소합니다. 일시정지·음량·배속 상태와 영상 끝에서 다시 탐색하는 동작을 검증합니다.
- 재생·탐색 중 자동 폴더 검색과 썸네일·메타데이터 추출을 미루고, 일시정지하면 다시 진행합니다. 사용자가 직접 실행한 재검색은 계속 사용할 수 있습니다.
- 재생 위치가 바뀔 때 타임라인만 갱신하여 재생 컨트롤 전체를 반복해서 구성하는 일을 줄였습니다.

## 설치와 업데이트

- [Windows x64 설치 EXE](https://github.com/poyal/soft-vault/releases/download/v0.3.4/SoftVault-0.3.4-Windows-x64-Setup.exe)
- [Apple Silicon Mac DMG](https://github.com/poyal/soft-vault/releases/download/v0.3.4/SoftVault-0.3.4-macOS-arm64.dmg)
- 기존 앱에서는 **설정 → 앱 정보·업데이트 → 지금 확인 → 다운로드 → 업데이트 후 재시작**으로 적용합니다. `.svupdate`와 `update.json` 파일은 앱이 자동으로 사용합니다.

Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않습니다. Mac 앱은 로컬 서명이며 자동 업데이트의 Ed25519 서명은 OS 코드 서명과 별개입니다.

검사 결과와 장시간 재생 측정의 범위·제한은 [0.3.4 검증 기록](https://github.com/poyal/soft-vault/blob/main/docs/releases/v0.3.4/VERIFICATION.md)에 기록합니다. 상세 성능 비교는 [탐색·재생 성능 기록](https://github.com/poyal/soft-vault/blob/main/docs/verification/2026-11-15-playback-quality.md)을 참고해 주세요.

설치 진단의 4K60 재생에서는 구버전과 후보 모두 렌더 드롭이 관측됐습니다. 30분 검사는 재생 지속·반복·메모리·탐색 검증이며 무드롭 재생 보장이 아닙니다. 조건과 비교 결과는 위 검증 기록을 참고해 주세요.

## 배포 파일

| 파일 | 크기(byte) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.3.4-Windows-x64-Setup.exe | 89115578 | `70cce97660f94b9500314aebfe1bbb7e05ec7bd407c954b3319cb3ef33002dce` |
| SoftVault-0.3.4-Windows-x64-Setup.exe.sha256 | 105 | `9246946a251ea7e4c0a0ed835b2d8b6a51a6df59f98585659ab5df6a58a9a5b0` |
| SoftVault-0.3.4-macOS-arm64.dmg | 95000424 | `2d36c61cc65d18b5e1aee0f1d5b2041e91cfa04c05774676953c257e9d1a0400` |
| SoftVault-0.3.4-macOS-arm64.dmg.sha256 | 98 | `9b52e09794165a525a62a770d9c62476c29ddfa46dc2c4a36dfa6b860ddd2ecd` |
| SoftVault-Windows.svupdate | 117189529 | `c3c1277b006b999819c4439d896fb0e545dc52f09fa5912b21b00b0e5bc91f3d` |
| SoftVault-macOS-arm64.svupdate | 86719733 | `a711985c0f1d9cc24f8addfba86e2c27385590a7938f8ece5c663a421723b7b9` |
| update.json | 446 | `197ae5bee2703db8200178f18d05f48b23ca653f64a8cd29235e3316d35868f0` |
| update.json.sig | 88 | `5797893564114964f4669ff2c70f6cb223152b46b409235dcfdfaba1630343c2` |
