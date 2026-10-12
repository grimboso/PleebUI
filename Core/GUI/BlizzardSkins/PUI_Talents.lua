local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshTalentColors(frame)
  local color = ns.Theme.GetColors().background
  frame.BottomBar:SetColorTexture(color[1], color[2], color[3], color[4])
end

local function SkinPvPTalentRow(row)
  -- Keep native selection rings, availability colors and desaturation.
  ns.Theme.ApplyFont(row.Name, "body")
  ns.Theme.ApplyFont(row.New, "body")
  local highlight = row:GetHighlightTexture()
  highlight:SetColorTexture(1, 1, 1, 0.06)
  highlight:SetAllPoints(row)
end

Skins.Register("Blizzard_PlayerSpells", "PlayerSpellsFrame.TalentsFrame", {
  install = function(frame)
    Skins.Hide(frame.BlackBG)
    frame.Background:SetAlpha(0.75)
    Skins.Button(frame.ApplyButton, true)
    Skins.Button(frame.InspectCopyButton, true)
    Skins.Dropdown(frame.LoadSystem.Dropdown)
    Skins.EditBox(frame.SearchBox)
    Skins.Button(frame.ResetButton, true)
    Skins.Button(frame.UndoButton, true)
    Skins.Font(frame.ClassCurrencyDisplay.CurrencyLabel, "header")
    Skins.Font(frame.SpecCurrencyDisplay.CurrencyLabel, "header")
    Skins.Font(frame.HeroTalentsContainer.HeroSpecLabel, "header")
    Skins.Panel(frame.SearchPreviewContainer)
    for _, key in ipairs({ "Top", "Middle", "Bottom" }) do
      Skins.Hide(frame.PvPTalentList[key])
    end
    Skins.Surface(frame.PvPTalentList)
    Skins.ScrollRows(frame.PvPTalentList.ScrollBox, SkinPvPTalentRow, SkinPvPTalentRow)
    RefreshTalentColors(frame)
  end,
  onTheme = RefreshTalentColors,
})
