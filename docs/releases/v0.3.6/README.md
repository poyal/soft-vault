# Soft Vault 0.3.6

Mac에서 영상을 재생하거나 재생 위치를 옮기는 도중 ⌘Q를 연달아 누르면 앱이 비정상 종료될 수 있던 문제를 수정했습니다. 이제 종료 요청이 겹쳐도 이어보기 위치를 저장하고 재생기를 해제한 뒤 앱을 한 번만 종료합니다.

macOS가 개발용 종료 시험 앱을 다시 열 때 시험 인자가 없으면 해당 앱이 바로 종료됩니다. 이전에 생성된 macOS 충돌 보고서는 그대로 보관됩니다.

## 설치와 업데이트

기존 앱에서는 **설정 → 앱 정보·업데이트 → 지금 확인**을 누르고 다운로드한 뒤 재시작하세요. 직접 설치할 때는 운영체제에 맞는 파일을 받으세요.

- [Apple Silicon Mac 설치 파일 (.dmg)](https://github.com/poyal/soft-vault/releases/download/v0.3.6/SoftVault-0.3.6-macOS-arm64.dmg)
- [Windows x64 설치 파일 (.exe)](https://github.com/poyal/soft-vault/releases/download/v0.3.6/SoftVault-0.3.6-Windows-x64-Setup.exe)

Mac 앱은 로컬 서명(ad hoc)으로 배포하며 Apple 공증은 받지 않았습니다. Windows 설치 파일에는 코드 서명이 없습니다. 앱 내 업데이트에는 기존 Ed25519 서명 키를 사용합니다.

[설치·종료·업데이트 검증 기록](https://github.com/poyal/soft-vault/blob/main/docs/releases/v0.3.6/VERIFICATION.md)

## 배포 파일

| 파일 | 크기(바이트) | SHA-256 |
| --- | ---: | --- |
| SoftVault-0.3.6-Windows-x64-Setup.exe | 89099885 | `c3676653f93d03f0f0ca94f4940a9a3b6fb841d0e34be3f76a870d11d763c60b` |
| SoftVault-0.3.6-Windows-x64-Setup.exe.sha256 | 105 | `a1b685c2f4c2a6e31efa3866803d88367b81b58c3fa72d6bbfd41ec8d9e9ed23` |
| SoftVault-0.3.6-macOS-arm64.dmg | 94997740 | `350df92bc4103b01b208737e560ff83d5214b37a68ae1336eada54a5fc6b8019` |
| SoftVault-0.3.6-macOS-arm64.dmg.sha256 | 98 | `1ae06c632ad8635fb6deed45593703d2ac1e788f21b38306020dbdc0e0989f6b` |
| SoftVault-Windows.svupdate | 120384262 | `7713b7a3b5462c1e8c25e5b8e515e6a38ddac7247332b246ef5ee8d4cafe9b4d` |
| SoftVault-macOS-arm64.svupdate | 86728718 | `8e954eec432a7f243fecee89524e6a42c337f1c5ac6e5505e57e64834437c8df` |
| update.json | 446 | `a7af2ff22fd463f7e398b27d3634d367b9730ab665738126f24967f7bf8869ed` |
| update.json.sig | 88 | `7828433b5e3e84d7fde7b585abbf8512288522938ec5797816c1d063c25d00c3` |
