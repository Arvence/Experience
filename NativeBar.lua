local _, addon = ...
local entries = {}
local events = CreateFrame("Frame")
local initializationIssue = "waiting for player login"
local fillTexture = "Interface\\TargetingFrame\\UI-StatusBar"
local roundedMask = "Interface\\AddOns\\Experience\\Media\\RoundedBarMask.png"

local function SuppressNativeAlpha(entry)
    if entry.active and entry.native:GetAlpha() ~= 0 then
        entry.native:SetAlpha(0)
    end
end

local function UpdateDecoration(entry)
    entry.container.BarFrameTexture:SetAlpha(entry.active and 0 or entry.borderAlpha)

    for divider in entry.container.HorizontalDividersPool:EnumerateActive() do
        if entry.dividerAlphas[divider] == nil then
            entry.dividerAlphas[divider] = divider:GetAlpha()
        end

        divider:SetAlpha(entry.active and 0 or entry.dividerAlphas[divider])
    end
end

local function SetActive(entry, active)
    if entry.active ~= active then
        entry.active = active
        entry.native:SetAlpha(active and 0 or entry.nativeAlpha)
        entry.native:EnableMouse(not active and entry.nativeMouse)
        entry.native.ExhaustionTick:EnableMouse(not active and entry.tickMouse)
        entry.bar:SetShown(active)
        if not active then
            addon:HideTooltip(entry)
        end
    end

    SuppressNativeAlpha(entry)
    UpdateDecoration(entry)
end

local function UpdateDivisions(entry)
    local count = entry.container:GetExpectedSegments()
    local width = entry.fill:GetWidth()

    for index = 1, count - 1 do
        local divider = entry.divisions[index]
        if not divider then
            divider = entry.fill:CreateTexture(nil, "OVERLAY")
            divider:SetAtlas("ui-hud-experiencebar-divider")
            divider:SetWidth(3)
            divider:SetAlpha(0.45)
            entry.divisions[index] = divider
        end

        local offset = width * index / count
        divider:ClearAllPoints()
        divider:SetPoint("TOP", entry.fill, "TOPLEFT", offset, 0)
        divider:SetPoint("BOTTOM", entry.fill, "BOTTOMLEFT", offset, 0)
        divider:Show()
    end

    for index = count, #entry.divisions do
        entry.divisions[index]:Hide()
    end
end

local function PlaceSegment(texture, fill, startXP, amount, maximum, width)
    if amount <= 0 then
        texture:Hide()
        return
    end

    local offset = width * startXP / maximum
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", fill, "TOPLEFT", offset, 0)
    texture:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", offset, 0)
    texture:SetWidth(width * amount / maximum)
    texture:Show()
end

local function UpdateSegments(entry)
    local data = addon.xpData
    if not data.current or not data.maximum then
        entry.questPreview:Hide()
        entry.restedPreview:Hide()
        return
    end

    local maximum = data.maximum
    local current = math.min(data.current, maximum)
    local available = maximum - current
    local quest = math.min(data.questKnownXP, available)
    local rested = math.min(data.restedXP or 0, available - quest)
    local width = entry.fill:GetWidth()

    PlaceSegment(entry.questPreview, entry.fill, current, quest, maximum, width)
    PlaceSegment(entry.restedPreview, entry.fill, current + quest, rested, maximum, width)
end

local function UpdateLayout(entry)
    entry.bar:SetHeight(entry.native.StatusBar:GetHeight() + 3)
    UpdateDivisions(entry)
    UpdateSegments(entry)
    addon:UpdateBarText(entry)
end

local function UpdateXP(entry)
    local data = addon.xpData
    local current = data.current
    local maximum = data.maximum

    if not current or not maximum then
        entry.dataAvailable = false
        SetActive(entry, false)
        return
    end

    entry.dataAvailable = true
    entry.fill:SetMinMaxValues(0, maximum)
    entry.fill:SetValue(math.min(math.max(current, 0), maximum))
    UpdateSegments(entry)
    addon:UpdateBarText(entry)
    SetActive(entry, entry.native:IsShown() and GameRulesUtil.CanShowExperienceBar())
    addon:UpdateTooltip(entry)
end

local function CreateEntry(container, native)
    local bar = CreateFrame("Frame", nil, native)
    bar:Hide()
    bar:SetIgnoreParentAlpha(true)
    bar:SetFrameStrata(native.OverlayFrame:GetFrameStrata())
    bar:SetFrameLevel(math.max(native.OverlayFrame:GetFrameLevel(), native.ExhaustionTick:GetFrameLevel()) + 1)
    bar:SetPoint("LEFT", native.StatusBar, "LEFT", 0, 0)
    bar:SetPoint("RIGHT", native.StatusBar, "RIGHT", 0, 0)
    bar:EnableMouse(true)

    local border = bar:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture(fillTexture)
    border:SetVertexColor(0.84, 0.69, 0.44, 1)

    local borderMask = bar:CreateMaskTexture()
    borderMask:SetAllPoints()
    borderMask:SetTexture(roundedMask)
    border:AddMaskTexture(borderMask)

    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    fill:SetStatusBarTexture(fillTexture)
    fill:SetStatusBarColor(0.62, 0.37, 0.90, 1)
    fill:EnableMouse(false)

    local background = fill:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(fillTexture)
    background:SetVertexColor(0.04, 0.055, 0.11, 1)

    local highlight = fill:CreateTexture(nil, "OVERLAY")
    highlight:SetPoint("TOPLEFT")
    highlight:SetPoint("TOPRIGHT")
    highlight:SetHeight(1)
    highlight:SetColorTexture(1, 1, 1, 0.04)

    local fillMask = fill:CreateMaskTexture()
    fillMask:SetAllPoints()
    fillMask:SetTexture(roundedMask)
    fill:GetStatusBarTexture():AddMaskTexture(fillMask)
    background:AddMaskTexture(fillMask)
    highlight:AddMaskTexture(fillMask)

    local questPreview = fill:CreateTexture(nil, "ARTWORK", nil, 1)
    questPreview:SetTexture(fillTexture)
    questPreview:SetVertexColor(0.54, 0.41, 0.18, 1)
    questPreview:AddMaskTexture(fillMask)
    questPreview:Hide()

    local restedPreview = fill:CreateTexture(nil, "ARTWORK", nil, 1)
    restedPreview:SetTexture(fillTexture)
    restedPreview:SetVertexColor(0.25, 0.30, 0.41, 1)
    restedPreview:AddMaskTexture(fillMask)
    restedPreview:Hide()

    local entry = {
        container = container,
        native = native,
        bar = bar,
        fill = fill,
        questPreview = questPreview,
        restedPreview = restedPreview,
        nativeAlpha = native:GetAlpha(),
        borderAlpha = container.BarFrameTexture:GetAlpha(),
        nativeMouse = native:IsMouseEnabled(),
        tickMouse = native.ExhaustionTick:IsMouseEnabled(),
        dividerAlphas = {},
        divisions = {},
    }

    addon:CreateBarText(entry)
    addon:AttachTooltip(entry)

    bar:SetScript("OnSizeChanged", function()
        UpdateDivisions(entry)
        UpdateSegments(entry)
        addon:UpdateBarText(entry)
    end)

    native.StatusBar:HookScript("OnSizeChanged", function()
        UpdateLayout(entry)
    end)

    native:HookScript("OnShow", function()
        UpdateXP(entry)
    end)

    native:HookScript("OnHide", function()
        SetActive(entry, false)
    end)

    hooksecurefunc(native, "SetAlpha", function()
        SuppressNativeAlpha(entry)
    end)

    hooksecurefunc(native, "Update", function()
        addon:RefreshProgressData()
        UpdateXP(entry)
    end)

    hooksecurefunc(container, "UpdateDividers", function()
        UpdateDivisions(entry)
        UpdateDecoration(entry)
    end)

    UpdateLayout(entry)
    UpdateXP(entry)
    return entry
end

local function Initialize()
    if #entries > 0 or not IsLoggedIn() then
        return
    end

    if InCombatLockdown() then
        initializationIssue = "waiting for combat to end"
        return
    end

    local manager = StatusTrackingBarManager
    local experienceIndex = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum and StatusTrackingBarInfo.BarsEnum.Experience
    if not manager or not manager.barContainers or not experienceIndex or not GameRulesUtil or not GameRulesUtil.CanShowExperienceBar then
        initializationIssue = "native status tracking manager unavailable"
        return
    end

    if #manager.barContainers == 0 then
        initializationIssue = "native status tracking containers unavailable"
        return
    end

    for _, container in ipairs(manager.barContainers) do
        local native = container.bars and container.bars[experienceIndex]
        if not native or not native.isExpBar or not native.StatusBar or not native.OverlayFrame or not native.ExhaustionTick
            or not container.BarFrameTexture or not container.HorizontalDividersPool
            or type(container.GetExpectedSegments) ~= "function" or type(container.UpdateDividers) ~= "function" or type(native.Update) ~= "function" then
            initializationIssue = "native XP frame layout is unsupported"
            return
        end

        if container:IsProtected() or native:IsProtected() or native.StatusBar:IsProtected() or native.ExhaustionTick:IsProtected() then
            initializationIssue = "native XP frames are protected; native display retained"
            return
        end
    end

    addon:RefreshProgressData()
    addon:RefreshQuestData()

    for _, container in ipairs(manager.barContainers) do
        entries[#entries + 1] = CreateEntry(container, container.bars[experienceIndex])
    end

    initializationIssue = nil
    events:UnregisterAllEvents()
end

function addon:RefreshBars()
    for _, entry in ipairs(entries) do
        UpdateXP(entry)
    end
end

function addon:PrintBarStatus()
    if initializationIssue then
        print("Experience: " .. initializationIssue .. ".")
        return
    end

    for index, entry in ipairs(entries) do
        local nativeX, nativeY = entry.native.StatusBar:GetCenter()
        local barX, barY = entry.bar:GetCenter()
        local delta = "unavailable"
        if nativeX and nativeY and barX and barY then
            delta = string.format("%.2f, %.2f", barX - nativeX, barY - nativeY)
        end

        local dimensions = string.format("native %.2fx%.2f, replacement %.2fx%.2f", entry.native.StatusBar:GetWidth(), entry.native.StatusBar:GetHeight(), entry.bar:GetWidth(), entry.bar:GetHeight())
        local alignment = string.format("center delta %s, scale %.3f", delta, entry.bar:GetEffectiveScale())
        local state = string.format("visible %s, native alpha %.2f, XP data %s", tostring(entry.bar:IsVisible()), entry.native:GetAlpha(), entry.dataAvailable and "available" or "unavailable")
        print(string.format("Experience: container %d, %s, %s, %s.", index, dimensions, alignment, state))
    end
end

function addon:PrintTextStatus()
    if initializationIssue then
        print("Experience: " .. initializationIssue .. ".")
        return
    end
    self:PrintTextStatusEntries(entries)
end

events:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName == "Blizzard_StatusTrackingBar" then
        Initialize()
    end
end)

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
Initialize()
