local ADDON, ns = ...

-- Defaults -------------------------------------------------------------------

local DEFAULTS = {
    locked = true,
    combat = {
        enabled = true,
        font = "Friz Quadrata",
        size = 28,
        outline = "OUTLINE",
        x = 0,
        y = 180,
        enterText = "+ Combat",
        leaveText = "- Combat",
        hold = 1.0,
    },
    death = {
        enabled = true,
        font = "Friz Quadrata",
        size = 32,
        outline = "OUTLINE",
        x = 0,
        y = 240,
        message = "%s died!",
        sound = "Raid Warning",
        includeSelf = false,
        dungeonOnly = false,
        hold = 3.0,
    },
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

ns.DEFAULTS = DEFAULTS

-- Fonts & sounds ---------------------------------------------------------------

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local BUILTIN_FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
}

-- Sound names mapped to SOUNDKIT keys; entries missing from the client are skipped.
local BUILTIN_SOUNDS = {
    { "Raid Warning", "RAID_WARNING" },
    { "Ready Check", "READY_CHECK" },
    { "Alarm Clock", "ALARM_CLOCK_WARNING_3" },
    { "Boss Whisper", "UI_RAID_BOSS_WHISPER_WARNING" },
    { "PvP Queue Ready", "PVP_THROUGH_QUEUE" },
    { "Level Up", "LEVEL_UP" },
}

function ns.GetFontList()
    local list, seen = {}, {}
    for _, f in ipairs(BUILTIN_FONTS) do
        list[#list + 1] = f[1]
        seen[f[1]] = true
    end
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            if not seen[name] then list[#list + 1] = name end
        end
    end
    return list
end

function ns.GetFontPath(name)
    for _, f in ipairs(BUILTIN_FONTS) do
        if f[1] == name then return f[2] end
    end
    if LSM and LSM:IsValid("font", name) then return LSM:Fetch("font", name) end
    return STANDARD_TEXT_FONT
end

function ns.GetSoundList()
    local list = { "None" }
    for _, s in ipairs(BUILTIN_SOUNDS) do
        if SOUNDKIT and SOUNDKIT[s[2]] then list[#list + 1] = s[1] end
    end
    if LSM then
        for _, name in ipairs(LSM:List("sound")) do
            if name ~= "None" then list[#list + 1] = name end
        end
    end
    return list
end

function ns.PlayAlertSound(name)
    if not name or name == "None" then return end
    for _, s in ipairs(BUILTIN_SOUNDS) do
        if s[1] == name then
            if SOUNDKIT and SOUNDKIT[s[2]] then PlaySound(SOUNDKIT[s[2]], "Master") end
            return
        end
    end
    if LSM and LSM:IsValid("sound", name) then
        PlaySoundFile(LSM:Fetch("sound", name), "Master")
    end
end

-- Alert frames -----------------------------------------------------------------

local FADE_IN, FADE_OUT = 0.3, 0.6

local function Alert_OnUpdate(self, elapsed)
    self.t = self.t + elapsed
    local hold = self.cfg.hold
    local t = self.t
    if t < FADE_IN then
        self:SetAlpha(t / FADE_IN)
    elseif t < FADE_IN + hold then
        self:SetAlpha(1)
    elseif t < FADE_IN + hold + FADE_OUT then
        self:SetAlpha(1 - (t - FADE_IN - hold) / FADE_OUT)
    else
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end
end

local function CreateAlert(key, sample)
    local f = CreateFrame("Frame", "CombatCues_" .. key, UIParent, "BackdropTemplate")
    f:SetSize(420, 60)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()
    f.key = key
    f.sample = sample

    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER")

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local px, py = UIParent:GetCenter()
        self.cfg.x = math.floor(cx - px + 0.5)
        self.cfg.y = math.floor(cy - py + 0.5)
        self:ApplySettings()
        if ns.RefreshOptions then ns.RefreshOptions() end
    end)

    function f:ApplySettings()
        local cfg = self.cfg
        local flags = cfg.outline ~= "NONE" and cfg.outline or ""
        self.text:SetFont(ns.GetFontPath(cfg.font), cfg.size, flags)
        if not self.text:GetFont() then
            self.text:SetFont(STANDARD_TEXT_FONT, cfg.size, flags)
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    end

    function f:Play(msg, r, g, b)
        if not ns.db.locked then return end
        self.text:SetText(msg)
        self.text:SetTextColor(r or 1, g or 1, b or 1)
        self.t = 0
        self:SetAlpha(0)
        self:Show()
        self:SetScript("OnUpdate", Alert_OnUpdate)
    end

    function f:SetUnlocked(unlocked)
        self:SetScript("OnUpdate", nil)
        self:EnableMouse(unlocked)
        if unlocked then
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(0, 0.4, 1, 0.35)
            self.text:SetText(self.sample)
            self.text:SetTextColor(1, 1, 1)
            self:SetAlpha(1)
            self:Show()
        else
            self:SetBackdrop(nil)
            self:Hide()
        end
    end

    return f
end

-- Combat -----------------------------------------------------------------------

local combatFrame, deathFrame

local function OnCombat(entering)
    local cfg = ns.db.combat
    if not cfg.enabled then return end
    if entering then
        combatFrame:Play(cfg.enterText, 1, 0.25, 0.25)
    else
        combatFrame:Play(cfg.leaveText, 0.3, 1, 0.3)
    end
end

-- Party deaths -----------------------------------------------------------------
-- Midnight-era API restrictions block the combat log for addons, so deaths are
-- detected by watching each party unit flip from alive to dead.

local deadState = {}

local function DeathTrackingActive()
    local cfg = ns.db.death
    if not cfg.enabled or not IsInGroup() or IsInRaid() then return false end
    if cfg.dungeonOnly then
        local _, instanceType = IsInInstance()
        if instanceType ~= "party" then return false end
    end
    return true
end

local function GroupUnits()
    local units = {}
    if ns.db.death.includeSelf then units[1] = "player" end
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then units[#units + 1] = u end
    end
    return units
end

-- Wrapped in pcall: restricted ("secret") values raise errors when tested.
local function IsUnitDead(unit)
    local ok, dead = pcall(function()
        if UnitIsFeignDeath and UnitIsFeignDeath(unit) then return false end
        if UnitIsDeadOrGhost(unit) then return true end
        return false
    end)
    return ok and dead
end

local function UnitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and type(guid) == "string" then return guid end
    return unit
end

local function AnnounceDeath(unit)
    local cfg = ns.db.death
    local name = UnitName(unit) or unit
    local _, class = UnitClass(unit)
    local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if color then name = color:WrapTextInColorCode(name) end
    local msg = cfg.message:gsub("%%s", name)
    deathFrame:Play(msg, 1, 0.2, 0.2)
    ns.PlayAlertSound(cfg.sound)
end

-- announce=false records current state without alerting (roster changes, zoning).
local function ScanGroup(announce)
    if not DeathTrackingActive() then
        wipe(deadState)
        return
    end
    local seen = {}
    for _, unit in ipairs(GroupUnits()) do
        local key = UnitKey(unit)
        local dead = IsUnitDead(unit)
        if announce and dead and deadState[key] == false then
            AnnounceDeath(unit)
        end
        deadState[key] = dead
        seen[key] = true
    end
    for key in pairs(deadState) do
        if not seen[key] then deadState[key] = nil end
    end
end

-- Public helpers for options ------------------------------------------------------

function ns.ApplyAll()
    combatFrame:ApplySettings()
    deathFrame:ApplySettings()
end

function ns.SetLocked(locked)
    ns.db.locked = locked
    combatFrame:SetUnlocked(not locked)
    deathFrame:SetUnlocked(not locked)
end

function ns.TestCombat()
    local cfg = ns.db.combat
    combatFrame:Play(cfg.enterText, 1, 0.25, 0.25)
    C_Timer.After(FADE_IN + cfg.hold + FADE_OUT + 0.2, function()
        combatFrame:Play(cfg.leaveText, 0.3, 1, 0.3)
    end)
end

function ns.TestDeath()
    AnnounceDeath("player")
end

function ns.ResetPositions()
    for _, key in ipairs({ "combat", "death" }) do
        ns.db[key].x = DEFAULTS[key].x
        ns.db[key].y = DEFAULTS[key].y
    end
    ns.ApplyAll()
end

-- Events -------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CombatCuesDB = CombatCuesDB or {}
        ApplyDefaults(CombatCuesDB, DEFAULTS)
        ns.db = CombatCuesDB
        ns.db.locked = true

        combatFrame = CreateAlert("Combat", "Combat text")
        combatFrame.cfg = ns.db.combat
        deathFrame = CreateAlert("Death", "Death alert text")
        deathFrame.cfg = ns.db.death
        ns.ApplyAll()

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UNIT_HEALTH")
        self:RegisterEvent("UNIT_FLAGS")
        -- Fallback poll in case health/flag events are throttled or restricted.
        C_Timer.NewTicker(0.5, function() ScanGroup(true) end)
        if ns.InitOptions then ns.InitOptions() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombat(false)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        ScanGroup(false)
    elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        if arg1 == "player" or (type(arg1) == "string" and arg1:match("^party%d$")) then
            ScanGroup(true)
        end
    end
end)
