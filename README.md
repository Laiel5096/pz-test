# GaelGunStore TimedAction Stabilizer (Project Zomboid B42)

로컬 안정화 패치 — GaelGunStore의 unsafe `ISBaseTimedAction:begin` 래퍼가 일으키는
**전역 타임드 액션 오류**를 완화합니다. 총기/탄약/루팅/아이템 ID 충돌까지 해결하지는 **않습니다.**
A local patch that mitigates the **global timed-action corruption** caused by GaelGunStore's
unsafe `ISBaseTimedAction:begin` wrapper on **Project Zomboid Build 42**. It does **not** fix
firearm/ammo overrides, loot tables, recipes, sandbox options, attachment UI, or item-ID
clashes between GaelGunStore and other gun mods.

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

GaelGunStore의 캐릭터 보호 가드는 유지하되 `pcall` 없이 동작하는 **vanilla-shaped fallback**
`begin()`(바닐라 begin 흐름을 재구현한 것 — 원본 함수 포인터를 복구하는 게 아님)을 설치합니다.
GaelGunStore가 켜져 있을 때만 동작하고, 워크샵 모드 파일은 전혀 수정하지 않습니다(업데이트 안전).
범위는 좁게 `begin()`만 건드립니다.

The patch installs a **vanilla-shaped fallback** `begin()` (a reimplementation of the vanilla
begin flow — it does not recover the original function pointer) that keeps GaelGunStore's
character guard but runs without `pcall`. It activates only when GaelGunStore is enabled,
never edits the Workshop mod's files (update-safe), and touches `begin()` only.

> **Trade-off / 주의:** GaelGunStore가 활성화된 동안 이 패치는 설치된 `begin()`을 fallback으로
> **교체**합니다. 만약 다른 모드가 `ISBaseTimedAction:begin()`을 정상적으로 감싸고 있었다면 그
> 래퍼는 사라집니다. GGS의 콜 프레임 오염 제거를 우선하기 위한 감수 가능한 선택입니다.
> While GaelGunStore is active, this patch **replaces** the installed `begin()`. If another mod
> had legitimately wrapped `ISBaseTimedAction:begin()`, that wrapper is dropped — an accepted
> trade-off, since removing GaelGunStore's corruption takes priority.

> **대상 / Scope:** `GaelGunStore_B42` 전용입니다. 레거시 팩(`GaelGunStore_Leagacy`,
> `3623297453`)은 **지원하지 않습니다.** Targets `GaelGunStore_B42` only; the legacy pack is
> **not supported**.

## 구성 / Contents

```
mods/GaelGunStoreCompat/
  mod.info
  media/lua/client/GGSCompat_TimedActionFix.lua   # 핵심 수정 / the runtime fix
tools/pz-lowercase-fix.sh                          # 리눅스 대소문자 보정 도구 / Linux case helper
docs/install.md                                    # 설치 안내 / install guide
docs/collection-notes.md                           # 97개 모드 분석 / collection analysis
CHANGELOG.md                                       # 변경 이력 / changelog
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

단, 이 도구는 **실제 이름에 대문자가 있고 참조가 소문자인 경우**(예: 실제 `AnimSets` → 참조
`animsets`)만 완화합니다. 반대 방향(실제 `animsets` → 참조 `AnimSets`)은 기본 스캔으로는 잡지
못하므로 서버 로그 기반으로 별도 alias가 필요합니다. Note: the tool only aliases when the real
name **contains uppercase** and the reference is lowercase; the reverse direction is not covered
by the scan.

## 범위 밖 / Out of scope

이 패치가 다루는 건 **타임드 액션 오염 하나뿐**입니다. GaelGunStore는 바닐라 총기/탄약을 전부
교체하므로, 다른 총기 모드(Vanilla Firearms Expansion, Hot Brass, RAF, Simple Silencers,
US Military Pack, Vanilla Gear Expanded 등)와는 바닐라 총기/탄약 override, 루팅 테이블, 제작
레시피, 샌드박스 옵션, 부착물 시스템, 아이템 ID 등에서 여전히 충돌할 수 있습니다. 이는 단순
표시 문제가 아니라 실제 동작 문제로 번질 수 있으며, 여기서 해결하지 않습니다(별도 테스트 필요).

TimedAction corruption is the only issue this patch targets. Other firearm mods may still
conflict with GaelGunStore through vanilla firearm/ammo overrides, loot tables, recipes,
sandbox options, attachment systems, and item IDs. Those are not fixed here and require
separate testing. 구체적인 충돌 쌍을 알려주시면 별도 de-conflict 작업을 추가할 수 있습니다.
