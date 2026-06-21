--[[
    GGSCompat_TimedActionFix.lua

    Neutralizes GaelGunStore's broken ISBaseTimedAction:begin() pcall wrapper.

    GaelGunStore (GGS, Workshop 3616176188, mod id "GaelGunStore_B42") wraps
    begin() in pcall(). On Build 42.15+, when the Java-side StartAction throws a
    RuntimeException, that pcall can leave Kahlua's internal call frame corrupted.
    The later symptom is a ReturnValues.put NullPointerException, or
    "Cannot assign field 'callFrame' because 'a' is null", raised from completely
    unrelated vanilla and other-mod timed actions. That is why GGS appears to
    "conflict" with other gun mods: it breaks every mod's timed actions, not its own.

    This patch installs a "vanilla-shaped fallback" begin() -- a reimplementation of
    the vanilla begin() flow (it does NOT recover the original vanilla function
    pointer) that keeps GGS's protective character guard but runs without pcall.

    Trade-off: while GGS is active we replace whatever begin() is installed with the
    fallback. If another mod has legitimately wrapped ISBaseTimedAction:begin(), that
    wrapper is dropped. Removing GGS's call-frame corruption takes priority.

    Scope is deliberately narrow: only begin() is touched. perform()/stop() are
    left alone. The patch is inert unless GGS is active.

    Credit: independent reimplementation; structure inspired by CommonSenseReborn's
    CSR_GaelGunStoreCompat.lua (mitcaka / FADED). No code copied verbatim. As-is.
]]

require "TimedActions/ISBaseTimedAction"

local function functionSource(fn)
    if type(fn) ~= "function" or not debug or type(debug.getinfo) ~= "function" then
        return ""
    end

    local ok, info = pcall(debug.getinfo, fn, "S")
    if ok and info and info.source then
        return tostring(info.source):lower()
    end

    return ""
end

local function isGGSActive()
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    if not mods or not mods.contains then return false end
    return mods:contains("GaelGunStore_B42") or mods:contains("GaelGunStore")
end

local function isGGSSource(fn)
    local src = functionSource(fn)
    return src:find("gaelgunstore", 1, true) ~= nil
        or src:find("ggs_timedactionguard", 1, true) ~= nil
end

-- Vanilla-shaped begin(), used as the clean replacement.
local function vanillaBegin(self)
    if not self.retriggerLastAction then
        self.character:setTimedActionToRetrigger(nil)
    end
    self:create()
    self.character:StartAction(self.action)
end

local _ggsActiveAtLoad = isGGSActive()
local _capturedBegin = ISBaseTimedAction and ISBaseTimedAction.begin or nil

-- Treat the begin() captured at load as unsafe if the guard marker is set, if its
-- source looks like GGS, OR if GGS is active at load. The last condition matters
-- because we load after GGS (require=GaelGunStore_B42): the captured begin() is
-- almost certainly GGS's wrapper, and it holds even when Kahlua's debug.getinfo
-- exposes no source for isGGSSource() to inspect.
local _capturedLooksUnsafe =
    _capturedBegin ~= nil
    and (
        (ISBaseTimedAction and ISBaseTimedAction.__ggsBeginGuard)
        or isGGSSource(_capturedBegin)
        or _ggsActiveAtLoad
    )

-- If the captured begin() looks unsafe, use the vanilla-shaped fallback; otherwise
-- keep whatever clean begin() was already installed.
local _rawCleanBegin = _capturedLooksUnsafe and vanillaBegin or _capturedBegin

-- Preserve GGS's protective character guard without the pcall.
local function guardedCleanBegin(self, ...)
    if not self or not self.character then return end
    return _rawCleanBegin(self, ...)
end

local _cleanBegin = _rawCleanBegin and guardedCleanBegin or nil
local _logged = false

local function ownsGGSGuard()
    return ISBaseTimedAction and ISBaseTimedAction.__ggsCompatOwnsGuard == true
end

local function markGGSGuardOwned()
    if not ISBaseTimedAction then return end
    ISBaseTimedAction.__ggsBeginGuard = true
    ISBaseTimedAction.__ggsCompatOwnsGuard = true
end

local function shouldRestoreBegin()
    if not ISBaseTimedAction or not _cleanBegin or not ISBaseTimedAction.begin then
        return false
    end
    -- Already our clean function; nothing to do (idempotent).
    if ISBaseTimedAction.begin == _cleanBegin then
        return false
    end
    -- GGS's unsafe wrapper was captured at load and is still installed. _rawCleanBegin
    -- is now the vanilla-shaped fallback, so we must compare against _capturedBegin,
    -- not _rawCleanBegin. This guarantees the swap even without debug.getinfo/marker.
    if _ggsActiveAtLoad
        and _capturedLooksUnsafe
        and ISBaseTimedAction.begin == _capturedBegin
    then
        return true
    end
    -- begin() now looks like it came from GGS's files.
    if isGGSSource(ISBaseTimedAction.begin) then
        return true
    end
    -- Someone else marked the guard but it is not us.
    if ISBaseTimedAction.__ggsBeginGuard and not ownsGGSGuard() then
        return true
    end
    return false
end

local function restoreCleanBegin(reason)
    if not shouldRestoreBegin() then
        return
    end

    ISBaseTimedAction.begin = _cleanBegin
    markGGSGuardOwned()

    if not _logged then
        _logged = true
        print("[GGSCompat] Installed safe ISBaseTimedAction:begin wrapper" .. (reason or ""))
    end
end

-- One-shot diagnostic so logs show which path was taken.
print("[GGSCompat] GGS active at load=" .. tostring(_ggsActiveAtLoad)
    .. ", captured looks unsafe=" .. tostring(_capturedLooksUnsafe))

-- If we load before GGS, claim the guard so GGS does not install its unsafe wrapper.
if ISBaseTimedAction and _ggsActiveAtLoad and not _capturedLooksUnsafe then
    markGGSGuardOwned()
end

restoreCleanBegin(" at file load")

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(function()
        restoreCleanBegin(" on OnGameBoot")
    end)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        restoreCleanBegin(" on OnGameStart")
    end)
end

-- One-shot safety net in case GGS re-wraps begin() later in load.
if Events and Events.OnPlayerUpdate then
    local checked = false
    local function oneShotSafetyNet()
        if checked then return end
        checked = true
        restoreCleanBegin(" on first OnPlayerUpdate")
        if Events.OnPlayerUpdate.Remove then
            Events.OnPlayerUpdate.Remove(oneShotSafetyNet)
        end
    end
    Events.OnPlayerUpdate.Add(oneShotSafetyNet)
end
