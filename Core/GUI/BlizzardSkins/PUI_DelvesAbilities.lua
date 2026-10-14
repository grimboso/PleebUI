local _, ns = ...
local Skins = ns.BlizzardSkins
local Theme = ns.Theme
local abilities = setmetatable({}, { __mode = "k" })

local function InstallAbilities(frame)
  if not Skins.CanStyle() then return end
  for _, button in ipairs(frame.buttons) do
    if not abilities[button] then
      abilities[button] = true
      -- Blizzard owns unlock colors, ranks and the new-ability indicator.
      Theme.ApplyFont(button.Name, "body")
      Theme.ApplyFont(button.UnlockCondition, "tiny")
      Theme.ApplyFont(button.Rank, "tiny")
      Skins.Icon(button.Icon)
    end
  end
end

Skins.Register("Blizzard_DelvesCompanionConfiguration", "DelvesCompanionAbilityListFrame", {
  label = "Delves companion abilities",
  category = "Delves",
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(frame.CompanionAbilityListBackground)
    Skins.Dropdown(frame.DelvesCompanionRoleDropdown)
    Skins.Paging(frame.DelvesCompanionAbilityListPagingControls)
    Skins.Hook(frame, "UpdatePaginatedButtonDisplay", InstallAbilities)
  end,
  onShow = InstallAbilities,
})
