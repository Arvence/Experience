local addonName, addon = ...
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    ExperienceDB = ExperienceDB or {}
    if ExperienceDB.wellRestedCalculator == nil then
        ExperienceDB.wellRestedCalculator = true
    end
    addon.wellRestedEnabled = ExperienceDB.wellRestedCalculator
    if ExperienceDB.xpTracker == nil then
        ExperienceDB.xpTracker = true
    end
    addon.xpTrackerEnabled = ExperienceDB.xpTracker
    for _, key in ipairs({ "showBarText", "showXP", "showLeft", "showQuestXP", "showRested", "showXPPerHour", "showLevelETA" }) do
        if ExperienceDB[key] == nil then
            ExperienceDB[key] = true
        end
    end
    addon.textSettings = ExperienceDB
    if type(ExperienceDB.barOpacity) ~= "number" then
        ExperienceDB.barOpacity = 100
    end
    ExperienceDB.barOpacity = math.max(0, math.min(100, math.floor(ExperienceDB.barOpacity + 0.5)))
    addon.barOpacity = ExperienceDB.barOpacity

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Experience")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -22)
    title:SetScale(1.12)
    title:SetText("Experience")

    local introduction = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    introduction:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
    introduction:SetWidth(490)
    introduction:SetScale(1.12)
    introduction:SetJustifyH("LEFT")
    introduction:SetText("Track your experience, rested XP, and completed quest rewards in a compact XP bar. Hover over the bar for detailed information.")

    local controls = {}
    local children = {}
    local UpdateChildStates
    local function AddToggle(key, label, y, indent, refreshText)
        local setting = Settings.RegisterAddOnSetting(category, "EXPERIENCE_" .. key:upper(), key, ExperienceDB, Settings.VarType.Boolean, label, true)
        local checkbox = CreateFrame("CheckButton", nil, panel, "CheckboxWithLabelTemplate")
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 28 + indent, -y)
        checkbox:SetChecked(setting:GetValue())
        checkbox.Text:SetFontObject(GameFontNormal)
        checkbox.Text:SetScale(1.12)
        checkbox.Text:SetText(label)
        checkbox:SetScript("OnClick", function(self)
            setting:SetValue(self:GetChecked())
            if key == "showBarText" or key == "xpTracker" then
                UpdateChildStates()
            end
            if refreshText then
                addon:RefreshBarText()
            end
        end)
        controls[#controls + 1] = { setting = setting, checkbox = checkbox }
        return checkbox
    end

    local calculator = AddToggle("wellRestedCalculator", "3% Well-Rested Calculator", 100, 0, false)

    local calculatorDescription = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    calculatorDescription:SetPoint("TOPLEFT", calculator.Text, "BOTTOMLEFT", 0, -5)
    calculatorDescription:SetScale(1.12)
    calculatorDescription:SetText("Includes the additional 3% Well-Rested bonus in XP calculations.")
    local reload = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableTiny")
    reload:SetPoint("TOPLEFT", calculatorDescription, "BOTTOMLEFT", 0, -3)
    reload:SetScale(1.12)
    reload:SetText("Reload Required")

    local tracker = AddToggle("xpTracker", "XP Tracker", 157, 0, false)
    local trackerReload = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableTiny")
    trackerReload:SetPoint("TOPLEFT", tracker.Text, "BOTTOMLEFT", 0, -3)
    trackerReload:SetScale(1.12)
    trackerReload:SetText("Reload Required")

    local master = AddToggle("showBarText", "Show Experience Bar Text", 207, 0, true)
    master.Text:SetScale(1.04)
    local textDescription = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    textDescription:SetPoint("TOPLEFT", master.Text, "BOTTOMLEFT", 0, -5)
    textDescription:SetScale(1.04)
    textDescription:SetText("Display experience information directly on the XP bar.")
    children[1] = AddToggle("showXP", "Show XP", 255, 18, true)
    children[2] = AddToggle("showLeft", "Show Left", 287, 18, true)
    children[3] = AddToggle("showQuestXP", "Show Quest XP", 319, 18, true)
    children[4] = AddToggle("showRested", "Show Rested", 351, 18, true)
    children[5] = AddToggle("showXPPerHour", "Show XP/h", 383, 18, true)
    children[6] = AddToggle("showLevelETA", "Show Level in", 415, 18, true)
    for _, child in ipairs(children) do
        child.Text:SetScale(1.04)
    end

    local display = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    display:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -457)
    display:SetScale(1.12)
    display:SetText("Display")

    local opacitySetting = Settings.RegisterAddOnSetting(category, "EXPERIENCE_BAR_OPACITY", "barOpacity", ExperienceDB, Settings.VarType.Number, "Bar Opacity", 100)
    local opacityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -15)
    opacityLabel:SetScale(1.12)
    local function UpdateOpacityLabel(value)
        opacityLabel:SetText(string.format("Bar Opacity — %d%%", value))
    end
    UpdateOpacityLabel(opacitySetting:GetValue())

    local opacityDescription = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityDescription:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -5)
    opacityDescription:SetScale(1.12)
    opacityDescription:SetText("Adjust the visibility of the Experience bar.")

    local slider = CreateFrame("Slider", nil, panel, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", opacityDescription, "BOTTOMLEFT", 0, -11)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetValue(opacitySetting:GetValue())
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        opacitySetting:SetValue(value)
        UpdateOpacityLabel(value)
        addon:SetBarOpacity(value)
    end)

    UpdateChildStates = function()
        for index, child in ipairs(children) do
            local enabled = master:GetChecked() and (index <= 4 or tracker:GetChecked())
            child:SetEnabled(enabled)
            child.Text:SetFontObject(enabled and GameFontNormal or GameFontDisable)
        end
    end

    local function UpdateControls()
        for _, control in ipairs(controls) do
            control.checkbox:SetChecked(control.setting:GetValue())
        end
        UpdateChildStates()
        local value = opacitySetting:GetValue()
        slider:SetValue(value)
        UpdateOpacityLabel(value)
        addon:SetBarOpacity(value)
    end

    panel.OnRefresh = function()
        UpdateControls()
    end
    panel.OnDefault = function()
        for _, control in ipairs(controls) do
            control.setting:SetValueToDefault()
        end
        opacitySetting:SetValueToDefault()
        UpdateControls()
        addon:RefreshBars()
    end
    UpdateControls()
    Settings.RegisterAddOnCategory(category)

    local function OpenSettings()
        if SettingsPanel and SettingsPanel:IsShown() and SettingsPanel:GetCurrentCategory() == category then
            return
        end
        Settings.OpenToCategory(category:GetID())
    end

    SLASH_EXP1 = "/exp"
    SlashCmdList.EXP = OpenSettings

    SLASH_EXPERIENCE1 = "/experience"
    SlashCmdList.EXPERIENCE = function(message)
        local command = (message or ""):lower():match("^%s*%-c%s*(.-)%s*$")
        if not command then
            OpenSettings()
            return
        end

        if command == "bar" then
            addon:PrintBarStatus()
            return
        end

        if command == "data" then
            addon:PrintDataStatus()
            return
        end

        if command == "text" then
            addon:PrintTextStatus()
            return
        end

        local version, build, _, interfaceVersion = GetBuildInfo()
        print(string.format("%s: bootstrap loaded. Client %s (build %s), interface %s.", addonName, version, build, tostring(interfaceVersion)))
    end

    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffd100Experience|r || v%s || Settings: /exp || XP/h & Level ETA enabled.", version))

    self:UnregisterEvent("ADDON_LOADED")
end)

frame:RegisterEvent("ADDON_LOADED")
