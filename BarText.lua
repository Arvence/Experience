local _, addon = ...
local separator = "  ·  "
local dash = "—"
local referenceFontSize = 11
local labelColor = CreateColor(0.95, 0.85, 0.08)
local valueColor = CreateColor(0.93, 0.93, 0.95)
local separatorColor = CreateColor(0.55, 0.45, 0.26)

local function Number(value, compact)
    if value == nil then
        return dash
    end

    if compact and value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    end
    if compact and value >= 10000 then
        return string.format("%.1fK", value / 1000)
    end
    if compact and value >= 1000 then
        return string.format("%.0fK", value / 1000)
    end
    return BreakUpLargeNumbers(value)
end

local function Segment(label, value, colored)
    if colored then
        return labelColor:WrapTextInColorCode(label) .. " " .. valueColor:WrapTextInColorCode(value)
    end
    return label .. " " .. value
end

local function FormatLine(data, compact, colored)
    local parts
    if compact then
        parts = {
            Segment("XP", Number(data.current, true) .. "/" .. Number(data.maximum, true), colored),
            Segment("Left", Number(data.remaining, true), colored),
            Segment("XP/h", dash, colored),
            Segment("Lvl in", dash, colored),
        }
    else
        parts = {
            Segment("XP", Number(data.current) .. " / " .. Number(data.maximum), colored),
            Segment("Left", Number(data.remaining), colored),
            Segment("XP/h", dash, colored),
            Segment("Level up in", dash, colored),
        }
    end
    return table.concat(parts, colored and separatorColor:WrapTextInColorCode(separator) or separator)
end

function addon:CreateBarText(entry)
    local overlay = CreateFrame("Frame", nil, entry.bar)
    overlay:SetAllPoints(entry.bar)
    overlay:SetFrameLevel(entry.fill:GetFrameLevel() + 1)
    overlay:EnableMouse(false)
    entry.textOverlay = overlay

    local text = overlay:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetTextColor(valueColor:GetRGB())
    text:SetShadowColor(0, 0, 0, 0)
    text:SetShadowOffset(0, 0)
    entry.text = text

    local measure = overlay:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    measure:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    measure:SetAlpha(0)
    entry.textMeasure = measure

    local font, _, flags = entry.native.OverlayFrame.Text:GetFont()
    entry.textFont = font
    entry.textSize = referenceFontSize
    entry.textFlags = flags
    self:UpdateBarText(entry)
end

function addon:UpdateBarText(entry)
    if not entry.text then
        return
    end
    local data = self.xpData
    if not data.current or not data.maximum then
        entry.textPlain = ""
        entry.text:SetText("")
        return
    end

    local available = math.max(0, entry.bar:GetWidth() - 8)
    local nativeSize = entry.textSize
    local measure = entry.textMeasure
    local chosen = FormatLine(data, false)
    local compact = false
    local fontSize = nativeSize
    measure:SetFont(entry.textFont, fontSize, entry.textFlags)
    measure:SetText(chosen)
    local width = measure:GetStringWidth()
    if width > available then
        chosen = FormatLine(data, true)
        compact = true
        measure:SetText(chosen)
        width = measure:GetStringWidth()
    end

    entry.text:SetFont(entry.textFont, fontSize, entry.textFlags)
    entry.text:SetWidth(math.min(available, math.ceil(width) + 4))
    entry.textFit = width <= available
    entry.textMeasuredWidth = width
    entry.textAvailableWidth = available
    entry.textChosenSize = fontSize
    entry.textPlain = chosen
    entry.text:SetText(FormatLine(data, compact, true))
    local textHeight = entry.text:GetStringHeight()
    entry.text:SetHeight(textHeight)
    entry.text:ClearAllPoints()
    entry.text:SetPoint("TOP", entry.textOverlay, "TOP", 0, -(entry.bar:GetHeight() - textHeight) / 2)
end

function addon:PrintTextStatusEntries(entries)
    for index, entry in ipairs(entries) do
        print(string.format("Experience: container %d native width %.1f, text width %.1f/%.1f, font %.1f, scale %.3f, fits %s: %s", index, entry.native.StatusBar:GetWidth(), entry.textMeasuredWidth or 0, entry.textAvailableWidth or 0, entry.textChosenSize or 0, entry.bar:GetEffectiveScale(), tostring(entry.textFit), entry.textPlain or ""))
    end
end
