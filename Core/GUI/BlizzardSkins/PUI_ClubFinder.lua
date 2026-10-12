local _, ns = ...
local Skins = ns.BlizzardSkins

local function SkinClubCard(card)
  Skins.Chrome(card)
  Skins.Surface(card, true)
  Skins.Texts(card)
  Skins.Hide(card.CardBackground)
  Skins.Hide(card.GuildBannerBackground)
  Skins.Hide(card.GuildBannerShadow)
  Skins.Hide(card.GuildBannerBorder)
  Skins.Hide(card.LogoBorder)
  if card.CommunityLogo then
    card.CommunityLogo:RemoveMaskTexture(card.CircleMask)
    Skins.Icon(card.CommunityLogo)
  end
  if card.RequestJoin:IsObjectType("Button") then Skins.Button(card.RequestJoin) end
  if card:IsObjectType("Button") then Skins.IconButton(card) end
end

local function RefreshClubFinder(frame)
  Skins.Panel(frame)
  Skins.Apply(frame, {
    Panel = { "InsetFrame", "OptionsList", "GuildCards", "CommunityCards", "PendingGuildCards", "PendingCommunityCards" },
    EditBox = { "OptionsList.SearchBox" },
    Dropdown = { "OptionsList.ClubFilterDropdown", "OptionsList.ClubSizeDropdown", "OptionsList.SortByDropdown" },
    Button = { "OptionsList.Search" },
    ScrollBar = { "CommunityCards.ScrollBar", "PendingCommunityCards.ScrollBar" },
    Tab = { "ClubFinderSearchTab", "ClubFinderPendingTab" },
  })
  for _, key in ipairs({ "GuildCards", "PendingGuildCards" }) do
    local cards = frame[key]
    Skins.Arrow(cards.PreviousPage, "<")
    Skins.Arrow(cards.NextPage, ">")
    for _, cardKey in ipairs({ "FirstCard", "SecondCard", "ThirdCard" }) do SkinClubCard(cards[cardKey]) end
  end
  Skins.ScrollRows(frame.CommunityCards.ScrollBox, SkinClubCard)
  Skins.ScrollRows(frame.PendingCommunityCards.ScrollBox, SkinClubCard)
end

Skins.Register("Blizzard_Communities", "CommunitiesFrame.GuildFinderFrame", RefreshClubFinder)
Skins.Register("Blizzard_Communities", "CommunitiesFrame.CommunityFinderFrame", RefreshClubFinder)
