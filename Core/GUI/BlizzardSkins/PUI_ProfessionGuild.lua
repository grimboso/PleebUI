local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintCrafterRow(row)
  ns.Theme.ApplyFont(row.Text, "body")
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame.CraftingPage.GuildFrame", {
  install = function(frame)
    Skins.Panel(frame)
    Skins.Chrome(frame.Container)
    Skins.Font(frame.Title, "header")
    Skins.ScrollBar(frame.Container.ScrollBar)
    Skins.ScrollRows(frame.Container.ScrollBox, RepaintCrafterRow, RepaintCrafterRow)
  end,
  onShow = function(frame) Skins.ScrollRows(frame.Container.ScrollBox, RepaintCrafterRow, RepaintCrafterRow) end,
})
