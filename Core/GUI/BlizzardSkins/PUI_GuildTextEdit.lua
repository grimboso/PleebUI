local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesGuildTextEditFrame", function(frame)
  Skins.Panel(frame)
  Skins.Panel(frame.Container)
  Skins.ScrollBar(frame.Container.ScrollFrame.ScrollBar)
  for _, child in ipairs({ frame:GetChildren() }) do
    if child:IsObjectType("Button") then
      if child:GetFontString() then
        Skins.Button(child)
      else
        ns.Theme.WidgetSkins.CloseButton(child)
      end
    end
  end
end)
