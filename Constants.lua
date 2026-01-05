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
        RestoredCofferKey = 3028,
        CofferKeyShard = 3310, -- Midnight only (in TWW it's an item)
    },
    Quest = {
        ShardsEarned = { 84736, 84737, 84738, 84739 },
        KeyEarned = { 91175, 91176, 91177, 91178 },
        BountyLooted = 86371,
    },
    Item = {
        BountyItem = 252415, -- TWW was 248142
        CofferKeyShard = 245653, -- TWW only (in Midnight it's a currency)
        RadiantEcho = 246771,
        DelveOBot7001 = 230850,
        NemesisLure = 253342, -- TWW was 248017
    },
    Widget = {
        GildedStash = 6659,
    },
    Activity = {
        World = 6
    },
    Spell = {
        BountyBuff = { 1254631, }, -- TWW was { 453004, 473218 },
    },
    DelveMapToPoi = {
        -- Midnight
        [2502] = 8438, -- The Shadow Enclave
        [2577] = 8425, -- Collegiate Calamity (Inside L1)
        [2578] = 8425, -- Collegiate Calamity (Inside L2)
        [2547] = 8425, -- Collegiate Calamity (Outside)
        [2545] = 8427, -- Parhelion Plaza
        [2503] = 8442, -- Twilight Crypts (Entrance)
        [2504] = 8442, -- Twilight Crypts (Main Chamber)
        [2535] = 8443, -- Atal'Aman
        [2510] = 8434, -- The Grudge Pit
        [2505] = 8443, -- The Gulf of Memory
        [2528] = 8430, -- Sunkiller Sanctum (1)
        [2571] = 8430, -- Sunkiller Sanctum (2)
        [2506] = 8431, -- Shadowguard Point
        [2525] = 8439, -- The Darkway
        -- TWW
        [2269] = 7787, -- Earthcrawl Mines
        [2249] = 7779, -- Fungal Folly
        [2250] = 7781, -- Kriegval's Rest
        [2251] = 7782, -- The Waterworks
        [2310] = 7789, -- Skittering Breach
        [2302] = 7788, -- The Dread Pit
        [2396] = 8181, -- Excavation Site 9
        [2312] = 7780, -- Mycomancer Cavern
        [2277] = 7785, -- Nightfall Sanctum
        [2301] = 7783, -- The Sinkhole
        [2259] = 7784, -- Tak-Rethan Abyss
        [2299] = 7786, -- The Underkeep
        [2347] = 7790, -- The Spiral Weave
        [2420] = 8246, -- Sidestreet Sluice, The Pits
        [2421] = 8246, -- Sidestreet Sluice, The Low Decks
        [2422] = 8246, -- Sidestreet Sluice, The High Decks
        [2423] = 8246, -- Sidestreet Sluice, Entrance
        [2452] = 8273, -- Archival Assault
    },
    DelvePois = {
        -- Midnight Delves
        [DelveBuddy.Zone.EversongWoods] = {
            { ["id"] = 8438, ["x"] = 45.50, ["y"] = 86.25, ["widgetID"] = 1814 }, -- The Shadow Enclave
            { ["id"] = 8443, ["x"] = 63.78, ["y"] = 80.195, ["widgetID"] = 0 }, -- Atal'Aman TODO widgetID
        },
        [DelveBuddy.Zone.SilvermoonCity] = {
            { ["id"] = 8425, ["x"] = 40.44, ["y"] = 53.39, ["widgetID"] = 0 }, -- Collegiate Calamity TODO widgetID
            { ["id"] = 8439, ["x"] = 39.26, ["y"] = 32.00, ["widgetID"] = 0 }, -- The Darkway TODO widgetID
        },
        [DelveBuddy.Zone.IsleOfQuelDanas] = {
            { ["id"] = 8427, ["x"] = 46.67, ["y"] = 40.88, ["widgetID"] = 0 }, -- Parhelion Plaza TODO widgetID
        },
        [DelveBuddy.Zone.Harandar] = {
            { ["id"] = 8434, ["x"] = 70.90, ["y"] = 65.49, ["widgetID"] = 1810 }, -- The Grudge Pit
            { ["id"] = 8435, ["x"] = 36.77, ["y"] = 49.51, ["widgetID"] = 0 }, -- The Gulf of Memory TODO widgetID
        },
        [DelveBuddy.Zone.ZulAman] = {
            { ["id"] = 8442, ["x"] = 25.41, ["y"] = 84.29, ["widgetID"] = 1813 }, -- Twilight Crypts
        },
        [DelveBuddy.Zone.Voidstorm] = {
            { ["id"] = 8430, ["x"] = 54.80, ["y"] = 47.12, ["widgetID"] = 1808 }, -- Sunkiller Sanctum
            { ["id"] = 8431, ["x"] = 37.37, ["y"] = 47.87, ["widgetID"] = 0 }, -- Shadowguard Point TODO widgetID
        },
        -- TWW Delves
        [DelveBuddy.Zone.IsleOfDorn] = {
            { ["id"] = 7787, ["x"] = 38.60, ["y"] = 74.00, ["widgetID"] = 6723 }, -- Earthcrawl Mines
            { ["id"] = 7779, ["x"] = 52.03, ["y"] = 65.77, ["widgetID"] = 6728 }, -- Fungal Folly
            { ["id"] = 7781, ["x"] = 62.19, ["y"] = 42.70, ["widgetID"] = 6719 }, -- Kriegval's Rest
        },
        [DelveBuddy.Zone.RingingDeeps] = {
            { ["id"] = 7782, ["x"] = 42.15, ["y"] = 48.71, ["widgetID"] = 6720 }, -- The Waterworks
            { ["id"] = 7788, ["x"] = 70.20, ["y"] = 37.30, ["widgetID"] = 6724 }, -- The Dread Pit
            { ["id"] = 8181, ["x"] = 76.00, ["y"] = 96.50, ["widgetID"] = 6659 }, -- Excavation Site 9
        },
        [DelveBuddy.Zone.Hallowfall] = {
            { ["id"] = 7780, ["x"] = 71.30, ["y"] = 31.20, ["widgetID"] = 6729 }, -- Mycomancer Cavern
            { ["id"] = 7785, ["x"] = 34.32, ["y"] = 47.43, ["widgetID"] = 6727 }, -- Nightfall Sanctum
            { ["id"] = 7783, ["x"] = 50.60, ["y"] = 53.30, ["widgetID"] = 6721 }, -- The Sinkhole
            { ["id"] = 7789, ["x"] = 65.48, ["y"] = 61.74, ["widgetID"] = 6725 }, -- Skittering Breach
        },
        [DelveBuddy.Zone.AzjKahet] = {
            { ["id"] = 7790, ["x"] = 45.00, ["y"] = 19.00, ["widgetID"] = 6726 }, -- The Spiral Weave
            { ["id"] = 7784, ["x"] = 55.00, ["y"] = 73.92, ["widgetID"] = 6722 }, -- Tak-Rethan Abyss
            { ["id"] = 7786, ["x"] = 51.85, ["y"] = 88.30, ["widgetID"] = 6794 }, -- The Underkeep
        },
        [DelveBuddy.Zone.Undermine] = {
            { ["id"] = 8246, ["x"] = 35.20, ["y"] = 52.80, ["widgetID"] = 6718 }, -- Sidestreet Sluice
        },
        [DelveBuddy.Zone.Karesh] = {
            { ["id"] = 8273, ["x"] = 55.08, ["y"] = 48.08, ["widgetID"] = 7193 }, -- Archival Assault
        },
    },
    CONST = {
        UNKNOWN_GILDED_STASH_COUNT = -1,
        MAX_WEEKLY_GILDED_STASHES = 3,
        MAX_WEEKLY_SHARDS = 200,
        MAX_WEEKLY_KEYS = 4,
        MIN_BOUNTIFUL_DELVE_LEVEL = 80,
    },
}

DelveBuddy.TierToVaultiLvl = {
    [0] = 233,
    [1] = 233, -- TWW 668
    [2] = 237, -- TWW 671
    [3] = 240, -- TWW 675
    [4] = 243, -- TWW 678
    [5] = 246, -- TWW 681
    [6] = 253, -- TWW 688
    [7] = 0, -- TWW 691 TODO
    [8] = 0, -- TWW 694 TODO
    [9] = 0, -- TWW 694 TODO
    [10] = 0, -- TWW 694 TODO
    [11] = 0, -- TWW 694 TODO
}
