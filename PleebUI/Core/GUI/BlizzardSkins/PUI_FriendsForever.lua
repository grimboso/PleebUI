local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins

local layout = {
  Dropdown = { "FriendsFrame.FriendsTabHeader.StatusDropdown", "FriendsFrame.FriendsTabHeader.BattlenetFrame.ContactsMenuButton" },
  Button = { "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton",
    "FriendsFrame.FriendsTabHeader.BattlenetFrame.BroadcastFrame.UpdateButton",
    "FriendsFrame.FriendsTabHeader.BattlenetFrame.BroadcastFrame.CancelButton" },
  Panel = { "FriendsFrame.FriendsTabHeader.BattlenetFrame.BroadcastFrame",
    "FriendsFrame.FriendsTabHeader.BattlenetFrame.UnavailableInfoFrame" },
  Hide = { "FriendsFrame.FriendsTabHeader.BattlenetFrame.BroadcastFrame.Border" },
  EditBox = { "FriendsFrame.FriendsTabHeader.BattlenetFrame.BroadcastFrame.EditBox" },
  ScrollBar = { "FriendsListFrame.ScrollBar", "RecentAlliesFrame.List.ScrollBar" },
  Font = { "FriendsFrame.FriendsTabHeader.BattlenetFrame.Tag", "FriendsFrame.FriendsTabHeader.BattlenetFrame.UnavailableLabel",
    "FriendsFrame.FriendsTabHeader.BattlenetFrame.UnavailableInfoFrame.Label",
    "FriendsFrame.FriendsTabHeader.BattlenetFrame.UnavailableInfoFrame.Text", "FriendsListFrame.FriendsDisabledText" },
}

local function RepaintRow(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
  if row.CharacterData then RepaintRow(row.CharacterData) end
end

local function SkinRow(row)
  Skins.Hide(row.background)
  Skins.Hide(row.Background)
  Skins.Hide(row.BG)
  if row.AcceptButton then Skins.Button(row.AcceptButton) end
  if row.DeclineButton then Skins.Button(row.DeclineButton) end
  RepaintRow(row)
end

local function PaintFriends(frame)
  Skins.Shell(frame)
  Skins.WindowTitle(frame, FriendsFrameTitleText, Skins.Surface(frame))
  Skins.Apply(_G, layout)
end

Skins.Register("Blizzard_FriendsFrame", "FriendsFrame", {
  label = "Friends", category = "Windows",
  install = function(frame)
    PaintFriends(frame)
    local tabs = frame.FriendsTabHeader.TabSystem
    Skins.TabSystem(tabs)
    Skins.Hook(tabs, "AddTab", function() Skins.TabSystem(tabs) end)
    Skins.ScrollRows(FriendsListFrame.ScrollBox, SkinRow, RepaintRow)
    Skins.ScrollRows(RecentAlliesFrame.List.ScrollBox, SkinRow, RepaintRow)
    local edit = frame.FriendsTabHeader.BattlenetFrame.BroadcastFrame.EditBox
    for _, region in ipairs({ edit:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
  end,
  onTheme = PaintFriends,
})

local function PaintIgnore(frame)
  Skins.Shell(frame)
  Skins.Button(frame.UnignorePlayerButton)
  Skins.ScrollBar(frame.ScrollBar)
end

Skins.Register("Blizzard_FriendsFrame", "FriendsFrame.IgnoreListWindow", {
  manageControls = false,
  install = function(frame)
    PaintIgnore(frame)
    Skins.ScrollRows(frame.ScrollBox, SkinRow, RepaintRow)
  end,
  onTheme = PaintIgnore,
})

local function PaintFriendsFriends(frame)
  Skins.Panel(frame)
  Skins.Texts(frame)
  Skins.Panel(frame.ScrollFrameBorder)
  Skins.Dropdown(frame.FriendsDropdown)
  Skins.Button(frame.SendRequestButton)
  Skins.Button(frame.CloseButton)
  Skins.ScrollBar(frame.ScrollBar)
end

Skins.Register("Blizzard_FriendsFrame", "FriendsFriendsFrame", {
  manageControls = false,
  install = function(frame)
    PaintFriendsFriends(frame)
    Skins.ScrollRows(frame.ScrollBox, SkinRow, RepaintRow)
  end,
  onTheme = PaintFriendsFriends,
})

local addFriendLayout = {
  Button = { "InfoFrame.OkayButton", "EntryFrame.EditBoxContainer.AcceptButton", "EntryFrame.EditBoxContainer.CancelButton" },
  EditBox = { "EntryFrame.EditBoxContainer.NameEditBox" },
  Texts = { "InfoFrame.InfoContainer.LeftTextContainer", "InfoFrame.InfoContainer.RightTextContainer",
    "EntryFrame.TitleContainer", "EntryFrame.OptionsContainer", "EntryFrame.OptionsContainer.LeftTextContainer",
    "EntryFrame.OptionsContainer.RightTextContainer", "EntryFrame.EditBoxContainer" },
}

local function PaintAddFriend(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, addFriendLayout)
  Skins.Hide(AddFriendNameEditBoxMiddle)
end

Skins.Register("Blizzard_AddFriend", "AddFriendFrame", {
  manageControls = false, install = PaintAddFriend, onTheme = PaintAddFriend,
})

local function PaintInvite(frame)
  Skins.Panel(frame)
  Skins.Texts(frame)
  Skins.Button(frame.SendButton)
  Skins.Button(frame.CancelButton)
end

Skins.Register("Blizzard_AddFriend", "BattleNetInviteFrame", {
  manageControls = false, install = PaintInvite, onTheme = PaintInvite,
})
