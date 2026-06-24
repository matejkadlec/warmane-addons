local addonName, addon = ...
local pairs = pairs

addon.DUNGEON_FINAL_BOSSES = {
    --==========================================================================--
    --                              Classic Dungeons                            --
    --==========================================================================--
    -- Ragefire Chasm
    [11520] = "Ragefire Chasm", -- Taragaman the Hungerer
    -- Deadmines
    [639] = "The Deadmines", -- Edwin VanCleef
    -- Wailing Caverns
    [3654] = "Wailing Caverns", -- Mutanus the Devourer
    -- Shadowfang Keep
    [4275] = "Shadowfang Keep", -- Archmage Arugal
    -- Blackfathom Deeps
    [4829] = "Blackfathom Deeps", -- Aku'mai
    -- Stockades
    [1716] = "The Stockade", -- Bazil Thredd
    -- Gnomeregan
    [7800] = "Gnomeregan", -- Mekgineer Thermaplugg
    -- Razorfen Kraul
    [4421] = "Razorfen Kraul", -- Charlga Razorflank
    -- Scarlet Monastery Graveyard
    [4543] = "Scarlet Monastery - Graveyard", -- Bloodmage Thalnos
    -- Scarlet Monastery Library
    [6487] = "Scarlet Monastery - Library", -- Arcanist Doan
    -- Scarlet Monastery Armory
    [3975] = "Scarlet Monastery - Armory", -- Herod
    -- Scarlet Monastery Cathedral
    [3976] = "Scarlet Monastery - Cathedral", -- Scarlet Commander Mograine
    -- Razorfen Downs
    [7358] = "Razorfen Downs", -- Amnennar the Coldbringer
    -- Uldaman
    [2748] = "Uldaman", -- Archaedas
    -- Maraudon Orange
    [12258] = "Maraudon - Orange Crystals", -- Razorlash
    -- Maraudon Purple
    [12236] = "Maraudon - Purple Crystals", -- Lord Vyletongue
    -- Maraudon Inner
    [12201] = "Maraudon - Pristine Waters", -- Princess Theradras
    -- Zul'Farrak
    [7267] = "Zul'Farrak", -- Chief Ukorz Sandscalp
    -- Sunken Temple
    [5709] = "Sunken Temple", -- Shade of Eranikus
    -- Blackrock Depths Prison
    [9018] = "Blackrock Depths - Prison", -- High Interrogator Gerstahn
    -- Blackrock Depths Upper City
    [9019] = "Blackrock Depths - Upper City", -- Emperor Dagran Thaurissan
    -- Dire Maul East
    [11492] = "Dire Maul - East", -- Alzzin the Wildshaper
    -- Dire Maul North
    [11501] = "Dire Maul - North", -- King Gordok
    -- Dire Maul West
    [11486] = "Dire Maul - West", -- Prince Tortheldrin
    -- Stratholme Living Side
    [10813] = "Stratholme - Main Gate", -- Balnazzar
    -- Stratholme Undead Side
    [10440] = "Stratholme - Service Entrance", -- Baron Rivendare
    -- Scholomance
    [1853] = "Scholomance", -- Darkmaster Gandling

    --==========================================================================--
    --                       The Burning Crusade Dungeons                       --
    --==========================================================================--
    -- Hellfire Ramparts
    [17536] = "Hellfire Ramparts", -- Nazan
    -- The Blood Furnace
    [17377] = "The Blood Furnace", -- Keli'dan the Breaker
    -- The Slave Pens
    [17942] = "The Slave Pens", -- Quagmirran
    -- The Underbog
    [17882] = "The Underbog", -- The Black Stalker
    -- Mana-Tombs
    [18344] = "Mana-Tombs", -- Nexus-Prince Shaffar
    -- Auchenai Crypts
    [18373] = "Auchenai Crypts", -- Exarch Maladaar
    -- Sethekk Halls
    [18473] = "Sethekk Halls", -- Talon King Ikiss
    -- Shadow Labyrinth
    [18708] = "Shadow Labyrinth", -- Murmur
    -- Old Hillsbrad Foothills
    [18096] = "Old Hillsbrad Foothills", -- Epoch Hunter
    -- The Black Morass
    [17881] = "The Black Morass", -- Aeonus
    -- The Steamvault
    [17798] = "The Steamvault", -- Warlord Kalithresh
    -- The Shattered Halls
    [16808] = "The Shattered Halls", -- Warchief Kargath Bladefist
    -- The Mechanar
    [19220] = "The Mechanar", -- Pathaleon the Calculator
    -- The Botanica
    [17977] = "The Botanica", -- Warp Splinter
    -- The Arcatraz
    [20912] = "The Arcatraz", -- Harbinger Skyriss
    -- Magisters' Terrace
    [24664] = "Magisters' Terrace", -- Kael'thas Sunstrider

    --==========================================================================--
    --                     Wrath of the Lich King Dungeons                      --
    --==========================================================================--
    -- Utgarde Keep
    [23954] = "Utgarde Keep", -- Ingvar the Plunderer
    -- The Nexus
    [26723] = "The Nexus", -- Keristrasza
    -- Azjol-Nerub
    [29120] = "Azjol-Nerub", -- Anub'arak
    -- Ahn'kahet: The Old Kingdom
    [29311] = "Ahn'kahet: The Old Kingdom", -- Herald Volazj
    -- Drak'Tharon Keep
    [26632] = "Drak'Tharon Keep", -- The Prophet Tharon'ja
    -- The Violet Hold
    [31134] = "The Violet Hold", -- Cyanigosa
    -- Gundrak
    [29306] = "Gundrak", -- Gal'darah
    -- Halls of Stone
    [27978] = "Halls of Stone", -- Sjonnir The Ironshaper
    -- Halls of Lightning
    [28923] = "Halls of Lightning", -- Loken
    -- The Oculus
    [27656] = "The Oculus", -- Ley-Guardian Eregos
    -- Culling of Stratholme
    [26533] = "The Culling of Stratholme", -- Mal'Ganis
    -- Utgarde Pinnacle
    [26861] = "Utgarde Pinnacle", -- King Ymiron
    -- The Forge of Souls
    [36502] = "The Forge of Souls", -- Devourer of Souls
    -- Pit of Saron
    [36658] = "Pit of Saron", -- Scourgelord Tyrannus
    -- Halls of Reflection
    [36954] = "Halls of Reflection", -- The Lich King
    -- Trial of the Champion
    [35451] = "Trial of the Champion", -- The Black Knight

    --==========================================================================--
    --                              Event Dungeons                              --
    --==========================================================================--
    -- Brewfest
    [23872] = "Blackrock Depths", -- Coren Direbrew
    -- Love is in the Air
    [36296] = "Shadowfang Keep", -- Apothecary Hummel
}

-- Map wing names back to live zone names for clients that report only the parent zone
addon.DUNGEON_BASE_INSTANCE_NAMES = {
    ["Scarlet Monastery - Graveyard"] = "Scarlet Monastery",
    ["Scarlet Monastery - Library"] = "Scarlet Monastery",
    ["Scarlet Monastery - Armory"] = "Scarlet Monastery",
    ["Scarlet Monastery - Cathedral"] = "Scarlet Monastery",
    ["Maraudon - Purple Crystals"] = "Maraudon",
    ["Maraudon - Orange Crystals"] = "Maraudon",
    ["Maraudon - Pristine Waters"] = "Maraudon",
    ["Blackrock Depths - Prison"] = "Blackrock Depths",
    ["Blackrock Depths - Upper City"] = "Blackrock Depths",
    ["Dire Maul - East"] = "Dire Maul",
    ["Dire Maul - North"] = "Dire Maul",
    ["Dire Maul - West"] = "Dire Maul",
    ["Stratholme - Main Gate"] = "Stratholme",
    ["Stratholme - Service Entrance"] = "Stratholme",
}

-- Canonical names for older client zone names and legacy saved rows
addon.DUNGEON_INSTANCE_NAME_ALIASES = {
    -- Classic dungeons
    ["The Wailing Caverns"] = "Wailing Caverns",
    ["Deadmines"] = "The Deadmines",
    ["Stormwind Stockade"] = "The Stockade",
    ["Stormwind Stockades"] = "The Stockade",
    ["The Stormwind Stockade"] = "The Stockade",
    ["The Stormwind Stockades"] = "The Stockade",
    ["Zul Farrak"] = "Zul'Farrak",
    ["ZulFarrak"] = "Zul'Farrak",
    ["The Temple of Atal'Hakkar"] = "Sunken Temple",
    ["Temple of Atal'Hakkar"] = "Sunken Temple",
    ["Temple of Atal Hakkar"] = "Sunken Temple",
    ["Atal'Hakkar Temple"] = "Sunken Temple",

    -- Scarlet Monastery wings
    ["Scarlet Monastery: Graveyard"] = "Scarlet Monastery - Graveyard",
    ["Scarlet Monastery Graveyard"] = "Scarlet Monastery - Graveyard",
    ["Scarlet Monastery: Library"] = "Scarlet Monastery - Library",
    ["Scarlet Monastery Library"] = "Scarlet Monastery - Library",
    ["Scarlet Monastery: Armory"] = "Scarlet Monastery - Armory",
    ["Scarlet Monastery Armory"] = "Scarlet Monastery - Armory",
    ["Scarlet Monastery: Cathedral"] = "Scarlet Monastery - Cathedral",
    ["Scarlet Monastery Cathedral"] = "Scarlet Monastery - Cathedral",

    -- Maraudon wings
    ["Maraudon: Purple Crystals"] = "Maraudon - Purple Crystals",
    ["Maraudon - Purple"] = "Maraudon - Purple Crystals",
    ["Maraudon: The Wicked Grotto"] = "Maraudon - Purple Crystals",
    ["Maraudon - Wicked Grotto"] = "Maraudon - Purple Crystals",
    ["Maraudon: Orange Crystals"] = "Maraudon - Orange Crystals",
    ["Maraudon - Orange"] = "Maraudon - Orange Crystals",
    ["Maraudon: Foulspore Cavern"] = "Maraudon - Orange Crystals",
    ["Maraudon - Foulspore Cavern"] = "Maraudon - Orange Crystals",
    ["Maraudon: Pristine Waters"] = "Maraudon - Pristine Waters",
    ["Maraudon - Inner"] = "Maraudon - Pristine Waters",
    ["Maraudon: Earth Song Falls"] = "Maraudon - Pristine Waters",
    ["Maraudon - Earth Song Falls"] = "Maraudon - Pristine Waters",

    -- Blackrock Depths wings
    ["Blackrock Depths - Detention Block"] = "Blackrock Depths - Prison",
    ["Blackrock Depths: Detention Block"] = "Blackrock Depths - Prison",
    ["Blackrock Depths - Lower City"] = "Blackrock Depths - Prison",
    ["Blackrock Depths: Lower City"] = "Blackrock Depths - Prison",
    ["Blackrock Depths: Upper City"] = "Blackrock Depths - Upper City",

    -- Dire Maul wings
    ["Dire Maul - Warpwood Quarter"] = "Dire Maul - East",
    ["Dire Maul - Warpwood Quarters"] = "Dire Maul - East",
    ["Dire Maul: Warpwood Quarter"] = "Dire Maul - East",
    ["Dire Maul: East"] = "Dire Maul - East",
    ["Dire Maul East"] = "Dire Maul - East",
    ["Dire Maul - Capital Gardens"] = "Dire Maul - West",
    ["Dire Maul: Capital Gardens"] = "Dire Maul - West",
    ["Dire Maul: West"] = "Dire Maul - West",
    ["Dire Maul West"] = "Dire Maul - West",
    ["Dire Maul - Gordok Commons"] = "Dire Maul - North",
    ["Dire Maul: Gordok Commons"] = "Dire Maul - North",
    ["Dire Maul: North"] = "Dire Maul - North",
    ["Dire Maul North"] = "Dire Maul - North",

    -- Stratholme wings
    ["Stratholme: Main Gate"] = "Stratholme - Main Gate",
    ["Stratholme Main Gate"] = "Stratholme - Main Gate",
    ["Stratholme - Live"] = "Stratholme - Main Gate",
    ["Stratholme Live"] = "Stratholme - Main Gate",
    ["Stratholme - Living Side"] = "Stratholme - Main Gate",
    ["Stratholme: Service Entrance"] = "Stratholme - Service Entrance",
    ["Stratholme Service Entrance"] = "Stratholme - Service Entrance",
    ["Stratholme - Undead"] = "Stratholme - Service Entrance",
    ["Stratholme Undead"] = "Stratholme - Service Entrance",
    ["Stratholme - Undead Side"] = "Stratholme - Service Entrance",

    -- Hellfire Citadel dungeons
    ["The Ramparts"] = "Hellfire Ramparts",
    ["Hellfire Citadel: Ramparts"] = "Hellfire Ramparts",
    ["Hellfire Citadel - Ramparts"] = "Hellfire Ramparts",
    ["Hellfire Citadel: Hellfire Ramparts"] = "Hellfire Ramparts",
    ["Blood Furnace"] = "The Blood Furnace",
    ["Hellfire Citadel: The Blood Furnace"] = "The Blood Furnace",
    ["Hellfire Citadel - The Blood Furnace"] = "The Blood Furnace",
    ["Hellfire Citadel: Blood Furnace"] = "The Blood Furnace",
    ["Shattered Halls"] = "The Shattered Halls",
    ["Hellfire Citadel: The Shattered Halls"] = "The Shattered Halls",
    ["Hellfire Citadel - The Shattered Halls"] = "The Shattered Halls",
    ["Hellfire Citadel: Shattered Halls"] = "The Shattered Halls",

    -- Coilfang Reservoir dungeons
    ["Slave Pens"] = "The Slave Pens",
    ["Coilfang Reservoir: The Slave Pens"] = "The Slave Pens",
    ["Coilfang Reservoir - The Slave Pens"] = "The Slave Pens",
    ["Coilfang Reservoir: Slave Pens"] = "The Slave Pens",
    ["Underbog"] = "The Underbog",
    ["Coilfang Reservoir: The Underbog"] = "The Underbog",
    ["Coilfang Reservoir - The Underbog"] = "The Underbog",
    ["Coilfang Reservoir: Underbog"] = "The Underbog",
    ["Steamvault"] = "The Steamvault",
    ["Steam Vault"] = "The Steamvault",
    ["The Steam Vault"] = "The Steamvault",
    ["Coilfang Reservoir: The Steamvault"] = "The Steamvault",
    ["Coilfang Reservoir - The Steamvault"] = "The Steamvault",

    -- Auchindoun dungeons
    ["Mana Tombs"] = "Mana-Tombs",
    ["Auchindoun: Mana-Tombs"] = "Mana-Tombs",
    ["Auchindoun - Mana-Tombs"] = "Mana-Tombs",
    ["Auchindoun: Mana Tombs"] = "Mana-Tombs",
    ["Auchindoun: Auchenai Crypts"] = "Auchenai Crypts",
    ["Auchindoun - Auchenai Crypts"] = "Auchenai Crypts",
    ["Auchindoun: Sethekk Halls"] = "Sethekk Halls",
    ["Auchindoun - Sethekk Halls"] = "Sethekk Halls",
    ["Auchindoun: Shadow Labyrinth"] = "Shadow Labyrinth",
    ["Auchindoun - Shadow Labyrinth"] = "Shadow Labyrinth",

    -- Caverns of Time dungeons
    ["Caverns of Time: Old Hillsbrad Foothills"] = "Old Hillsbrad Foothills",
    ["Caverns of Time - Old Hillsbrad Foothills"] = "Old Hillsbrad Foothills",
    ["Caverns of Time: Escape from Durnholde Keep"] = "Old Hillsbrad Foothills",
    ["Escape from Durnholde Keep"] = "Old Hillsbrad Foothills",
    ["Escape from Durnholde"] = "Old Hillsbrad Foothills",
    ["Black Morass"] = "The Black Morass",
    ["Caverns of Time: The Black Morass"] = "The Black Morass",
    ["Caverns of Time - The Black Morass"] = "The Black Morass",
    ["Caverns of Time: Opening the Dark Portal"] = "The Black Morass",
    ["Opening the Dark Portal"] = "The Black Morass",
    ["Caverns of Time: Culling of Stratholme"] = "The Culling of Stratholme",
    ["Caverns of Time - Culling of Stratholme"] = "The Culling of Stratholme",
    ["Culling of Stratholme"] = "The Culling of Stratholme",

    -- Tempest Keep dungeons
    ["Mechanar"] = "The Mechanar",
    ["Tempest Keep: The Mechanar"] = "The Mechanar",
    ["Tempest Keep - The Mechanar"] = "The Mechanar",
    ["Tempest Keep: Mechanar"] = "The Mechanar",
    ["Botanica"] = "The Botanica",
    ["Tempest Keep: The Botanica"] = "The Botanica",
    ["Tempest Keep - The Botanica"] = "The Botanica",
    ["Tempest Keep: Botanica"] = "The Botanica",
    ["Arcatraz"] = "The Arcatraz",
    ["Tempest Keep: The Arcatraz"] = "The Arcatraz",
    ["Tempest Keep - The Arcatraz"] = "The Arcatraz",
    ["Tempest Keep: Arcatraz"] = "The Arcatraz",
    ["Magisters Terrace"] = "Magisters' Terrace",
    ["Magister's Terrace"] = "Magisters' Terrace",

    -- Wrath of the Lich King dungeons
    ["Nexus"] = "The Nexus",
    ["Azjol Nerub"] = "Azjol-Nerub",
    ["Azjol'Nerub"] = "Azjol-Nerub",
    ["Ahnkahet: The Old Kingdom"] = "Ahn'kahet: The Old Kingdom",
    ["Ahn'kahet The Old Kingdom"] = "Ahn'kahet: The Old Kingdom",
    ["Ahnkahet The Old Kingdom"] = "Ahn'kahet: The Old Kingdom",
    ["Old Kingdom"] = "Ahn'kahet: The Old Kingdom",
    ["Draktharon Keep"] = "Drak'Tharon Keep",
    ["Drak Tharon Keep"] = "Drak'Tharon Keep",
    ["Violet Hold"] = "The Violet Hold",
    ["Gun'Drak"] = "Gundrak",
    ["Ulduar: Halls of Stone"] = "Halls of Stone",
    ["Ulduar - Halls of Stone"] = "Halls of Stone",
    ["Ulduar: Halls of Lightning"] = "Halls of Lightning",
    ["Ulduar - Halls of Lightning"] = "Halls of Lightning",
    ["Oculus"] = "The Oculus",
    ["The Trial of the Champion"] = "Trial of the Champion",
    ["Crusaders' Coliseum: Trial of the Champion"] = "Trial of the Champion",
    ["Argent Coliseum: Trial of the Champion"] = "Trial of the Champion",
    ["Forge of Souls"] = "The Forge of Souls",
    ["Frozen Halls: The Forge of Souls"] = "The Forge of Souls",
    ["Icecrown Citadel: The Forge of Souls"] = "The Forge of Souls",
    ["Icecrown Citadel - The Forge of Souls"] = "The Forge of Souls",
    ["Frozen Halls: Pit of Saron"] = "Pit of Saron",
    ["Icecrown Citadel: Pit of Saron"] = "Pit of Saron",
    ["Icecrown Citadel - Pit of Saron"] = "Pit of Saron",
    ["Frozen Halls: Halls of Reflection"] = "Halls of Reflection",
    ["Icecrown Citadel: Halls of Reflection"] = "Halls of Reflection",
    ["Icecrown Citadel - Halls of Reflection"] = "Halls of Reflection",
}

-- Warmane RDF level brackets used when the client LFD table is unavailable
addon.DUNGEON_LEVEL_RANGES = {
    ["Scarlet Monastery - Graveyard"] = { minLevel = 27, maxLevel = 37 },
    ["Scarlet Monastery - Library"] = { minLevel = 29, maxLevel = 39 },
    ["Scarlet Monastery - Armory"] = { minLevel = 32, maxLevel = 42 },
    ["Scarlet Monastery - Cathedral"] = { minLevel = 35, maxLevel = 45 },
    ["Maraudon - Purple Crystals"] = { minLevel = 39, maxLevel = 49 },
    ["Maraudon - Orange Crystals"] = { minLevel = 41, maxLevel = 51 },
    ["Maraudon - Pristine Waters"] = { minLevel = 43, maxLevel = 53 },
    ["Maraudon"] = { minLevel = 39, maxLevel = 53 },
    ["Sunken Temple"] = { minLevel = 45, maxLevel = 55 },
    ["Blackrock Depths - Prison"] = { minLevel = 47, maxLevel = 57 },
    ["Blackrock Depths - Upper City"] = { minLevel = 51, maxLevel = 61 },
    ["Blackrock Depths"] = { minLevel = 47, maxLevel = 61 },
    ["Dire Maul - East"] = { minLevel = 36, maxLevel = 46 },
    ["Dire Maul - West"] = { minLevel = 39, maxLevel = 49 },
    ["Dire Maul - North"] = { minLevel = 42, maxLevel = 52 },
    ["Dire Maul"] = { minLevel = 36, maxLevel = 52 },
    ["Stratholme - Main Gate"] = { minLevel = 42, maxLevel = 52 },
    ["Stratholme - Service Entrance"] = { minLevel = 46, maxLevel = 56 },
    ["Stratholme"] = { minLevel = 42, maxLevel = 56 },
}

-- Known boss NPC IDs used for boss-only debug output
addon.DUNGEON_DEBUG_BOSSES = {}

for npcId, _ in pairs(addon.DUNGEON_FINAL_BOSSES) do
    addon.DUNGEON_DEBUG_BOSSES[npcId] = true
end

-- Extra non-final bosses for low-level instances commonly used in tests
-- The Stockade
addon.DUNGEON_DEBUG_BOSSES[1663] = true -- Dextren Ward
-- Ragefire Chasm
addon.DUNGEON_DEBUG_BOSSES[11517] = true -- Oggleflint
addon.DUNGEON_DEBUG_BOSSES[11518] = true -- Jergosh the Invoker
addon.DUNGEON_DEBUG_BOSSES[11519] = true -- Bazzalan
-- The Deadmines
addon.DUNGEON_DEBUG_BOSSES[644] = true -- Rhahk'Zor
addon.DUNGEON_DEBUG_BOSSES[643] = true -- Sneed
addon.DUNGEON_DEBUG_BOSSES[1763] = true -- Gilnid
addon.DUNGEON_DEBUG_BOSSES[646] = true -- Mr. Smite
addon.DUNGEON_DEBUG_BOSSES[647] = true -- Captain Greenskin
-- Wailing Caverns
addon.DUNGEON_DEBUG_BOSSES[3653] = true -- Kresh
addon.DUNGEON_DEBUG_BOSSES[3669] = true -- Lord Cobrahn
addon.DUNGEON_DEBUG_BOSSES[3670] = true -- Lord Pythas
addon.DUNGEON_DEBUG_BOSSES[3671] = true -- Lady Anacondra
addon.DUNGEON_DEBUG_BOSSES[3672] = true -- Verdan the Everliving
addon.DUNGEON_DEBUG_BOSSES[3673] = true -- Lord Serpentis
addon.DUNGEON_DEBUG_BOSSES[3674] = true -- Skum
-- Maraudon
addon.DUNGEON_DEBUG_BOSSES[12225] = true -- Celebras the Cursed
addon.DUNGEON_DEBUG_BOSSES[13282] = true -- Noxxion
-- Dire Maul North
addon.DUNGEON_DEBUG_BOSSES[14324] = true -- Cho'Rush the Observer
