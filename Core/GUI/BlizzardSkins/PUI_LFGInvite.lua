local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "LFGInvitePopup", function(popup)
  Skins.Panel(popup)
  Skins.Apply(_G, {
    Button = { "LFGInvitePopupAcceptButton", "LFGInvitePopupDeclineButton" },
    Font = { "LFGInvitePopupText" },
  })
  for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
    local button = _G["LFGInvitePopupRoleButton" .. role]
    Skins.Surface(button, true)
    Skins.CheckBox(button.checkButton)
  end
end)
