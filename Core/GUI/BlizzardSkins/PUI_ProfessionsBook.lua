local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_ProfessionsBook", "ProfessionsBookFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(ProfessionsBookPage1)
    Skins.Hide(ProfessionsBookPage2)
    for _, entry in ipairs({ PrimaryProfession1, PrimaryProfession2, SecondaryProfession1, SecondaryProfession2, SecondaryProfession3 }) do
      Skins.Font(entry.professionName, "header")
      Skins.Font(entry.missingHeader, "header")
      Skins.Font(entry.missingText)
      Skins.Font(entry.rank)
      for _, button in ipairs({ entry.SpellButton1, entry.SpellButton2 }) do
        Skins.Surface(button, true, true)
        Skins.Icon(button.IconTexture)
        ns.Theme.ApplyFont(button.spellString, "body")
        ns.Theme.ApplyFont(button.subSpellString, "tiny")
        Skins.Hide(_G[button:GetName() .. "NameFrame"])
      end
      Skins.Bar(entry.statusBar)
      ns.Theme.ApplyFont(entry.statusBar.rankText, "tiny")
      for _, suffix in ipairs({ "Left", "Right", "BGLeft", "BGRight", "BGMiddle" }) do Skins.Hide(_G[entry.statusBar:GetName() .. suffix]) end
    end
    -- Secure spell/flyout attributes, cooldowns, checked state and unlearning stay native.
  end,
})
