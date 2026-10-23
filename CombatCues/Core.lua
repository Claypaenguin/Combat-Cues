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
    healer = {
        enabled = true,
        font = "Friz Quadrata",
        size = 28,
        outline = "OUTLINE",
        x = 0,
        y = 120,
        message = "%s low on mana!",
        threshold = 20,
        dungeonOnly = false,
        soloTest = false,
        hold = 3.0, -- only used by the Test button
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

function ns.ApplyFont(fs, cfg)
    local flags = cfg.outline ~= "NONE" and cfg.outline or ""
    fs:SetFont(ns.GetFontPath(cfg.font), cfg.size, flags)
    if not fs:GetFont() then
        fs:SetFont(STANDARD_TEXT_FONT, cfg.size, flags)
    end
end

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
        ns.ApplyFont(self.text, cfg)
        for _, line in ipairs(self.lines or {}) do ns.ApplyFont(line, cfg) end
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

local frames = {}
local ALERT_KEYS = { "combat", "death", "healer" }

-- Combat -----------------------------------------------------------------------

local function OnCombat(entering)
    local cfg = ns.db.combat
    if not cfg.enabled then return end
    if entering then
        frames.combat:Play(cfg.enterText, 1, 0.25, 0.25)
    else
        frames.combat:Play(cfg.leaveText, 0.3, 1, 0.3)
    end
end

-- Group helpers -------------------------------------------------------------------

-- True when in a 5-player group (not a raid), and inside a dungeon if cfg.dungeonOnly is set.
local function GroupTrackingActive(cfg)
    if not cfg.enabled or not IsInGroup() or IsInRaid() then return false end
    if cfg.dungeonOnly then
        local _, instanceType = IsInInstance()
        if instanceType ~= "party" then return false end
    end
    return true
end

local function GroupUnits(includeSelf)
    local units = {}
    if includeSelf then units[1] = "player" end
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

local function ColoredName(unit)
    local name = UnitName(unit) or unit
    local _, class = UnitClass(unit)
    local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if color then name = color:WrapTextInColorCode(name) end
    return name
end

-- Party deaths -----------------------------------------------------------------
-- Midnight-era API restrictions block the combat log for addons, so deaths are
-- detected by watching each party unit flip from alive to dead.

local deadState = {}

local function AnnounceDeath(unit)
    local cfg = ns.db.death
    local msg = cfg.message:gsub("%%s", ColoredName(unit))
    frames.death:Play(msg, 1, 0.2, 0.2)
    ns.PlayAlertSound(cfg.sound)
end

-- announce=false records current state without alerting (roster changes, zoning).
local function ScanDeaths(announce)
    local cfg = ns.db.death
    if not GroupTrackingActive(cfg) then
        wipe(deadState)
        return
    end
    local seen = {}
    for _, unit in ipairs(GroupUnits(cfg.includeSelf)) do
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

-- Healer mana indicator -----------------------------------------------------------
-- WoW Forever hands addons current mana only as a secret value, which addon code
-- can't compare or branch on. Instead, a curve maps the secret mana percentage to
-- an alpha (1 at or below the threshold, 0 above), and the game applies that alpha
-- to each healer's line itself. So the text stays visible while mana is low; it
-- can't play a sound or fade once, because that would need an if/else on the value.

local manaCurve, manaCurveThreshold
local testUntil = 0
ns.healerError = nil

local function GetManaCurve(threshold)
    if manaCurve and manaCurveThreshold == threshold then return manaCurve end
    local t = threshold / 100
    local curve = C_CurveUtil.CreateCurve()
    -- Step snaps between points; a smoothing type would bulge between the threshold and 100%
    -- and fade the text in well above the threshold.
    if curve.SetType and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
    curve:AddPoint(0, 1)
    curve:AddPoint(t, 1)
    curve:AddPoint(math.min(t + 0.001, 1), 0)
    curve:AddPoint(1, 0)
    manaCurve, manaCurveThreshold = curve, threshold
    return curve
end

-- Returns a (possibly secret) alpha for the unit's line, or nil plus an error.
local function LowManaAlpha(unit, threshold)
    local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    return pcall(function()
        return UnitPowerPercent(unit, mana, false, GetManaCurve(threshold))
    end)
end

local function IndicatorLine(f, i)
    f.lines = f.lines or {}
    local line = f.lines[i]
    if not line then
        line = f:CreateFontString(nil, "OVERLAY")
        ns.ApplyFont(line, f.cfg)
        f.lines[i] = line
    end
    line:ClearAllPoints()
    line:SetPoint("CENTER", f, "CENTER", 0, -(i - 1) * (f.cfg.size + 4))
    line:SetTextColor(0.3, 0.6, 1)
    return line
end

local function HealerUnits()
    local healers = {}
    for _, unit in ipairs(GroupUnits(true)) do
        if UnitGroupRolesAssigned(unit) == "HEALER" and not IsUnitDead(unit) then
            healers[#healers + 1] = unit
        end
    end
    return healers
end

-- Solo test mode treats you as the healer while you're not in a group (ignores dungeonOnly).
local function IndicatorUnits(cfg)
    if cfg.enabled and cfg.soloTest and not IsInGroup() then return { "player" } end
    if GroupTrackingActive(cfg) then return HealerUnits() end
    return {}
end

local function UpdateHealerIndicator()
    local f, cfg = frames.healer, ns.db.healer
    if not ns.db.locked then
        for _, line in ipairs(f.lines or {}) do line:Hide() end
        return
    end

    local shown = 0
    if GetTime() < testUntil then
        local line = IndicatorLine(f, 1)
        line:SetText((cfg.message:gsub("%%s", ColoredName("player"))))
        line:SetAlpha(1)
        line:Show()
        shown = 1
    else
        ns.healerError = nil
        for _, unit in ipairs(IndicatorUnits(cfg)) do
            local ok, alpha = LowManaAlpha(unit, cfg.threshold)
            if ok then
                shown = shown + 1
                local line = IndicatorLine(f, shown)
                line:SetText((cfg.message:gsub("%%s", ColoredName(unit))))
                line:SetAlpha(alpha)
                line:Show()
            else
                ns.healerError = tostring(alpha)
            end
        end
    end

    for i = shown + 1, #(f.lines or {}) do f.lines[i]:Hide() end
    f.text:SetText("")
    f:SetAlpha(1)
    f:SetShown(shown > 0)
end

-- Public helpers for options ------------------------------------------------------

function ns.ApplyAll()
    for _, key in ipairs(ALERT_KEYS) do frames[key]:ApplySettings() end
end

function ns.SetLocked(locked)
    ns.db.locked = locked
    for _, key in ipairs(ALERT_KEYS) do frames[key]:SetUnlocked(not locked) end
    UpdateHealerIndicator()
end

function ns.TestCombat()
    local cfg = ns.db.combat
    frames.combat:Play(cfg.enterText, 1, 0.25, 0.25)
    C_Timer.After(FADE_IN + cfg.hold + FADE_OUT + 0.2, function()
        frames.combat:Play(cfg.leaveText, 0.3, 1, 0.3)
    end)
end

function ns.TestDeath()
    AnnounceDeath("player")
end

function ns.TestHealer()
    testUntil = GetTime() + ns.db.healer.hold
    UpdateHealerIndicator()
    C_Timer.After(ns.db.healer.hold + 0.1, UpdateHealerIndicator)
end

-- Prints what the healer indicator sees for each group unit. Secret values print as SECRET.
function ns.DebugHealer()
    local function show(v)
        if issecretvalue and issecretvalue(v) then return "SECRET" end
        return tostring(v)
    end
    local function try(fn, ...)
        local ok, v = pcall(fn, ...)
        if not ok then return "ERROR: " .. tostring(v) end
        return show(v)
    end
    local cfg = ns.db.healer
    local _, instanceType = IsInInstance()
    print(("|cff33ccffCombatCues debug|r enabled=%s soloTest=%s dungeonOnly=%s threshold=%s inGroup=%s inRaid=%s instance=%s inCombat=%s active=%s")
        :format(tostring(cfg.enabled), tostring(cfg.soloTest), tostring(cfg.dungeonOnly), tostring(cfg.threshold), tostring(IsInGroup()),
            tostring(IsInRaid()), tostring(instanceType), tostring(InCombatLockdown()),
            try(GroupTrackingActive, cfg)))
    local curveOk, curve = pcall(C_CurveUtil.CreateCurve)
    print(("  APIs: UnitPowerPercent=%s C_CurveUtil.CreateCurve=%s curve:SetType=%s LuaCurveType.Step=%s"):format(
        tostring(UnitPowerPercent ~= nil), tostring(C_CurveUtil ~= nil and C_CurveUtil.CreateCurve ~= nil),
        tostring(curveOk and curve.SetType ~= nil),
        tostring(Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step)))
    local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    for _, unit in ipairs(GroupUnits(true)) do
        local ok, alpha = LowManaAlpha(unit, cfg.threshold)
        print(("  %s (%s): role=%s powerType=%s percent=%s indicatorAlpha=%s"):format(
            unit, try(UnitName, unit), try(UnitGroupRolesAssigned, unit), try(UnitPowerType, unit),
            try(UnitPowerPercent, unit, mana), ok and show(alpha) or ("ERROR: " .. tostring(alpha))))
    end
    local lines = 0
    for _, line in ipairs(frames.healer.lines or {}) do
        if line:IsShown() then lines = lines + 1 end
    end
    print(("  indicator frame shown=%s lines=%d lastError=%s"):format(
        tostring(frames.healer:IsShown()), lines, tostring(ns.healerError)))
end

-- Live on-screen readout of the hidden mana values. Addon code can't read them, but
-- FontString:SetText accepts secret values and the game draws them.
local readout
function ns.ToggleManaReadout()
    if not readout then
        readout = CreateFrame("Frame", "CombatCues_ManaReadout", UIParent, "BackdropTemplate")
        readout:SetSize(260, 92)
        readout:SetPoint("TOP", UIParent, "TOP", 0, -120)
        readout:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        readout:SetBackdropColor(0, 0, 0, 0.7)
        readout.rows = {}
        local labels = { "Unit", "Raw percent", "Curve output", "Threshold" }
        for i, label in ipairs(labels) do
            local l = readout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            l:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 18)
            l:SetText(label)
            local v = readout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            v:SetPoint("TOPLEFT", 130, -10 - (i - 1) * 18)
            readout.rows[i] = v
        end
        readout.elapsed = 0
        readout:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 0.2 then return end
            self.elapsed = 0
            local cfg = ns.db.healer
            local unit = IndicatorUnits(cfg)[1] or "player"
            local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
            self.rows[1]:SetText(unit .. " (" .. (UnitName(unit) or "?") .. ")")
            local ok, raw = pcall(UnitPowerPercent, unit, mana)
            if not ok or not pcall(self.rows[2].SetText, self.rows[2], raw) then
                self.rows[2]:SetText("ERROR: " .. tostring(raw))
            end
            local ok2, alpha = LowManaAlpha(unit, cfg.threshold)
            if not ok2 or not pcall(self.rows[3].SetText, self.rows[3], alpha) then
                self.rows[3]:SetText("ERROR: " .. tostring(alpha))
            end
            self.rows[4]:SetText(cfg.threshold .. "%  (curve switches at " .. cfg.threshold / 100 .. ")")
        end)
        readout:Show()
    else
        readout:SetShown(not readout:IsShown())
    end
end

function ns.ResetPositions()
    for _, key in ipairs(ALERT_KEYS) do
        ns.db[key].x = DEFAULTS[key].x
        ns.db[key].y = DEFAULTS[key].y
    end
    ns.ApplyAll()
end

-- Events -------------------------------------------------------------------------

local function IsGroupUnit(unit)
    return unit == "player" or (type(unit) == "string" and unit:match("^party%d$") ~= nil)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CombatCuesDB = CombatCuesDB or {}
        ApplyDefaults(CombatCuesDB, DEFAULTS)
        ns.db = CombatCuesDB
        ns.db.locked = true
        if ns.db.healer.message:find("%%p") then ns.db.healer.message = DEFAULTS.healer.message end
        ns.db.healer.sound = nil

        frames.combat = CreateAlert("Combat", "Combat text")
        frames.death = CreateAlert("Death", "Death alert text")
        frames.healer = CreateAlert("Healer", "Healer mana alert text")
        for _, key in ipairs(ALERT_KEYS) do frames[key].cfg = ns.db[key] end
        ns.ApplyAll()

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UNIT_HEALTH")
        self:RegisterEvent("UNIT_FLAGS")
        self:RegisterEvent("UNIT_POWER_UPDATE")
        -- Fallback poll in case unit events are throttled or restricted.
        C_Timer.NewTicker(0.5, function()
            ScanDeaths(true)
            UpdateHealerIndicator()
        end)
        if ns.InitOptions then ns.InitOptions() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombat(false)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        ScanDeaths(false)
        UpdateHealerIndicator()
    elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        if IsGroupUnit(arg1) then ScanDeaths(true) end
    elseif event == "UNIT_POWER_UPDATE" then
        if arg2 == "MANA" and IsGroupUnit(arg1) then UpdateHealerIndicator() end
    end
end)
