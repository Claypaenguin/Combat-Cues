local ADDON, ns = ...

local widgets = {}
local category

local function Refresh()
    for _, w in ipairs(widgets) do w:Refresh() end
end
ns.RefreshOptions = Refresh

-- Widget helpers ------------------------------------------------------------------

local function Label(parent, x, y, text, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Checkbox(parent, x, y, text, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(text)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function cb:Refresh() self:SetChecked(get()) end
    widgets[#widgets + 1] = cb
    return 26
end

local HAS_MODERN_DROPDOWN = C_XMLUtil and C_XMLUtil.GetTemplateInfo
    and C_XMLUtil.GetTemplateInfo("WowStyle1DropdownTemplate") ~= nil

local function Dropdown(parent, x, y, text, listFn, get, set)
    Label(parent, x, y - 6, text, "GameFontHighlight")
    local dd
    if HAS_MODERN_DROPDOWN then
        dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dd:SetWidth(170)
        dd:SetPoint("TOPLEFT", x + 90, y)
        dd:SetupMenu(function(_, root)
            root:SetScrollMode(400)
            for _, v in ipairs(listFn()) do
                root:CreateRadio(v, function() return get() == v end, function() set(v) end)
            end
        end)
        function dd:Refresh() self:GenerateMenu() end
    else
        -- Legacy UIDropDownMenu fallback.
        dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", x + 74, y + 2)
        UIDropDownMenu_SetWidth(dd, 150)
        UIDropDownMenu_Initialize(dd, function()
            for _, v in ipairs(listFn()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v
                info.checked = get() == v
                info.func = function()
                    set(v)
                    UIDropDownMenu_SetText(dd, v)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        function dd:Refresh() UIDropDownMenu_SetText(self, get()) end
    end
    widgets[#widgets + 1] = dd
    return 32
end

-- Slider with a number box beside it; type a value and press Enter.
local function Slider(parent, x, y, text, minV, maxV, step, get, set)
    Label(parent, x, y, text, "GameFontHighlight")
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(50, 20)
    input:SetPoint("TOPLEFT", x + 214, y - 12)
    input:SetAutoFocus(false)
    input:SetJustifyH("CENTER")

    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 16)
    s:SetPoint("TOPLEFT", x, y - 14)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local function clamp(v)
        v = math.floor(v / step + 0.5) * step
        return math.min(maxV, math.max(minV, v))
    end
    s:SetScript("OnValueChanged", function(self, v, userInput)
        v = clamp(v)
        if not input:HasFocus() then input:SetText(v) end
        if userInput then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = clamp(get() + delta * step)
        set(v)
        self:SetValue(v)
    end)
    function s:Refresh()
        self:SetValue(get())
        input:SetText(get())
    end

    local function commit(self)
        local v = tonumber(self:GetText())
        if v then
            v = clamp(v)
            set(v)
            s:SetValue(v)
        end
        self:SetText(get())
    end
    input:SetScript("OnEnterPressed", function(self)
        commit(self)
        self:ClearFocus()
    end)
    input:SetScript("OnEditFocusLost", commit)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(get())
        self:ClearFocus()
    end)
    widgets[#widgets + 1] = s
    return 40
end

local function TextInput(parent, x, y, text, get, set)
    Label(parent, x, y, text, "GameFontHighlight")
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(240, 20)
    eb:SetPoint("TOPLEFT", x + 6, y - 14)
    eb:SetAutoFocus(false)
    local function save(self)
        set(self:GetText())
        self:ClearFocus()
    end
    eb:SetScript("OnEnterPressed", save)
    eb:SetScript("OnEditFocusLost", function(self) set(self:GetText()) end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:Refresh()
    end)
    function eb:Refresh() self:SetText(get()) end
    widgets[#widgets + 1] = eb
    return 42
end

local function Button(parent, x, y, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return 30
end

-- Shared controls for one alert (font, outline, size, duration, position) -------------

local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }

local function AppearanceControls(parent, x, y, cfgKey)
    local function cfg() return ns.db[cfgKey] end
    local function setter(field)
        return function(v)
            cfg()[field] = v
            ns.ApplyAll()
        end
    end
    local function getter(field)
        return function() return cfg()[field] end
    end

    y = y - Dropdown(parent, x, y, "Font", ns.GetFontList, getter("font"), setter("font"))
    y = y - Dropdown(parent, x, y, "Outline", function() return OUTLINES end, getter("outline"), setter("outline"))
    y = y - Slider(parent, x, y, "Font size", 8, 72, 1, getter("size"), setter("size"))
    y = y - Slider(parent, x, y, "Display time (sec)", 0.5, 10, 0.5, getter("hold"), setter("hold"))
    y = y - Slider(parent, x, y, "Position X", -1200, 1200, 1, getter("x"), setter("x"))
    y = y - Slider(parent, x, y, "Position Y", -800, 800, 1, getter("y"), setter("y"))
    return y
end

-- Panel ---------------------------------------------------------------------------

local function BuildPanel()
    local panel = CreateFrame("Frame")
    panel.name = "CombatCues"

    Label(panel, 16, -16, "CombatCues", "GameFontNormalLarge")
    Label(panel, 16, -38, "Tip: unlock to drag the text frames, or use the X/Y sliders.", "GameFontDisableSmall")

    Checkbox(panel, 16, -58, "Unlock frames (show and drag to move)",
        function() return not ns.db.locked end,
        function(v) ns.SetLocked(not v) end)
    Button(panel, 330, -58, "Reset positions", 140, function()
        ns.ResetPositions()
        Refresh()
    end)

    -- Combat column
    local x, y = 16, -100
    Label(panel, x, y, "Combat text")
    y = y - 22
    y = y - Checkbox(panel, x, y, "Enabled",
        function() return ns.db.combat.enabled end,
        function(v) ns.db.combat.enabled = v end)
    y = AppearanceControls(panel, x, y, "combat")
    y = y - TextInput(panel, x, y, "Enter combat text",
        function() return ns.db.combat.enterText end,
        function(v) ns.db.combat.enterText = v end)
    y = y - TextInput(panel, x, y, "Leave combat text",
        function() return ns.db.combat.leaveText end,
        function(v) ns.db.combat.leaveText = v end)
    Button(panel, x, y, "Test", 100, ns.TestCombat)

    -- Death column
    x, y = 330, -100
    Label(panel, x, y, "Party death alert")
    y = y - 22
    y = y - Checkbox(panel, x, y, "Enabled",
        function() return ns.db.death.enabled end,
        function(v) ns.db.death.enabled = v end)
    y = AppearanceControls(panel, x, y, "death")
    y = y - TextInput(panel, x, y, "Message (%s = name)",
        function() return ns.db.death.message end,
        function(v) ns.db.death.message = v end)
    y = y - Dropdown(panel, x, y, "Sound", ns.GetSoundList,
        function() return ns.db.death.sound end,
        function(v)
            ns.db.death.sound = v
            ns.PlayAlertSound(v)
        end)
    y = y - Checkbox(panel, x, y, "Include myself",
        function() return ns.db.death.includeSelf end,
        function(v) ns.db.death.includeSelf = v end)
    y = y - Checkbox(panel, x, y, "Only inside dungeons",
        function() return ns.db.death.dungeonOnly end,
        function(v) ns.db.death.dungeonOnly = v end)
    Button(panel, x, y, "Test", 100, ns.TestDeath)

    panel:SetScript("OnShow", Refresh)
    return panel
end

local function OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("CombatCues")
    end
end

function ns.InitOptions()
    local panel = BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "CombatCues")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Slash commands --------------------------------------------------------------------

SLASH_COMBATCUES1 = "/combatcues"
SLASH_COMBATCUES2 = "/ccues"
SlashCmdList.COMBATCUES = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "unlock" then
        ns.SetLocked(false)
    elseif cmd == "lock" then
        ns.SetLocked(true)
    elseif cmd == "reset" then
        ns.ResetPositions()
    elseif cmd == "test" then
        if arg == "death" then ns.TestDeath() else ns.TestCombat() end
    elseif cmd == "" or cmd == "config" or cmd == "options" then
        OpenOptions()
    else
        print("|cff33ccffCombatCues|r: /ccues [options | unlock | lock | reset | test combat | test death]")
    end
    Refresh()
end
