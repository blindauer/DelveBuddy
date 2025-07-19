local LDB = LibStub("LibDataBroker-1.1")
local QTip = LibStub("LibQTip-1.0")

local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")
DelveBuddy.db = DelveBuddy.db or {}

-- For tooltip mouse tracking
local inMenuArea, inCharTip, inDelveTip = false, false, false

-- helper to dismiss  both tooltips
local function HideAllTips()
  if DelveBuddy.charTip then QTip:Release(DelveBuddy.charTip); DelveBuddy.charTip = nil end
  if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end
end

-- helper to check flags (call after every OnLeave)
local function TryHide()
    -- small delay to allow OnEnter of another frame to fire first
    C_Timer.After(0.1, function()
        if not (inMenuArea or inCharTip or inDelveTip) then
            HideAllTips()
        end
    end)
end

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
        if button == "RightButton" then
            if DelveBuddy.charTip then QTip:Release(DelveBuddy.charTip); DelveBuddy.charTip = nil end
            if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end
            GameTooltip:Hide()
            ToggleDropDownMenu(1, nil, DelveBuddyMenu, self, 0, 0)
        end
    end,
    OnEnter = function(display)
        inMenuArea = true

        -- Character summary tooltip (8 columns)
        local charTip = QTip:Acquire("DelveBuddyCharTip", 8,
            "LEFT","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER")
        charTip:EnableMouse(true)
        charTip:SetScript("OnEnter", function() inCharTip = true end)
        charTip:SetScript("OnLeave", function() inCharTip = false TryHide() end)
        charTip:SmartAnchorTo(display, "ANCHOR_CURSOR")
        DelveBuddy:PopulateCharacterSection(charTip)
        DelveBuddy.charTip = charTip
        charTip:Show()

        -- Delve list tooltip (2 columns), anchored below charTip
        local delveTip = QTip:Acquire("DelveBuddyDelveTip", 2, "LEFT","LEFT")
        delveTip:EnableMouse(true)
        delveTip:SetScript("OnEnter", function() inDelveTip = true end)
        delveTip:SetScript("OnLeave", function() inDelveTip = false TryHide() end)        delveTip:SmartAnchorTo(charTip.frame or charTip, "BOTTOMLEFT", 0, -4)
        DelveBuddy:PopulateDelveSection(delveTip)
        DelveBuddy.delveTip = delveTip
        delveTip:Show()
    end,
    OnLeave = function()
        inMenuArea = false
        TryHide()
    end,
})

DelveBuddyMenu.initialize = function(self, level)
    local info = UIDropDownMenu_CreateInfo()

    if level == 1 then
        -- Checkbox: Debug Logging
        info.text = "Debug Logging"
        info.checked = DelveBuddy.db.global.debugLogging
        info.func = function(_, _, _, checked)
            DelveBuddy.db.global.debugLogging = checked
        end
        info.keepShownOnClick = true
        info.isNotRadio = true
        UIDropDownMenu_AddButton(info, level)

        -- Divider
        info = UIDropDownMenu_CreateInfo()
        info.disabled = true
        info.text = " "
        UIDropDownMenu_AddButton(info, level)

        -- Remove Character
        info = UIDropDownMenu_CreateInfo()
        info.text      = "Remove Character"
        info.hasArrow  = true
        info.value     = "REMOVE_CHARACTER"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "REMOVE_CHARACTER" then
        -- build fully sorted alphabetical list
        local list = {}
        for charKey in pairs(DelveBuddy.db.charData) do
            table.insert(list, charKey)
        end
        table.sort(list)

        for _, charKey in ipairs(list) do
            local data = DelveBuddy.db.charData[charKey]
            local displayName = charKey
            if data and data.class then
                displayName = DelveBuddy:ClassColoredName(charKey, data.class)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text         = displayName
            info.func         = function()
                                   DelveBuddy.db.charData[charKey] = nil
                                   print(("DelveBuddy: Removed character %s"):format(charKey))
                               end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
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
            name = name:match("^[^-]+") or name
            local icon = ""
            if data.class and CLASS_ICON_TCOORDS[data.class] then
                local c = CLASS_ICON_TCOORDS[data.class]
                icon = string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:14:14:0:0:256:256:%d:%d:%d:%d|t ",
                    c[1]*256, c[2]*256, c[3]*256, c[4]*256)
            end
            local displayName = icon .. self:ClassColoredName(name, data.class)
            local keysText = self:FormatKeys(data.keysEarned, data.keysOwned)

            local stashesValue = data.gildedStashes
            local stashesText
            if stashesValue == 3 then
                stashesText = "|cff00ff003/3|r"
            elseif stashesValue == self.IDS.CONST.UNKNOWN_GILDED_STASHES then
                -- Unknown / unavailable
                stashesText = "|cffaaaaaa?/3|r"
            else
                stashesText = tostring(stashesValue or 0) .. "/3"
            end

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
        tip:SetLineScript(line, "OnMouseUp", function(_, button)
            DelveBuddy:Log("DelveBuddy: clicked delve ->", d.name)
            if C_Map.CanSetUserWaypointOnMap(d.zoneID) then
                local point = UiMapPoint.CreateFromCoordinates(d.zoneID, d.x/100, d.y/100)
                C_Map.SetUserWaypoint(point)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                DelveBuddy:Print(("DelveBuddy: Waypoint set to %s"):format(d.name))
            else
                DelveBuddy:Print(("DelveBuddy: Cannot set waypoint on map %s"):format(d.zoneID))
            end
        end)
        tip:SetLineScript(line, "OnEnter", function()
            -- Because hovering over the line calls delveTip's OnLeave, dismissing the tips otherwise.
            inDelveTip = true
        end)
    end
end

function DelveBuddy:FormatKeys(earned, owned)
    local earnedPart = tostring(earned)
    local ownedPart  = tostring(owned)

    if earned >= 4 then
        earnedPart = ("|cff00ff00%s|r"):format(earnedPart)
    end

    if owned == 0 then
        ownedPart = ("|cffff3333%s|r"):format(ownedPart)
    end

    return earnedPart .. "/" .. ownedPart
end