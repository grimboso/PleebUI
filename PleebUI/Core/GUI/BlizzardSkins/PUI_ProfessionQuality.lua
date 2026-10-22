local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

local function InstallQualityDialog(frame)
  Skins.Shell(frame)
  -- This template's extra direct texture is its decorative quality-window background.
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
  ns.Theme.WidgetSkins.CloseButton(frame.ClosePanelButton)
  Skins.Button(frame.AcceptButton)
  Skins.Button(frame.CancelButton)
  for _, container in ipairs({ frame.Container1, frame.Container2, frame.Container3 }) do
    Templates.Item(container.Button)
    Templates.Spinner(container.EditBox)
  end
end

Skins.Register("Blizzard_ProfessionsCustomerOrders", "ProfessionsCustomerOrdersFrame.Form.QualityDialog", { install = InstallQualityDialog })

for _, name in ipairs({ "ProfessionsFrame.CraftingPage.SchematicForm.QualityDialog",
  "ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.QualityDialog",
  "InspectRecipeFrame.SchematicForm.QualityDialog" }) do
  Skins.Register("Blizzard_Professions", name, { install = InstallQualityDialog })
end
