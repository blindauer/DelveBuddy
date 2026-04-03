
local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")

-- ── Live implementation ───────────────────────────────────────────────────────
-- Each method calls Blizzard APIs directly. Sub-calls that are themselves
-- PlayerState methods route through DelveBuddy so mocks compose correctly
-- (e.g. a mocked IsDelveInProgress is seen by a live IsInBountifulDelve).

local LivePlayerState = {}

function LivePlayerState:IsDelveInProgress()
    local result = C_PartyInfo.IsDelveInProgress()

    -- I've seen cases where IsDelveInProgress returns true when the player is clearly NOT in
    -- a delve (e.g., when zoning out of the Warlock class hall into the Dalaran Underbelly).
    -- To guard against this false positive, make sure the player has a mapID.
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID == nil then return false end

    return result
end

function LivePlayerState:IsInBountifulDelve()
    if not DelveBuddy:IsDelveInProgress() then return false end

    -- Instance name appears to match the delve name.
    local instanceName = GetInstanceInfo()
    if not instanceName or instanceName == "" then
        DelveBuddy:Log("IsInBountifulDelve: no instance name")
        return false
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        DelveBuddy:Log("IsInBountifulDelve: no mapID")
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
        DelveBuddy:Log("IsInBountifulDelve: no POIs found in map chain. map=%s inst=%q",
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
        DelveBuddy:Log("IsInBountifulDelve: could not match instance name to any POI. map=%s zone=%s inst=%q",
            tostring(mapID), tostring(zoneMap), tostring(instanceName))
        return false
    end

    local matchedInfo = C_AreaPoiInfo.GetAreaPOIInfo(zoneMap, matchedPoiID)
    local bountiful = matchedInfo.atlasName == "delves-bountiful"

    DelveBuddy:Log("IsInBountifulDelve: map=%s zone=%s poi=%s inst=%q poiName=%q bountiful=%s",
        tostring(mapID),
        tostring(zoneMap),
        tostring(matchedPoiID),
        tostring(instanceName),
        tostring(matchedInfo and matchedInfo.name or ""),
        tostring(bountiful)
    )

    return bountiful
end

function LivePlayerState:IsDelveComplete()
    return C_PartyInfo.IsDelveComplete()
end

function LivePlayerState:HasDelversBountyBuff()
    -- Can't get buffs (they're secret) in combat.
    if InCombatLockdown() then return false end

    local buffID = DelveBuddy:GetDelversBountyBuffId()
    for i = 1, math.huge do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        DelveBuddy:Log("aura %d: %s", i, aura and tostring(aura.spellId) or "nil")
        if not aura then break end
        if aura.spellId == buffID then return true end
    end

    return false
end

function LivePlayerState:HasDelversBountyItem()
    return C_Item.GetItemCount(DelveBuddy:GetDelversBountyItemId(), false) > 0
end

function LivePlayerState:HasNemesisLureItem()
    return C_Item.GetItemCount(DelveBuddy:GetNemesisLureItemId(), false) > 0
end

function LivePlayerState:WasBountyLootedThisWeek()
    return C_QuestLog.IsQuestFlaggedCompleted(DelveBuddy.IDS.Quest.BountyLooted)
end

function LivePlayerState:GetKeyCount()
    local c = C_CurrencyInfo.GetCurrencyInfo(DelveBuddy.IDS.Currency.RestoredCofferKey)
    return c and c.quantity or 0
end

function LivePlayerState:GetShardCount()
    local c = C_CurrencyInfo.GetCurrencyInfo(DelveBuddy.IDS.Currency.CofferKeyShard)
    return c and c.quantity or 0
end

function LivePlayerState:CompanionRoleSet()
    local roleSet, _, _ = DelveBuddy:GetActiveCompanionConfigFlags()
    return roleSet
end

function LivePlayerState:IsPlayerTimerunning()
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

-- ── Mock implementation ───────────────────────────────────────────────────────
-- Methods check _values first, then fall through to the live implementation.
-- Only the keys you explicitly Set() are mocked; everything else is real.

local MockPlayerState = {}
MockPlayerState._values = {}

-- Set a mocked return value. Key is the method name, e.g. "HasDelversBountyBuff".
-- Returns self so calls can be chained:
--   DelveBuddy:UseMockPlayerState():Set("IsInBountifulDelve", true):Set("GetKeyCount", 0)
function MockPlayerState:Set(key, value)
    self._values[key] = value
    return self
end

function MockPlayerState:ResetAll()
    self._values = {}
end

function MockPlayerState:IsDelveInProgress()
    local v = self._values["IsDelveInProgress"]
    if v ~= nil then return v end
    return LivePlayerState:IsDelveInProgress()
end

function MockPlayerState:IsInBountifulDelve()
    local v = self._values["IsInBountifulDelve"]
    if v ~= nil then return v end
    return LivePlayerState:IsInBountifulDelve()
end

function MockPlayerState:IsDelveComplete()
    local v = self._values["IsDelveComplete"]
    if v ~= nil then return v end
    return LivePlayerState:IsDelveComplete()
end

function MockPlayerState:HasDelversBountyBuff()
    local v = self._values["HasDelversBountyBuff"]
    if v ~= nil then return v end
    return LivePlayerState:HasDelversBountyBuff()
end

function MockPlayerState:HasDelversBountyItem()
    local v = self._values["HasDelversBountyItem"]
    if v ~= nil then return v end
    return LivePlayerState:HasDelversBountyItem()
end

function MockPlayerState:HasNemesisLureItem()
    local v = self._values["HasNemesisLureItem"]
    if v ~= nil then return v end
    return LivePlayerState:HasNemesisLureItem()
end

function MockPlayerState:WasBountyLootedThisWeek()
    local v = self._values["WasBountyLootedThisWeek"]
    if v ~= nil then return v end
    return LivePlayerState:WasBountyLootedThisWeek()
end

function MockPlayerState:GetKeyCount()
    local v = self._values["GetKeyCount"]
    if v ~= nil then return v end
    return LivePlayerState:GetKeyCount()
end

function MockPlayerState:GetShardCount()
    local v = self._values["GetShardCount"]
    if v ~= nil then return v end
    return LivePlayerState:GetShardCount()
end

function MockPlayerState:CompanionRoleSet()
    local v = self._values["CompanionRoleSet"]
    if v ~= nil then return v end
    return LivePlayerState:CompanionRoleSet()
end

function MockPlayerState:IsPlayerTimerunning()
    local v = self._values["IsPlayerTimerunning"]
    if v ~= nil then return v end
    return LivePlayerState:IsPlayerTimerunning()
end

-- ── Attach to addon, default to live ─────────────────────────────────────────

DelveBuddy.PlayerState     = LivePlayerState
DelveBuddy.MockPlayerState = MockPlayerState   -- exposed for slash-command reference

-- Switch to the mock implementation, clearing any previously set mock values.
-- Returns MockPlayerState so calls can be chained with :Set().
function DelveBuddy:UseMockPlayerState()
    self.PlayerState = MockPlayerState
    MockPlayerState:ResetAll()
    return MockPlayerState
end

-- Switch back to live Blizzard APIs.
function DelveBuddy:UseLivePlayerState()
    self.PlayerState = LivePlayerState
end

-- Activate the mock implementation (without resetting other mocked keys) and
-- set one value. Intended for use by the /db mock slash command.
function DelveBuddy:SetMock(key, value)
    self.PlayerState = MockPlayerState
    MockPlayerState:Set(key, value)
end
