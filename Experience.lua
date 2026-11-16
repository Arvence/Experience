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
    for _, key in ipairs({ "showBarText", "showXP", "showLeft", "showQuestXP", "showRested" }) do
        if ExperienceDB[key] == nil then
            ExperienceDB[key] = true
        end
    end
    addon.textSettings = ExperienceDB

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
            if refreshText then
                if key == "showBarText" then
                    for _, child in ipairs(children) do
                        child:SetEnabled(self:GetChecked())
                        child.Text:SetFontObject(self:GetChecked() and GameFontNormal or GameFontDisable)
                    end
                end
                addon:RefreshBars()
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

    local master = AddToggle("showBarText", "Show Experience Bar Text", 178, 0, true)
    local textDescription = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    textDescription:SetPoint("TOPLEFT", master.Text, "BOTTOMLEFT", 0, -5)
    textDescription:SetScale(1.12)
    textDescription:SetText("Display experience information directly on the XP bar.")
    children[1] = AddToggle("showXP", "Show XP", 236, 18, true)
    children[2] = AddToggle("showLeft", "Show Left", 273, 18, true)
    children[3] = AddToggle("showQuestXP", "Show Quest XP", 310, 18, true)
    children[4] = AddToggle("showRested", "Show Rested", 347, 18, true)

    local function UpdateControls()
        for _, control in ipairs(controls) do
            control.checkbox:SetChecked(control.setting:GetValue())
        end
        for _, child in ipairs(children) do
            child:SetEnabled(master:GetChecked())
            child.Text:SetFontObject(master:GetChecked() and GameFontNormal or GameFontDisable)
        end
    end

    panel.OnRefresh = function()
        UpdateControls()
    end
    panel.OnDefault = function()
        for _, control in ipairs(controls) do
            control.setting:SetValueToDefault()
        end
        UpdateControls()
        addon:RefreshBars()
    end
    UpdateControls()
    Settings.RegisterAddOnCategory(category)

    SLASH_EXPERIENCE1 = "/experience"
    SlashCmdList.EXPERIENCE = function(message)
        if message:lower():match("^%s*bar%s*$") then
            addon:PrintBarStatus()
            return
        end

        if message:lower():match("^%s*data%s*$") then
            addon:PrintDataStatus()
            return
        end

        if message:lower():match("^%s*text%s*$") then
            addon:PrintTextStatus()
            return
        end

        local version, build, _, interfaceVersion = GetBuildInfo()
        print(string.format("%s: bootstrap loaded. Client %s (build %s), interface %s.", addonName, version, build, tostring(interfaceVersion)))
    end

    self:UnregisterEvent("ADDON_LOADED")
end)

frame:RegisterEvent("ADDON_LOADED")
