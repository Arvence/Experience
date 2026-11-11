local _, addon = ...
local entries = {}
local events = CreateFrame("Frame")
local initializationIssue = "waiting for player login"
local fillTexture = "Interface\\TargetingFrame\\UI-StatusBar"

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

local function UpdateLayout(entry)
    entry.bar:SetHeight(entry.native.StatusBar:GetHeight() + 1)
    UpdateDivisions(entry)
end

local function UpdateXP(entry)
    local current = UnitXP("player")
    local maximum = UnitXPMax("player")

    if issecretvalue(current) or issecretvalue(maximum) or type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        entry.dataAvailable = false
        SetActive(entry, false)
        return
    end

    entry.dataAvailable = true
    entry.fill:SetMinMaxValues(0, maximum)
    entry.fill:SetValue(math.min(math.max(current, 0), maximum))
    SetActive(entry, entry.native:IsShown() and GameRulesUtil.CanShowExperienceBar())
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
    border:SetColorTexture(0.38, 0.31, 0.19, 1)

    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    fill:SetStatusBarTexture(fillTexture)
    fill:SetStatusBarColor(0.58, 0.14, 0.78, 1)
    fill:EnableMouse(false)

    local background = fill:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(fillTexture)
    background:SetVertexColor(0.08, 0.065, 0.10, 1)

    local highlight = fill:CreateTexture(nil, "OVERLAY")
    highlight:SetPoint("TOPLEFT")
    highlight:SetPoint("TOPRIGHT")
    highlight:SetHeight(1)
    highlight:SetColorTexture(1, 1, 1, 0.12)

    local entry = {
        container = container,
        native = native,
        bar = bar,
        fill = fill,
        nativeAlpha = native:GetAlpha(),
        borderAlpha = container.BarFrameTexture:GetAlpha(),
        nativeMouse = native:IsMouseEnabled(),
        tickMouse = native.ExhaustionTick:IsMouseEnabled(),
        dividerAlphas = {},
        divisions = {},
    }

    bar:SetScript("OnSizeChanged", function()
        UpdateDivisions(entry)
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

    for _, container in ipairs(manager.barContainers) do
        entries[#entries + 1] = CreateEntry(container, container.bars[experienceIndex])
    end

    initializationIssue = nil
    events:UnregisterAllEvents()
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

events:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName == "Blizzard_StatusTrackingBar" then
        Initialize()
    end
end)

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
Initialize()
