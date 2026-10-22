local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_QueueStatusFrame", "QueueStatusFrame", {
  install = Skins.Panel,
  -- Native entry formatting owns status colors, role icons, timers and measured heights.
})
