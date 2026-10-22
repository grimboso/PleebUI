local _, ns = ...
local Skins = ns.BlizzardSkins
local Theme = ns.Theme

local function InstallReward(button)
  Skins.Hide(button.NameFrame)
  Skins.Icon(button.Icon)
  Theme.ApplyFont(button.Name, "body")
end

Skins.Register("Blizzard_DelvesDifficultyPicker", "DelvesDifficultyPickerFrame", {
  label = "Delves and tiered entrances",
  category = "Delves",
  install = function(frame)
    Skins.Panel(frame)
    -- Native background widgets use BACKGROUND strata; keep the shell below them.
    Skins.Surface(frame):SetFrameStrata("BACKGROUND")
    Theme.WidgetSkins.CloseButton(frame.CloseButton)
    Skins.Font(frame.Title, "header")
    Skins.Font(frame.ScenarioLabel)
    Skins.Font(frame.Description)
    Theme.ApplyFont(frame.EntranceErrorText, "body")
    Skins.Hide(frame.DividingLine)
    Skins.Dropdown(frame.Dropdown)
    Skins.Button(frame.EnterDelveButton)
    Skins.Font(frame.DelveModifiersWidgetContainer.ModifiersLabel)
    Skins.Font(frame.ChallengesContainerFrame.Title, "header")
    Theme.ApplyFont(frame.ChallengesContainerFrame.BlockingFrame.Label, "body")
    local rewards = frame.DelveRewardsContainerFrame
    Skins.Font(rewards.RewardText)
    Skins.ScrollBar(rewards.ScrollBar)
    Skins.ScrollRows(rewards.ScrollBox, InstallReward, false)
  end,
})
