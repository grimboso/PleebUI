local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesFrame.RecruitmentDialog", function(frame)
  Skins.Panel(frame)
  Skins.Hide(frame.BG)
  Skins.Texts(frame)
  Skins.Apply(frame, {
    StripRegions = { "RecruitmentMessageFrame.RecruitmentMessageInput" },
    EditBox = { "RecruitmentMessageFrame.RecruitmentMessageInput.EditBox", "MinIlvlOnly.EditBox" },
    Dropdown = { "ClubFocusDropdown", "LookingForDropdown", "LanguageDropdown" },
    CheckBox = { "ShouldListClub.Button", "MaxLevelOnly.Button", "MinIlvlOnly.Button" },
    Button = { "Accept", "Cancel" },
  })
end)
