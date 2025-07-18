local DelveBuddy = LibStub("AceAddon-3.0"):NewAddon("DelveBuddy", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")

DelveBuddy.IDS = {
    Currency = {
        RestoredCofferKey = 3028,
    },
    Quest = {
        KeyEarned = { 84736, 84737, 84738, 84739 },
        BountyLooted = 86371,
    },
    Item = {
        DelversBounty = 233071,
    },
    Widget = {
        GildedStash = 6659,
    },
    Activity = {
        World = 6
    },
    Spell = {
        DelversBounty = { 453004, 473218 },
    },
    DelveMap = {
        [2269] = true, -- Earthcrawl Mines
        [2347] = true, -- The Spiral Weave
        [2277] = true, -- Nightfall Sanctum
        [2250] = true, -- Kriegval's Rest
        [2302] = true, -- The Dread Pit
        [2396] = true, -- Excavation Site 9
        [2249] = true, -- Fungal Folly
        [2312] = true, -- Mycomancer Cavarn
        [2420] = true, -- Sidestreet Sluice, The Pits
        [2421] = true, -- Sidestreet Sluice, The Low Decks
        [2422] = true, -- Sidestreet Sluice, The High Decks
        [2423] = true, -- Sidestreet Sluice, Entrance
        [2301] = true, -- The Sinkhole
        [2310] = true, -- Skittering Breach
        [2259] = true, -- Tak-Rethan Abyss
        [2299] = true, -- The Underkeep
        [2251] = true, -- The Waterworks
        [2452] = true, -- Archival Assault
    }
}

DelveBuddy.TierToVaultiLvl = {
    [1] = 623,
    [2] = 626,
    [3] = 629,
    [4] = 632,
    [5] = 639,
    [6] = 642,
    [7] = 645,
    [8] = 649,
    [9] = 649,
    [10] = 649,
    [11] = 649,
}

DelveBuddy.TierToVaultiLvl_Season3 = {
    [1] = 668,
    [2] = 671,
    [3] = 675,
    [4] = 678,
    [5] = 681,
    [6] = 642, -- ??
    [7] = 645, -- ??
    [8] = 649, -- ??
    [9] = 649, -- ??
    [10] = 649, -- ??
    [11] = 649, -- ??
}

function DelveBuddy:OnInitialize()
    -- Initialize DB
    DelveBuddyDB = DelveBuddyDB or {}
    DelveBuddyDB.global = DelveBuddyDB.global or {}
    DelveBuddyDB.charData = DelveBuddyDB.charData or {}
    local g = DelveBuddyDB.global
    if g.debugLogging == nil then g.debugLogging = false end
    self.db = DelveBuddyDB

    -- Slash commands
    self:RegisterChatCommand("delvebuddy", "SlashCommand")
    self:RegisterChatCommand("db", "SlashCommand")

    -- Batch-throttle the rapid‐fire data events into one OnDataChanged call every 2 seconds
    self:RegisterBucketEvent({
        "QUEST_LOG_UPDATE",
        "CURRENCY_DISPLAY_UPDATE",
        "WEEKLY_REWARDS_UPDATE",
    }, 2, "OnDataChanged")

    self:CleanupStaleCharacters()
end

function DelveBuddy:SlashCommand(input)
    local cmd, arg = input:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "debuglogging" then
        local enable = tonumber(arg) == 1
        self.db.global.debugLogging = enable
        self:Print("Debug logging %s", enable and "enabled" or "disabled")
    else
        self:Print("Usage: /db debugLogging 0|1")
    end
end

function DelveBuddy:ShouldShowBounty()
    self:Log("ShouldShowBounty")
    return
        self:IsInDelve()
        and not self:IsDelveComplete()
        and self:HasDelversBountyItem()
        and not self:HasDelversBountyBuff()
end

function DelveBuddy:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName():gsub("%s+", "") -- remove spaces from realm
    return name .. "-" .. realm
end

function DelveBuddy:OnEnable()
    self:RegisterBucketEvent({
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "BAG_UPDATE_DELAYED",
    }, 1, "OnBountyCheck")

    self:CollectDelveData()
end

function DelveBuddy:OnDataChanged()
    self:CollectDelveData()
end

function DelveBuddy:OnBountyCheck()
    self:Log("OnBountyCheck")
    C_Timer.After(1, function()
        if self:ShouldShowBounty() then
            self:StartBountyFlashing()
        end
    end)
end

function DelveBuddy:CollectDelveData()
    self:Log("CollectDelveData")

    -- Skip collecting for low-level characters (<80).
    if UnitLevel("player") < 80 then
        self:Log("Player level %d < 80, skipping data collect", UnitLevel("player"))
        return
    end

    local data = {}

    local IDS = DelveBuddy.IDS

    -- Class
    data.class = select(2, UnitClass("player"))

    -- Keys earned (this week)
    local earned = 0
    for _, questID in ipairs(IDS.Quest.KeyEarned) do
        earned = earned + (C_QuestLog.IsQuestFlaggedCompleted(questID) and 1 or 0)
    end
    data.keysEarned = earned

    -- Keys owned
    local c = C_CurrencyInfo.GetCurrencyInfo(IDS.Currency.RestoredCofferKey)
    data.keysOwned = c and c.quantity or 0

    -- Gilded stashes looted
    local w = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(IDS.Widget.GildedStash)
    local stash = w and w.spellInfo and string.match(w.spellInfo.tooltip or "", "(%d)/3")
    data.gildedStashes = tonumber(stash) or 0

    -- Have bounty / looted bounty
    data.hasBounty = C_Item.GetItemCount(IDS.Item.DelversBounty) > 0
    data.bountyLooted = C_QuestLog.IsQuestFlaggedCompleted(IDS.Quest.BountyLooted) or false

    -- Vault rewards
    data.vaultRewards = {}
    for _, a in ipairs(C_WeeklyRewards.GetActivities(IDS.Activity.World)) do
        table.insert(data.vaultRewards, {
            progress = a.progress,
            threshold = a.threshold,
            level = a.level
        })
    end

    -- Last login (used for data reset on reset day)
    data.lastLogin = GetServerTime()

    -- Save to DB under character key
    local charKey = self:GetCharacterKey()
    self.db.charData[charKey] = data

    if self.db.global.debugLogging then
        -- Too spammy
        -- DevTools_Dump(data)
    end
end

function DelveBuddy:FlashDelversBounty()
    local itemName = C_Item.GetItemInfo(DelveBuddy.IDS.Item.DelversBounty)
    if not itemName then return end

    for i = 1, 12 do
        for _, prefix in ipairs({
            "ActionButton",       -- Main bar
            "MultiBarBottomLeftButton", -- Bar 2
            "MultiBarBottomRightButton", -- Bar 3
            "MultiBarRightButton", -- Bar 4
            "MultiBarLeftButton", -- Bar 5
            "MultiBar5Button",    -- Bar 6 (in newer UIs)
            "MultiBar6Button",    -- Bar 7
            "MultiBar7Button",    -- Bar 8
        }) do
            local btn = _G[prefix .. i]
            if btn and btn.action then
                local actionType, id = GetActionInfo(btn.action)
                if actionType == "item" then
                    local itemLink = GetActionText(btn.action) or C_Item.GetItemInfo(id)
                    if itemLink == itemName then
                        ActionButton_ShowOverlayGlow(btn)
                        C_Timer.After(10, function()
                            ActionButton_HideOverlayGlow(btn)
                        end)
                        return
                    end
                end
            end
        end
    end
end

function DelveBuddy:IsInDelve()
    local result = false

    if C_Scenario.IsInScenario() then
        local mapID = C_Map.GetBestMapForUnit("player")
        result = mapID and DelveBuddy.IDS.DelveMap[mapID]
    end

    self:Log("IsInDelve: (%s)", tostring(result))
    return result
end

function DelveBuddy:HasDelversBountyItem()
    local result = false

    result = C_Item.GetItemCount(DelveBuddy.IDS.Item.DelversBounty, false) > 0

    self:Log("HasDelversBountyItem: (%s)", tostring(result))
    return result
end

function DelveBuddy:HasDelversBountyBuff()
    local result = false

    local buffIDs = self.IDS.Spell.DelversBounty
    local i = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end
        for _, id in ipairs(buffIDs) do
            if aura.spellId == id then
                result = true
                break
            end
        end
        i = i + 1
    end

    self:Log("HasDelversBountyBuff: (%s)", tostring(result))
    return result
end

local flashTicker = nil

function DelveBuddy:StartBountyFlashing()
    self:FlashDelversBounty()
    self:ShowBountyNotice()

    if flashTicker then
        flashTicker:Cancel()
    end

    flashTicker = C_Timer.NewTicker(60, function()
        if self:ShouldShowBounty() then
            self:FlashDelversBounty()
            self:ShowBountyNotice()
        else
            flashTicker:Cancel()
            flashTicker = nil
        end
    end)
end

function DelveBuddy:ShowBountyNotice()
    local msg = "|cffffd700Delver's Bounty available!|r" -- gold-colored
    if RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    else
        UIErrorsFrame:AddMessage("Delver's Bounty available!", 1.0, 1.0, 0.0, 53, 5)
    end
end

function DelveBuddy:HasWeeklyResetOccurred(lastLogin)
    if not lastLogin then return true end

    local now = GetServerTime()
    local secondsUntilNextReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
    local nextReset = now + secondsUntilNextReset
    local lastReset = nextReset - 7 * 24 * 60 * 60 -- subtract 1 week

    return lastLogin < lastReset
end

function DelveBuddy:CleanupStaleCharacters()
    self:Log("CleanupStaleCharacters")

    for charKey, data in pairs(self.db.charData) do
        if type(data) == "table" and self:HasWeeklyResetOccurred(data.lastLogin) then
            self:Log("Resetting weekly data for", charKey)
            data.keysEarned = 0
            data.gildedStashes = 0
            data.bountyLooted = false
            data.vaultRewards = {}
            -- keysOwned and hasBounty are preserved
        end
    end
end

function DelveBuddy:Log(fmt, ...)
    if not self.db.global.debugLogging then return end
    local msg = ("[DelveBuddy] " .. fmt):format(...)
    self:Print(msg)
end

function DelveBuddy:IsDelveComplete()
    if not C_Scenario.IsInScenario() then return false end

    local _, currentStage, totalStages = C_Scenario.GetInfo()
    self:Log("IsDelveComplete: currentStage=%s, totalStages=%s", tostring(currentStage), tostring(totalStages))

    if currentStage >= totalStages then
        self:Log("IsDelveComplete: At or beyond final stage — assuming complete")
        return true
    end

    local stepName, _, numCriteria = C_Scenario.GetStepInfo()
    self:Log("IsDelveComplete: stepName=%s, numCriteria=%s", tostring(stepName), tostring(numCriteria))

    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info then
            self:Log("Criteria %d: id %s (quantity %d/%d), completed=%s, quantityString=%s", i,
                tostring(info.criteriaID),
                info.quantity or 0,
                info.totalQuantity or 0,
                tostring(info.completed),
                tostring(info.quantityString))

            self:Log("Criteria desc=%s type=%s flags=%s", info.description, 
                tostring(info.criteriaType), tostring(info.flags))

			if not info.isWeightedProgress and not info.isFormatted then
				local criteriaString = string.format("%d/%d %s", info.quantity, info.totalQuantity, info.description);
                self:Log("criteriaString=%s", criteriaString)
			end

            -- Heuristics to skip optional criteria (probably doesn't work for non-English clients)
            local maybeOptional = (info.totalQuantity == 0)
                or (info.description and info.description:lower():find("optional"))

            if not info.completed and not maybeOptional then
                self:Log("IsDelveComplete: Found incomplete, required criteria")
                return false
            end
        end
    end

    self:Log("IsDelveComplete: All criteria complete or optional — assuming complete")
    return true
end

function DelveBuddy:ClassColoredName(name, class)
    local classColor = RAID_CLASS_COLORS[class] or {["r"] = 1, ["g"] = 1, ["b"] = 0}
    return format("|cff%02x%02x%02x%s|r", classColor["r"] * 255, classColor["g"] * 255, classColor["b"] * 255, name)
end

local DelvePois = {
    [2248] = { -- Isle of Dorn
        { ["id"] = 7787, ["x"] = 38.60, ["y"] = 74.00 }, -- Earthcrawl Mines
        { ["id"] = 7779, ["x"] = 52.03, ["y"] = 65.77 }, -- Fungal Folly
        { ["id"] = 7781, ["x"] = 62.19, ["y"] = 42.70 }, -- Kriegval's Rest
    },
    [2214] = { -- The Ringing Deeps
        { ["id"] = 7782, ["x"] = 42.15, ["y"] = 48.71 }, -- The Waterworks
        { ["id"] = 7788, ["x"] = 70.20, ["y"] = 37.30 }, -- The Dread Pit
        { ["id"] = 8181, ["x"] = 76.00, ["y"] = 96.50 }, -- Excavation Site 9
    },
    [2215] = { -- Hallowfall
        { ["id"] = 7780, ["x"] = 71.30, ["y"] = 31.20 }, -- Mycomancer Cavern
        { ["id"] = 7785, ["x"] = 34.32, ["y"] = 47.43 }, -- Nightfall Sanctum
        { ["id"] = 7783, ["x"] = 50.60, ["y"] = 53.30 }, -- The Sinkhole
        { ["id"] = 7789, ["x"] = 65.48, ["y"] = 61.74 }, -- Skittering Breach
    },
    [2255] = { -- Azj-Kahet
        { ["id"] = 7790, ["x"] = 45.00, ["y"] = 19.00 }, -- The Spiral Weave
        { ["id"] = 7784, ["x"] = 55.00, ["y"] = 73.92 }, -- Tak-Rethan Abyss
        { ["id"] = 7786, ["x"] = 51.85, ["y"] = 88.30 }, -- The Underkeep
    },
    [2346] = { -- Undermine
        { ["id"] = 8246, ["x"] = 35.20, ["y"] = 52.80 }, -- Sidestreet Sluice
    },
    [2371] = { -- K'aresh
        { ["id"] = 8273, ["x"] = 55.08, ["y"] = 48.08 }, -- Archival Assault
    },
}

function DelveBuddy:GetDelves()
    local delves = {}

    for zoneID, poiList in pairs(DelvePois) do
        for _, poi in ipairs(poiList) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(zoneID, poi.id)
            if info then
                self:Log("Found poi %s in zone %s", tostring(poi.id), tostring(zoneID))
                self:Log("name= %s", info.atlasName)
            end

            if info and info.atlasName == "delves-bountiful" then
                local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(info.iconWidgetSet)
                local isOvercharged = (#widgets == 2)

                delves[poi.id] = {
                    name        = info.name,
                    zoneID      = zoneID,
                    x           = poi.x,
                    y           = poi.y,
                    overcharged = isOvercharged,
                }
            end
        end
    end

    -- Spammy
    -- self:Print("Dumping Delves")
    -- DevTools_Dump(Delves)

    return delves
end

-- Only for discovering new delves.
function DelveBuddy:DumpPOIs(mapID)
    if not mapID then
        self:Log("DelveBuddy: No mapID provided.")
        return
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    self:Log(("DelveBuddy: Dumping POIs for map %d (%s)"):format(mapID, mapInfo and mapInfo.name or "unknown"))

    local poiIDs = C_AreaPoiInfo.GetDelvesForMap(mapID) or {}
    if #poiIDs == 0 then
        self:Log("DelveBuddy: No POIs found on map", mapID)
        return
    end

    for _, poiID in ipairs(poiIDs) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
        if info then
            self:Log((
                "POI %d: name=%q, atlas=%q, texIdx=%d, x=%.2f, y=%.2f, widgetSet=%s"
            ):format(
                poiID,
                info.name or "",
                info.atlasName or "",
                info.textureIndex or 0,
                (info.x or 0) * 100,
                (info.y or 0) * 100,
                tostring(info.iconWidgetSet)
            ))
        end
    end
end

