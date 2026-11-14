# Soft Vault 0.3.3

배우 이미지의 HTTPS 주소를 불러올 때 `Invalid request method`로 실패하던 문제를 수정했습니다.

## 변경 사항

- HTTPS 이미지 연결에 TLS 소켓을 사용하도록 수정했습니다. 검증한 공개 IP 주소를 고정하면서 원래 호스트 이름의 SNI와 인증서 검증을 유지합니다.
- 공개 주소·리다이렉트·파일 크기 제한을 유지하고 실제 HTTPS 이미지 다운로드와 디코딩 회귀 검사를 추가했습니다.
- 기존 자동 업데이트 공개키를 유지합니다.

## 설치와 업데이트

- [Windows x64 설치 EXE](https://github.com/poyal/soft-vault/releases/download/v0.3.3/SoftVault-0.3.3-Windows-x64-Setup.exe)
- [Apple Silicon Mac DMG](https://github.com/poyal/soft-vault/releases/download/v0.3.3/SoftVault-0.3.3-macOS-arm64.dmg)
- 기존 앱에서는 **설정 → 앱 정보·업데이트 → 지금 확인 → 다운로드 → 업데이트 후 재시작**으로 적용합니다. `.svupdate`는 앱 전용 파일입니다.

Windows 코드 서명과 Apple Developer ID 서명·공증은 제공하지 않습니다. Mac 앱은 로컬 서명이며 자동 업데이트의 Ed25519 서명은 OS 코드 서명과 별개입니다.

검사 범위와 중단 후 재개 기록, 설치·서명·배포 파일 검증 근거는 [0.3.3 검증 기록](https://github.com/poyal/soft-vault/blob/main/docs/releases/v0.3.3/VERIFICATION.md)에 기록합니다. 실제 사용자 라이브러리 전체 업그레이드, 장시간 재생과 물리 HDR·스피커 출력은 자동 검사 범위와 구분합니다.

## 배포 파일

| 파일 | 크기(byte) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.3.3-Windows-x64-Setup.exe | 89092824 | `d26a6995203fc8438fb0b63942883b6f8a6efadc68ebc4e5e10236f034eda4c0` |
| SoftVault-0.3.3-Windows-x64-Setup.exe.sha256 | 105 | `892d87b4a14bd444b647eb5acbf5580783b76d832e240eeb12229307e79b52c3` |
| SoftVault-0.3.3-macOS-arm64.dmg | 95002488 | `4fab6cccf4a1462e8f886fb4a85a693b6d0323f4e5df6a8224a64e0316ee1218` |
| SoftVault-0.3.3-macOS-arm64.dmg.sha256 | 98 | `f837f8a1bf50761c44bd8ed4109c90d4ec2c27fb0a197f0a077552a46a7f88b9` |
| SoftVault-Windows.svupdate | 117175073 | `44841f3898269c8f92829ead3f67d3c64c88ee2888af75b3b4b945aa53b49537` |
| SoftVault-macOS-arm64.svupdate | 86679488 | `83b1fcb204e4f7bf65276150a13e54961b8dd427d58a6d958b4bddbdff704c1a` |
| update.json | 446 | `7e1f62aca56e85d86f3bd165a720ca9575f8c21d10f7d953abf8fe220c3b8222` |
| update.json.sig | 88 | `fee9a1f114ef9b747b2e06e06ef7fdc1ee58a278e293546c275dc1abe9382ee6` |
