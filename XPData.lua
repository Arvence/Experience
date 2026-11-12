local _, addon = ...
local events = CreateFrame("Frame")

addon.xpData = {
    quests = {},
    questCount = 0,
    questKnownXP = 0,
    questKnownCount = 0,
    questUnknownCount = 0,
    questLogComplete = false,
    unknownQuestIDs = {},
}

local function IsNumber(value)
    return not issecretvalue(value) and type(value) == "number"
end

function addon:RefreshProgressData()
    local data = self.xpData
    local current = UnitXP("player")
    local maximum = UnitXPMax("player")

    if IsNumber(current) and IsNumber(maximum) and maximum > 0 then
        data.current = math.max(current, 0)
        data.maximum = maximum
        data.remaining = math.max(0, maximum - data.current)
        data.percent = data.current / maximum * 100
    else
        data.current = nil
        data.maximum = nil
        data.remaining = nil
        data.percent = nil
    end

    local rested = GetXPExhaustion()
    if rested == nil then
        data.restedXP = 0
    elseif IsNumber(rested) and rested >= 0 then
        data.restedXP = rested
    else
        data.restedXP = nil
    end

    data.restedPercent = data.maximum and data.restedXP and data.restedXP / data.maximum * 100 or nil
    data.questPercent = data.maximum and data.questXP and data.questXP / data.maximum * 100 or nil
end

function addon:RefreshQuestData()
    local data = self.xpData
    local quests = {}
    local unknownQuestIDs = {}
    local knownXP = 0
    local knownCount = 0
    local unknownCount = 0
    local observed = 0
    local complete = true

    if not C_QuestLog or type(C_QuestLog.GetNumQuestLogEntries) ~= "function" or type(C_QuestLog.GetInfo) ~= "function" or type(C_QuestLog.IsComplete) ~= "function" then
        complete = false
    else
        local shownEntries, totalQuests = C_QuestLog.GetNumQuestLogEntries()
        if not IsNumber(shownEntries) or shownEntries < 0 or not IsNumber(totalQuests) or totalQuests < 0 then
            complete = false
        else
            for index = 1, shownEntries do
                local info = C_QuestLog.GetInfo(index)
                if not info or issecretvalue(info) or type(info) ~= "table" or issecretvalue(info.isHeader) then
                    complete = false
                elseif not info.isHeader then
                    observed = observed + 1
                    local questID = info.questID
                    if not IsNumber(questID) then
                        complete = false
                    else
                        local isComplete = C_QuestLog.IsComplete(questID)
                        if issecretvalue(isComplete) then
                            complete = false
                        elseif isComplete then
                            local title = info.title
                            if issecretvalue(title) or type(title) ~= "string" then
                                title = nil
                                complete = false
                            end

                            local reward
                            if type(HaveQuestRewardData) == "function" and type(GetQuestLogRewardXP) == "function" then
                                local available = HaveQuestRewardData(questID)
                                if not issecretvalue(available) and available then
                                    local value = GetQuestLogRewardXP(questID)
                                    if IsNumber(value) and value >= 0 then
                                        reward = value
                                    end
                                end
                            end

                            quests[#quests + 1] = { id = questID, name = title, xp = reward }
                            if reward == nil then
                                unknownCount = unknownCount + 1
                                unknownQuestIDs[questID] = true
                            else
                                knownCount = knownCount + 1
                                knownXP = knownXP + reward
                            end
                        end
                    end
                end
            end

            if observed ~= totalQuests then
                complete = false
            end
        end
    end

    data.quests = quests
    data.questCount = #quests
    data.questKnownXP = knownXP
    data.questKnownCount = knownCount
    data.questUnknownCount = unknownCount
    data.questLogComplete = complete
    data.unknownQuestIDs = unknownQuestIDs
    data.questXP = (knownCount > 0 or (#quests == 0 and complete)) and knownXP or nil
    data.questPercent = data.maximum and data.questXP and data.questXP / data.maximum * 100 or nil
    data.questPercentPartial = not complete or unknownCount > 0
end

function addon:PrintDataStatus()
    local data = self.xpData
    local current = data.current and tostring(data.current) or "unavailable"
    local maximum = data.maximum and tostring(data.maximum) or "unavailable"
    local rested = data.restedXP and tostring(data.restedXP) or "unavailable"
    local questTotal = data.questXP and tostring(data.questXP) or "unavailable"
    local logState = data.questLogComplete and "complete" or "partial"

    print(string.format("Experience: XP %s / %s, remaining %s, rested bonus %s.", current, maximum, data.remaining and tostring(data.remaining) or "unavailable", rested))
    print(string.format("Experience: completed quests %d observed, known XP %d from %d, unknown rewards %d, quest preview XP %s, log %s.", data.questCount, data.questKnownXP, data.questKnownCount, data.questUnknownCount, questTotal, logState))

    for _, quest in ipairs(data.quests) do
        print(string.format("Experience: quest %d — %s: %s XP.", quest.id, quest.name or "name unavailable", quest.xp and tostring(quest.xp) or "unavailable"))
    end
end

events:SetScript("OnEvent", function(_, event, questID, success)
    if event == "QUEST_DATA_LOAD_RESULT" and (not success or not addon.xpData.unknownQuestIDs[questID]) then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
        addon:RefreshProgressData()
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" or event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" or event == "QUEST_DATA_LOAD_RESULT" then
        addon:RefreshQuestData()
    end

    if addon.RefreshBars then
        addon:RefreshBars()
    end
end)

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("UPDATE_EXHAUSTION")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
