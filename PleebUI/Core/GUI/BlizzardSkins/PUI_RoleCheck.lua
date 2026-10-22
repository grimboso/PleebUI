local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshRoleCheck(popup)
  Skins.Panel(popup)
  Skins.Font(popup.Text, "header")
  Skins.Apply(_G, {
    Button = { "LFDRoleCheckPopupAcceptButton", "LFDRoleCheckPopupDeclineButton" },
    Font = { "LFDRoleCheckPopupDescriptionText", "LFDRoleCheckPopupDescriptionSubText" },
  })
  for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
    local button = _G["LFDRoleCheckPopupRoleButton" .. role]
    Skins.Surface(button, true)
    Skins.CheckBox(button.checkButton)
  end
end

Skins.Register("Blizzard_GroupFinder", "LFDRoleCheckPopup", RefreshRoleCheck)
