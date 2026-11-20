local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins

local layout = {
  Hide = { "BottomBackground", "TopBackground", "PetStableMoneyFrame.Border", "PetStableFrame.insideFrameBottom",
    "PetStableFrame.TopDividerFrame.horzDivider", "PetStableFrame.BottomDividerFrame.horzDivider",
    "PetStableFrame.modelScene.Background" },
  Panel = { "PetStableFrame.modelScene" },
  Button = { "PetStableFrame.purchaseButton" },
  Font = { "PetStableLevelText", "PetStableLoyaltyText", "PetStableSlotText", "PetStableCostLabel", "PetStableFrame.GamepadSlotCostText" },
}

local function PaintStable(frame)
  Skins.Shell(frame)
  Skins.Apply(_G, layout)
  for _, slot in ipairs({ PetStableCurrentPet, PetStableStabledPet1, PetStableStabledPet2 }) do
    Skins.Hide(slot.currentGlow)
    Skins.Hide(slot.unlockedBackground)
    Skins.Hide(slot.currentBackground)
    Skins.Hide(slot.lockedBackground)
    Skins.IconButton(slot, _G[slot:GetName() .. "IconTexture"])
    Skins.Selection(slot:GetCheckedTexture())
    Skins.Font(slot.Text)
  end
end

Skins.Register("Blizzard_StableUI", "PetStableFrame", {
  label = "Pet stable", category = "Windows",
  install = function(frame)
    PaintStable(frame)
    Skins.ColoredProgressBar(frame.expBar)
  end,
  onTheme = PaintStable,
})
