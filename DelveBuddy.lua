
local DelveBuddy = LibStub("AceAddon-3.0"):NewAddon("DelveBuddy", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")
local LBG = LibStub("LibButtonGlow-1.0", true)

function DelveBuddy:OnInitialize()
    -- Initialize DB
    DelveBuddyDB = DelveBuddyDB or {}
    DelveBuddyDB.global = DelveBuddyDB.global or {}
    DelveBuddyDB.charData = DelveBuddyDB.charData or {}
    local g = DelveBuddyDB.global
    if g.debugLogging == nil then g.debugLogging = false end
    if g.tooltipScale == nil then g.tooltipScale = 1.0 end
    g.characterSort = g.characterSort or {}
    if g.characterSort.field == nil then g.characterSort.field = "name" end
    if g.characterSort.direction == nil then g.characterSort.direction = "asc" end
    self.db = DelveBuddyDB

    -- LibDBIcon
    DelveBuddyDB.global.minimap = DelveBuddyDB.global.minimap or {}
    self:InitMinimapIcon()

    -- Waypoints
    DelveBuddyDB.global.waypoints = DelveBuddyDB.global.waypoints or {}
    if DelveBuddyDB.global.waypoints.useBlizzard == nil then DelveBuddyDB.global.waypoints.useBlizzard = true end
    if DelveBuddyDB.global.waypoints.useTomTom == nil then DelveBuddyDB.global.waypoints.useTomTom = false end

    -- Reminders
    DelveBuddyDB.global.reminders = DelveBuddyDB.global.reminders or {}
    if DelveBuddyDB.global.reminders.cofferKey == nil then DelveBuddyDB.global.reminders.cofferKey = true end
    if DelveBuddyDB.global.reminders.delversBounty == nil then DelveBuddyDB.global.reminders.delversBounty = true end

    -- Slash commands
    self:RegisterChatCommand("delvebuddy", "SlashCommand")
    self:RegisterChatCommand("db", "SlashCommand")

    -- Batch-throttle the rapid‐fire data events into one OnDataChanged call every 2 seconds
    self:RegisterBucketEvent({
        "QUEST_LOG_UPDATE",
        "CURRENCY_DISPLAY_UPDATE",
        "WEEKLY_REWARDS_UPDATE",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    }, 2, "OnDataChanged")

    -- Hack to ensure weekly reward iLvls are ready when we need them later.
    self:EnsureWeeklyRewardsReady()

    -- Migrate persisted character snapshots to the current schema.
    self:MigrateCharacterData()

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

function DelveBuddy:MigrateCharacterData()
    local targetVersion = self.IDS.CONST.CHAR_DATA_SCHEMA_VERSION

    for charKey, data in pairs(self.db.charData) do
        if type(data) == "table" then
            local currentVersion = tonumber(data.schemaVersion) or 0
            if currentVersion < targetVersion then
                self:Log("Migrating character data for %s from schema %d to %d", charKey, currentVersion, targetVersion)
                self:MigrateCharacterDataRecord(data, currentVersion, targetVersion)
            end
        end
    end
end

function DelveBuddy:MigrateCharacterDataRecord(data, fromVersion, toVersion)
    local UNKNOWN = self.IDS.CONST.UNKNOWN_SHARD_COUNT
    local seasonStart = self:GetMidnightSeason1StartTimestamp()

    for version = fromVersion, toVersion - 1 do
        if version == 0 then
            -- Old versions tracked shard ownership as an item. Invalidate until recollected.
            data.shardsOwned = UNKNOWN
        elseif version == 1 then
            -- Blizzard removed leftover keys at Season 1 start.
            if not data.lastLogin or data.lastLogin < seasonStart then
                data.keysOwned = 0
            end
        elseif version == 2 then
            data.keysEarned = nil
            data.shardsEarnedMax = nil
        end
    end

    data.schemaVersion = toVersion
end

function DelveBuddy:GetMidnightSeason1StartTimestamp()
    local region = GetCurrentRegion and GetCurrentRegion() or nil
    if region == 3 then
        return self.IDS.CONST.MIDNIGHT_S1_START_EU
    end

    return self.IDS.CONST.MIDNIGHT_S1_START_US
end

-- Helper: parse on/off/true/false/1/0
local function StringToBool(v)
    v = tostring(v or ""):lower()
    if v == "on" or v == "true" or v == "1" then return true end
    if v == "off" or v == "false" or v == "0" then return false end
    return nil
end

function DelveBuddy:SlashCommand(input)
    local cmd, arg = input:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "debuglogging" then
        local onoff = StringToBool(arg)
        if onoff == nil then
            self:Print("Usage: /db debugLogging <on||off>")
        else
            self.db.global.debugLogging = onoff
            self:Print("Debug logging " .. (onoff and "enabled" or "disabled"))
        end
    elseif cmd == "scale" then
        local v = tonumber(arg)
        if v and v >= 0.75 and v <= 2.0 then
            self.db.global.tooltipScale = v
            -- apply immediately if our LibQTip tips are open
            if self.charTip then self.charTip:SetScale(v) end
            if self.delveTip then self.delveTip:SetScale(v) end
            self:Print(("Tooltip scale set to %d%%"):format(math.floor(v*100+0.5)))
        else
            self:Print("Usage: /db scale <0.75-2.0>")
        end
    elseif cmd == "reminders" then
        local which, val = arg:match("^(%S+)%s*(%S*)$")
        which = (which or ""):lower()
        local onoff = StringToBool(val)
        if which == "coffer" and onoff ~= nil then
            self.db.global.reminders.cofferKey = onoff
            self:Print("Reminders: Coffer Keys " .. (onoff and "ON" or "OFF"))
        elseif which == "bounty" and onoff ~= nil then
            self.db.global.reminders.delversBounty = onoff
            self:Print("Reminders: " .. self:GetDelversBountyItemName() .. " " .. (onoff and "ON" or "OFF"))
        else
            self:Print("Usage: /db reminders <coffer||bounty> <on||off>")
        end
    elseif cmd == "waypoints" then
        local choice = (arg or ""):lower()
        if choice == "blizzard" then
            self.db.global.waypoints.useBlizzard = true
            self.db.global.waypoints.useTomTom = false
            self:Print("Waypoints: Blizzard only")
        elseif choice == "tomtom" then
            self.db.global.waypoints.useBlizzard = false
            self.db.global.waypoints.useTomTom = true
            self:Print("Waypoints: TomTom only")
        elseif choice == "both" then
            self.db.global.waypoints.useBlizzard = true
            self.db.global.waypoints.useTomTom = true
            self:Print("Waypoints: Blizzard + TomTom")
        else
            self:Print("Usage: /db waypoints <blizzard||tomtom||both>")
        end
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
    elseif cmd == "debuginfo" or cmd == "di" then
        self:Print("Debug Info:")
        self:Print("Is in delve: " .. tostring(self:IsDelveInProgress()))
        self:Print("Is in bountiful delve: " .. tostring(self:IsInBountifulDelve()))
        self:Print("Is delve complete: " .. tostring(self:IsDelveComplete()))
        local owned = self:GetShardCount()
        local earned, weeklyMax = self:GetShardsEarnedThisWeek()
        self:Print("Shards: " .. tostring(owned) .. " | weekly " .. tostring(earned) .. "/" .. tostring(weeklyMax))
        local cur, max = self:GetGildedStashCounts()
        self:Print("Gilded stash count: " .. tostring(cur) .. "/" .. tostring(max))
        self:Print("Is player timerunning: " .. tostring(self:IsPlayerTimerunning()))
        local instanceName, instanceType = GetInstanceInfo()
        self:Print("Instance name=" .. instanceName .. " type=" .. instanceType)
        self:Print("Player mapID: " .. tostring(C_Map.GetBestMapForUnit("player")))
        self:Print("Has " .. self:GetDelversBountyItemName() .. " item: " .. tostring(self:HasDelversBountyItem()))
        self:Print("Has " .. self:GetDelversBountyItemName() .. " buff: " .. tostring(self:HasDelversBountyBuff()))
        self:Print("Has Nemesis Lure item: " .. tostring(self:HasNemesisLureItem()))
        local roleSet, curiosSet, detail = self:GetActiveCompanionConfigFlags()
        self:Print("Companion role set: " .. tostring(roleSet))
        self:Print("Companion curios set: " .. tostring(curiosSet))
        self:Print("Companion config: " .. detail)
        self:Print("Player iLevel: " .. tostring(self:GetPlayerItemLevel()))
        self:Print("Has available vault rewards: " .. tostring(self:HasAvailableVaultRewards()))
    elseif cmd == "rewards" or cmd == "rw" then
        self:DumpVaultRewards()
    elseif cmd == "ilvl" then
        local itemLevel = tonumber(arg)
        if itemLevel then
            self:PrintItemLevelColor(itemLevel)
        else
            self:Print("Usage: /db ilvl <num>")
        end
    elseif cmd == "dumppois" or cmd == "dp" then
        local mapID = tonumber(arg) or C_Map.GetBestMapForUnit("player")
        if mapID then
            self:DumpPOIs(mapID)
        else
            self:Print("Usage: /db dumppois <mapID> -- if omitted, use player's current map ID")
        end
    elseif cmd == "printiteminfo" or cmd == "pii" then
        if arg and arg ~= "" then
            self:PrintItemInfoByName(arg)
        else
            self:Print("Usage: /db printiteminfo <partial item name>")
        end
    else
        self:Print("Available commands:")
        self:Print("/db debugLogging <on||off> -- Enable/disable debug logging")
        self:Print("/db scale <0.75-2.0> -- Set tooltip scale")
        self:Print("/db reminders <coffer||bounty> <on||off> -- Enable/disable reminders")
        self:Print("/db minimap -- Toggle minimap icon")
        self:Print("/db waypoints <blizzard||tomtom||both> -- Set waypoint providers")
        self:Print("/db rewards -- Dump Great Vault (World) tier IDs and example reward item levels")
        self:Print("/db ilvl <num> -- Print GetItemLevelColor() result for an item level")
    end
end

function DelveBuddy:GetDelveStoryVariant(zoneID, poiID)
    local info = C_AreaPoiInfo.GetAreaPOIInfo(zoneID, poiID)

    if info and info.tooltipWidgetSet then
        local tooltipWidgets = C_UIWidgetManager.GetAllWidgetsBySetID(info.tooltipWidgetSet)
        if tooltipWidgets then
            for _, widgetInfo in ipairs(tooltipWidgets) do
                if widgetInfo.widgetType == Enum.UIWidgetVisualizationType.TextWithState then
                    local visInfo = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetInfo.widgetID)
                    if visInfo and visInfo.orderIndex == 0 then
                        return visInfo.text
                    end
                end
            end
        end
    end

    return ""
end

function DelveBuddy:ShouldShowCompanionRoleWarning()
    -- No option to disable this for now, because there's really no reason not to have it set, 
    -- it's pretty dire if you don't.
    local result =
        self:IsDelveInProgress()
        and not self:IsDelveComplete()
        and not self:CompanionRoleSet()

    self:Log("ShouldShowCompanionRoleWarning: %s", tostring(result))
    return result
end

function DelveBuddy:ShouldShowKeyWarning()
    local result =
        self.db.global.reminders.cofferKey
        and self:IsInBountifulDelve()
        and not self:IsDelveComplete()
        and self:GetKeyCount() == 0

    self:Log("ShouldShowKeyWarning: %s", tostring(result))
    return result
end

function DelveBuddy:ShouldShowBounty()
    local result =
        self.db.global.reminders.delversBounty
        and self:IsDelveInProgress()
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
    C_Timer.After(2, function()
        if self:ShouldShowCompanionRoleWarning() then
            self:ShowCompanionRoleWarning()
        elseif self:ShouldShowKeyWarning() then
            self:ShowKeyWarning()
        elseif self:ShouldShowBounty() then
            self:StartBountyFlashing()
        end
    end)
end

function DelveBuddy:CollectDelveData()
    self:Log("CollectDelveData")

    -- Skip collecting for low-level characters (<80).
    local playerLevel = UnitLevel("player")
    local minLevel = self.IDS.CONST.MIN_BOUNTIFUL_DELVE_LEVEL
    if playerLevel < minLevel then
        self:Log("Player level %d < %d, skipping data collect", playerLevel, minLevel)
        return
    end

    -- Skip collecting for Timerunning characters.
    if self:IsPlayerTimerunning() then
        self:Log("Player is timerunner, skipping data collection")
        return
    end

    local data = {}

    local IDS = DelveBuddy.IDS

    -- Existing data for non-destructive fields
    local charKey = self:GetCharacterKey()
    local prevData = self.db.charData and self.db.charData[charKey] or nil

    -- Class
    data.class = select(2, UnitClass("player"))

    -- iLvl
    data.itemLevel = self:GetPlayerItemLevel()

    -- Shards earned (this week)
    do
        local priorEarned = prevData and tonumber(prevData.shardsEarned) or 0
        local priorMax = prevData and tonumber(prevData.shardsEarnedMax) or 0
        local earned, max = self:GetShardsEarnedThisWeek()

        data.shardsEarned = earned or priorEarned or 0
        data.shardsEarnedMax = max or priorMax or 0
    end

    -- Shards owned
    data.shardsOwned = self:GetShardCount()

    -- Keys owned
    data.keysOwned = self:GetKeyCount()

    -- Gilded stashes looted
    -- If current count is unknown, don't overwrite previous known value.
    do
        local cur, _max = self:GetGildedStashCounts()
        local UNKNOWN = self.IDS.CONST.UNKNOWN_GILDED_STASH_COUNT
        local prior = prevData and tonumber(prevData.gildedStashes) or nil
        if cur == UNKNOWN and prior and prior ~= UNKNOWN then
            data.gildedStashes = prior
        else
            data.gildedStashes = cur
        end
    end

    -- Have bounty / looted bounty
    data.hasBounty = C_Item.GetItemCount(self:GetDelversBountyItemId()) > 0
    data.bountyLooted = C_QuestLog.IsQuestFlaggedCompleted(IDS.Quest.BountyLooted) or false

    -- Vault rewards
    data.vaultRewards = {}
    for _, a in ipairs(C_WeeklyRewards.GetActivities(IDS.Activity.World)) do
        table.insert(data.vaultRewards, {
            progress = a.progress,
            threshold = a.threshold,
            level = a.level,
            id = a.id,
            ilvl = self:RewardTierToiLvl(a.level) or 0,
        })
    end

    -- Last login (used for data reset on reset day)
    data.lastLogin = GetServerTime()

    -- Schema version (used for data migrations)
    data.schemaVersion = self.IDS.CONST.CHAR_DATA_SCHEMA_VERSION

    -- Save to DB under character key
    self.db.charData[charKey] = data

    if self.db.global.debugLogging then
        -- Too spammy
        -- DevTools_Dump(data)
    end
end

function DelveBuddy:HasAvailableVaultRewards()
    return C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or false
end

function DelveBuddy:GetGildedStashCounts()
    local UNKNOWN  = self.IDS.CONST.UNKNOWN_GILDED_STASH_COUNT
    local fallback = self.IDS.CONST.MAX_WEEKLY_GILDED_STASHES

    local cur, max = UNKNOWN, fallback

    local widget = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(self.IDS.CONST.WIDGET_ID_GILDED_STASH)
    local tooltip = widget and widget.spellInfo and widget.spellInfo.tooltip
    if tooltip then
        local c, m = tooltip:match("(%d+)%s*/%s*(%d+)")
        if c then
            cur = tonumber(c) or UNKNOWN
            max = tonumber(m) or fallback
            return cur, max -- first match wins
        end
    end

    return cur, max
end

function DelveBuddy:FlashDelversBounty()
    local itemName = self:GetDelversBountyItemName()
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
                        LBG.ShowOverlayGlow(btn)
                        C_Timer.After(10, function()
                            LBG.HideOverlayGlow(btn)
                        end)
                        return
                    end
                end
            end
        end
    end
end

function DelveBuddy:IsDelveInProgress()
    local  result = C_PartyInfo.IsDelveInProgress()

    -- I've seen cases where IsDelveInProgress returns true when the player is clearly NOT in
    -- a delve (e.g., when zoning out of the Warlock class hall into the Dalaran Underbelly).
    -- To guard against this false positive, make sure the player has a mapID.
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID == nil then return false end

    return result
end

function DelveBuddy:HasDelversBountyItem()
    return C_Item.GetItemCount(self:GetDelversBountyItemId(), false) > 0
end

function DelveBuddy:HasNemesisLureItem()
    return C_Item.GetItemCount(self:GetNemesisLureItemId(), false) > 0
end

function DelveBuddy:GetDelversBountyItemId()
    if self:IsMidnight() then
        return DelveBuddy.IDS.Item.BountyItem_Midnight
    end

    return DelveBuddy.IDS.Item.BountyItem_TWW
end

function DelveBuddy:GetDelversBountyItemName()
    return C_Item.GetItemNameByID(self:GetDelversBountyItemId()) or "Trovehunter's Bounty"
end

function DelveBuddy:GetNemesisLureItemId()
    if self:IsMidnight() then
        return DelveBuddy.IDS.Item.NemesisLure_Midnight
    end

    return DelveBuddy.IDS.Item.NemesisLure_TWW
end

function DelveBuddy:GetDelversBountyBuffIds()
    if self:IsMidnight() then
        return self.IDS.Spell.BountyBuff_Midnight
    end

    return self.IDS.Spell.BountyBuff_TWW
end

function DelveBuddy:HasDelversBountyBuff()
    -- Can't get buffs (they're secret) in combat.
    if InCombatLockdown() then return false end

    local result = false

    local buffIDs = self:GetDelversBountyBuffIds()
    local i = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        self:Log("aura %d: %s", i, aura and tostring(aura.spellId) or "nil")
        if not aura then break end
        for _, id in ipairs(buffIDs) do
            if aura.spellId == id then
                result = true
                break
            end
        end
        i = i + 1
    end

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

function DelveBuddy:ShowCompanionRoleWarning()
    self:DisplayRaidWarning("|cffff4444Your companion's role is not set! This will severely hamper your delve performance.|r", true)
end

function DelveBuddy:ShowKeyWarning()
    self:DisplayRaidWarning("|cffff4444In a bountiful delve, with no Restored Coffer Keys!|r", true)
end

function DelveBuddy:ShowBountyNotice()
    self:DisplayRaidWarning("|cffffd700" .. self:GetDelversBountyItemName() .. " available!|r", false)
end

function DelveBuddy:DisplayRaidWarning(msg, playSound)
    local fullMsg = "DelveBuddy: " .. msg
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, fullMsg, ChatTypeInfo["RAID_WARNING"])
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(fullMsg, 1, 0.1, 0.1, 53, 5)
    end

    self:Print(msg)

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
            data.shardsEarned = 0
            data.shardsEarnedMax = 0
            data.gildedStashes = 0
            data.bountyLooted = false
            -- data.vaultRewards = {} keep vaultRewards
            -- keysOwned, shardsOwned, hasBounty are preserved
        end
    end
end

function DelveBuddy:Log(fmt, ...)
    if not self.db.global.debugLogging then return end
    self:Print(fmt:format(...))
end

function DelveBuddy:IsDelveComplete()
    return C_PartyInfo.IsDelveComplete()
end

function DelveBuddy:ClassColoredName(name, class)
    local classColor = RAID_CLASS_COLORS[class] or {["r"] = 1, ["g"] = 1, ["b"] = 0}
    return format("|cff%02x%02x%02x%s|r", classColor["r"] * 255, classColor["g"] * 255, classColor["b"] * 255, name)
end

function DelveBuddy:GetKeyCount()
    local c = C_CurrencyInfo.GetCurrencyInfo(self.IDS.Currency.RestoredCofferKey)
    return c and c.quantity or 0
end

function DelveBuddy:GetShardCount()
    if self:IsMidnight() then
        local c = C_CurrencyInfo.GetCurrencyInfo(self.IDS.Currency.CofferKeyShard)
        return c and c.quantity or 0
    end

    -- This is the TWW way
    return C_Item.GetItemCount(self.IDS.Item.CofferKeyShard)
end

function DelveBuddy:GetShardsEarnedThisWeek()
    local c = C_CurrencyInfo.GetCurrencyInfo(self.IDS.Currency.CofferKeyShard)
    return (c and c.quantityEarnedThisWeek) or 0, (c and c.maxWeeklyQuantity) or 0
end

function DelveBuddy:GetDelves()
    -- Timerunners can't do delves.
    if self:IsPlayerTimerunning() then return {} end

    local master = self:GetAllDelvePOIs()
    local delves = {}

    for areaPoiID, cached in pairs(master) do
        local info = cached and cached.zoneID and C_AreaPoiInfo.GetAreaPOIInfo(cached.zoneID, areaPoiID)

        if info and info.atlasName == "delves-bountiful" then
            local px, py
            if info.position and info.position.GetXY then
                px, py = info.position:GetXY()
            end

            delves[areaPoiID] = {
                name      = info.name,
                zoneID    = cached.zoneID,
                areaPoiID = info.areaPoiID,
                x         = (tonumber(px) or 0) * 100,
                y         = (tonumber(py) or 0) * 100,
            }
        end
    end

    return delves
end

local mapDepthCache = {}
local mapAncestorCache = {}

local function GetMapAncestors(mapID)
    if type(mapID) ~= "number" or mapID == 0 then
        return {}
    end

    local cached = mapAncestorCache[mapID]
    if cached then
        return cached
    end

    local ancestors = {}
    local seen = {}
    local currentMapID = mapID

    while currentMapID and currentMapID ~= 0 and not seen[currentMapID] do
        seen[currentMapID] = true
        ancestors[currentMapID] = true

        local mi = C_Map.GetMapInfo(currentMapID)
        currentMapID = mi and mi.parentMapID or 0
    end

    mapAncestorCache[mapID] = ancestors
    mapDepthCache[mapID] = 0
    for _ in pairs(ancestors) do
        mapDepthCache[mapID] = mapDepthCache[mapID] + 1
    end

    return ancestors
end

local function GetMapDepth(mapID)
    if mapDepthCache[mapID] == nil then
        GetMapAncestors(mapID)
    end

    return mapDepthCache[mapID] or 0
end

local function MapsShareChain(a, b)
    if a == b then return true end
    if type(a) ~= "number" or type(b) ~= "number" then return false end

    local aAncestors = GetMapAncestors(a)
    local bAncestors = GetMapAncestors(b)

    for mapID in pairs(aAncestors) do
        if bAncestors[mapID] then
            return true
        end
    end

    return false
end

local function BuildDelvePoiCandidate(mapID, poiID)
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
    if not info then
        return nil
    end

    local px, py
    if info.position and info.position.GetXY then
        px, py = info.position:GetXY()
    end

    return {
        areaPoiID = (type(info.areaPoiID) == "number" and info.areaPoiID) or poiID,
        name      = info.name,
        zoneID    = mapID,
        x         = (tonumber(px) or 0) * 100,
        y         = (tonumber(py) or 0) * 100,
    }
end

-- Scan starting at fallback world map and collect ALL delve POIs (bountiful or not).
-- Cache for the session. Prefer primary-map POIs; otherwise keep first-seen fallback.
function DelveBuddy:GetAllDelvePOIs()
    if self._allDelvePOIsCache then
        return self._allDelvePOIsCache
    end

    local zoneMaps = {}
    for _, zoneID in pairs(self.Zone or {}) do
        zoneMaps[zoneID] = true
    end

    local function shouldReplaceCandidate(existing, candidate)
        local existingIsZone = zoneMaps[existing.zoneID] == true
        local candidateIsZone = zoneMaps[candidate.zoneID] == true
        if candidateIsZone ~= existingIsZone then
            return candidateIsZone
        end

        local existingDepth = GetMapDepth(existing.zoneID)
        local candidateDepth = GetMapDepth(candidate.zoneID)
        if candidateDepth ~= existingDepth then
            return candidateDepth > existingDepth
        end

        return false
    end

    local root = C_Map.GetFallbackWorldMapID()
    local mapIDs = { root }
    local children = C_Map.GetMapChildrenInfo(root, nil, true) or {}
    for _, mi in ipairs(children) do
        if mi and type(mi.mapID) == "number" then
            table.insert(mapIDs, mi.mapID)
        end
    end

    local candidates = {}
    local scannedMaps, scannedPoiCalls = 0, 0

    for _, mapID in ipairs(mapIDs) do
        scannedMaps = scannedMaps + 1
        local ids = C_AreaPoiInfo.GetDelvesForMap(mapID)

        if ids and #ids > 0 then
            for _, id in ipairs(ids) do
                scannedPoiCalls = scannedPoiCalls + 1

                local candidate = BuildDelvePoiCandidate(mapID, id)
                if candidate then
                    table.insert(candidates, candidate)
                end
            end
        end
    end

    -- Collapse duplicate POIs exposed on both parent and child maps for the same delve.
    local deduped = {}
    for _, candidate in ipairs(candidates) do
        local matchedIndex

        for i, existing in ipairs(deduped) do
            if candidate.name and candidate.name ~= "" and candidate.name == existing.name
                and MapsShareChain(existing.zoneID, candidate.zoneID) then
                matchedIndex = i
                break
            end
        end

        if not matchedIndex then
            table.insert(deduped, candidate)
        else
            local existing = deduped[matchedIndex]
            if shouldReplaceCandidate(existing, candidate) then
                self:Log("GetAllDelvePOIs: deduped %q, replacing zone=%s poi=%s with zone=%s poi=%s",
                    tostring(candidate.name),
                    tostring(existing.zoneID),
                    tostring(existing.areaPoiID),
                    tostring(candidate.zoneID),
                    tostring(candidate.areaPoiID)
                )
                deduped[matchedIndex] = candidate
            else
                self:Log("GetAllDelvePOIs: deduped %q, discarding zone=%s poi=%s in favor of zone=%s poi=%s",
                    tostring(candidate.name),
                    tostring(candidate.zoneID),
                    tostring(candidate.areaPoiID),
                    tostring(existing.zoneID),
                    tostring(existing.areaPoiID)
                )
            end
        end
    end

    local pois = {}
    local delveCount = 0
    for _, p in ipairs(deduped) do
        pois[p.areaPoiID] = p
        delveCount = delveCount + 1
    end

    self._allDelvePOIsCache = pois
    self._allDelvePOIsCacheStats = {
        root = root,
        maps = scannedMaps,
        poiCalls = scannedPoiCalls,
        delves = delveCount,
    }

    self:Log("GetAllDelvePOIs: scanned %d maps, %d POI calls, found %d delves",
        scannedMaps, scannedPoiCalls, self._allDelvePOIsCacheStats.delves
    )

    return pois
end

function DelveBuddy:IsInBountifulDelve()
    if not self:IsDelveInProgress() then return false end

    -- Instance name appears to match the delve name.
    local instanceName = GetInstanceInfo()
    if not instanceName or instanceName == "" then
        self:Log("IsInBountifulDelve: no instance name")
        return false
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        self:Log("IsInBountifulDelve: no mapID")
        return false
    end

    -- Walk up the map chain; stop at the first map that has delve POIs.
    local zoneMap = mapID
    local poiIDs
    for _ = 1, 12 do
        poiIDs = C_AreaPoiInfo.GetDelvesForMap(zoneMap)
        if poiIDs and #poiIDs > 0 then
            break
        end
        local mi = C_Map.GetMapInfo(zoneMap)
        if not mi or not mi.parentMapID or mi.parentMapID == 0 then
            break
        end
        zoneMap = mi.parentMapID
    end

    if not poiIDs or #poiIDs == 0 then
        self:Log("IsInBountifulDelve: no POIs found in map chain. map=%s inst=%q",
            tostring(mapID), tostring(instanceName))
        return false
    end

    -- Try exact name match first.
    local matchedPoiID
    for _, poiID in ipairs(poiIDs) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(zoneMap, poiID)
        if info and info.name == instanceName then
            matchedPoiID = poiID
            break
        end
    end

    if not matchedPoiID then
        self:Log("IsInBountifulDelve: could not match instance name to any POI. map=%s zone=%s inst=%q",
            tostring(mapID), tostring(zoneMap), tostring(instanceName))
        return false
    end

    local matchedInfo = C_AreaPoiInfo.GetAreaPOIInfo(zoneMap, matchedPoiID)
    local bountiful = matchedInfo.atlasName == "delves-bountiful"

    self:Log("IsInBountifulDelve: map=%s zone=%s poi=%s inst=%q poiName=%q bountiful=%s",
        tostring(mapID),
        tostring(zoneMap),
        tostring(matchedPoiID),
        tostring(instanceName),
        tostring(matchedInfo and matchedInfo.name or ""),
        tostring(bountiful)
    )

    return bountiful
end

function DelveBuddy:IsPlayerTimerunning()
    if C_ChatInfo.IsTimerunningPlayer(UnitGUID("player")) then
        return true
    end

    -- Sometimes the above check erroneously returns false. Fallback to season check.
    local sid = PlayerGetTimerunningSeasonID()
    if sid and sid ~= 0 then
        return true
    end

    return false
end

function DelveBuddy:GetPlayerItemLevel()
    local avg, equipped = GetAverageItemLevel()
    self:Log("GetPlayerItemLevel: avg=%s equipped=%s", tostring(avg), tostring(equipped))
    return math.floor(equipped or 0)
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

function DelveBuddy:SetWaypoint(poi)
    local usedAny = false

    -- Blizzard waypoint
    if self.db.global.waypoints.useBlizzard then
        if C_Map.CanSetUserWaypointOnMap(poi.zoneID) then
            if poi.areaPoiID then
                C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, poi.areaPoiID)
            else
                local point = UiMapPoint.CreateFromCoordinates(poi.zoneID, poi.x / 100, poi.y / 100)
                C_Map.SetUserWaypoint(point)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            self:Print(("Waypoint set to %s"):format(poi.name))
            usedAny = true
        else
            self:Print(("Cannot set waypoint on map %s"):format(poi.zoneID))
        end
    end

    -- TomTom waypoint
    if self.db.global.waypoints.useTomTom then
        local tt = _G.TomTom
        if tt and tt.AddWaypoint then
            self:Log(("TomTom waypoint debug: zone=%s x=%.4f y=%.4f name=%s"):format(tostring(poi.zoneID), (poi.x or -1)/100, (poi.y or -1)/100, tostring(poi.name)))
            tt:AddWaypoint(poi.zoneID, poi.x / 100, poi.y / 100, {
                title = poi.name,
                persistent = false,
                minimap = true,
                world = true,
            })
            self:Print(("TomTom waypoint set to %s"):format(poi.name))
            usedAny = true
        else
            self:Print("TomTom not detected. Enable/install TomTom or disable it in DelveBuddy options.")
        end
    end

    if not usedAny then
        self:Print("No waypoint providers active.")
    end
end

function DelveBuddy:EnsureWeeklyRewardsReady()
    -- Goal: make Great Vault example reward links/ilvls resolve WITHOUT popping the UI.
    -- The data request seems tied to "UI interaction" (WeeklyRewards_OnShow calls it).
    -- We emulate that via C_WeeklyRewards.OnUIInteract().

    -- If the data is already generated/available, we can proceed.
    if C_WeeklyRewards.HasGeneratedRewards() then
        return
    end

    -- Initiate an interaction to fetch/generate weekly rewards data.
    C_WeeklyRewards.OnUIInteract()
end

function DelveBuddy:RewardTierToiLvl(tierID)
    self:Log("RewardTierToiLvl: tierID=%s", tostring(tierID))
    if type(tierID) ~= "number" then return nil end

    -- This is apparently not reliable - I get incorrect results sometimes. Fall back to hardcoding.
    -- local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(tierID)
    -- if not link then
    --     self:Log("RewardTierToiLvl: no example reward links for tierID %s", tostring(tierID))
    --     return nil
    -- end
    -- return C_Item.GetDetailedItemLevelInfo(link)

    TierToiLvl = {
        233, -- T1
        237,
        240,
        243,
        246,
        253,
        256,
        259, -- T8
        259,
        259,
        259,
    }
    self:Log("RewardTierToiLvl: tier=%s", tostring(TierToiLvl[tierID]))
    return TierToiLvl[tierID] or nil
end

function DelveBuddy:CompanionRoleSet()
    local roleSet, _, _ = self:GetActiveCompanionConfigFlags()
    return roleSet
end

function DelveBuddy:GetActiveCompanionConfigFlags()
    local roleSet = false
    local curiosSet = false
    local detail = ""

    -- Resolve the companion trait tree and config (needed to inspect node ranks).
    local treeID = C_DelvesUI.GetTraitTreeForCompanion(nil) or 0
    local configID = 0
    if treeID ~= 0 then
        configID = C_Traits.GetConfigIDByTreeID(treeID)
    end

    -- Helper: get purchased ranks for a node
    local function getNodeRanksPurchased(nodeID)
        if type(nodeID) ~= "number" or nodeID == 0 then return 0 end
        if configID == 0 then return 0 end
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if type(ni) ~= "table" then return 0 end
        return tonumber(ni.ranksPurchased or ni.currentRank or ni.activeRank or 0) or 0
    end

    -- ROLE: role is set iff the role node has purchased ranks.
    local roleNodeID = C_DelvesUI.GetRoleNodeForCompanion(nil) or 0
    local rolePurchased = getNodeRanksPurchased(roleNodeID)
    roleSet = rolePurchased > 0

    -- CURIOS: curios are set iff any curio node has purchased ranks.
    local combatPurchased, utilityPurchased = 0, 0
    if C_DelvesUI.GetCurioNodeForCompanion and Enum and Enum.CurioType then
        for name, curioType in pairs(Enum.CurioType) do
            local nodeID = C_DelvesUI.GetCurioNodeForCompanion(curioType, nil) or 0
            local purchased = getNodeRanksPurchased(nodeID)
            if tostring(name):lower() == "combat" then
                combatPurchased = purchased
            elseif tostring(name):lower() == "utility" then
                utilityPurchased = purchased
            end
            if purchased > 0 then
                curiosSet = true
            end
        end
    end

    detail = ("treeID=%s configID=%s rolePurchased=%s combatPurchased=%s utilityPurchased=%s")
        :format(tostring(treeID), tostring(configID), tostring(rolePurchased), tostring(combatPurchased), tostring(utilityPurchased))

    return roleSet, curiosSet, detail
end

-- Midnight does a bunch of stuff different. For example, coffer key shards are a currency, not an item.
-- This function allows us to abstract those differences. For testing on PTR), flip this to true. 
-- Once launched, we can flip it to true, or maybe remove it entirely.
function DelveBuddy:IsMidnight()
    return true
end

-- Debug-only functions.
-- Below are just for debugging, or accessible via slash commands.
-- Using Print instead of Log to output uncondintionally (regardless of Debug Logging being enabled).

-- Only for discovering new delves.
function DelveBuddy:DumpPOIs(mapID)
    if not mapID then
        self:Print("DelveBuddy: No mapID provided.")
        return
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    self:Print(("DelveBuddy: Dumping POIs for map %d (%s)"):format(mapID, mapInfo and mapInfo.name or "unknown"))

    local poiIDs = C_AreaPoiInfo.GetDelvesForMap(mapID) or {}
    if #poiIDs == 0 then
        self:Print("DelveBuddy: No POIs found on map", mapID)
        return
    end

    for _, poiID in ipairs(poiIDs) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
        if info then
            local px, py = info.position:GetXY()
            self:Print((
                "POI %d: name=%q, atlas=%q, texIdx=%s, pos=%.2f, %.2f, iconWidgetSet=%s, tooltipWidgetSet=%s"
            ):format(
                poiID,
                info.name or "",
                info.atlasName or "",
                tostring(info.textureIndex),
                tonumber(px or 0) * 100,
                tonumber(py or 0) * 100,
                tostring(info.iconWidgetSet),
                tostring(info.tooltipWidgetSet)
            ))
        end
    end
end

-- Only for finding item IDs of items (to find IDs of new bounty items, e.g.)
function DelveBuddy:PrintItemInfoByName(partialName)
    if not partialName or partialName == "" then
        return
    end

    partialName = partialName:lower()

    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local itemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                local itemName = itemInfoFn(link)
                if itemName and itemName:lower():find(partialName, 1, true) then
                    local itemID = link:match("item:(%d+)")
                    print("ItemID:", itemID, "Name:", itemName)
                    print(link:gsub("|", "||"))
                end
            end
        end
    end
end

-- Only for debugging; dump vault rewards and get iLvls of them.
function DelveBuddy:DumpVaultRewards()
    local IDS = self.IDS

    local activities = C_WeeklyRewards.GetActivities(IDS.Activity.World) or {}
    if #activities == 0 then
        self:Print("No Weekly Rewards activities returned (World)")
        return
    end

    self:Print("Vault Rewards (World):")

    local requestedAnyItemData = false
    local hadAnyNil = false
    self._vaultRewardsRetrying = self._vaultRewardsRetrying or false

    local function getIlvlFromLink(link)
        if not link then return nil end
        local ilvl = C_Item.GetDetailedItemLevelInfo(link)
        if type(ilvl) == "number" and ilvl > 0 then
            return ilvl
        end

        local _, _, _, ilvl = C_Item.GetItemInfo(link)
        if not ilvl then
            -- If item data isn't cached yet, request it so a subsequent /db rewards will succeed.
            local itemID = link:match("item:(%d+)")
            if itemID then
                C_Item.RequestLoadItemDataByID(tonumber(itemID))
                requestedAnyItemData = true
            end
        end
        return ilvl
    end

    local function getExampleIlvl(tierID)
        local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(tierID)
        local ilvl = getIlvlFromLink(link)
        if ilvl == nil then
            hadAnyNil = true
        end
        return ilvl
    end

    local lines = {}
    for _, a in ipairs(activities) do
        local tier = a.level
        local tierID = a.id

        local ilvl = getExampleIlvl(tierID)

        table.insert(lines, ("Tier %s: %d/%d (id=%s) %s")
            :format(
                tostring(tier),
                tonumber(a.progress or 0) or 0,
                tonumber(a.threshold or 0) or 0,
                tostring(tierID),
                tostring(ilvl)
            ))
    end

    -- If item data wasn't cached yet, schedule one automatic retry so the user doesn't have to run /db rewards twice.
    -- Defer printing tier lines until we have ilvls, to avoid noisy nil/nil output.
    if requestedAnyItemData and hadAnyNil and not self._vaultRewardsRetrying then
        self._vaultRewardsRetrying = true
        self:Print("(Vault reward item data not cached yet; retrying shortly...)")
        C_Timer.After(0.75, function()
            self:DumpVaultRewards()
        end)
        return
    end

    -- We either had all data, or we're on the retry pass.
    self._vaultRewardsRetrying = false
    for _, line in ipairs(lines) do
        self:Print(line)
    end
end

function DelveBuddy:PrintItemLevelColor(itemLevel)
    local r, g, b = GetItemLevelColor(itemLevel)
    if not r then
        self:Print(("GetItemLevelColor(%s) -> nil"):format(tostring(itemLevel)))
        return
    end

    local r255 = math.floor(r * 255 + 0.5)
    local g255 = math.floor(g * 255 + 0.5)
    local b255 = math.floor(b * 255 + 0.5)
    local hex = ("%02x%02x%02x"):format(r255, g255, b255)
    local sample = ("|cff%s%d|r"):format(hex, itemLevel)

    self:Print(("GetItemLevelColor(%d) -> r=%.3f g=%.3f b=%.3f hex=#%s sample=%s")
        :format(itemLevel, r, g, b, hex, sample))
end

-- Tiny function for measuring execution time of functions.
function DelveBuddy:MeasureMs(label, fn)
    local t0 = debugprofilestop and debugprofilestop() or (GetTimePreciseSec() * 1000)
    local a, b, c, d = fn()
    local t1 = debugprofilestop and debugprofilestop() or (GetTimePreciseSec() * 1000)
    local dt = t1 - t0
    if label then
        self:Print(("%s: %.1fms"):format(label, dt))
    end
    return dt, a, b, c, d
end
