local addonName, addon = ...
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    if type(ExperienceDB) ~= "table" then
        ExperienceDB = {}
    end

    addon.db = ExperienceDB

    SLASH_EXPERIENCE1 = "/experience"
    SlashCmdList.EXPERIENCE = function()
        local version, build, _, interfaceVersion = GetBuildInfo()
        print(string.format("%s: bootstrap loaded. Client %s (build %s), interface %s.", addonName, version, build, tostring(interfaceVersion)))
    end

    self:UnregisterEvent("ADDON_LOADED")
end)

frame:RegisterEvent("ADDON_LOADED")
