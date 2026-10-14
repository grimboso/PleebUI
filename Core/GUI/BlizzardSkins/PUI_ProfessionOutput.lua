local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintOutputRow(row)
  ns.Theme.ApplyFont(row.ItemContainer.Text, "body")
end

local function InstallOutputRow(row)
  local item = row.ItemContainer
  Skins.Hide(item.NameFrame)
  Skins.Hide(item.BorderFrame)
  Skins.Surface(item, true, true)
  Skins.IconButton(item.Item, item.Item.icon, true)
  ns.Theme.ApplyFont(item.CritText, "tiny")
  ns.Theme.ApplyFont(item.Item.Count, "body")
  item.HighlightNameFrame:SetColorTexture(1, 1, 1, 0.08)
  item.PushedNameFrame:SetColorTexture(1, 1, 1, 0.12)
  for _, extra in ipairs({ row.Multicraft, row.Resources, row.BonusCraft }) do
    ns.Theme.ApplyFont(extra.Text, "tiny")
  end
  RepaintOutputRow(row)
  -- CritFrame, resource icons and multicraft counts convey native results.
end

local callbacks = {
  install = function(frame)
    Skins.Shell(frame)
    ns.Theme.WidgetSkins.CloseButton(frame.ClosePanelButton)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.ScrollRows(frame.ScrollBox, InstallOutputRow, RepaintOutputRow)
  end,
  onShow = function(frame) Skins.ScrollRows(frame.ScrollBox, InstallOutputRow, RepaintOutputRow) end,
}
Skins.Register("Blizzard_Professions", "ProfessionsFrame.CraftingPage.CraftingOutputLog", callbacks)
Skins.Register("Blizzard_Professions", "ProfessionsFrame.OrdersPage.OrderView.CraftingOutputLog", callbacks)
