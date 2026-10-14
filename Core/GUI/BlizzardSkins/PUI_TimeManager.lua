local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_TimeManager", "TimeManagerFrame", {
  label = "Clock and alarm", category = "System",
  install = function(frame)
    -- Keep the globe and its live clock; the native title is the other direct font region.
    Skins.Panel(frame)
    Skins.Chrome(frame.Inset)
    ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
    Skins.Texts(frame)
    Skins.Texts(TimeManagerStopwatchFrame)
    TimeManagerGlobe:ClearAllPoints()
    TimeManagerGlobe:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    TimeManagerGlobe:SetSize(36, 36)
    Skins.Font(TimeManagerFrameTicker, "tiny")
    for _, dropdown in ipairs({ frame.AlarmTimeFrame.HourDropdown,
      frame.AlarmTimeFrame.MinuteDropdown, frame.AlarmTimeFrame.AMPMDropdown }) do Skins.Dropdown(dropdown) end
    Skins.EditBox(TimeManagerAlarmMessageEditBox)
    for _, check in ipairs({ TimeManagerAlarmEnabledButton, TimeManagerMilitaryTimeCheck,
      TimeManagerLocalTimeCheck }) do Skins.CheckBox(check) end
    Skins.Font(TimeManagerAlarmTimeLabel)
    Skins.Font(TimeManagerAlarmMessageLabel)
    Skins.Surface(TimeManagerStopwatchCheck, true)
    Skins.Icon(TimeManagerStopwatchCheck:GetNormalTexture())
    -- This checkbox's pocket-watch icon and native checked glow remain functional.
  end,
})
