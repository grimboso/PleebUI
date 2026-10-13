local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintLootRow(row)
  if not Skins.CanStyle() or not row.Item then return end
  ns.Theme.ApplyFont(row.Text, "body")
end

local function InstallLootRow(row)
  if not row.Item then return end
  Skins.Hide(row.NameFrame)
  Skins.Hide(row.BorderFrame)
  Skins.Surface(row, true, true)
  Skins.IconButton(row.Item, row.Item.icon, true)
  ns.Theme.ApplyFont(row.Item.Count, "body")
  if row.QualityText then ns.Theme.ApplyFont(row.QualityText, "tiny") end
  -- Native mouse handlers own visibility; replace only the decorative strokes.
  row.HighlightNameFrame:SetColorTexture(1, 1, 1, 0.08)
  row.PushedNameFrame:SetColorTexture(1, 1, 1, 0.12)
  RepaintLootRow(row)
  Skins.Hook(row, "Init", RepaintLootRow)
end

Skins.Register("Blizzard_UIPanels_Game", "LootFrame", {
  install = function(frame)
    Skins.Shell(frame)
    ns.Theme.WidgetSkins.CloseButton(frame.ClosePanelButton)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.ScrollRows(frame.ScrollBox, InstallLootRow, RepaintLootRow)
  end,
  onShow = function(frame)
    Skins.ScrollRows(frame.ScrollBox, InstallLootRow, RepaintLootRow)
  end,
})
