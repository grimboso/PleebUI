local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_UIPanels_Game", "ReputationFrame.ReputationDetailFrame", {
  install = function(frame)
    Skins.StripRegions(frame)
    ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
    Skins.Font(frame.Title, "header")
    for _, check in ipairs({ frame.AtWarCheckbox, frame.MakeInactiveCheckbox, frame.WatchFactionCheckbox }) do
      Skins.CheckBox(check)
      ns.Theme.ApplyFont(check.Label, "body")
    end
    Skins.Button(frame.ViewRenownButton)
    Skins.ScrollBar(frame.ScrollingDescriptionScrollBar)
  end,
  manageControls = false,
})
