local _, ns = ...
local Skins = ns.BlizzardSkins

local function SkinMapOverlay(frame, templateName)
  local overlay = frame.overlayFrames[#frame.overlayFrames]
  if templateName == "WorldMapFloorNavigationFrameTemplate" then
    Skins.Dropdown(overlay)
  elseif templateName == "WorldMapTrackingOptionsButtonTemplate" then
    Skins.IconButton(overlay, overlay.Icon)
  elseif templateName == "WorldMapTrackingPinButtonTemplate" then
    Skins.IconButton(overlay, overlay.Icon)
  end
end

local function InstallMap(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
  local surface = Skins.Surface(frame)
  surface:ClearAllPoints()
  surface:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 0)
  surface:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -8)
  Skins.Panel(frame.ScrollContainer)

  local navigation = frame.NavBar
  Skins.Navigation(navigation, "<")
  Skins.Button(navigation.homeButton)

  local border = frame.BorderFrame
  Skins.Chrome(border)
  border:SetFrameStrata(frame:GetFrameStrata())

  border.PortraitContainer:ClearAllPoints()
  border.PortraitContainer:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -10)

  ns.Theme.WidgetSkins.CloseButton(border.CloseButton)
  Skins.Arrow(border.MaximizeMinimizeFrame.MaximizeButton, "+")
  Skins.Arrow(border.MaximizeMinimizeFrame.MinimizeButton, "-")
  Skins.Arrow(frame.SidePanelToggle.CloseButton, "<")
  Skins.Arrow(frame.SidePanelToggle.OpenButton, ">")

  local dropdown, tracking, pin = unpack(frame.overlayFrames)
  Skins.Dropdown(dropdown)
  Skins.IconButton(tracking, tracking.Icon)
  Skins.IconButton(pin, pin.Icon)
  hooksecurefunc(frame, "AddOverlayFrame", SkinMapOverlay)
end

Skins.Register("Blizzard_WorldMap", "WorldMapFrame", {
  install = InstallMap,
  installOnLoad = true,
  manageControls = false,
})
