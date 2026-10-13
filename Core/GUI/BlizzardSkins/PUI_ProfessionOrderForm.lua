local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

Skins.Register("Blizzard_ProfessionsCustomerOrders", "ProfessionsCustomerOrdersFrame.Form", {
  install = function(form)
    Skins.Hide(form.RecipeHeader)
    Skins.Chrome(form.LeftPanelBackground)
    Skins.Chrome(form.RightPanelBackground)
    Templates.Fonts(form)
    Templates.Fonts(form.ReagentContainer)
    Templates.Fonts(form.ReagentContainer.Reagents)
    Templates.Fonts(form.ReagentContainer.OptionalReagents)
    Templates.Fonts(form.MinimumQuality)
    Templates.Fonts(form.OrderRecipientDisplay)
    Skins.Button(form.BackButton, true)
    Skins.CheckBox(form.TrackRecipeCheckbox.Checkbox)
    Templates.Fonts(form.TrackRecipeCheckbox)
    Skins.CheckBox(form.AllocateBestQualityCheckbox)
    Skins.EditBox(form.OrderRecipientTarget)
    Skins.Dropdown(form.MinimumQuality.Dropdown)
    Skins.Dropdown(form.OrderRecipientDropdown)
    local payment = form.PaymentContainer
    Templates.Fonts(payment)
    Templates.Fonts(payment.TimeRemainingDisplay)
    Templates.Note(payment.NoteEditBox)
    Skins.Dropdown(payment.DurationDropdown)
    Skins.Button(payment.ListOrderButton, true)
    Skins.Button(payment.CancelOrderButton, true)
    Templates.ObserveFlyouts()
    Templates.RefreshForm(form)
    Skins.Hook(form, "Init", Templates.RefreshForm)
    -- Money, native reagent warnings, recipient validation and listing actions stay native.
  end,
  onShow = Templates.RefreshForm,
})
