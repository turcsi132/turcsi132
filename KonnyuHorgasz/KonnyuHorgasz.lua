-- Konnyu Horgasz - egygombos horgaszas
-- Egy gomb (alapból F): ha nincs kint a csali -> bedobja (Fishing),
-- ha kint van -> kiveszi a halat (Interact a soft-targetelt úszóra).
-- Az automatikus zsákmányolás bekapcsol, így a hal egyből a táskába kerül.

local ADDON = ...
local PREFIX = "|cff33ccff[Könnyű Horgász]|r "

local defaults = {
    key = "F",
    enabled = false,
    loudSound = true,
}

-- A "Fishing" varázslat neve a kliens nyelvén (Classic: 7620, Retail: 131474)
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        return (GetSpellInfo(id))
    end
end
local FISHING = SpellName(131474) or SpellName(7620) or "Fishing"

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

-- Titkos (secure) gomb, ami a horgászat varázslatot dobja
local castButton = CreateFrame("Button", "KonnyuHorgaszCastButton", UIParent, "SecureActionButtonTemplate")
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")
castButton:SetAttribute("spell", FISHING)
castButton:Hide()

local f = CreateFrame("Frame")
local savedCVars = {}
local pendingUpdate = false

-- Ezeket a beállításokat ideiglenesen átállítjuk, kikapcsoláskor visszaállnak
local cvarsWhileFishing = {
    autoLootDefault          = "1",
    SoftTargetInteract       = "3",
    SoftTargetInteractArc    = "2",
    SoftTargetInteractRange  = "30",
}
local soundCVars = {
    Sound_EnableSFX          = "1",
    Sound_SFXVolume          = "1.0",
    Sound_MusicVolume        = "0",
    Sound_AmbienceVolume     = "0",
    Sound_EnableSoundWhenGameIsInBG = "1",
}

local function ApplyCVars(tbl)
    for name, value in pairs(tbl) do
        local old = GetCVar(name)
        if old ~= nil then
            if savedCVars[name] == nil then savedCVars[name] = old end
            SetCVar(name, value)
        end
    end
end

local function RestoreCVars()
    for name, value in pairs(savedCVars) do SetCVar(name, value) end
    wipe(savedCVars)
end

local function IsFishing()
    local name = UnitChannelInfo("player")
    return name ~= nil and name == FISHING
end

-- A gomb jelentését a helyzethez igazítjuk
local function UpdateBinding()
    if InCombatLockdown() then pendingUpdate = true return end
    pendingUpdate = false
    ClearOverrideBindings(f)
    local db = KonnyuHorgaszDB
    if not db.enabled then return end
    if IsFishing() then
        SetOverrideBinding(f, true, db.key, "INTERACTTARGET")
    else
        SetOverrideBindingClick(f, true, db.key, castButton:GetName(), "LeftButton")
    end
end

local function Enable()
    if InCombatLockdown() then Print("Harc közben nem kapcsolható be.") return end
    KonnyuHorgaszDB.enabled = true
    ApplyCVars(cvarsWhileFishing)
    if KonnyuHorgaszDB.loudSound then ApplyCVars(soundCVars) end
    UpdateBinding()
    Print("BEKAPCSOLVA. Nyomd meg a(z) |cffffff00" .. KonnyuHorgaszDB.key ..
        "|r gombot a dobáshoz, majd kapáskor (csobbanás) újra a kifogáshoz.")
end

local function Disable()
    if InCombatLockdown() then Print("Harc közben nem kapcsolható ki.") return end
    KonnyuHorgaszDB.enabled = false
    ClearOverrideBindings(f)
    RestoreCVars()
    Print("KIKAPCSOLVA. Az eredeti beállítások visszaálltak.")
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        KonnyuHorgaszDB = KonnyuHorgaszDB or {}
        for k, v in pairs(defaults) do
            if KonnyuHorgaszDB[k] == nil then KonnyuHorgaszDB[k] = v end
        end
        -- Előző munkamenetből ottmaradt mentett beállítások visszaállítása
        if KonnyuHorgaszDB.savedCVars then
            for name, value in pairs(KonnyuHorgaszDB.savedCVars) do SetCVar(name, value) end
            KonnyuHorgaszDB.savedCVars = nil
        end
    elseif event == "PLAYER_LOGIN" then
        -- Biztonsági okból mindig kikapcsolva indul
        KonnyuHorgaszDB.enabled = false
        Print("Betöltve. Bekapcsolás: |cffffff00/horgasz|r  (súgó: /horgasz help)")
    elseif event == "PLAYER_LOGOUT" then
        -- Ha bekapcsolva lépett ki, a következő betöltéskor visszaállítjuk
        if next(savedCVars) then
            KonnyuHorgaszDB.savedCVars = CopyTable(savedCVars)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingUpdate then UpdateBinding() end
    elseif (event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP")
        and arg1 == "player" then
        if KonnyuHorgaszDB and KonnyuHorgaszDB.enabled then UpdateBinding() end
    end
end)

SLASH_KONNYUHORGASZ1 = "/horgasz"
SLASH_KONNYUHORGASZ2 = "/kh"
SlashCmdList.KONNYUHORGASZ = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        if KonnyuHorgaszDB.enabled then Disable() else Enable() end
    elseif cmd == "be" or cmd == "on" then
        Enable()
    elseif cmd == "ki" or cmd == "off" then
        Disable()
    elseif cmd == "gomb" or cmd == "key" then
        if rest == "" then Print("Jelenlegi gomb: " .. KonnyuHorgaszDB.key) return end
        if InCombatLockdown() then Print("Harc közben nem módosítható.") return end
        KonnyuHorgaszDB.key = rest:upper()
        UpdateBinding()
        Print("Új gomb: |cffffff00" .. KonnyuHorgaszDB.key .. "|r")
    elseif cmd == "hang" or cmd == "sound" then
        KonnyuHorgaszDB.loudSound = not KonnyuHorgaszDB.loudSound
        Print("Hangos kapás mód: " .. (KonnyuHorgaszDB.loudSound and "BE" or "KI") ..
            " (a következő bekapcsoláskor lép életbe)")
    else
        Print("Parancsok:")
        Print("  /horgasz            - be/ki kapcsolás")
        Print("  /horgasz gomb F     - a horgász gomb beállítása (pl. F, SPACE, BUTTON3, MOUSEWHEELUP)")
        Print("  /horgasz hang       - hangos kapás mód (SFX fel, zene/környezet le) be/ki")
    end
end
