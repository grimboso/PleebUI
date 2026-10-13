local _, ns = ...
local Skins = ns.BlizzardSkins

local function ApplyRowFonts(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
  if not row.Item then return end
  ns.Theme.ApplyFont(row.WinningRollInfo.WinningRoll, "body")
  ns.Theme.ApplyFont(row.PendingRollInfo.CurrentWinnerText, "body")
  ns.Theme.ApplyFont(row.AllPassedInfo.AllPassedText, "body")
end

local function InstallHistoryRow(row)
  ApplyRowFonts(row)
  if not row.Item then return end
  Skins.Hide(row.BackgroundArtFrame.NameFrame)
  Skins.Hide(row.BackgroundArtFrame.BorderFrame)
  Skins.Surface(row.BackgroundArtFrame, true, true)
  Skins.Icon(row.Item.icon)
  ns.Theme.ApplyFont(row.Item.Count, "tiny")
  -- Native Init updates content/colors; it does not reset these fonts or shell textures.
end

local function RefreshHistoryRows(frame)
  Skins.ScrollRows(frame.ScrollBox, InstallHistoryRow, false)
end

local function RefreshHistoryColors(frame)
  local accent = ns.Theme.GetColors().accent
  frame.Timer.Fill:SetTexture(ns.Theme.GetBarTexture())
  frame.Timer.Fill:SetVertexColor(accent[1], accent[2], accent[3], accent[4])
end

Skins.Register("Blizzard_FrameXML", "GroupLootHistoryFrame", {
  install = function(frame)
    Skins.Shell(frame)
    ns.Theme.WidgetSkins.CloseButton(frame.ClosePanelButton)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.Dropdown(frame.EncounterDropdown)
    Skins.Hide(frame.Timer.Border)
    ns.Theme.ApplyFont(frame.NoInfoString, "body")
    for _, region in ipairs({ frame.ResizeButton:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Arrow(frame.ResizeButton, "v")
    InstallHistoryRow(frame.PerfectAnimFrame)
    RefreshHistoryRows(frame)
    RefreshHistoryColors(frame)
    frame:SetDontSavePosition(true)
    -- Keep native drag/height-resize handlers and timer Fill width/visibility ownership.
  end,
  onShow = RefreshHistoryRows,
  onTheme = RefreshHistoryColors,
})
