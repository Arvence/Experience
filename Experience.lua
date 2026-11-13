local addonName, addon = ...
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

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
