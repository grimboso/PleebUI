local _, ns = ...
local Skins = ns.BlizzardSkins

local function SkinClubCard(card)
  Skins.Chrome(card)
  Skins.Surface(card, true)
  Skins.Texts(card)
end

local function RefreshClubFinder(frame)
  Skins.Panel(frame)
  Skins.Apply(frame, {
    Panel = { "InsetFrame", "OptionsList", "GuildCards", "CommunityCards", "PendingGuildCards", "PendingCommunityCards" },
    EditBox = { "OptionsList.SearchBox" },
    Dropdown = { "OptionsList.ClubFilterDropdown", "OptionsList.ClubSizeDropdown", "OptionsList.SortByDropdown" },
    Button = { "OptionsList.Search", "GuildCards.PreviousPage", "GuildCards.NextPage", "PendingGuildCards.PreviousPage", "PendingGuildCards.NextPage" },
    ScrollBar = { "CommunityCards.ScrollBar", "PendingCommunityCards.ScrollBar" },
    Tab = { "ClubFinderSearchTab", "ClubFinderPendingTab" },
  })
  for _, key in ipairs({ "GuildCards", "PendingGuildCards" }) do
    local cards = frame[key]
    for _, cardKey in ipairs({ "FirstCard", "SecondCard", "ThirdCard" }) do SkinClubCard(cards[cardKey]) end
  end
  Skins.ScrollRows(frame.CommunityCards.ScrollBox, SkinClubCard)
  Skins.ScrollRows(frame.PendingCommunityCards.ScrollBox, SkinClubCard)
end

Skins.Register("Blizzard_Communities", "CommunitiesFrame.GuildFinderFrame", RefreshClubFinder)
Skins.Register("Blizzard_Communities", "CommunitiesFrame.CommunityFinderFrame", RefreshClubFinder)
