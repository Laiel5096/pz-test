# Collection compatibility notes — 97-mod gun pack + GaelGunStore

This documents how the patch relates to the actual collection (`3746021319`, 97 mods)
running alongside GaelGunStore (`3616176188`).

## The patch IS required for this pack

The only mod that fixes GaelGunStore's broken `ISBaseTimedAction:begin()` wrapper is
**CommonSenseReborn (CSR)** — and CSR is **not** in this collection. The pack ships the
original *Common Sense* line instead:

- #86 Common Sense (`2875848298`)
- #42 Common Sense B42 Patch (`3586053117`)
- #90 CommonSense FIX (42.19) (`3714335263`)

None of these touch the GaelGunStore `begin()` corruption. So without this patch the bug is
live in your modpack.

## What the GaelGunStore bug actually breaks

The corrupted Kahlua call frame surfaces as failures in **unrelated timed actions**, so the
mods most visibly affected are the timed-action-heavy ones in this pack:

- #43 Run and Reload (`3397207461`) — reloading
- #29 Fast Knifing B42 (`3626702761`)
- #26 Better Auto Mechanics (`3635856965`)
- #70 Vehicle Repair Overhaul (`2757712197`)
- #6 Project Cook (`3490188370`) — cooking
- #3 First Aid VHS Tapes (`3153010942`)
- …and **vanilla** actions, including the classic symptom of **gates/doors opening then
  immediately closing on `E` press** (documented in CSR's changelog as the same root cause).

Because the fix is global (it repairs `begin()` itself), every timed action in the pack
benefits — it is not specific to gun mods.

## Verification is easy in this pack

The collection already includes **#82 errorMagnifier (`2896041179`)**, which surfaces Lua
errors on-screen. To confirm the patch:

1. With the patch **disabled**, play with GaelGunStore on: errorMagnifier will eventually
   show `NullPointerException … ReturnValues.put` / `callFrame … null` after a GGS action,
   and doors/gates will mis-trigger on `E`.
2. With the patch **enabled** (loaded after `GaelGunStore_B42`), those errors and the
   door/gate misfire should stop, and the console shows
   `[GGSCompat] Installed safe ISBaseTimedAction:begin wrapper`.

## Load order

The pack runs **#48 Mod Load Order Sorter (`3423660713`)**. This patch's `mod.info` declares
`require=GaelGunStore_B42`, which forces it to load **after** GaelGunStore regardless of the
sorter. No manual ordering is needed, but if you pin order by hand, keep
`GaelGunStoreCompat` after `GaelGunStore_B42`.

## Linux case-sensitivity in this pack

The pack already carries dedicated case-fix mods for the Ubuntu server:

- #94 PZ B42 Linux Case Fix (`3728891707`) — general
- #93 RAF B42 Linux Case Fix (`3728837648`) — for RAF (`3634727573`)

There is **no** dedicated case-fix mod for GaelGunStore's own assets. If, after the general
fix (#94), the server log still reports missing GaelGunStore icons/textures/sounds while
Windows clients look fine, point `tools/pz-lowercase-fix.sh` at GaelGunStore's Workshop
directory specifically:

```bash
tools/pz-lowercase-fix.sh --apply ~/.steam/steamapps/workshop/content/108600/3616176188
```

It only adds lowercase symlinks (no rename/delete), so it coexists with #93/#94 and survives
Workshop updates.

## Other gun mods — item/sandbox overlaps (low priority, unverified)

These also add firearms/attachments and *could* share item IDs or sandbox-option keys with
GaelGunStore, but none are known to crash — the only hard failure is the timed-action
corruption fixed above:

- #9 [42] Vanilla Firearms Expansion (`3611718925`)
- #44 US Military Pack (`612100872`)
- #45 Simple Silencers (`3309896124`) + #96 Simple Silencers - Load Order Fix (`3712571540`)
- #89 RAF - Real Automatic Firerate (`3634727573`, deprecated)
- #34 Vanilla Gear Expanded (`3401134276`)
- #8 Hot Brass (`3610677934`)

If you see duplicate item names or duplicate sandbox-option labels in-game, send the specific
pair and a targeted de-conflict script can be added. This is cosmetic, not a crash, so it is
intentionally left out of the core patch.
