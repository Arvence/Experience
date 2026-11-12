local _, addon = ...
local tooltip
local owner
local minimumWidth = 260
local width = minimumWidth
local padding = 8
local rowHeight = 13
local columnGap = 8
local dash = "—"

local function Value(value)
    return value == nil and dash or BreakUpLargeNumbers(value)
end

local function NewText(parent, template, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(false)
    return text
end

local function MeasureText(value)
    tooltip.measure:SetText(value)
    return tooltip.measure:GetStringWidth()
end

local function NewRow(parent)
    local left = NewText(parent, "GameFontHighlightSmall")
    local right = NewText(parent, "GameFontHighlightSmall", "RIGHT")
    left:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    right:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    return { left = left, right = right }
end

local function PlaceRow(row, y, label, value)
    local valueWidth = math.ceil(MeasureText(value)) + 1
    row.left:ClearAllPoints()
    row.left:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -y)
    row.left:SetWidth(width - 2 * padding - valueWidth - columnGap)
    row.left:SetText(label)
    row.right:ClearAllPoints()
    row.right:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -padding, -y)
    row.right:SetWidth(valueWidth)
    row.right:SetText(value)
end

local function PlaceHeading(heading, y, title)
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -y)
    heading:SetText(title)
end

local function CanKeepOpen()
    return owner and owner.bar:IsMouseOver() or tooltip:IsMouseOver()
end

local function HideIfOutside()
    if not CanKeepOpen() then
        tooltip:Hide()
        owner = nil
    end
end

local function CreateTooltip()
    tooltip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetWidth(width)
    tooltip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tooltip:SetBackdropColor(0.04, 0.04, 0.06, 0.94)
    tooltip:SetBackdropBorderColor(0.55, 0.47, 0.31, 0.9)
    tooltip:EnableMouse(true)
    tooltip:Hide()
    tooltip:SetScript("OnLeave", HideIfOutside)

    tooltip.measure = NewText(tooltip, "GameFontHighlightSmall")
    tooltip.measure:SetAlpha(0)

    tooltip.experienceHeading = NewText(tooltip, "GameFontNormalSmall")
    tooltip.questHeading = NewText(tooltip, "GameFontNormalSmall")
    tooltip.sessionHeading = NewText(tooltip, "GameFontNormalSmall")
    tooltip.progress = NewRow(tooltip)
    tooltip.remaining = NewRow(tooltip)
    tooltip.questSummary = NewRow(tooltip)
    tooltip.rested = NewRow(tooltip)
    tooltip.unknown = NewRow(tooltip)
    tooltip.sessionXP = NewRow(tooltip)
    tooltip.sessionTime = NewRow(tooltip)
    tooltip.sessionRate = NewRow(tooltip)
    tooltip.sessionETA = NewRow(tooltip)
    tooltip.questRows = {}

    local scroll = CreateFrame("ScrollFrame", nil, tooltip)
    scroll:SetWidth(width - 2 * padding)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width - 2 * padding)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if tooltip.scrollNeeded then
            self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 26)))
        end
    end)
    tooltip.scroll = scroll
    tooltip.content = content
end

local function UpdateWidth(data, progressValue, questLabel, questTotal)
    local needed = 0
    local function Include(label, value)
        needed = math.max(needed, MeasureText(label) + MeasureText(value) + columnGap + 2 * padding)
    end

    Include("Current", progressValue)
    Include("Remaining", Value(data.remaining))
    Include(questLabel, Value(questTotal))
    Include("Rested bonus", Value(data.restedXP))
    if data.questUnknownCount > 0 then
        Include("Rewards unavailable", tostring(data.questUnknownCount))
    end
    Include("XP gained", dash)
    Include("Elapsed", dash)
    Include("XP/h", dash)
    Include("Time to level", dash)
    needed = math.max(needed, MeasureText(string.format("Completed quests (%d)", data.questCount)) + 2 * padding)

    for _, quest in ipairs(data.quests) do
        Include(quest.name or "Name unavailable", Value(quest.xp))
    end

    width = math.max(minimumWidth, math.ceil(needed) + 2)
    tooltip:SetWidth(width)
    tooltip.scroll:SetWidth(width - 2 * padding)
    tooltip.content:SetWidth(width - 2 * padding)
end

local function PopulateQuests(data)
    local y = 0
    for index, quest in ipairs(data.quests) do
        local row = tooltip.questRows[index]
        if not row then
            row = NewRow(tooltip.content)
            row.left:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            tooltip.questRows[index] = row
        end
        row.left:ClearAllPoints()
        row.left:SetPoint("TOPLEFT", tooltip.content, "TOPLEFT", 0, -y)
        local reward = Value(quest.xp)
        local rewardWidth = math.ceil(MeasureText(reward)) + 1
        row.left:SetWidth(width - 2 * padding - rewardWidth - columnGap)
        row.left:Show()
        row.left:SetText(quest.name or "Name unavailable")
        local height = math.max(rowHeight, math.ceil(row.left:GetStringHeight()))
        row.right:ClearAllPoints()
        row.right:SetPoint("TOPRIGHT", tooltip.content, "TOPRIGHT", 0, -y)
        row.right:SetWidth(rewardWidth)
        row.right:SetText(reward)
        row.right:Show()
        y = y + height + 2
    end
    for index = #data.quests + 1, #tooltip.questRows do
        tooltip.questRows[index].left:Hide()
        tooltip.questRows[index].right:Hide()
    end
    tooltip.content:SetHeight(math.max(1, y))
    return y
end

local function Populate(entry)
    local data = addon.xpData
    local progressValue = Value(data.current) .. " / " .. Value(data.maximum)
    local questTotal = data.questXP
    local questLabel = data.questPercentPartial and "Known quest XP" or "Completed quest XP"
    UpdateWidth(data, progressValue, questLabel, questTotal)
    local y = padding
    PlaceHeading(tooltip.experienceHeading, y, "Experience")
    y = y + 15
    PlaceRow(tooltip.progress, y, "Current", progressValue)
    y = y + rowHeight
    PlaceRow(tooltip.remaining, y, "Remaining", Value(data.remaining))
    y = y + rowHeight

    PlaceRow(tooltip.questSummary, y, questLabel, Value(questTotal))
    y = y + rowHeight
    PlaceRow(tooltip.rested, y, "Rested bonus", Value(data.restedXP))
    y = y + rowHeight + 3

    PlaceHeading(tooltip.questHeading, y, string.format("Completed quests (%d)", data.questCount))
    y = y + 15
    local questTop = y
    local questHeight = PopulateQuests(data)
    local footerHeight = (data.questUnknownCount > 0 and rowHeight or 0) + 3 + 15 + 4 * rowHeight + padding
    local above = UIParent:GetHeight() - (entry.bar:GetTop() or 0)
    local below = entry.bar:GetBottom() or 0
    local placeAbove = above >= below
    local availableHeight = (placeAbove and above or below) - 16
    local maxListHeight = math.max(1, availableHeight - questTop - footerHeight)
    local visibleHeight = math.min(questHeight, maxListHeight)
    tooltip.scrollNeeded = questHeight > visibleHeight
    tooltip.scroll:ClearAllPoints()
    tooltip.scroll:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -questTop)
    tooltip.scroll:SetHeight(math.max(1, visibleHeight))
    tooltip.scroll:SetVerticalScroll(0)
    tooltip.scroll:SetShown(questHeight > 0)
    y = y + visibleHeight

    if data.questUnknownCount > 0 then
        PlaceRow(tooltip.unknown, y, "Rewards unavailable", tostring(data.questUnknownCount))
        tooltip.unknown.left:Show()
        tooltip.unknown.right:Show()
        y = y + rowHeight
    else
        tooltip.unknown.left:Hide()
        tooltip.unknown.right:Hide()
    end

    y = y + 3
    PlaceHeading(tooltip.sessionHeading, y, "This session")
    y = y + 15
    PlaceRow(tooltip.sessionXP, y, "XP gained", dash)
    y = y + rowHeight
    PlaceRow(tooltip.sessionTime, y, "Elapsed", dash)
    y = y + rowHeight
    PlaceRow(tooltip.sessionRate, y, "XP/h", dash)
    y = y + rowHeight
    PlaceRow(tooltip.sessionETA, y, "Time to level", dash)
    y = y + rowHeight + padding

    tooltip:SetHeight(y)
    tooltip:ClearAllPoints()
    if placeAbove then
        tooltip:SetPoint("BOTTOMLEFT", entry.bar, "TOPLEFT", 0, -3)
    else
        tooltip:SetPoint("TOPLEFT", entry.bar, "BOTTOMLEFT", 0, 3)
    end
end

function addon:AttachTooltip(entry)
    entry.bar:SetScript("OnEnter", function()
        if not tooltip then
            CreateTooltip()
        end
        owner = entry
        Populate(entry)
        tooltip:Show()
    end)
    entry.bar:SetScript("OnLeave", HideIfOutside)
end

function addon:UpdateTooltip(entry)
    if tooltip and tooltip:IsShown() and owner == entry then
        Populate(entry)
    end
end

function addon:HideTooltip(entry)
    if tooltip and owner == entry then
        tooltip:Hide()
        owner = nil
    end
end
