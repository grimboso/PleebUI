local _, ns = ...
local Skins = ns.BlizzardSkins

local function InstallRow(row)
  Skins.Icon(row.CurrencyIcon)
  for _, text in ipairs({ row.SourceName, row.DestinationName, row.CurrencyQuantity }) do
    ns.Theme.ApplyFont(text, "body")
  end
end

Skins.Register("Blizzard_TokenUI", "CurrencyTransferLog", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Font(frame.EmptyLogMessage)
    Skins.ScrollBar(frame.ScrollBar)
  end,
  onShow = function(frame) Skins.ScrollRows(frame.ScrollBox, InstallRow, false) end,
  manageControls = false,
})
