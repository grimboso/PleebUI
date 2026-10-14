local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme
local buttons = setmetatable({}, { __mode = "k" })

function Skins.IconSelectorButton(button)
  if buttons[button] or button:IsForbidden() or not Skins.CanStyle() then return end
  for _, region in ipairs({ button:GetRegions() }) do
    if region:IsObjectType("Texture") and region ~= button.Icon
      and region ~= button.SelectedTexture and region ~= button.Highlight then
      Skins.Hide(region)
    end
  end
  button.Icon:ClearAllPoints()
  button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  Skins.Icon(button.Icon)
  Skins.Surface(button, true)
  if button.SelectedTexture then
    button.SelectedTexture:SetAllPoints(button)
    Skins.Selection(button.SelectedTexture, 0.25)
  end
  if button.Highlight then
    button.Highlight:SetAllPoints(button)
    button.Highlight:SetColorTexture(1, 1, 1, 0.10)
  end
  Skins.Font(button.Name, "tiny")
  buttons[button] = true
end

local function RefreshIconSelector(popup)
  if not Skins.CanStyle() then return end
  -- ScrollBoxSelector creates its view on its own first OnShow, after the popup's OnShow.
  if popup.IconSelector.initialized then
    for button in popup.IconSelector:EnumerateButtons() do Skins.IconSelectorButton(button) end
  end
  -- Blizzard switches this font object when the selected icon is outside the filtered list.
  Theme.ApplyFont(popup.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription, "body")
end

local function InstallIconSelector(popup)
  local box = popup.BorderBox
  -- BorderBox contains native controls: suppress its artwork, never the container itself.
  for _, frame in ipairs({ popup, box }) do
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
  end
  Skins.Hide(box.NineSlice)
  Skins.Surface(popup)
  local edit = box.IconSelectorEditBox
  Skins.Hide(edit.IconSelectorPopupNameLeft)
  Skins.Hide(edit.IconSelectorPopupNameMiddle)
  Skins.Hide(edit.IconSelectorPopupNameRight)
  Skins.EditBox(edit)
  edit:SetTextInsets(6, 6, 0, 0)
  Skins.Button(box.OkayButton)
  Skins.Button(box.CancelButton)
  Skins.Dropdown(box.IconTypeDropdown)
  Skins.Font(box.EditBoxHeaderText)
  Skins.Font(box.IconSelectionText)
  Skins.Font(box.SelectedIconArea.SelectedIconText.SelectedIconHeader)
  Skins.Font(box.IconDragArea.IconDragAreaContent.IconDragText)
  Skins.ScrollBar(popup.IconSelector.ScrollBar)
  Skins.Hook(popup.IconSelector, "RunSetup", function(_, button) Skins.IconSelectorButton(button) end)
  local description = box.SelectedIconArea.SelectedIconText.SelectedIconDescription
  Skins.Hook(description, "SetFontObject", function()
    if Skins.CanStyle() then Theme.ApplyFont(description, "body") end
  end)
  Skins.IconSelectorButton(box.SelectedIconArea.SelectedIconButton)
end

for _, target in ipairs({
  { "Blizzard_UIPanels_Game", "GearManagerPopupFrame" },
  { "Blizzard_MacroUI", "MacroPopupFrame" },
}) do
  Skins.Register(target[1], target[2], {
    install = InstallIconSelector,
    onShow = RefreshIconSelector,
    manageControls = false,
  })
end
