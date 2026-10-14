local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Chrome = { "CommunitiesList", "GuildBenefitsFrame", "GuildDetailsFrame", "MemberList.ColumnDisplay",
    "CommunitiesList.InsetFrame", "Chat.InsetFrame", "MemberList.InsetFrame", "GuildBenefitsFrame.Perks",
    "GuildBenefitsFrame.Rewards", "GuildDetailsFrame.Info", "GuildDetailsFrame.News", "InvitationFrame.InsetFrame",
    "ClubFinderInvitationFrame.InsetFrame", "TicketFrame.InsetFrame" },
  Hide = { "CommunitiesList.FilligreeOverlay", "CommunitiesList.TopFiligree", "CommunitiesList.BottomFiligree",
    "MemberList.WatermarkFrame", "ChatEditBox.Mid" },
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

local function LayoutCommunities(frame)
  if not Skins.CanStyle() then return end
  local minimized = frame.MaximizeMinimizeFrame:IsMinimized()
  if issecretvalue(minimized) then return end
  local chat = frame.Chat
  if not minimized then
    chat:SetPoint("BOTTOMRIGHT", frame.MemberList, "BOTTOMLEFT", -32, 40)
    frame.StreamDropdown:ClearAllPoints()
    frame.StreamDropdown:SetPoint("BOTTOMLEFT", chat.MessageFrame, "TOPLEFT", 0, 8)
    frame.StreamDropdown:SetSize(160, 26)
  end
  chat.ScrollBar:ClearAllPoints()
  chat.ScrollBar:SetPoint("TOPLEFT", chat.MessageFrame, "TOPRIGHT", 4, 0)
  chat.ScrollBar:SetPoint("BOTTOMLEFT", chat.MessageFrame, "BOTTOMRIGHT", 4, 0)
  local edit = frame.ChatEditBox
  edit:ClearAllPoints()
  edit:SetPoint("TOPLEFT", chat.MessageFrame, "BOTTOMLEFT", 0, -6)
  edit:SetPoint("TOPRIGHT", chat.MessageFrame, "BOTTOMRIGHT", 0, -6)
  edit:SetHeight(minimized and 24 or 28)
  edit:SetTextInsets(8, 8, 0, 0)

  local offline = frame.MemberList.ShowOfflineButton
  local _, fontSize = offline.Text:GetFont()
  if not issecretvalue(fontSize) then
    local size = math.max(16, fontSize)
    offline:SetSize(size, size)
    offline:SetHitRectInsets(-4, -4, -4, -4)
    offline.Text:ClearAllPoints()
    offline.Text:SetPoint("LEFT", offline, "RIGHT", 6, 0)
  end
end

local function InstallPortrait(frame)
  local overlay = frame.PortraitOverlay
  overlay:SetAlpha(1)
  local portrait = overlay.Portrait
  portrait:RemoveMaskTexture(overlay.CircleMask)
  portrait:ClearAllPoints()
  portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
  portrait:SetSize(36, 36)
  for _, texture in ipairs({ overlay.TabardBackground, overlay.TabardBorder }) do
    texture:ClearAllPoints()
    texture:SetAllPoints(portrait)
  end
  overlay.TabardEmblem:ClearAllPoints()
  overlay.TabardEmblem:SetPoint("CENTER", portrait, "CENTER")
  overlay.TabardEmblem:SetSize(34, 38)
end

local function SkinCommunityRow(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.IconRing)
  Skins.Button(row, true)
  Skins.Selection(row.Selection)
  row.Selection:SetAllPoints(row)
  Skins.Font(row.Name)
  for _, method in ipairs({ "SetAddCommunity", "SetFindCommunity", "SetGuildFinder" }) do
    Skins.Hook(row, method, function(entry)
      if Skins.CanStyle() then SkinCommunityRow(entry) end
    end)
  end
end

local function SkinRewardRow(row)
  Skins.Hide(row.Background)
  Skins.Surface(row, true, true)
  Skins.Icon(row.Icon)
  Skins.Texts(row)
end

local function SkinMemberRow(row)
  Skins.Hide(row:GetNormalTexture())
  Skins.Surface(row, true, true)
  local highlight = row:GetHighlightTexture()
  highlight:SetColorTexture(1, 1, 1, 0.08)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
  ns.Theme.ApplyFont(row.NameFrame.Name, "body")
  if row.ProfessionHeader then
    Skins.Hide(row.ProfessionHeader.Left)
    Skins.Hide(row.ProfessionHeader.Middle)
    Skins.Hide(row.ProfessionHeader.Right)
    ns.Theme.ApplyFont(row.ProfessionHeader.Name, "body")
  end
end

local function SkinNewsRow(row)
  Skins.Hide(row.header)
  Skins.Surface(row, true, true)
  Skins.Texts(row)
end

local function RefreshCommunities(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, layout)
  InstallPortrait(frame)
  LayoutCommunities(frame)
  Skins.Hook(frame, "SetDisplayMode", LayoutCommunities)
  Skins.Hook(frame.MaximizeMinimizeFrame, "Maximize", function() LayoutCommunities(frame) end)
  Skins.Hook(frame.MaximizeMinimizeFrame, "Minimize", function() LayoutCommunities(frame) end)
  for _, pane in ipairs({ frame.CommunitiesList, frame.GuildBenefitsFrame, frame.GuildBenefitsFrame.Perks,
    frame.GuildDetailsFrame, frame.MemberList.ColumnDisplay }) do
    for _, region in ipairs({ pane:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Surface(pane, false, true)
  end
  for _, pane in ipairs({ frame.Chat.MessageFrame, frame.GuildBenefitsFrame.Perks, frame.GuildBenefitsFrame.Rewards }) do
    Skins.Surface(pane, true, true)
  end

  local faction = frame.GuildBenefitsFrame.FactionFrame
  local bar = faction.Bar

  for _, texture in ipairs({ bar.Left, bar.Middle, bar.Right, bar.BG, bar.Shadow }) do
    Skins.Hide(texture)
  end

  Skins.Surface(bar, true)

  bar.Progress:ClearAllPoints()
  bar.Progress:SetPoint("LEFT", bar, "LEFT", 1, 0)
  bar.Progress:SetHeight(bar:GetHeight() - 2)
  bar.Progress:SetTexture(ns.Theme.GetBarTexture())

  local accent = ns.Theme.GetColors().accent
  bar.Progress:SetVertexColor(accent[1], accent[2], accent[3], accent[4])

  Skins.Font(faction.Label)
  Skins.Font(bar.Label)

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
  Skins.ScrollRows(frame.GuildDetailsFrame.News.ScrollBox, SkinNewsRow)
end

Skins.Register("Blizzard_Communities", "CommunitiesFrame", RefreshCommunities)
