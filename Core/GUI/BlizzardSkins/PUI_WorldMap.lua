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
  Skins.Hook(frame, "SetDisplayState", function(map)
    if Skins.CanStyle() then RefreshMap(map) end
  end)
end

Skins.Register("Blizzard_WorldMap", "WorldMapFrame", RefreshMap)
