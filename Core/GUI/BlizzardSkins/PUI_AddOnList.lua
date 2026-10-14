local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme

local function InstallRow(row)
  Theme.ApplyFont(row.Title, "body")
  if row.Enabled then
    Skins.CheckBox(row.Enabled)
    Skins.Button(row.LoadAddonButton)
    Theme.ApplyFont(row.Status, "tiny")
    Theme.ApplyFont(row.Reload, "tiny")
  end
  -- Native category arrows and tri-state desaturation retain their state and rotation.
end

Skins.Register("Blizzard_AddOnList", "AddonList", {
  label = "AddOns", category = "System",
  install = function(frame)
    Skins.Shell(frame)
    frame.PortraitContainer:Show()
    frame.PortraitContainer.portrait:SetTexture("Interface\\AddOns\\PleebUI\\Media\\logo.tga")
    frame.PortraitContainer.portrait:Show()
    Skins.Dropdown(frame.Dropdown)
    Skins.EditBox(frame.SearchBox)
    Skins.CheckBox(frame.ForceLoad)
    Skins.Texts(frame.ForceLoad)
    Skins.ScrollBar(frame.ScrollBar)
    for _, button in ipairs({ frame.EnableAllButton, frame.DisableAllButton,
      frame.OkayButton, frame.CancelButton }) do Skins.Button(button) end
    for _, text in ipairs({ frame.Performance.Header, frame.Performance.Current,
      frame.Performance.Average, frame.Performance.Peak }) do Theme.ApplyFont(text, "body") end
    frame.Dropdown:ClearAllPoints()
    frame.Dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    frame.SearchBox:ClearAllPoints()
    frame.SearchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -40)
    frame.ForceLoad:ClearAllPoints()
    frame.ForceLoad:SetPoint("TOP", frame, "TOP", -80, -36)
    frame.Performance:SetPoint("TOP", frame, "TOP", 0, -82)
  end,
  onShow = function(frame) Skins.ScrollRows(frame.ScrollBox, InstallRow, false) end,
})
