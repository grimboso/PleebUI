local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintSearchRow(row)
  if not Skins.CanStyle() then return end
  ns.Theme.ApplyFont(row.Name, "body")
end

local function InstallSearchRow(row)
  Skins.Button(row, true)
  Skins.Hide(row.IconFrame)
  Skins.Icon(row.Icon)
  RepaintSearchRow(row)
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame.CraftingPage.MinimizedSearchResults", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.ScrollRows(frame.ScrollBox, InstallSearchRow, RepaintSearchRow)
  end,
  onShow = function(frame) Skins.ScrollRows(frame.ScrollBox, InstallSearchRow, RepaintSearchRow) end,
})
