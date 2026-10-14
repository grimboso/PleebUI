local _, ns = ...
local Skins = ns.BlizzardSkins
local mapOverlays = setmetatable({}, { __mode = "k" })

local function InstallMap(frame)
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
end

local function RefreshMapArtwork(frame)
  Skins.Chrome(frame.BorderFrame)
  Skins.Chrome(frame.BorderFrame.Inset)
  Skins.Navigation(frame.NavBar)
  for _, overlay in ipairs(frame.overlayFrames) do
    if not mapOverlays[overlay] and overlay:IsObjectType("DropdownButton") then
      mapOverlays[overlay] = true
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
    InstallMap(frame)
    local function RefreshAfterClick()
      RefreshMapArtwork(frame)
    end
    local buttons = frame.BorderFrame.MaximizeMinimizeFrame
    buttons.MaximizeButton:HookScript("OnClick", RefreshAfterClick)
    buttons.MinimizeButton:HookScript("OnClick", RefreshAfterClick)
  end,
  onShow = RefreshMapArtwork,
})
