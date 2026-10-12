local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  StripRegions = { "CommunitiesList", "GuildBenefitsFrame", "GuildDetailsFrame", "MemberList.ColumnDisplay" },
  Panel = { "CommunitiesList.InsetFrame", "Chat.InsetFrame", "MemberList.InsetFrame", "GuildBenefitsFrame.Perks",
    "GuildBenefitsFrame.Rewards", "GuildDetailsFrame.Info", "GuildDetailsFrame.News", "InvitationFrame.InsetFrame",
    "ClubFinderInvitationFrame.InsetFrame", "TicketFrame.InsetFrame" },
  Hide = { "PortraitOverlay", "CommunitiesList.FilligreeOverlay", "CommunitiesList.TopFiligree", "CommunitiesList.BottomFiligree",
    "MemberList.WatermarkFrame" },
  Button = { "InviteButton", "GuildLogButton", "CommunitiesControlFrame.GuildControlButton",
    "CommunitiesControlFrame.GuildRecruitmentButton", "CommunitiesControlFrame.CommunitiesSettingsButton",
    "InvitationFrame.AcceptButton", "InvitationFrame.DeclineButton", "ClubFinderInvitationFrame.AcceptButton",
    "ClubFinderInvitationFrame.DeclineButton", "ClubFinderInvitationFrame.ApplyButton", "TicketFrame.AcceptButton", "TicketFrame.DeclineButton",
    "GuildDetailsFrame.Info.EditMOTDButton", "GuildDetailsFrame.Info.EditDetailsButton", "GuildDetailsFrame.News.SetFiltersButton" },
  EditBox = { "ChatEditBox" },
  Dropdown = { "StreamDropdown", "CommunitiesListDropdown", "GuildMemberListDropdown", "CommunityMemberListDropdown" },
  CheckBox = { "MemberList.ShowOfflineButton" },
  ScrollBar = { "CommunitiesList.ScrollBar", "Chat.ScrollBar", "MemberList.ScrollBar", "GuildBenefitsFrame.Perks.ScrollBar",
    "GuildBenefitsFrame.Rewards.ScrollBar", "GuildDetailsFrame.News.ScrollBar", "GuildDetailsFrame.Info.DetailsFrame.ScrollBar" },
}

local function SkinCommunityRow(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.IconRing)
  row.Icon:RemoveMaskTexture(row.CircleMask)
  Skins.IconButton(row, row.Icon)
  Skins.Selection(row.Selection)
  Skins.Font(row.Name)
  for _, method in ipairs({ "SetAddCommunity", "SetFindCommunity", "SetGuildFinder" }) do
    Skins.Hook(row, method, function(entry)
      if Skins.CanStyle() then SkinCommunityRow(entry) end
    end)
  end
end

local function SkinRewardRow(row)
  Skins.Surface(row, true)
  Skins.Icon(row.Icon)
  Skins.Texts(row)
end

local function SkinMemberRow(row)
  Skins.Surface(row, true)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function RefreshCommunities(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, layout)
  for _, key in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
    local tab = frame[key]
    for _, region in ipairs({ tab:GetRegions() }) do
      if region:IsObjectType("Texture") and region ~= tab.Icon and region ~= tab.IconOverlay
        and region ~= tab:GetCheckedTexture() and region ~= tab:GetHighlightTexture() then
        Skins.Hide(region)
      end
    end
    Skins.IconButton(tab, tab.Icon)
    Skins.Selection(tab:GetCheckedTexture())
  end
  Skins.ScrollRows(frame.CommunitiesList.ScrollBox, SkinCommunityRow)
  Skins.ScrollRows(frame.GuildBenefitsFrame.Perks.ScrollBox, SkinRewardRow)
  Skins.ScrollRows(frame.GuildBenefitsFrame.Rewards.ScrollBox, SkinRewardRow)
  Skins.ScrollRows(frame.MemberList.ScrollBox, SkinMemberRow)
  Skins.ScrollRows(frame.GuildDetailsFrame.News.ScrollBox, SkinRewardRow)
end

Skins.Register("Blizzard_Communities", "CommunitiesFrame", RefreshCommunities)
