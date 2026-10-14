local _, ns = ...
local Skins = ns.BlizzardSkins
local navigationButtons = setmetatable({}, { __mode = "k" })
local positioningNavigationButton

local function PositionNavigationButton(button, point, relativeTo, relativePoint, x, y)
  if positioningNavigationButton == button then return end
  positioningNavigationButton = button
  button:SetPoint(point, relativeTo, relativePoint, 1, y)
  positioningNavigationButton = nil
end

local function SkinNavigationButton(button, index)
  if navigationButtons[button] then return end
  navigationButtons[button] = true
  Skins.Button(button, true)
  if button.MenuArrowButton then
    Skins.Arrow(button.MenuArrowButton, "v")
  end
  -- Native layout reads xoffset; adjust the rendered anchor without assigning that field.
  if index > 1 then
    PositionNavigationButton(button, button:GetPoint())
    hooksecurefunc(button, "SetPoint", PositionNavigationButton)
  end
end

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
  Skins.Surface(frame)
  Skins.Panel(frame.ScrollContainer)

  local navigation = frame.NavBar
  Skins.Chrome(navigation)
  Skins.Hide(navigation.overlay)
  navigation:SetPoint("TOPLEFT", 1, -40)
  for index, button in ipairs(navigation.navList) do
    SkinNavigationButton(button, index)
  end
  Skins.Button(navigation.homeButton)
  Skins.Arrow(navigation.overflowButton, "<")
  hooksecurefunc("NavBar_AddButton", function(bar)
    if bar == navigation then
      local index = #bar.navList
      SkinNavigationButton(bar.navList[index], index)
    end
  end)

  local border = frame.BorderFrame
  Skins.Chrome(border)
  border:SetFrameStrata(frame:GetFrameStrata())
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
