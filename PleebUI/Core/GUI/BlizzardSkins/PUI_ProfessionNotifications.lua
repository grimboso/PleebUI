local _, ns = ...
local Skins = ns.BlizzardSkins

local function InstallAlert(frame)
  Skins.StripRegions(frame, { [frame.Icon] = true, [frame.glow] = true, [frame.shine] = true })
  Skins.Font(frame.Title, "tiny")
  Skins.Font(frame.Name)
end

local function PaintAlert(frame)
  frame.glow:SetVertexColor(1, 1, 1, 0)
  frame.shine:SetVertexColor(1, 1, 1, 0)
end

ns.NotificationSkins.Register("RecipeNotifications", "Recipe notifications", "NewRecipeLearnedAlertSystem", InstallAlert, PaintAlert)
ns.NotificationSkins.Register("ProfessionUnlockNotifications", "Profession unlock notifications", "SkillLineSpecsUnlockedAlertSystem", InstallAlert, PaintAlert)
