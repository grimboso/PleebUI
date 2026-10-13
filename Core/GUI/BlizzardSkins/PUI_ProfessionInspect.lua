local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

Skins.Register("Blizzard_Professions", "InspectRecipeFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Templates.Schematic(frame.SchematicForm)
  end,
  onShow = function(frame) Templates.RefreshForm(frame.SchematicForm) end,
})
