local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_TimeManager", "StopwatchFrame", {
  label = "Stopwatch", category = "System",
  install = function(frame)
    Skins.StripRegions(frame)
    for _, region in ipairs({ StopwatchTabFrame:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Font(StopwatchTitle, "tiny")
    Skins.Texts(StopwatchTicker)
    ns.Theme.WidgetSkins.CloseButton(StopwatchCloseButton)
    for _, button in ipairs({ StopwatchPlayPauseButton, StopwatchResetButton }) do
      Skins.Surface(button, true)
      -- Blizzard swaps the play/pause texture; retain its native normal and hover slots.
    end
  end,
  manageControls = false,
})
