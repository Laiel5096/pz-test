# Changelog

## v1.1

Review-driven fixes. The headline change is a **correctness fix** to the runtime patch.

### Fixed (critical)
- **The patch could re-call GaelGunStore's unsafe wrapper instead of neutralizing it.**
  Because this mod loads *after* GaelGunStore (`require=GaelGunStore_B42`), at load time
  `ISBaseTimedAction.begin` is already GGS's `pcall` wrapper, and the guard marker is unset.
  v1.0 therefore captured that wrapper as the "clean" begin and re-invoked it — logging a
  successful install while the call-frame corruption continued.
  - `_capturedWasUnsafe` → renamed `_capturedLooksUnsafe` and now also treats the captured
    begin as unsafe when its source looks like GGS **or** when GGS is active at load
    (`_ggsActiveAtLoad`). The latter is independent of `debug.getinfo`, which Kahlua may not
    expose, so the vanilla-shaped fallback is selected reliably.
  - `shouldRestoreBegin()` gained an explicit branch
    `_ggsActiveAtLoad and _capturedLooksUnsafe and begin == _capturedBegin`. Since
    `_rawCleanBegin` is now the fallback (not the captured begin), the old
    `begin == _rawCleanBegin` comparison no longer fired at file load; this guarantees the
    swap even without `debug.getinfo`/marker.
- Added a one-shot diagnostic log line reporting `GGS active at load` and
  `captured looks unsafe` so the chosen path is visible in `console.txt`.

### Changed
- Renamed the mod (display only): **GaelGunStore Compatibility Patch → GaelGunStore
  TimedAction Stabilizer**. The mod `id=GaelGunStoreCompat` and folder name are unchanged,
  so existing deployments and the `require` chain are unaffected.
- `mod.info`: `modversion=1.1`, `versionMin=42.0 → 42.17` (matches the B42.15+ target and the
  current GaelGunStore build).
- Documentation no longer claims the patch makes GaelGunStore "coexist with other gun mods".
  It stabilizes the global timed-action corruption only; firearm/ammo overrides, loot tables,
  recipes, sandbox options, attachment systems, and item-ID clashes are explicitly out of scope.
- Removed the "Mod Load Order Sorter means no manual ordering is needed" guidance. Docs now
  standardize on an explicit `Mods=...;GaelGunStore_B42;GaelGunStoreCompat` order, with
  `require=` described as a backup only.
- `collection-notes.md`: replaced the "item/sandbox overlaps are cosmetic, not a crash"
  statement with an accurate warning that such conflicts can affect looting, ammo, reloading,
  attachment UI, crafting, and item conversion.
- `tools/pz-lowercase-fix.sh`: documented that it only aliases **uppercase real name →
  lowercase reference**; the reverse direction needs a log-derived alias.

### Removed
- **Legacy support dropped.** `GaelGunStore_Leagacy` (`3623297453`) is no longer mentioned as
  a supported configuration; the patch targets `GaelGunStore_B42` only.

### Notes
- **Trade-off:** while GaelGunStore is active, the patch replaces the installed `begin()` with
  a vanilla-shaped fallback. If another mod had legitimately wrapped
  `ISBaseTimedAction:begin()`, that wrapper is dropped — accepted, since removing GGS's
  corruption takes priority.
- Credit: structure inspired by CommonSenseReborn's `CSR_GaelGunStoreCompat.lua`
  (mitcaka / FADED). Independent reimplementation; no code copied verbatim.

## v1.0

- Initial local patch: client-side neutralizer for GaelGunStore's
  `ISBaseTimedAction:begin()` pcall wrapper; `tools/pz-lowercase-fix.sh`; install guide and
  97-mod collection notes.
