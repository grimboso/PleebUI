local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshMap(frame)
  Skins.Shell(frame.BorderFrame, frame)
  Skins.Navigation(frame.NavBar)
  Skins.Arrow(frame.BorderFrame.MaximizeMinimizeFrame.MaximizeButton, "+")
  Skins.Arrow(frame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton, "-")
  if frame.SidePanelToggle then
    Skins.StripRegions(frame.SidePanelToggle.OpenButton)
    Skins.StripRegions(frame.SidePanelToggle.CloseButton)
    Skins.Arrow(frame.SidePanelToggle.OpenButton, "<")
    Skins.Arrow(frame.SidePanelToggle.CloseButton, ">")
  end
  Skins.Apply(frame, {
    Panel = { "ScrollContainer" },
  })
  for _, overlay in ipairs(frame.overlayFrames) do
    if overlay:IsObjectType("DropdownButton") then
      if overlay.Icon then
        Skins.IconButton(overlay, overlay.Icon)
      else
        Skins.Dropdown(overlay)
      end
    end
  end
end

-- SetDisplayState can run inside OnShow before Blizzard's protected reading emote.
-- Repaint mode changes after the native button action has finished instead.
Skins.Register("Blizzard_WorldMap", "WorldMapFrame", {
  install = function(frame)
    local function RefreshAfterClick()
      if Skins.CanStyle() then RefreshMap(frame) end
    end
    local buttons = frame.BorderFrame.MaximizeMinimizeFrame
    buttons.MaximizeButton:HookScript("OnClick", RefreshAfterClick)
    buttons.MinimizeButton:HookScript("OnClick", RefreshAfterClick)
  end,
  onShow = RefreshMap,
  onTheme = RefreshMap,
})
