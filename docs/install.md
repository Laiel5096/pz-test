# GaelGunStore Compatibility Patch — Install Guide

This is a **local** (non-Workshop) mod. Read the distribution note carefully: a
dedicated server does **not** push local mods to clients automatically.

## What it fixes

GaelGunStore (Workshop `3616176188`, mod id `GaelGunStore_B42`) wraps
`ISBaseTimedAction:begin()` in a `pcall()`. On Build 42.15+ that can corrupt
Kahlua's internal call frame when the Java side throws, after which **unrelated
vanilla and other-mod timed actions** start failing with errors like:

```
java.lang.NullPointerException ... ReturnValues.put
Cannot assign field "callFrame" because "a" is null
```

This is why GaelGunStore seems to "conflict with other gun mods" — it breaks every
mod's timed actions, not just its own. The patch reinstalls a clean `begin()` that
keeps GaelGunStore's character guard but drops the `pcall`.

## 1. Server (GCP Ubuntu 24.04 LTS)

1. Copy the mod folder to the server profile's `mods/` directory:

   ```
   ~/Zomboid/mods/GaelGunStoreCompat/
   ```

   (The folder must contain `mod.info` and `media/lua/client/GGSCompat_TimedActionFix.lua`.)

2. Edit the server config (e.g. `~/Zomboid/Server/servertest.ini`). On the `Mods=`
   line, add `GaelGunStoreCompat` **after** `GaelGunStore_B42`:

   ```
   Mods=GaelGunStore_B42;GaelGunStoreCompat
   ```

   (Keep your other gun mods on the line as usual; the patch just needs to come
   after GaelGunStore.)

3. Do **not** add anything to `WorkshopItems=` — this mod is local, not a Workshop item.

4. Restart the server.

## 2. Every Windows client

A dedicated server only auto-downloads **Workshop** mods to clients. Because this
patch is a local mod, **each player must install it manually** or they will fail
the mod check / not get the fix:

1. Copy the same `GaelGunStoreCompat` folder to:

   ```
   %USERPROFILE%\Zomboid\mods\GaelGunStoreCompat\
   ```

2. Enable it in the in-game Mods menu (or it is pulled in by the server's mod list
   on join). Make sure it loads **after** GaelGunStore.

> If you would rather not hand it to every player, upload this folder as your own
> Workshop item and add its id to `WorkshopItems=` instead. The mod contents are
> identical; only the distribution changes.

## 3. Confirm it loaded

In the client console / `console.txt` you should see, once per session:

```
[GGSCompat] Installed safe ISBaseTimedAction:begin wrapper ...
```

If GaelGunStore is **not** enabled, the patch stays inert and prints nothing — that
is expected.

Behavioral check (no patch vs patch): the GaelGunStore bug makes **gates/doors open then
immediately close on `E` press**, and other mods' timed actions (Run and Reload, Fast Knifing,
Vehicle Repair Overhaul, Project Cook, etc.) throw `callFrame ... null` / `ReturnValues.put`
errors after a GaelGunStore action. Your collection already includes **errorMagnifier**
(`2896041179`), which shows those errors on-screen — they should disappear once the patch is
active. See [`collection-notes.md`](collection-notes.md) for the full breakdown.

Because your pack runs **Mod Load Order Sorter** (`3423660713`), no manual ordering is needed:
the `require=GaelGunStore_B42` line forces this patch to load after GaelGunStore regardless.

## 4. Legacy GaelGunStore build

If your server runs the legacy pack (`GaelGunStore_Leagacy`, Workshop `3623297453`)
instead of `GaelGunStore_B42`, edit `mod.info` and change the require line to match:

```
require=GaelGunStore_Leagacy
```

The runtime fix itself already checks for both `GaelGunStore_B42` and `GaelGunStore`.

## 5. Linux case-sensitivity (only if you see missing textures/sounds)

This patch's own files are all lowercase-safe, so it never triggers the Linux
case problem. But other gun mods in the collection might. If the **server** log
shows missing icons, pink/black textures, or "file not found" for a mod's assets
(and Windows clients look fine), run the helper against that mod's directory:

```bash
# dry-run report
tools/pz-lowercase-fix.sh ~/Zomboid/Workshop/<id>

# create the lowercase symlink aliases
tools/pz-lowercase-fix.sh --apply ~/Zomboid/Workshop/<id>
```

It only adds lowercase symlinks (never renames or deletes), so it is safe against
Steam Workshop re-downloads. Re-run after a mod update if needed.
