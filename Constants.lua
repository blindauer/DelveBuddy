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
        GildedStash = 6659,
    },
    Activity = {
        World = 6
    },
    Spell = {
        BountyBuff_Midnight = { 1254631, },
    },
    Achievement = {
        DelveLoremaster = 61741,  -- "Delve Loremaster: Midnight"
    },
    CONST = {
        CHAR_DATA_SCHEMA_VERSION = 3,
        MIDNIGHT_S1_START_US = 1773759600, -- March 17, 2026 08:00 PDT
        MIDNIGHT_S1_START_EU = 1773813600, -- March 18, 2026 06:00 UTC
        WIDGET_ID_GILDED_STASH = 7591,
        UNKNOWN_GILDED_STASH_COUNT = -1,
        UNKNOWN_SHARD_COUNT = -1,
        MAX_WEEKLY_GILDED_STASHES = 4,
        MIN_BOUNTIFUL_DELVE_LEVEL = 80,
    },
}
