local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshMap(frame)
  Skins.Shell(frame.BorderFrame)
  Skins.StripRegions(frame.NavBar)
  Skins.StripRegions(frame.NavBar.overlay)
  Skins.Button(frame.NavBar.homeButton)
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
