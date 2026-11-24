# Soft Vault 0.3.5

영상을 재생하다가 타임라인에서 같은 지점을 다시 눌러도 해당 위치로 돌아갑니다. 구간 이동 중 앱을 닫으면 다음에 열 때 마지막으로 확인된 재생 위치에서 이어볼 수 있습니다.

- Windows와 Mac에서 재생 시계가 이미 지나간 20초 지점을 다시 눌렀을 때, 각각 30회 모두 2초 안에 목표 프레임이 표시됐습니다. 0.3.4에서는 같은 조건에서 Windows 0회, Mac 2회였습니다.
- 연속 이동 중 창을 닫았을 때 양쪽 모두 30회 중 30회 이어보기 위치를 보존했습니다. Mac의 ⌘Q에도 같은 종료 처리를 적용했습니다.
- 구간 이동 뒤 화면이 멈추는 시간은 영상과 장비에 따라 다릅니다. Windows Intel UHD 630에서 4K60 HEVC 영상을 방향키로 연속 이동한 뒤 화면 정지 시간(P95)은 1.53초에서 1.34초로 줄었습니다. Mac M4에서는 연속 클릭이 빨라졌지만 방향키 연타와 드래그에서는 더 긴 정지가 관측됐습니다. [장비별 측정 결과](https://github.com/poyal/soft-vault/blob/v0.3.5/docs/verification/2026-11-23-playback-recovery.md)

## 설치와 업데이트

- [Windows x64 설치 파일 (.exe)](https://github.com/poyal/soft-vault/releases/download/v0.3.5/SoftVault-0.3.5-Windows-x64-Setup.exe)
- [Apple Silicon Mac 설치 파일 (.dmg)](https://github.com/poyal/soft-vault/releases/download/v0.3.5/SoftVault-0.3.5-macOS-arm64.dmg)
- 기존 앱에서는 **설정 → 앱 정보·업데이트 → 지금 확인 → 다운로드 → 업데이트 후 재시작**으로 적용할 수 있습니다.

자동 업데이트에는 기존 Ed25519 서명 키를 사용했습니다. Windows 설치 파일은 코드 서명 없이 배포합니다. Mac 앱은 로컬 서명(ad hoc)이며 Apple 공증을 받지 않았습니다.

[설치·업데이트 검증 기록](https://github.com/poyal/soft-vault/blob/main/docs/releases/v0.3.5/VERIFICATION.md)

## 배포 파일

| 파일 | 크기(바이트) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.3.5-Windows-x64-Setup.exe | 89103536 | `73c9c697a5f9b638255af64b89ebf3b30196d54b3741f3a3747e1e8e80b5ac68` |
| SoftVault-0.3.5-Windows-x64-Setup.exe.sha256 | 105 | `9c6a5d9408ba36d195f1cd4cad330fb566e2e1b5dacc6e835662b27a6140f425` |
| SoftVault-0.3.5-macOS-arm64.dmg | 94998155 | `6aa40d92784d554fa21889b8cd073f833e50b7081b5361933a615adaba887315` |
| SoftVault-0.3.5-macOS-arm64.dmg.sha256 | 98 | `e9645f9bdbbff5d7ad2bdf454dfe14ab8e6e4f494d713dbfcb8eb52243b6ada2` |
| SoftVault-Windows.svupdate | 120384355 | `6537f55994a3387db804d85aed0e70a91964be13fe79adaddcc97fb49262e447` |
| SoftVault-macOS-arm64.svupdate | 86722650 | `17362a24f9886bcdac9be8837354c5913331fd872931a82a9dfeff2570a6e9e7` |
| update.json | 446 | `620024153a074edb5499eede8baf13fc5edecc3fb6e52542bcc042087fcca1bf` |
| update.json.sig | 88 | `972c65fc354e8c2b51d026de16d4e9e1fe1834affd6745a996aa795c1d1c4e4f` |
