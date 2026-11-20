local _, ns = ...
local Skins = ns.BlizzardSkins
local isForever = ns.Client.IsForever

local function RefreshTalentControlSurface(control, bg, border)
  local surface = Skins.Surface(control, true)
  surface:SetFrameLevel(control:GetFrameLevel() + 1)
  ns.Theme.SetSquareBackdrop(surface, {
    bg = bg,
    border = border,
  }, ns.Theme.GetEdgeSize())
end

local function RefreshTalentColors(frame)
  local colors = ns.Theme.GetColors()
  if not isForever then
    local background = colors.background
    frame.BottomBar:SetColorTexture(background[1], background[2], background[3], background[4])
  end

  RefreshTalentControlSurface(frame.LoadSystem.Dropdown, colors.control, colors.controlBorder)
  RefreshTalentControlSurface(frame.SearchBox, colors.control, colors.controlBorder)
  RefreshTalentControlSurface(frame.SearchPreviewContainer, {
    colors.control[1] * 0.7, colors.control[2] * 0.7, colors.control[3] * 0.7, 1,
  }, colors.controlBorder)
end

local function SkinPvPTalentRow(row)
  -- Keep native selection rings, availability colors and desaturation.
  ns.Theme.ApplyFont(row.Name, "body")
  ns.Theme.ApplyFont(row.New, "body")
  local highlight = row:GetHighlightTexture()
  highlight:SetColorTexture(1, 1, 1, 0.06)
  highlight:SetAllPoints(row)
end

local function SkinTalentSearchResult(row)
  Skins.Button(row, true)
  Skins.Hide(row.IconFrame)
  Skins.Icon(row.Icon)
  Skins.Font(row.Name)
  Skins.Selection(row.HighlightTexture, 0.18)
end

local skinnedSuggestedSearchButtons = setmetatable({}, { __mode = "k" })

local function SkinSuggestedTalentResults(preview)
  for button in preview.suggestedResultButtonsPool:EnumerateActive() do
    if not skinnedSuggestedSearchButtons[button] then
      skinnedSuggestedSearchButtons[button] = true
      Skins.Button(button, true)
      Skins.Font(button.Text)
      Skins.Selection(button.HighlightTexture, 0.18)
    end
  end
end



Skins.Register("Blizzard_PlayerSpells", "PlayerSpellsFrame.TalentsFrame", {
  install = function(frame)
    if not isForever then
      Skins.Hide(frame.BlackBG)
    end
    frame.Background:SetAlpha(0.75)
    Skins.Button(frame.ApplyButton, true)
    Skins.Button(frame.InspectCopyButton, true)
    Skins.Dropdown(frame.LoadSystem.Dropdown)
    Skins.DropdownMenu(frame.LoadSystem.Dropdown)
    Skins.EditBox(frame.SearchBox)
    frame.LoadSystem.Dropdown:SetHeight(frame.SearchBox:GetHeight())
    Skins.Button(frame.ResetButton, true)
    Skins.Button(frame.UndoButton, true)
    Skins.Font(frame.ClassCurrencyDisplay.CurrencyLabel, "header")
    if not isForever and frame.SpecCurrencyDisplay then
      Skins.Font(frame.SpecCurrencyDisplay.CurrencyLabel, "header")
    end
    Skins.Font(frame.HeroTalentsContainer.HeroSpecLabel, "header")
    local preview = frame.SearchPreviewContainer
    Skins.Chrome(preview)
    Skins.Hide(preview.BorderAnchor)
    Skins.Hide(preview.BotRightCorner)
    Skins.Surface(preview, true)
    Skins.ScrollRows(preview.ScrollBox, SkinTalentSearchResult, false)
    Skins.Hook(preview, "UpdateResultsDisplay", SkinSuggestedTalentResults)
    SkinSuggestedTalentResults(preview)
    if not isForever then
      local pvpTalentList = frame.PvPTalentList
      for _, key in ipairs({ "Top", "Middle", "Bottom" }) do
        Skins.Hide(pvpTalentList[key])
      end
      Skins.Surface(pvpTalentList)
      Skins.ScrollRows(pvpTalentList.ScrollBox, SkinPvPTalentRow, SkinPvPTalentRow)
    end
    RefreshTalentColors(frame)
  end,
  onTheme = RefreshTalentColors,
})
