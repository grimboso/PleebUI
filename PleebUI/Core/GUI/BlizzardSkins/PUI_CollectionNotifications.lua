local _, ns = ...
local Skins = ns.BlizzardSkins

local function InstallAlert(frame)
  Skins.Surface(frame)
  Skins.Font(frame.Label)
  Skins.Font(frame.Name)
  Skins.Icon(frame.Icon)
end

local function PaintAlert(frame)
  Skins.Hide(frame.Background)
  frame.glow:SetVertexColor(1, 1, 1, 0)
  frame.shine:SetVertexColor(1, 1, 1, 0)
end

ns.NotificationSkins.Register("MountNotifications", "Mount notifications", "NewMountAlertSystem", InstallAlert, PaintAlert)
ns.NotificationSkins.Register("PetNotifications", "Pet notifications", "NewPetAlertSystem", InstallAlert, PaintAlert)
ns.NotificationSkins.Register("ToyNotifications", "Toy notifications", "NewToyAlertSystem", InstallAlert, PaintAlert)
ns.NotificationSkins.Register("CosmeticNotifications", "Appearance notifications", "NewCosmeticAlertFrameSystem", InstallAlert, PaintAlert)
ns.NotificationSkins.Register("WarbandSceneNotifications", "Campsite notifications", "NewWarbandSceneAlertSystem", InstallAlert, PaintAlert)
