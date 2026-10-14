local _, ns = ...
local Skins = ns.BlizzardSkins

local function RefreshIcons(frame)
  local selector = frame.MacroSelector
  -- The selector builds its native view in its own first OnShow.
  if selector.initialized then
    for button in selector:EnumerateButtons() do Skins.IconSelectorButton(button) end
  end
end

Skins.Register("Blizzard_MacroUI", "MacroFrame", {
  label = "Macros", category = "System",
  install = function(frame)
    frame.TitleContainer.TitleText:SetText(CREATE_MACROS)
    frame.PortraitContainer.portrait:SetTexture(MacroFramePortrait:GetTexture())
    Skins.Hide(MacroFramePortrait)
    Skins.Hide(MacroFrameSelectedMacroBackground)
    -- The remaining direct textures are decorative dividers; the portrait is in its container.
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
      if region:IsObjectType("FontString") and region ~= MacroFrameSelectedMacroName
        and region ~= MacroFrameEnterMacroText and region ~= MacroFrameCharLimitText then
        region:Hide()
      end
    end
    Skins.Shell(frame)
    Skins.Panel(MacroFrameTextBackground)
    Skins.Font(MacroFrameText)
    Skins.Font(MacroFrameSelectedMacroName)
    Skins.Font(MacroFrameEnterMacroText)
    Skins.Font(MacroFrameCharLimitText, "tiny")
    Skins.ScrollBar(MacroFrameScrollFrame.ScrollBar)
    Skins.ScrollBar(frame.MacroSelector.ScrollBar)
    for _, button in ipairs({ MacroSaveButton, MacroCancelButton, MacroDeleteButton,
      MacroNewButton, MacroExitButton, MacroEditButton }) do Skins.Button(button) end
    Skins.WindowTabs(frame, { MacroFrameTab1, MacroFrameTab2 })
    MacroFrameTab1:ClearAllPoints()
    MacroFrameTab1:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
    Skins.IconSelectorButton(frame.SelectedMacroButton)
    Skins.Hook(frame.MacroSelector, "RunSetup", function(_, button) Skins.IconSelectorButton(button) end)
  end,
  onShow = RefreshIcons,
})
