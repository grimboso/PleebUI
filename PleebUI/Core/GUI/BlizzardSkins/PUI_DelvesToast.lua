local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_DelvesToast", "DelvesToastFrame", {
  label = "Delves assistance notifications",
  category = "Notifications",
  manageControls = false,
  install = function(frame)
    Skins.StripRegions(frame)
    Skins.Font(frame.Text)
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("LEFT", frame, "LEFT", 12, 0)
    frame.Text:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
    ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
  end,
})
