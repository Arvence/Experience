local _, addon = ...
local events = CreateFrame("Frame")
local rateRecord
local lastTick
local wasAFK
local rateTicker
local levelCheckQueued
local QueueLevelObservation

local function PlayerIsAFK()
    return type(UnitIsAFK) ~= "function" or UnitIsAFK("player")
end

local function AdvanceActiveTime()
    if not rateRecord or not lastTick then
        return
    end
    local now = GetTime()
    local elapsed = now - lastTick
    if not wasAFK and elapsed > 0 and elapsed <= 90 then
        rateRecord.active = rateRecord.active + elapsed
    end
    lastTick = now
    rateRecord.lastSeen = time()
end

local function UpdateRate()
    local data = addon.xpData
    local level = UnitLevel("player")
    local maxLevel = GameRulesUtil.GetEffectiveMaxLevelForPlayer()
    if not rateRecord or wasAFK or not data.maximum or issecretvalue(level) or issecretvalue(maxLevel) or type(level) ~= "number" or type(maxLevel) ~= "number" or level >= maxLevel or rateRecord.active < 600 or rateRecord.gains < 2 or rateRecord.earned <= 0 then
        data.xpPerHour = nil
        data.levelETA = nil
        return
    end
    data.xpPerHour = rateRecord.earned * 3600 / rateRecord.active
    data.levelETA = data.remaining and data.remaining * 3600 / data.xpPerHour or nil
end

local function ObserveEarnedXP(settled)
    if not rateRecord then
        return
    end
    local level = UnitLevel("player")
    local current = UnitXP("player")
    local maximum = UnitXPMax("player")
    if issecretvalue(level) or issecretvalue(current) or issecretvalue(maximum) or type(level) ~= "number" or type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        return
    end
    if level ~= rateRecord.level and not settled then
        QueueLevelObservation()
        return
    end
    local gained = 0
    if level == rateRecord.level and current >= rateRecord.xp then
        gained = current - rateRecord.xp
    elseif level == rateRecord.level + 1 then
        gained = math.max(0, rateRecord.maximum - rateRecord.xp) + current
    elseif level == rateRecord.level and current < rateRecord.xp then
        return
    end
    if gained > 0 then
        rateRecord.earned = rateRecord.earned + gained
        rateRecord.gains = rateRecord.gains + 1
    end
    rateRecord.level = level
    rateRecord.xp = current
    rateRecord.maximum = maximum
    rateRecord.lastSeen = time()
    UpdateRate()
end

QueueLevelObservation = function()
    if levelCheckQueued then
        return
    end
    levelCheckQueued = true
    C_Timer.After(0, function()
        levelCheckQueued = nil
        addon:RefreshProgressData()
        ObserveEarnedXP(true)
        if addon.RefreshBars then
            addon:RefreshBars()
        end
    end)
end

local function StartRateTracking()
    if not addon.xpTrackerEnabled then
        return
    end
    local guid = UnitGUID("player")
    if not guid then
        return
    end
    ExperienceDB.xpRates = ExperienceDB.xpRates or {}
    local record = ExperienceDB.xpRates[guid]
    local now = time()
    if not record or type(record.lastSeen) ~= "number" or now < record.lastSeen or now - record.lastSeen > 86400 then
        record = { earned = 0, active = 0, gains = 0 }
        ExperienceDB.xpRates[guid] = record
    end
    rateRecord = record
    rateRecord.level = UnitLevel("player")
    rateRecord.xp = UnitXP("player")
    rateRecord.maximum = UnitXPMax("player")
    rateRecord.lastSeen = now
    lastTick = GetTime()
    wasAFK = PlayerIsAFK()
    UpdateRate()
    events:RegisterEvent("PLAYER_FLAGS_CHANGED")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    if not rateTicker then
        rateTicker = C_Timer.NewTicker(45, function()
            if PlayerIsAFK() and not wasAFK then
                wasAFK = true
            end
            AdvanceActiveTime()
            wasAFK = PlayerIsAFK()
            UpdateRate()
            if addon.RefreshBarText then
                addon:RefreshBarText()
            end
        end)
    end
end

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
    data.questBonusPercent = self.wellRestedEnabled and data.maximum and data.questBonusXP and data.questBonusXP / data.maximum * 100 or nil
    data.questProjectedPercent = self.wellRestedEnabled and data.maximum and data.questProjectedXP and data.questProjectedXP / data.maximum * 100 or nil
end

function addon:RefreshQuestData()
    local data = self.xpData
    local quests = {}
    local unknownQuestIDs = {}
    local knownXP = 0
    local knownBonusXP = 0
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

                            local bonusXP = nil
                            if self.wellRestedEnabled and IsNumber(reward) and reward >= 0 then
                                bonusXP = reward * 0.03
                            end

                            quests[#quests + 1] = { id = questID, name = title, xp = reward, bonusXP = bonusXP }
                            if reward == nil then
                                unknownCount = unknownCount + 1
                                unknownQuestIDs[questID] = true
                            else
                                knownCount = knownCount + 1
                                knownXP = knownXP + reward
                                if self.wellRestedEnabled then
                                    knownBonusXP = knownBonusXP + bonusXP
                                end
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
    data.questKnownBonusXP = self.wellRestedEnabled and knownBonusXP or nil
    data.questKnownCount = knownCount
    data.questUnknownCount = unknownCount
    data.questLogComplete = complete
    data.unknownQuestIDs = unknownQuestIDs
    data.questXP = (knownCount > 0 or (#quests == 0 and complete)) and knownXP or nil
    data.questBonusXP = self.wellRestedEnabled and (knownCount > 0 or (#quests == 0 and complete)) and knownBonusXP or nil
    data.questProjectedXP = self.wellRestedEnabled and data.questXP and data.questBonusXP and data.questXP + data.questBonusXP or nil
    data.questPercent = data.maximum and data.questXP and data.questXP / data.maximum * 100 or nil
    data.questBonusPercent = self.wellRestedEnabled and data.maximum and data.questBonusXP and data.questBonusXP / data.maximum * 100 or nil
    data.questProjectedPercent = self.wellRestedEnabled and data.maximum and data.questProjectedXP and data.questProjectedXP / data.maximum * 100 or nil
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
    if rateRecord then
        print(string.format("Experience: earned XP %d, active time %dm, XP/h %s, level ETA %s.", rateRecord.earned, math.floor(rateRecord.active / 60), data.xpPerHour and string.format("%.0f", data.xpPerHour) or "unavailable", data.levelETA and string.format("%.0fs", data.levelETA) or "unavailable"))
    end
    if self.wellRestedEnabled then
        local questBonusTotal = data.questBonusXP and tostring(data.questBonusXP) or "unavailable"
        print(string.format("Experience: completed quests %d observed, known XP %d from %d, bonus XP %s, unknown rewards %d, quest preview XP %s, log %s.", data.questCount, data.questKnownXP, data.questKnownCount, questBonusTotal, data.questUnknownCount, questTotal, logState))
    else
        print(string.format("Experience: completed quests %d observed, known XP %d from %d, unknown rewards %d, quest preview XP %s, log %s.", data.questCount, data.questKnownXP, data.questKnownCount, data.questUnknownCount, questTotal, logState))
    end

    for _, quest in ipairs(data.quests) do
        if self.wellRestedEnabled then
            local bonus = quest.bonusXP and tostring(quest.bonusXP) or "unavailable"
            print(string.format("Experience: quest %d — %s: %s XP (%s bonus XP).", quest.id, quest.name or "name unavailable", quest.xp and tostring(quest.xp) or "unavailable", bonus))
        else
            print(string.format("Experience: quest %d — %s: %s XP.", quest.id, quest.name or "name unavailable", quest.xp and tostring(quest.xp) or "unavailable"))
        end
    end
end

events:SetScript("OnEvent", function(_, event, questID, success)
    if event == "QUEST_DATA_LOAD_RESULT" and (not success or not addon.xpData.unknownQuestIDs[questID]) then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
        addon:RefreshProgressData()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if not rateRecord then
            StartRateTracking()
        else
            lastTick = GetTime()
            wasAFK = PlayerIsAFK()
        end
    elseif event == "PLAYER_XP_UPDATE" and addon.xpTrackerEnabled then
        AdvanceActiveTime()
        ObserveEarnedXP()
    elseif event == "PLAYER_LEVEL_UP" and addon.xpTrackerEnabled then
        QueueLevelObservation()
    elseif event == "PLAYER_FLAGS_CHANGED" and questID == "player" then
        AdvanceActiveTime()
        wasAFK = PlayerIsAFK()
        UpdateRate()
    elseif event == "PLAYER_FLAGS_CHANGED" then
        return
    elseif event == "PLAYER_LEAVING_WORLD" then
        AdvanceActiveTime()
        lastTick = nil
    elseif event == "PLAYER_LOGOUT" then
        AdvanceActiveTime()
        rateRecord = nil
        lastTick = nil
        return
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
