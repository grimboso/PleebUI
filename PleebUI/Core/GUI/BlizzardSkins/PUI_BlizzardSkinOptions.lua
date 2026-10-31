local _, ns = ...
local Addon = ns.Addon
local Options = {}
ns.BlizzardSkinOptions = Options
local registered = {}
local owners = {}
local sessionSettings
local families = {
  { "ContainerFrameCombinedBags", "Bags", "Bags", {
    "ContainerFrame6", "StackSplitFrame",
  } },
  { "BankFrame", "Bank and Warband bank", "Bags", {
    "BankFrame.BankPanel.TabSettingsMenu", "BankCleanUpConfirmationPopup",
  } },
  { "CharacterFrame", "Character sheet", "Character & items", {
    "GearManagerPopupFrame", "ReputationFrame", "ReputationFrame.ReputationDetailFrame",
    "TokenFrame", "TokenFramePopup", "CurrencyTransferMenu", "CurrencyTransferLog",
    "ItemInteractionFrame", "ItemSocketingFrame", "ItemUpgradeFrame", "DressUpFrame",
    "SideDressUpFrame", "TransmogFrame",
  } },
  { "InspectFrame", "Inspect", "Character & items" },
  { "PVEFrame", "Dungeons and raids", "Groups & loot", {
    "LFDRoleCheckPopup", "LFGDungeonReadyDialog", "LFGDungeonReadyStatus", "LFGInvitePopup",
    "LFGListApplicationDialog", "LFGListInviteDialog", "LFGReadyCheckPopup", "ReadyCheckListenerFrame",
    "QueueStatusFrame",
  } },
  { "PVPQueueFrame", "Player vs. Player", "Groups & loot", {
    "PVPQueueFrame.NewSeasonPopup", "PVPReadyDialog",
  } },
  { "ChallengesFrame", "Mythic+", "Groups & loot", { "ChallengesKeystoneFrame" } },
  { "LootFrame", "Loot", "Groups & loot", {
    "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4", "GroupLootHistoryFrame",
  } },
  { "WeeklyRewardsFrame", "Great Vault", "Groups & loot", { "WeeklyRewardExpirationWarningDialog" } },
  { "AchievementFrame", "Achievements", "Windows" },
  { "AuctionHouseFrame", "Auction house", "Windows", {
    "AuctionHouseFrame.AuctionsFrame", "AuctionHouseFrame.BrowseResultsFrame", "AuctionHouseFrame.BuyDialog",
    "AuctionHouseFrame.CommoditiesBuyFrame", "AuctionHouseFrame.CommoditiesSellFrame", "AuctionHouseFrame.CommoditiesSellList",
    "AuctionHouseFrame.ItemBuyFrame", "AuctionHouseFrame.ItemSellFrame", "AuctionHouseFrame.ItemSellList",
    "AuctionHouseFrame.WoWTokenResults", "AuctionHouseFrame.WoWTokenResults.GameTimeTutorial",
    "AuctionHouseFrame.WoWTokenSellFrame", "AuctionHouseMultisellProgressFrame",
  } },
  { "ClassTrainerFrame", "Trainer", "Windows" },
  { "CollectionsJournal", "Collections", "Windows" },
  { "CommunitiesFrame", "Guild and communities", "Windows", {
    "CommunitiesFrame.CommunityFinderFrame", "CommunitiesFrame.EditStreamDialog", "CommunitiesFrame.GuildFinderFrame",
    "CommunitiesFrame.GuildMemberDetailFrame", "CommunitiesFrame.NotificationSettingsDialog", "CommunitiesFrame.RecruitmentDialog",
    "CommunitiesAvatarPickerDialog", "CommunitiesGuildLogFrame", "CommunitiesGuildTextEditFrame", "CommunitiesSettingsDialog",
    "GuildBankFrame", "GuildBankPopupFrame",
  } },
  { "DelvesCompanionConfigurationFrame", "Delves", "Windows", {
    "DelvesCompanionAbilityListFrame", "DelvesDifficultyPickerFrame",
  } },
  { "EncounterJournal", "Adventure guide", "Windows" },
  { "GossipFrame", "NPC conversations", "Windows" },
  { "MailFrame", "Mail", "Windows", { "OpenMailFrame" } },
  { "MerchantFrame", "Merchant", "Windows" },
  { "Notifications", "Notifications", "Windows", {
    "AchievementNotifications", "AchievementProgressNotifications", "MountNotifications", "PetNotifications",
    "ToyNotifications", "CosmeticNotifications", "WarbandSceneNotifications", "HonorNotifications",
    "DungeonNotifications", "LootUpgradeNotifications", "LootNotifications", "RecipeNotifications",
    "ProfessionUnlockNotifications", "QuestNotifications", "MoneyNotifications", "DelvesToastFrame",
  } },
  { "ObjectiveTrackerFrame", "Objective tracker", "Windows" },
  { "PlayerSpellsFrame", "Spellbook and talents", "Windows", { "PlayerSpellsFrame.TalentsFrame" } },
  { "ProfessionsFrame", "Professions", "Windows", {
    "ProfessionsBookFrame", "InspectRecipeFrame", "InspectRecipeFrame.SchematicForm.QualityDialog",
    "ProfessionsCustomerOrdersFrame", "ProfessionsCustomerOrdersFrame.Form", "ProfessionsCustomerOrdersFrame.Form.CurrentListings",
    "ProfessionsCustomerOrdersFrame.Form.QualityDialog", "ProfessionsFrame.CraftingPage.CraftingOutputLog",
    "ProfessionsFrame.CraftingPage.GuildFrame", "ProfessionsFrame.CraftingPage.MinimizedSearchResults",
    "ProfessionsFrame.CraftingPage.SchematicForm.QualityDialog", "ProfessionsFrame.OrdersPage",
    "ProfessionsFrame.OrdersPage.OrderView.CraftingOutputLog", "ProfessionsFrame.OrdersPage.OrderView.DeclineOrderDialog",
    "ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.QualityDialog", "ProfessionsFrame.SpecPage",
  } },
  { "QuestFrame", "NPC quests", "Windows" },
  { "TradeFrame", "Trade", "Windows" },
  { "WorldMapFrame", "World map and quest log", "Windows", { "QuestMapFrame" } },
  { "AddonList", "AddOns", "System" },
  { "GameMenuFrame", "Game menu", "System" },
  { "MacroFrame", "Macros", "System", { "MacroPopupFrame" } },
  { "PlayerChoiceFrame", "Player choices", "System" },
  { "StaticPopups", "Popups", "System" },
  { "TimeManagerFrame", "Clock, alarm and stopwatch", "System", { "StopwatchFrame" } },
}
local labels = {}
for _, family in ipairs(families) do
  local owner = family[1]
  labels[owner] = { label = family[2], category = family[3] }
  owners[owner] = owner
  for _, name in ipairs(family[4] or {}) do owners[name] = owner end
end
local categoryOwners = {
  ["Auction house"] = "AuctionHouseFrame",
  ["Guild & Communities"] = "CommunitiesFrame",
  ["Delves"] = "DelvesCompanionConfigurationFrame",
  ["Notifications"] = "Notifications",
  ["Professions"] = "ProfessionsFrame",
}
local categoryOrder = { "Windows", "Character & items", "Bags", "Groups & loot", "System" }

hooksecurefunc(Addon, "EnsureSchema", function()
  local profile = Addon.db.profile.pui
  if profile.blizzardSkins == nil then profile.blizzardSkins = {} end
end)

local function GetLegacyWindowEnabled(settings, name)
  if name == "QuestMapFrame" and settings.WorldMapFrame == false then return false end
  local path = ""
  for key in name:gmatch("[^.]+") do
    path = path == "" and key or path .. "." .. key
    if settings[path] == false then return false end
  end
  return true
end

local function GetSettings()
  local settings = Addon.db.profile.pui.blizzardSkins
  if settings.groupedTogglesVersion ~= 2 then
    local windows = {}
    for name, owner in pairs(owners) do
      if name ~= owner then
        if settings.groupedTogglesVersion == 1 then
          windows[name] = settings[owner] ~= false
        else
          windows[name] = GetLegacyWindowEnabled(settings, name)
        end
      end
    end
    for name, enabled in pairs(windows) do settings[name] = enabled end
    settings.groupedTogglesVersion = 2
  end
  return settings
end

local function IsWindowEnabled(settings, name)
  local enabled = settings[name]
  if enabled == nil then enabled = settings[owners[name] or name] end
  return enabled ~= false
end

local function HasMixedFamilySettings(settings, owner)
  local enabled = IsWindowEnabled(settings, owner)
  for name, family in pairs(owners) do
    if family == owner and IsWindowEnabled(settings, name) ~= enabled then return true end
  end
  return false
end

local function SetFamilyEnabled(owner, enabled)
  local settings = GetSettings()
  settings[owner] = enabled
  for name, family in pairs(owners) do
    if family == owner and name ~= owner then settings[name] = nil end
  end
end

function Options.Register(name, label, category)
  local owner = owners[name] or categoryOwners[category] or name
  owners[name] = owner
  local entry = labels[owner]
  registered[owner] = entry or { label = label, category = category }
end

function Options.IsEnabled(name)
  if not sessionSettings then
    sessionSettings = {}
    for key, value in pairs(GetSettings()) do sessionSettings[key] = value end
  end
  return sessionSettings.enabled ~= false and IsWindowEnabled(sessionSettings, name)
end

function Options:GetOptions()
  local settings = {
    type = "group", name = "Blizzard windows",
    args = {
      description = {
        type = "description", order = 2,
        name = "Choose which game windows use PleebUI skins. Each toggle includes its related dialogs. Changes, including profile changes, take effect after a reload.",
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
  for index, category in ipairs(categoryOrder) do
    local group = { type = "group", name = category, inline = true, args = {}, order = index + 10 }
    settings.args[category] = group
    for name, entry in pairs(registered) do
      if entry.category == category then
        group.args[name] = {
          type = "toggle",
          name = function()
            return entry.label .. (HasMixedFamilySettings(GetSettings(), name) and " (mixed)" or "")
          end,
          desc = "Changing this toggle applies to every window in the group. Mixed groups keep your existing window choices until you change them.",
          get = function() return GetSettings()[name] ~= false end,
          set = function(_, value) SetFamilyEnabled(name, value) end,
          disabled = function() return GetSettings().enabled == false end,
        }
      end
    end
  end
  return settings
end

Options.Register("CharacterFrame")
Options.Register("GameMenuFrame")
Options.Register("StaticPopups")
