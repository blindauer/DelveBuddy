local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")
DelveBuddy.db = DelveBuddy.db or {}

local LDB = LibStub("LibDataBroker-1.1")
local QTip = LibStub("LibQTip-1.0")

-- For tooltip mouse tracking
local inMenuArea, inCharTip, inDelveTip, inWorldTip = false, false, false, false

-- Helper to dismiss all tooltips
local function HideAllTips()
    if DelveBuddy.charTip  then QTip:Release(DelveBuddy.charTip);  DelveBuddy.charTip  = nil end
    if DelveBuddy.delveTip then QTip:Release(DelveBuddy.delveTip); DelveBuddy.delveTip = nil end
    if DelveBuddy.worldTip then QTip:Release(DelveBuddy.worldTip); DelveBuddy.worldTip = nil end
end

-- Helper to check flags (call after every OnLeave)
local function TryHide()
    -- Small delay to allow OnEnter of another frame to fire first
    C_Timer.After(0.1, function()
        if not (inMenuArea or inCharTip or inDelveTip or inWorldTip) then
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
            HideAllTips()
            GameTooltip:Hide()
            ToggleDropDownMenu(1, nil, DelveBuddyMenu, self, 0, 0)
        else
            -- left click toggle tooltips (or show/hide main UI if you re-enable it)
            if DelveBuddy.charTip then
                HideAllTips()
            else
                -- show
                DelveBuddy.ldb.OnEnter(self)
            end
        end
    end,
    OnEnter = function(display)
        inMenuArea = true

        -- Character summary tooltip
        local charTip = QTip:Acquire("DelveBuddyCharTip", 9,
            "LEFT","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER","CENTER", "CENTER")
        charTip:EnableMouse(true)
        charTip:SetScript("OnEnter", function() inCharTip = true end)
        charTip:SetScript("OnLeave", function() inCharTip = false TryHide() end)
        charTip:SmartAnchorTo(display, "ANCHOR_CURSOR")
        DelveBuddy:PopulateCharacterSection(charTip)
        DelveBuddy.charTip = charTip
        charTip:Show()

        -- Delve list tooltip
        local delveTip = QTip:Acquire("DelveBuddyDelveTip", 2, "LEFT","LEFT")
        delveTip:EnableMouse(true)
        delveTip:SetScript("OnEnter", function() inDelveTip = true end)
        delveTip:SetScript("OnLeave", function() inDelveTip = false TryHide() end)
        delveTip:ClearAllPoints()
        delveTip:SetPoint("TOPRIGHT", (charTip.frame or charTip), "BOTTOM", -4, 0)
        DelveBuddy:PopulateDelveSection(delveTip)
        DelveBuddy.delveTip = delveTip
        delveTip:Show()

        -- World Soul Memories tooltip
        local worldTip = QTip:Acquire("DelveBuddyWorldTip", 2, "LEFT","LEFT")
        worldTip:EnableMouse(true)
        worldTip:SetScript("OnEnter", function() inWorldTip = true end)
        worldTip:SetScript("OnLeave", function() inWorldTip = false TryHide() end)
        worldTip:ClearAllPoints()
        worldTip:SetPoint("TOPLEFT", (charTip.frame or charTip), "BOTTOM", 4, 0)
        DelveBuddy:PopulateWorldSoulSection(worldTip)
        DelveBuddy.worldTip = worldTip
        worldTip:Show()
    end,
    OnLeave = function()
        inMenuArea = false
        TryHide()
    end,
})

local LDBIcon = LibStub("LibDBIcon-1.0", true)

DelveBuddyMenu.initialize = function(self, level)
    local info = UIDropDownMenu_CreateInfo()

    if level == 1 then
        -- Minimap Icon Show/Hide
        info.text = "Show Minimap Icon"
        info.checked = not DelveBuddy.db.global.minimap.hide
        info.keepShownOnClick = true
        info.isNotRadio = true
        info.func = function(_, _, _, checked)
            -- Toggle the saved setting
            DelveBuddy.db.global.minimap.hide = not checked
            -- Show or hide via LibDBIcon
            if LDBIcon then
                if checked then
                    LDBIcon:Show("DelveBuddy")
                else
                    LDBIcon:Hide("DelveBuddy")
                end
            end
        end
        UIDropDownMenu_AddButton(info, level)

        -- Checkbox: Debug Logging
        info.text = "Debug Logging"
        info.checked = DelveBuddy.db.global.debugLogging
        info.keepShownOnClick = true
        info.isNotRadio = true
        info.func = function(_, _, _, checked)
            DelveBuddy.db.global.debugLogging = checked
        end
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
                                   DelveBuddy:Print(("Removed character %s"):format(charKey))
                                   CloseDropDownMenus()
                               end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

function DelveBuddy:PopulateCharacterSection(tip)
    tip:Clear()

    local KEY_ICON   = "|TInterface\\Icons\\Inv_10_blacksmithing_consumable_key_color1:16:16:0:0|t"
    local BOUNTY_ICON = "|TInterface\\Icons\\Icon_treasuremap:16:16:0:0|t"
    local STASH_ICON = "|TInterface\\Icons\\Inv_cape_special_treasure_c_01:16:16:0:0|t"
    local VAULT_ICON = "|TInterface\\Icons\\Delves-scenario-treasure-upgrade:16:16:0:0|t"

    -- Row 1: Icons (blank where you don't want one)
    tip:AddHeader(
        " ",
        KEY_ICON,
        KEY_ICON,
        STASH_ICON,
        BOUNTY_ICON,
        BOUNTY_ICON,
        VAULT_ICON,
        VAULT_ICON,
        VAULT_ICON
    )

    -- Row 2: Text labels
    local labelLine = tip:AddLine(
        " ",
        "Earned",
        "Owned",
        "Stashes",
        "Owned",
        "Looted",
        "Vault 1",
        "Vault 2",
        "Vault 3"
    )

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
            local icon = self:ClassIconMarkup(data.class)
            local displayName = icon .. self:ClassColoredName(name, data.class)
            local keysEarnedText = self:FormatKeysEarned(data.keysEarned)
            local keysOwnedText = self:FormatKeysOwned(data.keysOwned)
            local stashesText = self:FormatStashes(data.gildedStashes)

            local CHECK = self:AtlasIcon("common-icon-checkmark")
            local CROSS = self:AtlasIcon("common-icon-redx")
            local bountyText  = data.hasBounty and CHECK or CROSS
            local lootedText  = data.bountyLooted and CHECK or CROSS

            local rewards = data.vaultRewards
            local vault1 = self:FormatVaultCell(rewards and rewards[1])
            local vault2 = self:FormatVaultCell(rewards and rewards[2])
            local vault3 = self:FormatVaultCell(rewards and rewards[3])

            local line = tip:AddLine(displayName, keysEarnedText, keysOwnedText, stashesText, bountyText, lootedText, vault1, vault2, vault3)

            -- Only for current character: open vault if clicking vault cells.
            if name == UnitName("player") then
                for col = 7, 9 do -- Vault cells
                    tip:SetCellScript(line, col, "OnMouseUp", function()
                        DelveBuddy:OpenVaultUI()
                    end)
                    tip:SetCellScript(line, col, "OnEnter", function()
                        -- Because hovering over the cell calls charTip's OnLeave, dismissing the tips otherwise.
                        inCharTip = true
                    end)
                end
            end
        end
    end
end

function DelveBuddy:PopulateDelveSection(tip)
    tip:Clear()

    -- Get all bountiful delves; if none, show a placeholder message
    local delves = self:GetDelves() or {}
    if not next(delves) then
        tip:SetColumnLayout(1, "LEFT")
        tip:AddLine("|cffaaaaaaNo bountiful delves available|r")
        return
    end

    -- Otherwise show the list
    tip:SetColumnLayout(2, "LEFT", "LEFT")
    tip:AddHeader("|cffdda0ddBountiful Delves|r", "")
    for poiID, d in pairs(delves) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(d.zoneID, poiID)
        local icon = ""
        if info and info.atlasName then
            icon = self:AtlasIcon(info.atlasName) .. " "
        end
        local name = icon .. d.name
        local mapInfo = C_Map.GetMapInfo(d.zoneID)
        local zoneName = (mapInfo and mapInfo.name) or "?"
        local line = tip:AddLine(name, zoneName)
        tip:SetLineScript(line, "OnMouseUp", function(_, button)
            self:Log("DelveBuddy: clicked delve ->", d.name)
            if C_Map.CanSetUserWaypointOnMap(d.zoneID) then
                local point = UiMapPoint.CreateFromCoordinates(d.zoneID, d.x/100, d.y/100)
                C_Map.SetUserWaypoint(point)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                self:Print(("DelveBuddy: Waypoint set to %s"):format(d.name))
            else
                self:Print(("DelveBuddy: Cannot set waypoint on map %s"):format(d.zoneID))
            end
        end)
        tip:SetLineScript(line, "OnEnter", function()
            -- Because hovering over the line calls delveTip's OnLeave, dismissing the tips otherwise.
            inDelveTip = true
        end)
    end
end

function DelveBuddy:PopulateWorldSoulSection(tip)
    tip:Clear()

    local memories = self:GetWorldSoulMemories() or {}
    if not next(memories) then
        tip:SetColumnLayout(1, "LEFT")
        tip:AddLine("|cffaaaaaaNo World Soul Memories available|r")
        return
    end

    tip:SetColumnLayout(2, "LEFT", "LEFT")
    tip:AddHeader("|cff80c0ffWorld Soul Memories|r", "")

    -- name, zone
    for poiID, m in pairs(memories) do
        local zoneName = self:GetZoneName(m.zoneID)
        local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(m.zoneID, poiID)
        local icon = ""
        if poiInfo and poiInfo.atlasName then
            icon = self:AtlasIcon(poiInfo.atlasName) .. " "
        else
            -- Fallback to the known World Soul Memory atlas if not provided
            icon = self:AtlasIcon("UI-EventPoi-WorldSoulMemory") .. " "
        end
        local displayName = icon .. (m.name or "World Soul Memory")

        local line = tip:AddLine(displayName, zoneName)
        tip:SetLineScript(line, "OnEnter", function() inWorldTip = true end)
        tip:SetLineScript(line, "OnMouseUp", function(_, button)
            if C_Map.CanSetUserWaypointOnMap(m.zoneID) then
                local p = UiMapPoint.CreateFromCoordinates(m.zoneID, (m.x or 0)/100, (m.y or 0)/100)
                C_Map.SetUserWaypoint(p)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                self:Print(("DelveBuddy: Waypoint set to %s"):format(m.name))
            end
        end)
    end
end

DelveBuddy.Colors = {
    Green = "00ff00",
    Red   = "ff3333",
    Gray  = "aaaaaa",
}

function DelveBuddy:FormatKeysEarned(earned)
    local earnedPart = tostring(earned)

    if earned >= 4 then
        earnedPart = self:ColorText(earnedPart, self.Colors.Green)
    end

    return earnedPart
end

function DelveBuddy:FormatKeysOwned(owned)
    local ownedPart  = tostring(owned)

    if owned == 0 then
        ownedPart = self:ColorText(ownedPart, self.Colors.Red)
    end

    return ownedPart
end

function DelveBuddy:FormatStashes(cur)
    local UNKNOWN = self.IDS.CONST.UNKNOWN_GILDED_STASH_COUNT
    local _, max = self:GetGildedStashCounts()

    if cur == UNKNOWN then
        return self:ColorText(("?/%%d"):format(max), self.Colors.Gray)
    end

    cur = cur or 0
    if cur >= max then
        return self:ColorText(("%d/%d"):format(cur, max), self.Colors.Green)
    end

    return ("%d/%d"):format(cur, max)
end

function DelveBuddy:FormatVaultCell(v)
    if not v then return "—" end

    if v.progress >= v.threshold then
        local tier = v.level > 0 and v.level or "—"
        local iLvl = self.TierToVaultiLvl[v.level] or "?"
        return self:ColorText(("Tier %s (%s)"):format(tier, iLvl), self.Colors.Green)
    else
        return self:ColorText(("%d/%d"):format(v.progress, v.threshold), self.Colors.Gray)
    end
end

function DelveBuddy:AtlasIcon(name, size)
    size = size or 14
    return ("|A:%s:%d:%d|a"):format(name, size, size)
end

function DelveBuddy:TextureIcon(path, size)
    size = size or 14
    return ("|T%s:%d:%d|t"):format(path, size, size)
end

function DelveBuddy:ClassIconMarkup(class, size)
    size = size or 14
    local c = CLASS_ICON_TCOORDS[class]
    if not c then return "" end
    return ("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t "):format(
        size, size, c[1]*256, c[2]*256, c[3]*256, c[4]*256)
end

function DelveBuddy:ColorText(text, color)
    return ("|cff%s%s|r"):format(color, tostring(text))
end

function DelveBuddy:InitMinimapIcon()
    if not LDBIcon then return end
    -- Ensure settings table exists
    self.db.global.minimap = self.db.global.minimap or {}
    -- Register only once
    if not self.minimapIconRegistered then
        LDBIcon:Register("DelveBuddy", self.ldb, self.db.global.minimap)
        self.minimapIconRegistered = true
    end
end