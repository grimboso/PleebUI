local _, ns = ...
local Skins = ns.BlizzardSkins

local function InstallMap(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
  local surface = Skins.Surface(frame)
  surface:ClearAllPoints()
  surface:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 0)
  surface:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -8)
  Skins.Panel(frame.ScrollContainer)

  local border = frame.BorderFrame
  Skins.Chrome(border)

  ns.Theme.WidgetSkins.CloseButton(border.CloseButton)
  Skins.Arrow(border.MaximizeMinimizeFrame.MaximizeButton, "+")
  Skins.Arrow(border.MaximizeMinimizeFrame.MinimizeButton, "-")
  Skins.Arrow(frame.SidePanelToggle.CloseButton, "<")
  Skins.Arrow(frame.SidePanelToggle.OpenButton, ">")
end

Skins.Register("Blizzard_WorldMap", "WorldMapFrame", {
  install = InstallMap,
  installOnLoad = true,
  manageControls = false,
})
