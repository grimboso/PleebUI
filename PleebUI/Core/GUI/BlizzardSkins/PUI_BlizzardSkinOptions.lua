local _, ns = ...
local Addon = ns.Addon
local Options = {}
ns.BlizzardSkinOptions = Options
local registered = {}
local sessionSettings
local labels = {
  ["InspectRecipeFrame.SchematicForm.QualityDialog"] = { "Inspect recipe: reagent quality", "Professions" },
  ["ContainerFrameCombinedBags"] = { "Bags", "Bags" },
  ["ContainerFrame6"] = { "Reagent bag", "Bags" },
  ["AchievementFrame"] = { "Achievements", "Windows" },
  ["AuctionHouseFrame"] = { "Auction House", "Auction house" },
  ["AuctionHouseFrame.AuctionsFrame"] = { "Auction house: Auctions", "Auction house" },
  ["AuctionHouseFrame.BrowseResultsFrame"] = { "Auction house: Browse Results", "Auction house" },
  ["AuctionHouseFrame.BuyDialog"] = { "Auction house: Buy", "Auction house" },
  ["AuctionHouseFrame.CommoditiesBuyFrame"] = { "Auction house: Commodities Buy", "Auction house" },
  ["AuctionHouseFrame.CommoditiesSellFrame"] = { "Auction house: Commodities Sell", "Auction house" },
  ["AuctionHouseFrame.CommoditiesSellList"] = { "Auction house: Commodities Sell List", "Auction house" },
  ["AuctionHouseFrame.ItemBuyFrame"] = { "Auction house: Item Buy", "Auction house" },
  ["AuctionHouseFrame.ItemSellFrame"] = { "Auction house: Item Sell", "Auction house" },
  ["AuctionHouseFrame.ItemSellList"] = { "Auction house: Item Sell List", "Auction house" },
  ["AuctionHouseFrame.WoWTokenResults"] = { "Auction house: WoWToken Results", "Auction house" },
  ["AuctionHouseFrame.WoWTokenResults.GameTimeTutorial"] = { "Auction house: Game time Tutorial", "Auction house" },
  ["AuctionHouseFrame.WoWTokenSellFrame"] = { "Auction house: WoWToken Sell", "Auction house" },
  ["AuctionHouseMultisellProgressFrame"] = { "Auction selling progress", "Auction house" },
  ["ChallengesFrame"] = { "Mythic+", "Groups & loot" },
  ["ChallengesKeystoneFrame"] = { "Keystone", "Groups & loot" },
  ["CharacterFrame"] = { "Character", "Character & items" },
  ["ClassTrainerFrame"] = { "Trainer", "Windows" },
  ["CollectionsJournal"] = { "Collections", "Windows" },
  ["CommunitiesAvatarPickerDialog"] = { "Communities Avatar Picker", "Guild & Communities" },
  ["CommunitiesFrame"] = { "Guild & Communities", "Guild & Communities" },
  ["CommunitiesFrame.CommunityFinderFrame"] = { "Guild & Communities: Community Finder", "Guild & Communities" },
  ["CommunitiesFrame.EditStreamDialog"] = { "Guild & Communities: Edit Stream", "Guild & Communities" },
  ["CommunitiesFrame.GuildFinderFrame"] = { "Guild & Communities: Guild Finder", "Guild & Communities" },
  ["CommunitiesFrame.GuildMemberDetailFrame"] = { "Guild & Communities: Guild Member Detail", "Guild & Communities" },
  ["CommunitiesFrame.NotificationSettingsDialog"] = { "Guild & Communities: Notification Settings", "Guild & Communities" },
  ["CommunitiesFrame.RecruitmentDialog"] = { "Guild & Communities: Recruitment", "Guild & Communities" },
  ["CommunitiesGuildLogFrame"] = { "Guild log", "Guild & Communities" },
  ["CommunitiesGuildTextEditFrame"] = { "Guild text editor", "Guild & Communities" },
  ["CommunitiesSettingsDialog"] = { "Communities Settings", "Guild & Communities" },
  ["CurrencyTransferLog"] = { "Currency transfer history", "Character & items" },
  ["CurrencyTransferMenu"] = { "Currency transfer", "Character & items" },
  ["DressUpFrame"] = { "Dressing room", "Windows" },
  ["EncounterJournal"] = { "Adventure guide", "Windows" },
  ["GameMenuFrame"] = { "Game menu", "System" },
  ["GearManagerPopupFrame"] = { "Equipment set icon picker", "Character & items" },
  ["GossipFrame"] = { "NPC conversations", "Windows" },
  ["GroupLootFrame1"] = { "Loot roll 1", "Groups & loot" },
  ["GroupLootFrame2"] = { "Loot roll 2", "Groups & loot" },
  ["GroupLootFrame3"] = { "Loot roll 3", "Groups & loot" },
  ["GroupLootFrame4"] = { "Loot roll 4", "Groups & loot" },
  ["GroupLootHistoryFrame"] = { "Loot history", "Groups & loot" },
  ["InspectFrame"] = { "Inspect", "Character & items" },
  ["InspectRecipeFrame"] = { "Inspect recipe", "Professions" },
  ["ItemInteractionFrame"] = { "Catalyst and item interactions", "Windows" },
  ["ItemSocketingFrame"] = { "Gem socketing", "Windows" },
  ["ItemUpgradeFrame"] = { "Item Upgrade", "Windows" },
  ["LFDRoleCheckPopup"] = { "Dungeon role check", "Groups & loot" },
  ["LFGDungeonReadyDialog"] = { "Enter dungeon", "Groups & loot" },
  ["LFGDungeonReadyStatus"] = { "Dungeon ready status", "Groups & loot" },
  ["LFGInvitePopup"] = { "Dungeon invitation", "Groups & loot" },
  ["LFGListApplicationDialog"] = { "Group application", "Groups & loot" },
  ["LFGListInviteDialog"] = { "Group invitation", "Groups & loot" },
  ["LFGReadyCheckPopup"] = { "Dungeon ready check", "Groups & loot" },
  ["LootFrame"] = { "Loot", "Windows" },
  ["MacroPopupFrame"] = { "Macro icon picker", "System" },
  ["MailFrame"] = { "Mail", "Windows" },
  ["MerchantFrame"] = { "Merchant", "Windows" },
  ["OpenMailFrame"] = { "Read mail", "Windows" },
  ["PVEFrame"] = { "Dungeons & Raids", "Groups & loot" },
  ["PVPQueueFrame"] = { "Player vs. Player", "Groups & loot" },
  ["PVPQueueFrame.NewSeasonPopup"] = { "PvP: New Season", "Groups & loot" },
  ["PVPReadyDialog"] = { "PvP ready check", "Groups & loot" },
  ["PlayerSpellsFrame"] = { "Spellbook and player spells", "Character & items" },
  ["PlayerSpellsFrame.TalentsFrame"] = { "Talents", "Character & items" },
  ["ProfessionsBookFrame"] = { "Professions book", "Professions" },
  ["ProfessionsCustomerOrdersFrame"] = { "Professions Customer Orders", "Professions" },
  ["ProfessionsCustomerOrdersFrame.Form"] = { "Crafting orders: Form", "Professions" },
  ["ProfessionsCustomerOrdersFrame.Form.CurrentListings"] = { "Crafting orders: Current Listings", "Professions" },
  ["ProfessionsCustomerOrdersFrame.Form.QualityDialog"] = { "Crafting orders: Quality", "Professions" },
  ["ProfessionsFrame"] = { "Professions", "Professions" },
  ["ProfessionsFrame.CraftingPage.CraftingOutputLog"] = { "Professions: Crafting Output Log", "Professions" },
  ["ProfessionsFrame.CraftingPage.GuildFrame"] = { "Professions: Guild", "Professions" },
  ["ProfessionsFrame.CraftingPage.MinimizedSearchResults"] = { "Professions: Minimized Search Results", "Professions" },
  ["ProfessionsFrame.CraftingPage.SchematicForm.QualityDialog"] = { "Professions: Quality", "Professions" },
  ["ProfessionsFrame.OrdersPage"] = { "Professions: Orders Page", "Professions" },
  ["ProfessionsFrame.OrdersPage.OrderView.CraftingOutputLog"] = { "Professions: Crafting Output Log", "Professions" },
  ["ProfessionsFrame.OrdersPage.OrderView.DeclineOrderDialog"] = { "Professions: Decline Order", "Professions" },
  ["ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.QualityDialog"] = { "Professions: Quality", "Professions" },
  ["ProfessionsFrame.SpecPage"] = { "Professions: Spec Page", "Professions" },
  ["QuestFrame"] = { "NPC quests", "Windows" },
  ["QuestMapFrame"] = { "Quest log", "Windows" },
  ["QueueStatusFrame"] = { "Queue Status", "Groups & loot" },
  ["ReadyCheckListenerFrame"] = { "Group ready check", "Groups & loot" },
  ["ReputationFrame"] = { "Reputation", "Character & items" },
  ["ReputationFrame.ReputationDetailFrame"] = { "Reputation details", "Character & items" },
  ["SideDressUpFrame"] = { "Side dressing room", "Windows" },
  ["StackSplitFrame"] = { "Stack Split", "Windows" },
  ["StaticPopups"] = { "Popups", "System" },
  ["TokenFrame"] = { "Currency", "Character & items" },
  ["TokenFramePopup"] = { "Currency options", "Character & items" },
  ["TradeFrame"] = { "Trade", "Windows" },
  ["TransmogFrame"] = { "Transmogrification", "Windows" },
  ["WeeklyRewardExpirationWarningDialog"] = { "Great Vault expiry warning", "Windows" },
  ["WeeklyRewardsFrame"] = { "Great Vault", "Windows" },
  ["WorldMapFrame"] = { "World map", "Windows" },
}

hooksecurefunc(Addon, "EnsureSchema", function()
  local profile = Addon.db.profile.pui
  if profile.blizzardSkins == nil then profile.blizzardSkins = {} end
end)

local function GetSettings()
  return Addon.db.profile.pui.blizzardSkins
end

function Options.Register(name, label, category)
  local entry = labels[name]
  registered[name] = { label = label or entry[1], category = category or entry[2] }
end

function Options.IsEnabled(name)
  if not sessionSettings then
    sessionSettings = {}
    for key, value in pairs(GetSettings()) do sessionSettings[key] = value end
  end
  if sessionSettings.enabled == false then return false end
  if name == "QuestMapFrame" and sessionSettings.WorldMapFrame == false then return false end
  local path = ""
  for key in name:gmatch("[^.]+") do
    path = path == "" and key or path .. "." .. key
    if sessionSettings[path] == false then return false end
  end
  return true
end

function Options:GetOptions()
  local settings = {
    type = "group", name = "Blizzard windows", childGroups = "tree",
    args = {
      description = {
        type = "description", order = 2,
        name = "Choose which game windows use PleebUI skins. Changes, including profile changes, take effect after a reload. Turning off a parent window also turns off its embedded panes.",
      },
      enabled = {
        type = "toggle", name = "Skin Blizzard windows", order = 3, width = "full",
        get = function() return GetSettings().enabled ~= false end,
        set = function(_, value) GetSettings().enabled = value end,
      },
      reload = {
        type = "execute", name = "Reload to apply", order = 4,
        disabled = function() return InCombatLockdown() end,
        func = function() if not InCombatLockdown() then ReloadUI() end end,
      },
    },
  }
  local groups = {}
  for name, entry in pairs(registered) do
    local category = entry.category
    if not groups[category] then
      groups[category] = { type = "group", name = category, inline = false, args = {}, order = 10 }
      settings.args[category] = groups[category]
    end
    groups[category].args[name] = {
      type = "toggle", name = entry.label,
      get = function() return GetSettings()[name] ~= false end,
      set = function(_, value) GetSettings()[name] = value end,
      disabled = function() return GetSettings().enabled == false end,
    }
  end
  return settings
end

Options.Register("CharacterFrame")
Options.Register("GameMenuFrame")
Options.Register("StaticPopups")
