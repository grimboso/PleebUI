local _, ns = ...
local Skins = ns.BlizzardSkins
local rewardFrames = setmetatable({}, { __mode = "k" })

local layout = {
  Chrome = { "LFDParentFrame", "LFDParentFrame.Inset", "RaidFinderFrame", "RaidFinderFrame.Inset",
    "RaidFinderFrameRoleInset", "RaidFinderFrameBottomInset", "LFGListFrame.CategorySelection.Inset",
    "LFGListFrame.NothingAvailable.Inset", "LFGListFrame.SearchPanel.ResultsInset", "LFGListFrame.EntryCreation.Inset" },
  Panel = { "LFGListFrame.EntryCreation.ActivityFinder.Dialog" },
  Hide = { "LFDParentFrameRoleBackground", "LFDQueueFrameBackground", "RaidFinderFrameRoleBackground", "RaidFinderQueueFrameBackground" },
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
    button.bg:SetAlpha(0.25)
    button:GetHighlightTexture():SetAlpha(0.12)
    ns.Theme.ApplyFont(button.name, "header")
  end
end

local function RefreshShellArtwork()
  if not Skins.CanStyle() then return end
  Skins.Chrome(PVEFrame.Inset)
  Skins.Hide(PVEFrame.shadows)
  for _, key in ipairs({ "BlueBg", "TLCorner", "TRCorner", "BRCorner", "BLCorner", "LLVert", "RLVert",
    "BottomLine", "TopLine", "TopFiligree", "BottomFiligree" }) do
    Skins.Hide(_G["PVEFrame" .. key])
  end
end

local function RefreshQueueDropdown(dropdown)
  if not Skins.CanStyle() then return end
  dropdown.Text:ClearAllPoints()
  dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
  dropdown.Text:SetPoint("RIGHT", dropdown, "RIGHT", -28, 0)
  dropdown.Arrow:ClearAllPoints()
  dropdown.Arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
end

local function RefreshRewards(parentFrame)
  if not Skins.CanStyle() then return end
  if parentFrame == LFDQueueFrameRandomScrollFrameChildFrame or parentFrame == RaidFinderQueueFrameScrollFrameChildFrame then
    Skins.Hide(LFDQueueFrameBackground)
    Skins.Hide(RaidFinderQueueFrameBackground)
    Skins.Font(parentFrame.title, "header")
    Skins.Font(parentFrame.rewardsLabel, "header")
    Skins.Font(parentFrame.description)
    Skins.Font(parentFrame.rewardsDescription)
    Skins.Font(parentFrame.xpLabel)
    ns.Theme.ApplyFont(parentFrame.xpAmount, "body")
    for _, reward in ipairs({ parentFrame:GetChildren() }) do
      if reward.NameFrame and not rewardFrames[reward] then
        rewardFrames[reward] = true
        Skins.Hide(reward.NameFrame)
        local host = Skins.Surface(reward, true, true)
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", reward.Icon, "TOPRIGHT", 0, 0)
        host:SetPoint("BOTTOMRIGHT", reward, "BOTTOMRIGHT", 0, 0)
        ns.Theme.ApplyFont(reward.Name, "body")
      end
    end
  end
end

local function RefreshCategoryFonts()
  if not Skins.CanStyle() then return end
  for _, button in ipairs(LFGListFrame.CategorySelection.CategoryButtons) do
    ns.Theme.ApplyFont(button:GetFontString(), "body")
  end
end

local function InstallGroupFinder(frame)
  Skins.Shell(frame)
  RefreshShellArtwork()
  for index = 1, 3 do Skins.Tab(frame["tab" .. index]) end
  RefreshGroupButtons()
  Skins.Apply(_G, layout)
  for _, dropdown in ipairs({ LFDQueueFrame.TypeDropdown, RaidFinderQueueFrame.SelectionDropdown }) do
    RefreshQueueDropdown(dropdown)
    Skins.Hook(dropdown, "OnMenuAssigned", RefreshQueueDropdown)
  end
  RefreshCategoryFonts()
  RefreshRewards(LFDQueueFrameRandomScrollFrameChildFrame)
  RefreshRewards(RaidFinderQueueFrameScrollFrameChildFrame)
  -- Applicant and search-result state stays entirely in Blizzard's restricted path.
  Skins.Hook(_G, "PVEFrame_ShowLeftInset", RefreshShellArtwork)
  Skins.Hook(_G, "GroupFinderFrameButton_SetEnabled", function(button)
    if Skins.CanStyle() then ns.Theme.ApplyFont(button.name, "header") end
  end)
  Skins.Hook(_G, "GroupFinderFrame_OnShow", RefreshGroupButtons)
  Skins.Hook(_G, "LFGRewardsFrame_UpdateFrame", RefreshRewards)
  Skins.Hook(_G, "LFGListCategorySelection_AddButton", function(panel, index)
    local button = panel.CategoryButtons[index]
    if button and Skins.CanStyle() then
      ns.Theme.ApplyFont(button:GetFontString(), "body")
    end
  end)
end

Skins.Register("Blizzard_GroupFinder", "PVEFrame", {
  install = InstallGroupFinder,
  onShow = function()
    RefreshShellArtwork()
    RefreshRewards(LFDQueueFrameRandomScrollFrameChildFrame)
    RefreshRewards(RaidFinderQueueFrameScrollFrameChildFrame)
  end,
})
