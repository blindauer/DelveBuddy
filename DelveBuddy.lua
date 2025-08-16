local DelveBuddy = LibStub("AceAddon-3.0"):NewAddon("DelveBuddy", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")

DelveBuddy.Zone = {
    IsleOfDorn = 2248,
    Hallowfall = 2215,
    RingingDeeps = 2214,
    AzjKahet = 2255,
    Undermine = 2346,
    Karesh = 2371,
}

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
    DelveMapToPoi = {
        [2269] = 7787, -- Earthcrawl Mines
        [2249] = 7779, -- Fungal Folly
        [2250] = 7781, -- Kriegval's Rest
        [2251] = 7782, -- The Waterworks
        [2310] = 7789, -- Skittering Breach
        [2302] = 7788, -- The Dread Pit
        [2396] = 8181, -- Excavation Site 9
        [2312] = 7780, -- Mycomancer Cavern
        [2277] = 7785, -- Nightfall Sanctum
        [2301] = 7783, -- The Sinkhole
        [2259] = 7784, -- Tak-Rethan Abyss
        [2299] = 7786, -- The Underkeep
        [2347] = 7790, -- The Spiral Weave
        [2420] = 8246, -- Sidestreet Sluice, The Pits
        [2421] = 8246, -- Sidestreet Sluice, The Low Decks
        [2422] = 8246, -- Sidestreet Sluice, The High Decks
        [2423] = 8246, -- Sidestreet Sluice, Entrance
        [2452] = 8273, -- Archival Assault
    },
    DelvePois = {
        [DelveBuddy.Zone.IsleOfDorn] = {
            { ["id"] = 7787, ["x"] = 38.60, ["y"] = 74.00 }, -- Earthcrawl Mines
            { ["id"] = 7779, ["x"] = 52.03, ["y"] = 65.77 }, -- Fungal Folly
            { ["id"] = 7781, ["x"] = 62.19, ["y"] = 42.70 }, -- Kriegval's Rest
        },
        [DelveBuddy.Zone.RingingDeeps] = {
            { ["id"] = 7782, ["x"] = 42.15, ["y"] = 48.71 }, -- The Waterworks
            { ["id"] = 7788, ["x"] = 70.20, ["y"] = 37.30 }, -- The Dread Pit
            { ["id"] = 8181, ["x"] = 76.00, ["y"] = 96.50 }, -- Excavation Site 9
        },
        [DelveBuddy.Zone.Hallowfall] = {
            { ["id"] = 7780, ["x"] = 71.30, ["y"] = 31.20 }, -- Mycomancer Cavern
            { ["id"] = 7785, ["x"] = 34.32, ["y"] = 47.43 }, -- Nightfall Sanctum
            { ["id"] = 7783, ["x"] = 50.60, ["y"] = 53.30 }, -- The Sinkhole
            { ["id"] = 7789, ["x"] = 65.48, ["y"] = 61.74 }, -- Skittering Breach
        },
        [DelveBuddy.Zone.AzjKahet] = {
            { ["id"] = 7790, ["x"] = 45.00, ["y"] = 19.00 }, -- The Spiral Weave
            { ["id"] = 7784, ["x"] = 55.00, ["y"] = 73.92 }, -- Tak-Rethan Abyss
            { ["id"] = 7786, ["x"] = 51.85, ["y"] = 88.30 }, -- The Underkeep
        },
        [DelveBuddy.Zone.Undermine] = {
            { ["id"] = 8246, ["x"] = 35.20, ["y"] = 52.80 }, -- Sidestreet Sluice
        },
        [DelveBuddy.Zone.Karesh] = {
            { ["id"] = 8273, ["x"] = 55.08, ["y"] = 48.08 }, -- Archival Assault
        },
    },
    CONST = {
        UNKNOWN_GILDED_STASH_COUNT = -1,
        MAX_WEEKLY_GILDED_STASHES = 3,
    },
}

DelveBuddy.TierToVaultiLvl = {
    [1] = 668,
    [2] = 671,
    [3] = 675,
    [4] = 678,
    [5] = 681,
    [6] = 688,
    [7] = 691,
    [8] = 694,
    [9] = 694,
    [10] = 694,
    [11] = 694,
}

function DelveBuddy:OnInitialize()
    -- Initialize DB
    DelveBuddyDB = DelveBuddyDB or {}
    DelveBuddyDB.global = DelveBuddyDB.global or {}
    DelveBuddyDB.charData = DelveBuddyDB.charData or {}
    local g = DelveBuddyDB.global
    if g.debugLogging == nil then g.debugLogging = false end
    self.db = DelveBuddyDB

    -- LibDBIcon
    DelveBuddyDB.global.minimap = DelveBuddyDB.global.minimap or {}
    self:InitMinimapIcon()

    -- Slash commands
    self:RegisterChatCommand("delvebuddy", "SlashCommand")
    self:RegisterChatCommand("db", "SlashCommand")

    -- Batch-throttle the rapid‐fire data events into one OnDataChanged call every 2 seconds
    self:RegisterBucketEvent({
        "QUEST_LOG_UPDATE",
        "CURRENCY_DISPLAY_UPDATE",
        "WEEKLY_REWARDS_UPDATE",
    }, 2, "OnDataChanged")

    -- Clean up after weekly reset, if appropriate
    self:CleanupStaleCharacters()
end

function DelveBuddy:OnEnable()
    self:RegisterBucketEvent({
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "BAG_UPDATE_DELAYED",
    }, 1, "OnBountyCheck")

    self:CollectDelveData()
end

function DelveBuddy:SlashCommand(input)
    local cmd, arg = input:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "debuglogging" then
        local enable = tonumber(arg) == 1
        self.db.global.debugLogging = enable
        self:Print("Debug logging", enable and "enabled" or "disabled")
    elseif cmd == "minimap" or cmd == "mm" then
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if not LDBIcon then
            self:Print("LibDBIcon-1.0 not loaded.")
        else
            self.db.global.minimap.hide = not self.db.global.minimap.hide
            if self.db.global.minimap.hide then
                LDBIcon:Hide("DelveBuddy")
                self:Print("Minimap icon hidden.")
            else
                LDBIcon:Show("DelveBuddy")
                self:Print("Minimap icon shown.")
            end
        end
    else
        self:Print("Usage: /db debugLogging 0|1")
    end
end

function DelveBuddy:ShouldShowKeyWarning()
    local result =
        self:IsInBountifulDelve()
        and not self:IsDelveComplete()
        and self:GetKeyCount() == 0

    self:Log("ShouldShowKeyWarning: %s", tostring(result))
    return result
end

function DelveBuddy:ShouldShowBounty()
    local result =
        self:IsInDelve()
        and not self:IsDelveComplete()
        and self:HasDelversBountyItem()
        and not self:HasDelversBountyBuff()

    self:Log("ShouldShowBounty: %s", tostring(result))
    return result
end

function DelveBuddy:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName():gsub("%s+", "") -- remove spaces from realm
    return name .. "-" .. realm
end

function DelveBuddy:OnDataChanged()
    self:CollectDelveData()
end

function DelveBuddy:OnBountyCheck()
    self:Log("OnBountyCheck")
    C_Timer.After(1, function()
        if self:ShouldShowKeyWarning() then
            self:ShowKeyWarning()
        elseif self:ShouldShowBounty() then
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
    data.keysOwned = self:GetKeyCount()

    -- Gilded stashes looted
    data.gildedStashes, _ = self:GetGildedStashCounts()

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

function DelveBuddy:GetGildedStashCounts()
    local UNKNOWN = self.IDS.CONST.UNKNOWN_GILDED_STASH_COUNT
    local fallbackMax = self.IDS.CONST.MAX_WEEKLY_GILDED_STASHES

    local w = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(self.IDS.Widget.GildedStash)
    if not (w and w.spellInfo and w.spellInfo.tooltip) then
        return UNKNOWN, fallbackMax
    end

    -- Locale-safe-ish: grab two numbers around a slash
    local cur, max = w.spellInfo.tooltip:match("(%d+)%s*/%s*(%d+)")
    cur = tonumber(cur)
    max = tonumber(max) or fallbackMax

    if not cur then
        return UNKNOWN, max
    end
    return cur, max
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
        result = mapID and DelveBuddy.IDS.DelveMapToPoi[mapID] ~= nil
    end

    self:Log("IsInDelve: (%s) map=%s poi=%s", 
        tostring(result),
        tostring(mapID),
        tostring(result and DelveBuddy.IDS.DelveMapToPoi[mapID])
    )

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

function DelveBuddy:ShowKeyWarning()
    self:DisplayRaidWarning("|cffff4444DelveBuddy: In a bountiful delve, with no Restored Coffer Keys!|r", true)
end

function DelveBuddy:ShowBountyNotice()
    self:DisplayRaidWarning("|cffffd700Delver's Bounty available!|r", false)
end

function DelveBuddy:DisplayRaidWarning(msg, playSound)
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1, 53, 5)
    else
        self:Print(msg)
    end

    if playSound and PlaySound then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

function DelveBuddy:HasWeeklyResetOccurred(lastLogin)
    if not lastLogin then return true end

    local now = GetServerTime()
    local secondsUntilNextReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
    self:Log("Next weekly reset: %s hours", tostring(secondsUntilNextReset / 60 / 60))
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
            -- data.vaultRewards = {} keep vaultRewards
            -- TODO some indication of when you have a reward in the vault?
            -- keysOwned and hasBounty are preserved
        end
    end
end

function DelveBuddy:Log(fmt, ...)
    if not self.db.global.debugLogging then return end
    self:Print(fmt:format(...))
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

function DelveBuddy:GetKeyCount()
    local c = C_CurrencyInfo.GetCurrencyInfo(self.IDS.Currency.RestoredCofferKey)
    return c and c.quantity or 0
end

function DelveBuddy:GetDelves()
    local delves = {}

    local delvePois = self.IDS.DelvePois
    for zoneID, poiList in pairs(delvePois) do
        for _, poi in ipairs(poiList) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(zoneID, poi.id)
            if info then
                self:Log("Found poi %s in zone %s", tostring(poi.id), tostring(zoneID))
                self:Log("name= %s", info.atlasName)
            end

            if info and info.atlasName == "delves-bountiful" then
                local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(info.iconWidgetSet)

                delves[poi.id] = {
                    name        = info.name,
                    zoneID      = zoneID,
                    x           = poi.x,
                    y           = poi.y,
                }
            end
        end
    end

    -- Spammy
    -- self:Print("Dumping Delves")
    -- DevTools_Dump(Delves)

    return delves
end

function DelveBuddy:GetWorldSoulMemories()
    local memories = {}

    for _, zoneID in pairs(self.Zone) do
        local pois = C_AreaPoiInfo.GetEventsForMap(zoneID) or {}
        for _, poiID in ipairs(pois) do
            local poi = C_AreaPoiInfo.GetAreaPOIInfo(zoneID, poiID)
            if poi and poi.atlasName == "UI-EventPoi-WorldSoulMemory" then
                local name = (poi.name and (poi.name:match(":%s*(.+)") or poi.name)) or "World Soul Memory"
                memories[poiID] = {
                    name   = name,
                    zoneID = zoneID,
                    x      = poi.position and poi.position.x * 100 or 0,
                    y      = poi.position and poi.position.y * 100 or 0,
                }
            end
        end
    end

    return memories
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

function DelveBuddy:IsInBountifulDelve()
    if not C_Scenario.IsInScenario() then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    local poiID = mapID and self.IDS.DelveMapToPoi[mapID]
    if not poiID then return false end

    -- Ascend to zone map (mapType 3) to query POI
    local zoneMap = mapID
    local info = C_Map.GetMapInfo(zoneMap)
    while info and info.parentMapID and info.mapType ~= 3 do
        zoneMap = info.parentMapID
        info = C_Map.GetMapInfo(zoneMap)
    end

    local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(zoneMap, poiID)
    local bountiful = poiInfo and poiInfo.atlasName == "delves-bountiful"

    self:Log("IsInBountifulDelve: map=%s zone=%s poi=%s bountiful=%s",
        tostring(mapID),
        tostring(zoneMap),
        tostring(poiID),
        tostring(bountiful)
    )

    return bountiful
end

function DelveBuddy:GetZoneName(uiMapID)
    self._zoneNameCache = self._zoneNameCache or {}
    local name = self._zoneNameCache[uiMapID]
    if not name then
        local info = C_Map.GetMapInfo(uiMapID)
        name = (info and info.name) or ("Map " .. tostring(uiMapID))
        self._zoneNameCache[uiMapID] = name
    end
    return name
end

function DelveBuddy:OpenVaultUI()
    C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
    WeeklyRewardsFrame:Show()
end