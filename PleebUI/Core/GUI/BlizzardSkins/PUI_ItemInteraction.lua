local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintInteraction(frame)
  Skins.Hide(frame.Background)
  Skins.Hide(frame.ItemConversionFrame.ItemConversionInputSlot.ButtonFrame)
  Skins.Hide(frame.ItemConversionFrame.ItemConversionOutputSlot.ButtonFrame)
end

Skins.Register("Blizzard_ItemInteractionUI", "ItemInteractionFrame", {
  install = function(frame)
    Skins.Shell(frame)
    local footer = frame.ButtonFrame
    Skins.Hide(footer.ButtonBorder)
    Skins.Hide(footer.ButtonBottomBorder)
    Skins.Hide(footer.BlackBorder)
    Skins.Hide(footer.MoneyFrameEdge)
    Skins.Button(footer.ActionButton)
    Skins.Surface(frame.ItemSlot, true)
    Skins.Icon(frame.ItemSlot.Icon)
    for _, slot in ipairs({ frame.ItemConversionFrame.ItemConversionInputSlot,
      frame.ItemConversionFrame.ItemConversionOutputSlot }) do
      Skins.Surface(slot, true)
      Skins.Icon(slot.icon)
    end
    -- Native description and charge colors communicate missing items and insufficient costs.
    ns.Theme.ApplyFont(frame.Description, "body")
    ns.Theme.ApplyFont(frame.CurrencyCost.Costs, "body")
    ns.Theme.ApplyFont(frame.CurrencyCost.Currency.Count, "body")
    ns.Theme.ApplyFont(footer.Currency.Count, "body")
    Skins.Hook(frame, "LoadInteractionFrameData", RepaintInteraction)
    RepaintInteraction(frame)
  end,
  onShow = RepaintInteraction,
})
