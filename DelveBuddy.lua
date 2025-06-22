local DelveBuddy = LibStub("AceAddon-3.0"):NewAddon("DelveBuddy", "AceConsole-3.0", "AceEvent-3.0")

function DelveBuddy:OnInitialize()
    DelveBuddyDB = DelveBuddyDB or {}
    self.db = DelveBuddyDB

    self:RegisterChatCommand("delvebuddy", "ShowStatus")
    self:RegisterChatCommand("db", "ShowStatus")
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

    local earned = 0
    for i = 84736, 84739 do
        if C_QuestLog.IsQuestFlaggedCompleted(i) then
            earned = earned + 1
        end
    end
    data.keysEarned = earned

    local c = C_CurrencyInfo.GetCurrencyInfo(3028)
    data.keysOwned = c and c.quantity or 0

    local w = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(6659)
    local stash = w and w.spellInfo and string.match(w.spellInfo.tooltip or "", "(%d)/3")
    data.gildedStashes = tonumber(stash) or 0

    data.hasBounty = GetItemCount(233071) > 0
    data.bountyLooted = C_QuestLog.IsQuestFlaggedCompleted(86371) or false

    data.vaultRewards = {}
    for _, a in ipairs(C_WeeklyRewards.GetActivities(6)) do
        table.insert(data.vaultRewards, {
            progress = a.progress,
            threshold = a.threshold,
            level = a.level
        })
    end

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
        cell(data.keysEarned .. "/4", 2)
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
