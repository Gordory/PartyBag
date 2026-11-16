local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale("PartyBag")

local MODES = { "SHORT", "FULL" }
local MODE_LABELS = { SHORT = "MODE_SHORT", FULL = "MODE_FULL" }

local function RegisterSettingsPage()
    local category = Settings.RegisterVerticalLayoutCategory(L.OPTIONS_TITLE)
    local function Register(key, label)
        local default = ns.DEFAULTS[key]
        local setting = Settings.RegisterAddOnSetting(category, "PartyBag_" .. key, key, PartyBagDB,
            type(default), label, default)
        setting:SetValueChangedCallback(ns.OnSettingsChanged)
        return setting
    end
    Settings.CreateCheckbox(category, Register("showHeader", L.OPT_HEADER), L.OPT_HEADER_DESC)
    Settings.CreateCheckbox(category, Register("showSelf", L.OPT_SELF), L.OPT_SELF_DESC)
    local function GetModeOptions()
        local container = Settings.CreateControlTextContainer()
        for _, mode in ipairs(MODES) do
            container:Add(mode, L[MODE_LABELS[mode]], L[MODE_LABELS[mode] .. "_DESC"])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, Register("mode", L.OPT_MODE), GetModeOptions, L.OPT_MODE_DESC)
    Settings.RegisterAddOnCategory(category)
end

local function SetLabel(button, text)
    -- Older templates expose the label as .text, newer ones as .Text.
    local label = button.Text or button.text
    if label then
        label:SetText(text)
    end
end

local function AddTooltip(widget, title, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function BuildPanel()
    local panel = CreateFrame("Frame")
    panel.name = L.OPTIONS_TITLE
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.OPTIONS_TITLE)

    local refreshers = {}
    local anchor, offset = title, -12
    local function Place(widget, x)
        widget:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, offset)
        anchor, offset = widget, -4
    end

    local function AddCheckbox(key, label, desc)
        local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        Place(box)
        SetLabel(box, label)
        AddTooltip(box, label, desc)
        box:SetScript("OnClick", function(self)
            PartyBagDB[key] = self:GetChecked() and true or false
            ns.OnSettingsChanged()
        end)
        refreshers[#refreshers + 1] = function()
            box:SetChecked(PartyBagDB[key])
        end
    end
    AddCheckbox("showHeader", L.OPT_HEADER, L.OPT_HEADER_DESC)
    AddCheckbox("showSelf", L.OPT_SELF, L.OPT_SELF_DESC)

    local modeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    offset = -12
    Place(modeTitle)
    modeTitle:SetText(L.OPT_MODE)
    offset = -6
    local radios = {}
    for _, mode in ipairs(MODES) do
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        Place(radio, mode == MODES[1] and 4 or 0)
        SetLabel(radio, L[MODE_LABELS[mode]])
        AddTooltip(radio, L[MODE_LABELS[mode]], L[MODE_LABELS[mode] .. "_DESC"])
        radio:SetScript("OnClick", function()
            PartyBagDB.mode = mode
            ns.OnSettingsChanged()
            for value, other in pairs(radios) do
                other:SetChecked(value == mode)
            end
        end)
        radios[mode] = radio
    end
    refreshers[#refreshers + 1] = function()
        for value, radio in pairs(radios) do
            radio:SetChecked(PartyBagDB.mode == value)
        end
    end

    panel:SetScript("OnShow", function()
        for _, refresh in ipairs(refreshers) do
            refresh()
        end
    end)
    return panel
end

-- The vertical layout needs the 11.x Settings API (CreateDropdown); older clients get a hand-built panel.
function ns.RegisterOptions()
    if Settings and Settings.RegisterVerticalLayoutCategory and Settings.CreateDropdown and Settings.CreateCheckbox then
        RegisterSettingsPage()
        return
    end
    local panel = BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    else
        InterfaceOptions_AddCategory(panel)
    end
end
