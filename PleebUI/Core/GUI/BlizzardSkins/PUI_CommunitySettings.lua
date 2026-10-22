local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesSettingsDialog", function(frame)
  Skins.Panel(frame)
  Skins.Apply(frame, {
    Hide = { "BG", "IconPreviewRing" },
    Icon = { "IconPreview" },
    Button = { "ChangeAvatarButton", "Accept", "Delete", "Cancel" },
    StripRegions = { "Description", "MessageOfTheDay" },
    EditBox = { "NameEdit", "ShortNameEdit", "Description.EditBox", "MessageOfTheDay.EditBox", "MinIlvlOnly.EditBox" },
    Dropdown = { "ClubFocusDropdown", "LookingForDropdown", "LanguageDropdown" },
    CheckBox = { "CrossFactionToggle.CheckButton", "ShouldListClub.Button", "AutoAcceptApplications.Button",
      "MaxLevelOnly.Button", "MinIlvlOnly.Button" },
  })
end)
