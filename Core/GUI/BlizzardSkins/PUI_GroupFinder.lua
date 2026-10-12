local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Panel = { "LFDParentFrame.Inset", "RaidFinderFrame.Inset", "LFGListFrame.CategorySelection.Inset",
    "LFGListFrame.NothingAvailable.Inset", "LFGListFrame.SearchPanel.ResultsInset", "LFGListFrame.EntryCreation.Inset",
    "LFGListFrame.EntryCreation.ActivityFinder.Dialog" },
  Button = { "LFDQueueFrameFindGroupButton", "LFDQueueFrameNoLFDWhileLFRLeaveQueueButton", "RaidFinderFrameFindRaidButton",
    "LFGListFrame.CategorySelection.FindGroupButton", "LFGListFrame.CategorySelection.StartGroupButton",
    "LFGListFrame.SearchPanel.BackButton", "LFGListFrame.SearchPanel.BackToGroupButton", "LFGListFrame.SearchPanel.SignUpButton",
    "LFGListFrame.EntryCreation.ListGroupButton", "LFGListFrame.EntryCreation.CancelButton",
    "LFGListFrame.EntryCreation.ActivityFinder.Dialog.SelectButton", "LFGListFrame.EntryCreation.ActivityFinder.Dialog.CancelButton" },
  Dropdown = { "LFDQueueFrame.TypeDropdown", "RaidFinderQueueFrame.SelectionDropdown" },
  EditBox = { "LFGListFrame.SearchPanel.SearchBox", "LFGListFrame.EntryCreation.Name",
    "LFGListFrame.EntryCreation.ActivityFinder.Dialog.EntryBox", "LFGListFrame.EntryCreation.Description.EditBox" },
  StripRegions = { "LFGListFrame.EntryCreation.Description" },
  ScrollBar = { "LFDQueueFrame.Specific.ScrollBar", "LFDQueueFrame.Follower.ScrollBar",
    "LFGListFrame.SearchPanel.ScrollBar", "LFGListFrame.EntryCreation.ActivityFinder.Dialog.ScrollBar" },
}

local function RefreshGroupButtons()
  if not Skins.CanStyle() then return end
  for index = 1, 4 do
    local button = GroupFinderFrame["groupButton" .. index]
    Skins.Hide(button.bg)
    Skins.Hide(button.ring)
    button.icon:RemoveMaskTexture(button.CircleMask)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.icon:SetSize(42, 42)
    Skins.IconButton(button, button.icon)
    Skins.Font(button.name, "header")
  end
end

local function RefreshGroupFinder(frame)
  Skins.Shell(frame)
  Skins.Hide(frame.shadows)
  for _, key in ipairs({ "BlueBg", "TLCorner", "TRCorner", "BRCorner", "BLCorner", "LLVert", "RLVert",
    "BottomLine", "TopLine", "TopFiligree", "BottomFiligree" }) do
    Skins.Hide(_G["PVEFrame" .. key])
  end
  for index = 1, 3 do Skins.Tab(frame["tab" .. index]) end
  RefreshGroupButtons()
  Skins.Apply(_G, layout)
  for _, role in ipairs({ "Tank", "Healer", "DPS", "Leader" }) do
    Skins.CheckBox(_G["LFDQueueFrameRoleButton" .. role].checkButton)
    Skins.CheckBox(_G["RaidFinderQueueFrameRoleButton" .. role].checkButton)
  end
  for _, button in ipairs(LFGListFrame.CategorySelection.CategoryButtons) do
    Skins.IconButton(button, button.Icon)
    Skins.Font(button:GetFontString())
  end
  -- Applicant and search-result state stays entirely in Blizzard's restricted path.
  Skins.Hook(_G, "PVEFrame_ShowLeftInset", function()
    if Skins.CanStyle() then RefreshGroupFinder(frame) end
  end)
  Skins.Hook(_G, "GroupFinderFrame_SelectGroupButton", RefreshGroupButtons)
  Skins.Hook(_G, "GroupFinderFrame_OnShow", RefreshGroupButtons)
  Skins.Hook(_G, "LFGListCategorySelection_AddButton", function(panel, index)
    local button = panel.CategoryButtons[index]
    if button and Skins.CanStyle() then
      Skins.IconButton(button, button.Icon)
      Skins.Font(button:GetFontString())
    end
  end)
end

Skins.Register("Blizzard_GroupFinder", "PVEFrame", RefreshGroupFinder)
