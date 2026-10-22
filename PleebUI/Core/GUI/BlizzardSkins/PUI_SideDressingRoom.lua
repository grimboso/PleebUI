local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_UIPanels_Game", "SideDressUpFrame", {
  install = function(frame)
    -- Keep the class/model background; the remaining root textures form the old auction-frame shell.
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") and region ~= frame.BGTopLeft and region ~= frame.BGBottomLeft then
        Skins.Hide(region)
      end
    end
    Skins.Surface(frame)
    Skins.Button(frame.ResetButton)
    ns.Theme.WidgetSkins.CloseButton(SideDressUpFrameCloseButton)
  end,
})
