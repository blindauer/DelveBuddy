local DelveBuddy = LibStub("AceAddon-3.0"):GetAddon("DelveBuddy")

DelveBuddy.Zone = {
    -- TWW
    IsleOfDorn = 2248,
    Hallowfall = 2215,
    RingingDeeps = 2214,
    AzjKahet = 2255,
    Undermine = 2346,
    Karesh = 2371,
    -- Midnight
    EversongWoods = 2395,
    SilvermoonCity = 2393,
    IsleOfQuelDanas = 2424,
    Voidstorm = 2405,
    ZulAman = 2437,
    Harandar = 2413,
}

-- Maps Midnight delve POI IDs (both active and inactive) to their "Delver's Call" quest ID.
-- Covering both POI states so the lookup works regardless of which ID GetDelvesForMap returns.
DelveBuddy.DelveQuest = {
    [8426] = 93384, [8425] = 93384, -- Collegiate Calamity   (Silvermoon City)
    [8440] = 93385, [8439] = 93385, -- The Darkway           (Silvermoon City)
    [8428] = 93386, [8427] = 93386, -- Parhelion Plaza       (Isle of Quel'Danas)
    [8438] = 93372, [8437] = 93372, -- The Shadow Enclave    (Eversong Woods)
    [8432] = 93428, [8431] = 93428, -- Shadowguard Point     (Voidstorm)
    [8430] = 93427, [8429] = 93427, -- Sunkiller Sanctum     (Voidstorm)
    [8434] = 93421, [8433] = 93421, -- The Grudge Pit        (Harandar)
    [8436] = 93416, [8435] = 93416, -- The Gulf of Memory    (Harandar)
    [8444] = 93409, [8443] = 93409, -- Atal'Aman             (Zul'Aman)
    [8442] = 93410, [8441] = 93410, -- Twilight Crypts       (Zul'Aman)
}

DelveBuddy.MidnightZone = {
    [2395] = true, -- EversongWoods
    [2393] = true, -- SilvermoonCity
    [2424] = true, -- IsleOfQuelDanas
    [2405] = true, -- Voidstorm
    [2437] = true, -- ZulAman
    [2413] = true, -- Harandar
}

-- Blizzard typos in story variant widget text, mapped to the correct achievement criteria string.
DelveBuddy.StoryVariantTypoFixes = {
    ["Captured Widlife"] = "Captured Wildlife",
}

DelveBuddy.IDS = {
    Currency = {
        AdventurerDawncrest = 3383,
        VeteranDawncrest = 3341,
        ChampionDawncrest = 3343,
        HeroDawncrest = 3345,
        MythDawncrest = 3347,
        RestoredCofferKey = 3028,
        CofferKeyShard = 3310,
    },
    Quest = {
        BountyLooted = 86371,
    },
    Item = {
        BountyItem_Midnight = 252415,
        RadiantEcho = 246771,
        NemesisLure_Midnight = 253342,
    },
    Widget = {
        GildedStash = 7591,
    },
    Activity = {
        World = 6
    },
    Spell = {
        BountyBuff_Midnight = 1254631,
    },
    Achievement = {
        DelveLoremaster = 61741,  -- "Delve Loremaster: Midnight"
    },
    CONST = {
        CHAR_DATA_SCHEMA_VERSION = 3,
        MIDNIGHT_S1_START_US = 1773759600, -- March 17, 2026 08:00 PDT
        MIDNIGHT_S1_START_EU = 1773813600, -- March 18, 2026 06:00 UTC
        UNKNOWN_GILDED_STASH_COUNT = -1,
        UNKNOWN_SHARD_COUNT = -1,
        MAX_WEEKLY_GILDED_STASHES = 4,
        MIN_BOUNTIFUL_DELVE_LEVEL = 80,
        BOUNTY_MIN_TIER = 4,
        BOUNTY_ITEM_REQUIRED_LEVEL = 90,
    },
}
