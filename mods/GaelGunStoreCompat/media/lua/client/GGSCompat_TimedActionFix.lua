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

    This patch reinstalls a clean begin() that keeps GGS's protective character
    guard but calls vanilla begin() directly, without pcall.

    Scope is deliberately narrow: only begin() is touched. perform()/stop() are
    left alone. The patch is inert unless GGS is active.

    Standalone re-implementation; behavior modeled on CommonSenseReborn's
    CSR_GaelGunStoreCompat.lua.
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
local _capturedWasUnsafe = ISBaseTimedAction
    and ISBaseTimedAction.__ggsBeginGuard
    and _capturedBegin ~= nil

-- If the begin() captured at load is GGS's unsafe wrapper, fall back to a fresh
-- vanilla-shaped begin(); otherwise keep whatever clean begin() was installed.
local _rawCleanBegin = _capturedWasUnsafe and vanillaBegin or _capturedBegin

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
    -- GGS was active at load and begin() still points at the raw captured one.
    if _ggsActiveAtLoad and ISBaseTimedAction.begin == _rawCleanBegin then
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

-- If we load before GGS, claim the guard so GGS does not install its unsafe wrapper.
if ISBaseTimedAction and _ggsActiveAtLoad and not _capturedWasUnsafe then
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
