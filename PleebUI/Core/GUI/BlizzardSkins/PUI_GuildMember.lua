local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesFrame.GuildMemberDetailFrame", function(frame)
  Skins.Panel(frame)
  Skins.Texts(frame)
  Skins.Apply(frame, {
    Panel = { "NoteBackground", "OfficerNoteBackground" },
    Button = { "RemoveButton", "GroupInviteButton" },
    Dropdown = { "RankDropdown" },
  })
  ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
end)
