# GaelGunStore Compatibility Patch (Project Zomboid B42)

로컬 호환 패치 모드 — GaelGunStore와 다른 총기 모드들을 함께 쓸 수 있게 만듭니다.
A local compatibility mod that lets **GaelGunStore** coexist with other gun mods on
**Project Zomboid Build 42**.

- 서버 / Server: GCP Ubuntu 24.04 LTS (dedicated)
- 클라이언트 / Client: Windows
- 대상 모드 / Target: GaelGunStore — Workshop `3616176188`, mod id `GaelGunStore_B42`

## 문제 / The problem

GaelGunStore는 `ISBaseTimedAction:begin()`을 `pcall()`로 감쌉니다. Build 42.15+에서는
자바 쪽 예외가 발생할 때 이 `pcall`이 Kahlua의 내부 콜 프레임(call frame)을 손상시킬 수
있고, 그 뒤로 **다른 모드와 바닐라의 타임드 액션**이 다음과 같은 오류로 깨집니다:

```
java.lang.NullPointerException ... ReturnValues.put
Cannot assign field "callFrame" because "a" is null
```

즉 GaelGunStore가 "다른 총기 모드와 충돌"하는 것처럼 보이는 진짜 원인은, 자기 액션뿐 아니라
**모든 모드의 타임드 액션**을 망가뜨리기 때문입니다.

GaelGunStore wraps `ISBaseTimedAction:begin()` in `pcall()`. On B42.15+ that can corrupt
Kahlua's call frame when the Java side throws, after which unrelated timed actions fail
with the errors above. That global corruption — not item ID clashes — is the real reason
GaelGunStore appears to conflict with other gun mods.

## 해결 / The fix

타임드 액션이 깨지지 않도록, GaelGunStore의 캐릭터 보호 가드는 유지하되 `pcall` 없이 바닐라
`begin()`을 직접 호출하는 깨끗한 `begin()`을 다시 설치합니다. GaelGunStore가 켜져 있을 때만
동작하며, 워크샵 모드 파일은 전혀 수정하지 않습니다(업데이트 안전).

The patch reinstalls a clean `begin()` that keeps GaelGunStore's character guard but drops
the `pcall`. It only activates when GaelGunStore is enabled and never edits the Workshop
mod's files (update-safe). Scope is narrow — only `begin()` is touched.

## 구성 / Contents

```
mods/GaelGunStoreCompat/
  mod.info
  media/lua/client/GGSCompat_TimedActionFix.lua   # 핵심 수정 / the runtime fix
tools/pz-lowercase-fix.sh                          # 리눅스 대소문자 보정 도구 / Linux case helper
docs/install.md                                    # 설치 안내 / install guide
```

## 설치 / Install

전체 설치 절차는 [`docs/install.md`](docs/install.md)를 참고하세요. 요약:

1. `mods/GaelGunStoreCompat/`를 서버의 `~/Zomboid/mods/`에 복사.
2. 서버 설정 `Mods=` 줄에서 `GaelGunStore_B42` **뒤에** `GaelGunStoreCompat` 추가.
3. **로컬 모드는 서버가 클라이언트에 자동 배포하지 않습니다** — 모든 Windows 클라이언트의
   `%USERPROFILE%\Zomboid\mods\`에도 같은 폴더를 복사해야 합니다.
4. 클라이언트 콘솔에 `[GGSCompat] Installed safe ISBaseTimedAction:begin wrapper`가 보이면 정상.

> **Important:** a dedicated server does not auto-distribute local (non-Workshop) mods.
> Install the folder on the server **and** on every Windows client. See the install guide.

## 이 모드팩에서 / In this collection (97 mods)

컬렉션(`3746021319`) 분석 결과 — 자세한 내용은 [`docs/collection-notes.md`](docs/collection-notes.md):

- **패치 필요 확정**: 이 팩에는 GaelGunStore의 `begin()` 버그를 고치는 모드가 없습니다(원본
  Common Sense 계열만 있고 CommonSenseReborn은 없음). → 이 패치가 반드시 필요합니다.
- **가장 큰 영향**: Run and Reload, Fast Knifing, Better Auto Mechanics, Vehicle Repair
  Overhaul, Project Cook 등 **타임드 액션을 쓰는 모든 모드** + 바닐라(특히 **E키로 문/대문이
  열렸다 바로 닫히는** 증상)가 이 버그로 깨지며, 패치가 전역으로 복구합니다.
- **검증 도구 내장**: 팩에 errorMagnifier(`2896041179`)가 있어, 패치 적용 전후로
  `callFrame ... null` / `ReturnValues.put` 오류가 사라지는지 화면에서 바로 확인 가능합니다.
- **리눅스 대소문자**: 팩에 PZ B42 Linux Case Fix(`3728891707`)와 RAF B42 Linux Case
  Fix(`3728837648`)가 이미 있습니다. GaelGunStore 전용 케이스 픽스는 없으므로, 서버 로그에
  GaelGunStore 에셋 누락이 남으면 아래 도구를 GaelGunStore 워크샵 폴더에 적용하세요.

## 리눅스 대소문자 / Linux case-sensitivity

이 패치의 파일은 모두 소문자로 통일되어 있어 리눅스에서 문제를 일으키지 않습니다. 다른 총기
모드의 텍스처/사운드가 서버에서 누락되면(클라이언트는 정상인데 서버 로그에 file not found),
`tools/pz-lowercase-fix.sh`로 해당 모드 폴더에 소문자 심볼릭 링크를 만들 수 있습니다. 파일을
이름 변경/삭제하지 않으므로 워크샵 재다운로드 및 팩의 케이스 픽스 모드와 함께 써도 안전합니다.

## 범위 밖 / Out of scope (for now)

개별 총기 모드(Vanilla Firearms Expansion, US Military Pack, Simple Silencers 등)와의
아이템 ID·샌드박스 옵션 키 중복 정리는 크래시가 아닌 표시상 문제이며, 구체적인 충돌 쌍을
알려주시면 별도 de-conflict 스크립트로 추가할 수 있습니다. 핵심 타임드 액션 수정은 컬렉션
내용과 무관하게 동작합니다.
