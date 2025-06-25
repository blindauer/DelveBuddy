local DelveBuddy = LibStub("AceAddon-3.0"):NewAddon("DelveBuddy", "AceConsole-3.0", "AceEvent-3.0")

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
        DelversBounty = 453004,
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
        [2423] = true, -- Sidestreet Sluice
        [2301] = true, -- The Sinkhole
        [2310] = true, -- Skittering Breach
        [2259] = true, -- Tak-Rethan Abyss
        [2299] = true, -- The Underkeep
        [2251] = true, -- The Waterworks
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

function DelveBuddy:OnInitialize()
    DelveBuddyDB = DelveBuddyDB or {}
    self.db = DelveBuddyDB

    self:RegisterChatCommand("delvebuddy", "ShowStatus")
    self:RegisterChatCommand("db", "ShowStatus")

    self:SetupEventHandler()

    self:CleanupStaleCharacters()
    self:CollectDelveData()
end

function DelveBuddy:SetupEventHandler()
    if self.eventFrame then return end

    GetQuestResetTime()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    f:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    self.eventFrame = f
end

function DelveBuddy:OnEvent(event, ...)
    C_Timer.After(1, function()
        if self:ShouldShowBounty() then
            self:StartBountyFlashing()
        end
    end)
end

function DelveBuddy:ShouldShowBounty()
    return self:IsInDelve() and self:HasDelversBountyItem() and not self:HasDelversBountyBuff()
end

function DelveBuddy:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName():gsub("%s+", "") -- remove spaces from realm
    return name .. "-" .. realm
end

function DelveBuddy:OnEnable()
    -- Placeholder for future event handling
end

function DelveBuddy:ShowStatus()
    self:CreateUI()
    self:CollectDelveData()
    self:UpdateUI()
end

function DelveBuddy:CollectDelveData()
    local data = {}

    local IDS = DelveBuddy.IDS

    local earned = 0
    for _, questID in ipairs(IDS.Quest.KeyEarned) do
        earned = earned + (C_QuestLog.IsQuestFlaggedCompleted(questID) and 1 or 0)
    end

    data.keysEarned = earned

    local c = C_CurrencyInfo.GetCurrencyInfo(IDS.Currency.RestoredCofferKey)
    data.keysOwned = c and c.quantity or 0

    local w = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(IDS.Widget.GildedStash)
    local stash = w and w.spellInfo and string.match(w.spellInfo.tooltip or "", "(%d)/3")
    data.gildedStashes = tonumber(stash) or 0

    data.hasBounty = C_Item.GetItemCount(IDS.Item.DelversBounty) > 0
    data.bountyLooted = C_QuestLog.IsQuestFlaggedCompleted(IDS.Quest.BountyLooted) or false

    data.vaultRewards = {}
    for _, a in ipairs(C_WeeklyRewards.GetActivities(IDS.Activity.World)) do
        table.insert(data.vaultRewards, {
            progress = a.progress,
            threshold = a.threshold,
            level = a.level
        })
    end

    data.lastLogin = GetServerTime()

    -- Save to DB under character key
    local charKey = self:GetCharacterKey()
    self.db[charKey] = data

    return data
end

function DelveBuddy:CreateUI()
    if self.frame then
        self.frame:Show()
        return
    end

    local f = CreateFrame("Frame", "DelveBuddyFrame", UIParent, "UIPanelDialogTemplate")
    f:SetSize(600, 300)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.titleText:SetPoint("TOP", 0, -10)
    f.titleText:SetText("DelveBuddy - Weekly Delves Summary")

    self.frame = f
    self.rows = {}
end

function DelveBuddy:UpdateUI()
    if not self.frame then return end

    local headerLabels = {
        "Character", "Keys", "Stashes", "Bounty", "Looted", "Vault 1", "Vault 2", "Vault 3"
    }

    local columnWidths = { 150, 56, 56, 56, 56, 72, 72, 72 }

    -- Clear previous rows
    for _, row in ipairs(self.rows) do
        row:Hide()
    end
    self.rows = {}

    local x = 15
    for i, text in ipairs(headerLabels) do
        local label = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", x, -35)
        label:SetText(text)
        x = x + columnWidths[i]
        table.insert(self.rows, label)
    end

    local rowIndex = 0
    for char, data in pairs(DelveBuddyDB) do
        rowIndex = rowIndex + 1
        local yOffset = -35 - (rowIndex * 20)

        local function cell(text, col)
            local x = 15
            for j = 1, col - 1 do x = x + columnWidths[j] end

            local fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", x, yOffset)
            fs:SetText(text)
            table.insert(self.rows, fs)
        end

        cell(char, 1)
        cell(data.keysEarned .. "/" .. data.keysOwned, 2)
        cell(data.gildedStashes .. "/3", 3)
        cell(data.hasBounty and "Yes" or "No", 4)
        cell(data.bountyLooted and "Yes" or "No", 5)

        for i = 1, 3 do
            local vault = data.vaultRewards and data.vaultRewards[i]
            local text = vault and string.format("%d/%d (T%s)", vault.progress, vault.threshold, vault.level > 0 and vault.level or "—") or "—"
            cell(text, 5 + i)
        end
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
    if C_Scenario.IsInScenario() then
        local mapID = C_Map.GetBestMapForUnit("player")
        return mapID and DelveBuddy.IDS.DelveMap[mapID]
    end
    return false
end

function DelveBuddy:HasDelversBountyItem()
    return C_Item.GetItemCount(DelveBuddy.IDS.Item.DelversBounty, false) > 0
end

function DelveBuddy:HasDelversBountyBuff()
    local i = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end
        if aura.spellId == DelveBuddy.IDS.Spell.DelversBounty then
            return true
        end
        i = i + 1
    end
    return false
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
    for charKey, data in pairs(self.db) do
        if type(data) == "table" and self:HasWeeklyResetOccurred(data.lastLogin) then
            self:Print("Resetting weekly data for", charKey)
            data.keysEarned = 0
            data.gildedStashes = 0
            data.bountyLooted = false
            data.vaultRewards = {}
            -- keysOwned and hasBounty are preserved
        end
    end
end