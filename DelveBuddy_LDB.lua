local LDB = LibStub("LibDataBroker-1.1")
local QTip = LibStub("LibQTip-1.0")

local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")
DelveBuddy.db = DelveBuddy.db or {}


-- Initialize settings in the global table
DelveBuddy.db.global = DelveBuddy.db.global or {}
if DelveBuddy.db.global.showIcon == nil then DelveBuddy.db.global.showIcon = true end
if DelveBuddy.db.global.mode == nil then DelveBuddy.db.global.mode = "A" end

local DelveBuddyMenu = CreateFrame("Frame", "DelveBuddyMenu", nil, "UIDropDownMenuTemplate")
DelveBuddyMenu.displayMode = "MENU"
DelveBuddyMenu.info = {}

DelveBuddy.ldb = LDB:NewDataObject("DelveBuddy", {
    type = "data source",
    text = "DelveBuddy",
    icon = "Interface\\AddOns\\DelveBuddy\\media\\DelveIcon",
    OnClick = function(self, button)
        if button == "LeftButton" then
            DelveBuddy:SlashCommand("toggle")
        elseif button == "RightButton" then
            if DelveBuddy.charTip then QTip:Release(DelveBuddy.charTip); DelveBuddy.charTip = nil end
            if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end
            GameTooltip:Hide()
            ToggleDropDownMenu(1, nil, DelveBuddyMenu, self, 0, 0)
        end
    end,
    OnEnter = function(display)
        -- Release old tips
        if DelveBuddy.charTip then QTip:Release(DelveBuddy.charTip); DelveBuddy.charTip = nil end
        if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end

        -- Character summary tooltip (8 columns)
        local charTip = QTip:Acquire("DelveBuddyCharTip", 8,
            "LEFT","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER")
        DelveBuddy.charTip = charTip
        charTip:EnableMouse(true)
        charTip:SetAutoHideDelay(0, display)
        charTip:SmartAnchorTo(display, "ANCHOR_CURSOR")
        DelveBuddy:PopulateCharacterSection(charTip)
        charTip:Show()

        -- Delve list tooltip (2 columns), anchored below charTip
        local delveTip = QTip:Acquire("DelveBuddyDelveTip", 2, "LEFT","LEFT")
        DelveBuddy.delveTip = delveTip
        delveTip:EnableMouse(true)
        delveTip:SetAutoHideDelay(0, display)
        delveTip:SmartAnchorTo(charTip.frame or charTip, "BOTTOMLEFT", 0, -4)
        DelveBuddy:PopulateDelveSection(delveTip)
        delveTip:Show()
    end,
    OnLeave = function()
        if DelveBuddy.charTip then QTip:Release(DelveBuddy.charTip); DelveBuddy.charTip = nil end
        if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end
    end,
})

DelveBuddyMenu.initialize = function(self, level)
    -- Checkbox: Show Icon
    local info = UIDropDownMenu_CreateInfo()
    info.text = "Show Icon"
    info.checked = DelveBuddy.db.global.showIcon
    info.func = function(_, _, _, checked)
        DelveBuddy.db.global.showIcon = checked
    end
    info.keepShownOnClick = true
    info.isNotRadio = true
    UIDropDownMenu_AddButton(info, level)

    -- Divider
    info = UIDropDownMenu_CreateInfo()
    info.disabled = true
    info.text = " "
    UIDropDownMenu_AddButton(info, level)

    -- Radio: Mode A
    info = UIDropDownMenu_CreateInfo()
    info.text = "Mode A"
    info.checked = (DelveBuddy.db.global.mode == "A")
    info.func = function()
        DelveBuddy.db.global.mode = "A"
    end
    info.keepShownOnClick = true
    UIDropDownMenu_AddButton(info, level)

    -- Radio: Mode B
    info = UIDropDownMenu_CreateInfo()
    info.text = "Mode B"
    info.checked = (DelveBuddy.db.global.mode == "B")
    info.func = function()
        DelveBuddy.db.global.mode = "B"
    end
    info.keepShownOnClick = true
    UIDropDownMenu_AddButton(info, level)
end

-- Populate the character summary (8 columns)
function DelveBuddy:PopulateCharacterSection(tip)
    tip:Clear()
    tip:AddHeader("Character", "Keys", "Stashes", "Bounty", "Looted", "Vault 1", "Vault 2", "Vault 3")
    local charKeyList, current = {}, self:GetCharacterKey()
    for key in pairs(self.db.charData) do
        if key ~= current then table.insert(charKeyList, key) end
    end
    table.sort(charKeyList)
    table.insert(charKeyList, 1, current)
    for _, charKey in ipairs(charKeyList) do
        local data = self.db.charData[charKey]
        if data then
            -- Build displayName as in OnTooltipShow
            local name = charKey
            if not self.db.global.showFullCharName then
                name = name:match("^[^-]+") or name
            end
            local icon = ""
            if data.class and CLASS_ICON_TCOORDS[data.class] then
                local c = CLASS_ICON_TCOORDS[data.class]
                icon = string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:14:14:0:0:256:256:%d:%d:%d:%d|t ",
                    c[1]*256, c[2]*256, c[3]*256, c[4]*256)
            end
            local displayName = icon .. self:ClassColoredName(name, data.class)
            local keysText    = string.format("%d/%d", data.keysEarned, data.keysOwned)
            local stashesText = (data.gildedStashes == 3) and "|cff00ff003/3|r" or (data.gildedStashes.."/3")
            local bountyText  = data.hasBounty and "Yes" or "No"
            local lootedText  = data.bountyLooted and "Yes" or "No"
            local vault1 = (function(v)
                if not v then return "—" end
                if v.progress >= v.threshold then
                    local tier = v.level > 0 and v.level or "—"
                    local iLvl = self.TierToVaultiLvl[v.level] or "?"
                    return ("|cff00ff00Tier %s (%s)|r"):format(tier, iLvl)
                else
                    return ("|cffaaaaaa%d/%d|r"):format(v.progress, v.threshold)
                end
            end)(data.vaultRewards and data.vaultRewards[1])
            local vault2 = (function(v)
                if not v then return "—" end
                if v.progress >= v.threshold then
                    local tier = v.level > 0 and v.level or "—"
                    local iLvl = self.TierToVaultiLvl[v.level] or "?"
                    return ("|cff00ff00Tier %s (%s)|r"):format(tier, iLvl)
                else
                    return ("|cffaaaaaa%d/%d|r"):format(v.progress, v.threshold)
                end
            end)(data.vaultRewards and data.vaultRewards[2])
            local vault3 = (function(v)
                if not v then return "—" end
                if v.progress >= v.threshold then
                    local tier = v.level > 0 and v.level or "—"
                    local iLvl = self.TierToVaultiLvl[v.level] or "?"
                    return ("|cff00ff00Tier %s (%s)|r"):format(tier, iLvl)
                else
                    return ("|cffaaaaaa%d/%d|r"):format(v.progress, v.threshold)
                end
            end)(data.vaultRewards and data.vaultRewards[3])

            tip:AddLine(displayName, keysText, stashesText, bountyText, lootedText, vault1, vault2, vault3)
        end
    end
end

-- Populate the delve list (2 columns)
function DelveBuddy:PopulateDelveSection(tip)
    tip:SetColumnLayout(2, "LEFT", "LEFT")
    tip:AddHeader("|cffdda0ddBountiful Delves|r", "")
    local delves = self:GetDelves() or {}
    for poiID, d in pairs(delves) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(d.zoneID, poiID)
        local icon = ""
        if info and info.atlasName then
            icon = ("|A:%s:14:14|a "):format(info.atlasName)
        end
        local name = icon .. d.name
        if d.overcharged then
            name = ("|cff80c0ff%s (OC)|r"):format(name)
        end
        local mapInfo = C_Map.GetMapInfo(d.zoneID)
        local zoneName = (mapInfo and mapInfo.name) or "?"
        local line = tip:AddLine(name, zoneName)
        -- TODO this doesn't work
        -- tip:SetLineScript(line, "OnMouseUp", function(_, _, button)
        --     if button == "LeftButton" then
        --         if C_Map.CanSetUserWaypointOnMap(d.zoneID) then
        --             local point = UiMapPoint.CreateFromCoordinates(d.zoneID, d.x/100, d.y/100)
        --             C_Map.SetUserWaypoint(point)
        --             print(("DelveBuddy: Waypoint set to %s"):format(d.name))
        --         else
        --             print(("DelveBuddy: Cannot set waypoint on map %s"):format(d.zoneID))
        --         end
        --     end
        -- end)
    end
end
