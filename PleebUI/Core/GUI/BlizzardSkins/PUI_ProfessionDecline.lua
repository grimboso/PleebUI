local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

Skins.Register("Blizzard_Professions", "ProfessionsFrame.OrdersPage.OrderView.DeclineOrderDialog", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Font(frame.ConfirmationText)
    Templates.Note(frame.NoteEditBox)
    Skins.Button(frame.ConfirmButton)
    Skins.Button(frame.CancelButton)
  end,
})
