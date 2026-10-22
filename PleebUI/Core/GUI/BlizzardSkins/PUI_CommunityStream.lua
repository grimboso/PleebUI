local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesFrame.EditStreamDialog", function(frame)
  Skins.Panel(frame)
  Skins.Hide(frame.BG)
  Skins.Texts(frame)
  Skins.Apply(frame, {
    StripRegions = { "Description" },
    EditBox = { "NameEdit", "Description.EditBox" },
    CheckBox = { "TypeCheckbox" },
    Button = { "Accept", "Delete", "Cancel" },
  })
end)
