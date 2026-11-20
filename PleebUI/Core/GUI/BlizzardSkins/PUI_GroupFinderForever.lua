local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins

local function RepaintRow(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
  if row.NameButton then ns.Theme.ApplyFont(row.NameButton.Name, "body") end
  if row.DataDisplay then RepaintRow(row.DataDisplay) end
end

local function SkinRow(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.ResultBG)
  Skins.Surface(row, true)
  Skins.Selection(row.Selected)
  Skins.Selection(row.Highlight)
  if row.InviteButton then Skins.Button(row.InviteButton) end
  if row.DataDisplay then Skins.Button(row.DataDisplay.DelistButton) end
  RepaintRow(row)
end

local function SkinActivityRow(row)
  SkinRow(row)
  local checkButton = row.CheckButton
  checkButton:SetSize(18, 18)
  row.NameButton:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)

  -- Blizzard assigns distinct textures for partial and full group selection.
  Skins.Surface(checkButton, true)
  Skins.Hide(checkButton:GetNormalTexture())
end

local function SkinCategories(view)
  local width, height = 300, 44
  for _, button in ipairs(view.CategoryButtons) do
    -- The button skin replaces the artwork that Blizzard uses to size this layout.
    button:SetFixedSize(width, height)
    button:SetSize(width, height)
    Skins.Button(button)
    Skins.Hide(button.Cover)
    button.Icon:SetAlpha(0.25)
  end
end

local listingLayout = {
  Panel = { "Inset" },
  StripRegions = { "ActivityView.Comment" },
  Hide = { "Inset.CustomBG", "DividerFrame.Divider", "ActivityView.BarTop", "ActivityView.BarMiddle" },
  Button = { "BackButton", "PostButton", "GroupRoleButtons.RolePollButton" },
  Dropdown = { "GroupRoleButtons.RoleDropdown", "ActivityView.PlayStyleDropdown", "ActivityView.VoiceChatDropdown" },
  CheckBox = { "SoloRoleButtons.Tank.CheckButton", "SoloRoleButtons.Healer.CheckButton",
    "SoloRoleButtons.DPS.CheckButton", "NewPlayerFriendlyButton.CheckButton", "ActivityView.LevelRangesCheckbox.Checkbox" },
  ScrollBar = { "ActivityView.ScrollBar", "ActivityView.Comment.ScrollBar" },
  Font = { "ActivityView.VoiceChatLabel", "ActivityView.LevelRangesCheckbox.Text", "ActivityView.Comment.EditBox",
    "ActivityView.Comment.EditBox.Instructions", "LockedView.ErrorText", "LockedView.ActivityText" },
}

local function PaintListing(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, listingLayout)
  SkinCategories(frame.CategoryView)
end

Skins.Register("Blizzard_GroupFinder_VanillaStyle", "LFGParentFrame", {
  label = "Looking for group", category = "Groups & loot", manageControls = false,
  install = function(frame)
    Skins.SideTab(frame.ListingTab)
    Skins.SideTab(frame.BrowsingTab)
    Skins.SideTab(frame.WhoListingTab)
    ns.Theme.WidgetSkins.CloseButton(LFGParentFrameCloseButton)
  end,
})

Skins.Register("Blizzard_GroupFinder_VanillaStyle", "LFGListingFrame", {
  manageControls = false,
  install = function(frame)
    PaintListing(frame)
    local roleBackground = frame.RolesSection:GetRegions()
    Skins.Hide(roleBackground)
    Skins.ScrollRows(frame.ActivityView.ScrollBox, SkinActivityRow, RepaintRow)
    Skins.Hook(_G, "LFGListingCategorySelection_UpdateCategoryButtons", SkinCategories)
  end,
  onTheme = PaintListing,
})

local browseLayout = {
  Panel = { "Inset" },
  Hide = { "BackgroundArt", "BarTop", "BarMiddle", "Inset.CustomBG" },
  Dropdown = { "CategoryDropdown", "ActivityDropdown" },
  Button = { "OptionsButton", "SendMessageButton", "GroupInviteButton" },
  ScrollBar = { "ScrollBar" },
  Font = { "NoResultsFound", "SearchingSpinner.Label" },
}

local function PaintBrowse(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, browseLayout)
end

Skins.Register("Blizzard_GroupFinder_VanillaStyle", "LFGBrowseFrame", {
  manageControls = false,
  install = function(frame)
    PaintBrowse(frame)
    Skins.RefreshButton(frame.RefreshButton, frame.RefreshButton:GetHeight())
    Skins.ScrollRows(frame.ScrollBox, SkinRow, RepaintRow)
  end,
  onTheme = PaintBrowse,
})

local whoLayout = {
  Hide = { "BackgroundArt", "headerBackground", "insideFrame", "BarTop", "BarMiddle" },
  EditBox = { "EditBox" }, Dropdown = { "FilterDropdown" },
  Button = { "WhoSearch" }, ScrollBar = { "ScrollBar" }, Font = { "WhoFrameTotals" },
}

local function PaintWho(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, whoLayout)
end

Skins.Register("Blizzard_GroupFinder_VanillaStyle", "LFGWhoListFrame", {
  manageControls = false,
  install = function(frame)
    PaintWho(frame)
    Skins.ScrollRows(frame.ScrollBox, SkinRow, RepaintRow)
  end,
  onTheme = PaintWho,
})
