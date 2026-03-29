local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")
local QTip = LibStub("LibQTip-1.0")

local rewardQualityByType = {
    adventurer = 2,
    veteran = 3,
    champion = 4,
    hero = 5,
    myth = 6,
}

local crestCurrencyByType = {
    adventurer = DelveBuddy.IDS.Currency.AdventurerDawncrest,
    veteran = DelveBuddy.IDS.Currency.VeteranDawncrest,
    champion = DelveBuddy.IDS.Currency.ChampionDawncrest,
    hero = DelveBuddy.IDS.Currency.HeroDawncrest,
    myth = DelveBuddy.IDS.Currency.MythDawncrest,
}

local rewardsByTier = {
    [1] = { loot = { type = "adventurer", value = 220 }, vault = { type = "veteran", value = 233 }, hasGildedStash = false },
    [2] = { loot = { type = "adventurer", value = 224 }, vault = { type = "veteran", value = 237 }, hasGildedStash = false },
    [3] = { loot = { type = "adventurer", value = 227 }, vault = { type = "veteran", value = 240 }, hasGildedStash = false },
    [4] = {
        loot = { type = "adventurer", value = 230 },
        vault = { type = "veteran", value = 243 },
        crest = { type = "adventurer", value = 5 },
        bountyLoot = { type = "veteran", value = 237 },
        bountyCrest = { type = "veteran", value = 8 },
        hasGildedStash = false,
    },
    [5] = {
        loot = { type = "adventurer", value = 233 },
        vault = { type = "champion", value = 246 },
        crest = { type = "veteran", value = 5 },
        bountyLoot = { type = "veteran", value = 243 },
        bountyCrest = { type = "veteran", value = 16 },
        hasGildedStash = false,
    },
    [6] = {
        loot = { type = "veteran", value = 237 },
        vault = { type = "champion", value = 250 },
        crest = { type = "veteran", value = 10 },
        bountyLoot = { type = "champion", value = 246 },
        bountyCrest = { type = "champion", value = 8 },
        hasGildedStash = false,
    },
    [7] = {
        loot = { type = "champion", value = 246 },
        vault = { type = "champion", value = 253 },
        crest = { type = "champion", value = 4 },
        bountyLoot = { type = "champion", value = 250 },
        bountyCrest = { type = "champion", value = 16 },
        hasGildedStash = false,
    },
    [8] = {
        loot = { type = "champion", value = 250 },
        vault = { type = "hero", value = 259 },
        crest = { type = "champion", value = 6 },
        nemesisCrest = { type = "champion", value = 5 },
        bountyLoot = { type = "hero", value = 259 },
        bountyCrest = { type = "hero", value = 14 },
        hasGildedStash = false,
    },
    [9] = {
        loot = { type = "champion", value = 250 },
        vault = { type = "hero", value = 259 },
        crest = { type = "champion", value = 8 },
        nemesisCrest = { type = "champion", value = 5 },
        bountyLoot = { type = "hero", value = 259 },
        bountyCrest = { type = "hero", value = 16 },
        hasGildedStash = false,
    },
    [10] = {
        loot = { type = "champion", value = 250 },
        vault = { type = "hero", value = 259 },
        crest = { type = "champion", value = 10 },
        nemesisCrest = { type = "hero", value = 5 },
        bountyLoot = { type = "hero", value = 259 },
        bountyCrest = { type = "hero", value = 18 },
        hasGildedStash = false,
    },
    [11] = {
        loot = { type = "champion", value = 250 },
        vault = { type = "hero", value = 259 },
        crest = { type = "hero", value = 5 },
        nemesisCrest = { type = "hero", value = 5 },
        bountyLoot = { type = "hero", value = 259 },
        bountyCrest = { type = "hero", value = 20 },
        hasGildedStash = true,
    },
}

local function colorWithQuality(value, quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.hex then
        return ("|c%s%s|r"):format(color.hex:gsub("|c", ""), tostring(value))
    end

    return tostring(value)
end

local function colorWithType(value, rewardType)
    return colorWithQuality(value, rewardQualityByType[rewardType])
end

local function formatTypedValue(reward)
    if not reward or reward.value == nil then
        return ""
    end

    return colorWithType(reward.value, reward.type)
end

local function getCrestCurrencyInfo(reward)
    if not reward or not reward.type then
        return nil
    end

    local currencyID = crestCurrencyByType[reward.type]
    if not currencyID then
        return nil
    end

    return C_CurrencyInfo.GetCurrencyInfo(currencyID)
end

local function formatCrestsAndNemesis(rewards)
    local crests = formatTypedValue(rewards.crest)
    local nemesis = formatTypedValue(rewards.nemesisCrest)
    if crests ~= "" and nemesis ~= "" then
        return ("%s |cffffffff+|r %s"):format(crests, nemesis)
    end
    if crests ~= "" then
        return crests
    end
    return nemesis
end

local function addCrestLineToTooltip(prefix, reward)
    if not reward then
        return
    end

    local crestInfo = getCrestCurrencyInfo(reward)
    local crestIcon = (crestInfo and crestInfo.iconFileID) and DelveBuddy:TextureIcon(crestInfo.iconFileID, 16) .. " " or ""
    local crestName = (crestInfo and crestInfo.name) or "Dawncrest"
    GameTooltip:AddLine(
        ("%s%s %s%s"):format(
            prefix or "",
            colorWithType(reward.value, reward.type),
            crestIcon,
            crestName
        ),
        1, 1, 1
    )
end

function DelveBuddy:HideDelveRewardsTooltip()
    if self.delveRewardsTip then
        self.delveRewardsTip:Hide()
        QTip:Release(self.delveRewardsTip)
        self.delveRewardsTip = nil
    end
end

function DelveBuddy:ShowDelveRewardsTooltip(owner)
    if not owner then return end

    local heroCrestInfo = C_CurrencyInfo.GetCurrencyInfo(self.IDS.Currency.HeroDawncrest)

    self:HideDelveRewardsTooltip()

    local rewardsTip = QTip:Acquire(
        "DelveBuddyDelveRewardsTip",
        6,
        "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT"
    )
    rewardsTip:EnableMouse(true)
    rewardsTip:ClearAllPoints()
    rewardsTip:SetPoint("TOPLEFT", (owner.frame or owner), "TOPRIGHT", 8, 0)
    rewardsTip:SetScale(self.db.global.tooltipScale)
    rewardsTip:SetHitRectInsets(-2, -2, -2, -2)
    rewardsTip:Clear()
    rewardsTip:SetColumnLayout(6, "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER")

    local lootHeader = self:TextureIcon("Interface\\Icons\\inv_helmet_06", 16)
    local vaultHeader = self:TextureIcon("Interface\\Icons\\Delves-scenario-treasure-upgrade", 16)
    local crestsHeader = "Crests"
    local bountyLootHeader = self:TextureIcon("Interface\\Icons\\Icon_treasuremap", 16) .. " " .. lootHeader
    local bountyCrestsHeader = "Bounty Crests"
    if heroCrestInfo and heroCrestInfo.iconFileID then
        crestsHeader = self:TextureIcon(heroCrestInfo.iconFileID, 16)
        bountyCrestsHeader = self:TextureIcon("Interface\\Icons\\Icon_treasuremap", 16) .. " " .. crestsHeader
    end
    rewardsTip:AddHeader("Tier", lootHeader, vaultHeader, crestsHeader, bountyLootHeader, bountyCrestsHeader)

    for tier = 1, 11 do
        local rewards = rewardsByTier[tier] or {}
        local line = rewardsTip:AddLine(
            tostring(tier),
            formatTypedValue(rewards.loot),
            formatTypedValue(rewards.vault),
            formatCrestsAndNemesis(rewards),
            formatTypedValue(rewards.bountyLoot),
            formatTypedValue(rewards.bountyCrest)
        )
        rewardsTip:SetLineScript(line, "OnEnter", function()
            GameTooltip:Hide()
            GameTooltip:SetOwner(rewardsTip, "ANCHOR_NONE")
            GameTooltip:ClearLines()
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("TOPLEFT", (rewardsTip.frame or rewardsTip), "TOPRIGHT", 8, 0)
            GameTooltip:AddLine(("Completing a tier %d Bountiful Delve rewards the following:"):format(tier), 1, 1, 1, true)
            GameTooltip:AddLine(("- Gear (iLvl %s)"):format(formatTypedValue(rewards.loot)), 1, 1, 1)
            if rewards.crest then
                addCrestLineToTooltip("- ", rewards.crest)
            end
            if rewards.nemesisCrest then
                local nemesisInfo = getCrestCurrencyInfo(rewards.nemesisCrest)
                local nemesisIcon = (nemesisInfo and nemesisInfo.iconFileID) and DelveBuddy:TextureIcon(nemesisInfo.iconFileID, 16) .. " " or ""
                local nemesisName = (nemesisInfo and nemesisInfo.name) or "Dawncrest"
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    ("Defeating all nemesis groups awards an additional %s %s%s"):format(
                        colorWithType(rewards.nemesisCrest.value, rewards.nemesisCrest.type),
                        nemesisIcon,
                        nemesisName
                    ),
                    1, 1, 1, true
                )
            end
            if rewards.bountyLoot and rewards.bountyCrest then
                local bountyIcon = DelveBuddy:TextureIcon("Interface\\Icons\\Icon_treasuremap", 16)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    ("Completing it with a %s Trovehunter's Bounty active additionally rewards:"):format(bountyIcon),
                    1, 1, 1, true
                )
                GameTooltip:AddLine(("- Gear (iLvl %s)"):format(formatTypedValue(rewards.bountyLoot)), 1, 1, 1)
                addCrestLineToTooltip("- ", rewards.bountyCrest)
            end
            if rewards.hasGildedStash then
                local heroCrestName = (heroCrestInfo and heroCrestInfo.name) or "Hero Dawncrest"
                local heroCrestIcon = (heroCrestInfo and heroCrestInfo.iconFileID) and DelveBuddy:TextureIcon(heroCrestInfo.iconFileID, 16) .. " " or ""
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    ("The first %d completed per week additionally reward a Gilded Stash containing:"):format(
                        DelveBuddy.IDS.CONST.MAX_WEEKLY_GILDED_STASHES
                    ),
                    1, 1, 1, true
                )
                GameTooltip:AddLine(
                    ("- %s %s%s"):format(
                        colorWithQuality(10, rewardQualityByType.hero),
                        heroCrestIcon,
                        heroCrestName
                    ),
                    1, 1, 1
                )
            end
            GameTooltip:Show()
        end)
        rewardsTip:SetLineScript(line, "OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    rewardsTip:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if DelveBuddy.MaybeHideHoverTips then
            DelveBuddy.MaybeHideHoverTips()
        end
    end)
    rewardsTip:Show()

    self.delveRewardsTip = rewardsTip
end
