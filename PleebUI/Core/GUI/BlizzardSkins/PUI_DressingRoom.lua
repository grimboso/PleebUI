local _, ns = ...
local Skins = ns.BlizzardSkins
local details = setmetatable({}, { __mode = "k" })

local function RepaintSetRow(row)
  ns.Theme.ApplyFont(row.ItemName, "body")
  ns.Theme.ApplyFont(row.ItemSlot, "body")
end

local function InstallSetRow(row)
  Skins.Hide(row.BackgroundTexture)
  Skins.Surface(row, true, true)
  Skins.Icon(row.Icon)
  RepaintSetRow(row)
end

local function RefreshDetails(panel)
  for slot in panel.slotPool:EnumerateActive() do
    if not details[slot] then
      details[slot] = true
      Skins.Icon(slot.Icon)
    end
    ns.Theme.ApplyFont(slot.Name, "body")
  end
end

Skins.Register("Blizzard_UIPanels_Game", "DressUpFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Button(frame.ResetButton)
    Skins.Button(DressUpFrameCancelButton)
    Skins.Button(frame.LinkButton)
    Skins.Dropdown(frame.CustomSetDropdown)
    if frame.CustomSetDropdown.SaveButton then Skins.Button(frame.CustomSetDropdown.SaveButton) end
    local selection = frame.SetSelectionPanel
    Skins.Hide(selection.Border)
    Skins.Hide(selection.BlackBackground)
    Skins.Surface(selection, false, true)
    Skins.Font(selection.SetName, "header")
    Skins.ScrollBar(selection.ScrollBar)
    Skins.ScrollRows(selection.ScrollBox, InstallSetRow, RepaintSetRow)
    local panel = frame.CustomSetDetailsPanel
    -- Only this panel's direct artwork is decorative; pooled icons and hidden-appearance cues are children.
    for _, region in ipairs({ panel:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Surface(panel, false, true)
    Skins.Hook(panel, "Refresh", RefreshDetails)
    RefreshDetails(panel)
    -- ModelScene camera controls, appearance-list glyph and maximize/minimize stay native.
  end,
  onShow = function(frame) RefreshDetails(frame.CustomSetDetailsPanel) end,
})
