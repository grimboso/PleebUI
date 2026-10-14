local _, ns = ...
local Skins = ns.BlizzardSkins
local activities = setmetatable({}, { __mode = "k" })

local function RefreshActivities(frame)
  for _, activity in ipairs(frame.Activities) do
    if not activities[activity] then
      activities[activity] = true
      -- Backgrounds distinguish locked rewards; selection and completion artwork retain native state.
      Skins.Hide(activity.Border)
      if activity.ItemFrame then
        Skins.Icon(activity.ItemFrame.Icon)
        ns.Theme.ApplyFont(activity.ItemFrame.Name, "body")
      end
      if activity.Threshold then ns.Theme.ApplyFont(activity.Threshold, "body") end
      if activity.Progress then ns.Theme.ApplyFont(activity.Progress, "body") end
      if activity.RewardsFrame then
        ns.Theme.ApplyFont(activity.RewardsFrame.Label, "body")
        ns.Theme.ApplyFont(activity.RewardsFrame.Text, "body")
      end
    end
  end
end

Skins.Register("Blizzard_WeeklyRewards", "WeeklyRewardsFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(frame.BorderShadow)
    Skins.Hide(frame.BorderContainer)
    Skins.Hide(frame.Divider1)
    Skins.Hide(frame.Divider2)
    Skins.Hide(frame.HeaderFrame.HeaderDivider)
    Skins.Font(frame.HeaderFrame.Text, "header")
    Skins.Font(frame.PreviousRewardNotification)
    Skins.Font(frame.ConcessionsFrame.HeaderText, "header")
    Skins.Button(frame.SelectRewardButton)
    for _, category in ipairs({ frame.RaidFrame, frame.MythicFrame, frame.PVPFrame, frame.WorldFrame }) do
      Skins.Hide(category.Border)
      Skins.Font(category.Name, "header")
    end
    Skins.Hook(frame, "SetUpActivity", RefreshActivities)
    RefreshActivities(frame)
  end,
  onShow = RefreshActivities,
})
