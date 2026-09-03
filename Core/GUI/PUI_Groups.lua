local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins

local PUI_TREE_BUTTON_DESCRIPTIONS = {
  ["General"] = "Core size, texture, and behavior.",
  ["General settings"] = "Shared baseline options.",
  ["Name"] = "Name text and visibility rules.",
  ["Health"] = "Health text and health display.",
  ["Power"] = "Power text and power display.",
  ["Auras"] = "Buffs, debuffs, filters, and layout.",
  ["Castbar"] = "Castbar size, text, and behavior.",
  ["Pet"] = "Pet frame appearance and layout.",
  ["Target of Target"] = "Target target frame settings.",
  ["Focus Target"] = "Focus target frame settings.",
  ["Boss Stack Info"] = "Shared boss stack notes.",
  ["Party Pets"] = "Party pet frame settings.",
  ["Unit Frame Appearance"] = "Borders, colors, and shared visuals.",
  ["Global Text and Fonts"] = "Fonts, text scale, and style.",
  ["Unit Frame Textures"] = "Health, power, and absorb textures.",
  ["Anchors"] = "Frame anchors and offsets.",
  ["Behavior"] = "Visibility and runtime behavior.",
  ["Size"] = "Width, height, and spacing.",
  ["Anchoring"] = "Attachment point and offsets.",
  ["Cooldowns"] = "Cooldown viewer settings.",
  ["Buffs"] = "Buff viewer settings.",
  ["Bars"] = "Bar layout and display.",
  ["Icons"] = "Icon layout and display.",

  ["Essential Cooldowns"] = "Primary cooldown viewer styling.",
  ["Utility Cooldowns"] = "Utility cooldown viewer styling.",
  ["Buff Icons"] = "Buff icon viewer layout and text.",
  ["Buff Bars"] = "Tracked buff bar layout and style.",
  ["Custom trackers"] = "Create and tune custom tracked buttons and bars.",

  ["Size and rows"] = "Width, icon size, rows, and spacing.",
  ["Borders"] = "Icon border and frame border styling.",
  ["Toggles"] = "Swipe, count, keybind, and display rules.",
  ["Cooldown Font"] = "Cooldown timer font and offsets.",
  ["Keybind Font"] = "Keybind font and offsets.",
  ["Charge Font"] = "Charge count font and offsets.",
  ["Buff Bar"] = "Tracked buff bar visuals.",
  ["Glow"] = "Glow animation and color settings.",

  ["Create Bar"] = "Add a new custom tracked bar.",
  ["Controls"] = "Enable, rename, or delete this bar.",
  ["Spell Settings"] = "Tracked spell and visibility rules.",
  ["Bar Design"] = "Bar size, texture, and color.",
  ["Fonts"] = "Text font, outline, and offsets.",
  ["Indicator"] = "Duration or stack indicator behavior.",
  ["Indicator Settings"] = "Indicator size, spacing, and color.",
  ["No custom bars yet"] = "Create a bar to begin tracking.",

  ["Top box"] = "Top minimap data panel.",
  ["Second Wind"] = "Second Wind display settings.",
  ["Whirling Surge"] = "Whirling Surge display settings.",
}

local function _PUI_NormalizeTreeButtonLabel(label)
  label = tostring(label or "")
  label = label:gsub("|T.-|t%s*", "")
  label = label:gsub("|c%x%x%x%x%x%x%x%xPUI_PCM_TRACKER:[A-Z]+|r%s*", "")
  label = label:gsub("|c%x%x%x%x%x%x%x%x", "")
  label = label:gsub("|r", "")
  label = label:gsub("^%[Cooldown%]%s*", "")
  label = label:gsub("^%[Charge Cooldown%]%s*", "")
  label = label:gsub("^%[Duration%]%s*", "")
  label = label:gsub("^%[Stack%]%s*", "")
  return label:gsub("^%s+", ""):gsub("%s+$", "")
end

local function _PUI_GetTreeButtonText(button)
  return _PUI_NormalizeTreeButtonLabel(button.text:GetText() or "")
end

local function _PUI_GetTreeButtonDescription(label)
  return PUI_TREE_BUTTON_DESCRIPTIONS[tostring(label or "")] or ""
end

local function _PUI_TreeGroupUsesCustomCards(widget)
  local user = widget:GetUserDataTable()
  if user.appName == "PleebUI" then
    return true
  end

  local owner = widget.frame
  while owner do
    if owner.__puiOwnedApp == "PleebUI" or owner.__puiCustomOptionsWindow == true or owner.__puiNavShell or owner.__puiContentShell then
      return true
    end
    owner = owner:GetParent()
  end

  return false
end

local function _PUI_SkinGenericTreeButton(button, isSelected)
  local colors = Theme.GetColors()

  button.__puiUseTextureBackdrop = true
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")

  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.82 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.42 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], 0.90 }
      or { colors.border[1], colors.border[2], colors.border[3], 0.28 },
  }, Theme.GetEdgeSize())

  for _, key in ipairs({ "__puiTreeIconBack", "__puiTreeGlyph", "__puiSelectedAccent", "__puiTreeDescription" }) do
    local region = button[key]
    if region then
      region:Hide()
    end
  end

  local text = button.text
  text.__puiOptionsFontOwned = true
  Theme.ApplyFont(text, "label", 11)
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], isSelected and colors.text[4] or colors.text[4] * 0.82)
  text:Show()
end

local PCM_TRACKER_TREE_REGIONS = {
  "__puiPCMTrackerSpellIcon",
  "__puiPCMTrackerPreviewBack",
  "__puiPCMTrackerPreviewFill",
  "__puiPCMTrackerPreviewIcon",
  "__puiPCMTrackerSwipe",
  "__puiPCMTrackerDividerOne",
  "__puiPCMTrackerDividerTwo",
  "__puiPCMTrackerTitle",
}

local function _PUI_HidePCMTrackerTreeCard(button)
  for index = 1, #PCM_TRACKER_TREE_REGIONS do
    local region = button[PCM_TRACKER_TREE_REGIONS[index]]
    if region then
      region:Hide()
    end
  end
end

local function _PUI_GetPCMTrackerTreeData(button)
  local raw = button.text and button.text:GetText() or ""
  local kind = raw:match("PUI_PCM_TRACKER:([A-Z]+)")
  if not kind then
    return nil
  end

  return {
    kind = kind,
    texture = raw:match("|T([^:|]+):") or "134400",
    label = _PUI_NormalizeTreeButtonLabel(raw),
    unavailable = raw:sub(1, 10) == "|cff808080",
  }
end

local function _PUI_SkinPCMTrackerTreeButton(button, isSelected, data)
  local colors = Theme.GetColors()
  local edge = math.max(Theme.GetEdgeSize(), 2)

  button.__puiUseTextureBackdrop = true
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")
  button:SetHeight(38)
  button:SetHitRectInsets(0, 0, 0, 0)

  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.92 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.56 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], 1 }
      or { colors.border[1], colors.border[2], colors.border[3], 0.38 },
  }, edge)

  for _, key in ipairs({ "__puiTreeIconBack", "__puiTreeGlyph", "__puiTreeDescription" }) do
    local region = button[key]
    if region then
      region:Hide()
    end
  end

  if not button.__puiSelectedAccent then
    button.__puiSelectedAccent = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiSelectedAccent)
  end
  button.__puiSelectedAccent:ClearAllPoints()
  button.__puiSelectedAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.__puiSelectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  button.__puiSelectedAccent:SetWidth(3)
  button.__puiSelectedAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
  if isSelected then
    button.__puiSelectedAccent:SetVertexColor(
      colors.accent[1], colors.accent[2], colors.accent[3], 1
    )
    button.__puiSelectedAccent:Show()
  else
    button.__puiSelectedAccent:Hide()
  end

  if not button.__puiPCMTrackerSpellIcon then
    button.__puiPCMTrackerSpellIcon = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerSpellIcon)
  end
  local spellIcon = button.__puiPCMTrackerSpellIcon
  spellIcon:ClearAllPoints()
  spellIcon:SetPoint("LEFT", button, "LEFT", 8, 0)
  spellIcon:SetSize(24, 24)
  spellIcon:SetTexture(data.texture)
  spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  spellIcon:SetDesaturated(data.unavailable)
  spellIcon:SetAlpha(data.unavailable and 0.45 or 1)
  spellIcon:Show()

  if not button.__puiPCMTrackerPreviewBack then
    button.__puiPCMTrackerPreviewBack = button:CreateTexture(nil, "ARTWORK")
    button.__puiPCMTrackerPreviewBack:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewBack)
  end
  if not button.__puiPCMTrackerPreviewFill then
    button.__puiPCMTrackerPreviewFill = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.__puiPCMTrackerPreviewFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewFill)
  end
  if not button.__puiPCMTrackerPreviewIcon then
    button.__puiPCMTrackerPreviewIcon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerPreviewIcon)
  end
  if not button.__puiPCMTrackerSwipe then
    button.__puiPCMTrackerSwipe = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerSwipe:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerSwipe)
  end
  if not button.__puiPCMTrackerDividerOne then
    button.__puiPCMTrackerDividerOne = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerDividerOne:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerDividerOne)
  end
  if not button.__puiPCMTrackerDividerTwo then
    button.__puiPCMTrackerDividerTwo = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.__puiPCMTrackerDividerTwo:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerDividerTwo)
  end

  local back = button.__puiPCMTrackerPreviewBack
  local fill = button.__puiPCMTrackerPreviewFill
  local previewIcon = button.__puiPCMTrackerPreviewIcon
  local swipe = button.__puiPCMTrackerSwipe
  local dividerOne = button.__puiPCMTrackerDividerOne
  local dividerTwo = button.__puiPCMTrackerDividerTwo

  back:Hide()
  fill:Hide()
  previewIcon:Hide()
  swipe:Hide()
  dividerOne:Hide()
  dividerTwo:Hide()

  if data.kind == "ICON" then
    previewIcon:ClearAllPoints()
    previewIcon:SetPoint("LEFT", spellIcon, "RIGHT", 10, 0)
    previewIcon:SetSize(22, 22)
    previewIcon:SetTexture(data.texture)
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    previewIcon:SetDesaturated(data.unavailable)
    previewIcon:SetAlpha(data.unavailable and 0.45 or 1)
    previewIcon:Show()

    swipe:ClearAllPoints()
    swipe:SetPoint("TOPRIGHT", previewIcon, "TOPRIGHT", 0, 0)
    swipe:SetPoint("BOTTOMRIGHT", previewIcon, "BOTTOMRIGHT", 0, 0)
    swipe:SetWidth(11)
    swipe:SetVertexColor(0, 0, 0, data.unavailable and 0.35 or 0.62)
    swipe:Show()
  else
    back:ClearAllPoints()
    back:SetPoint("LEFT", spellIcon, "RIGHT", 10, 0)
    back:SetSize(42, 10)
    back:SetVertexColor(
      colors.background[1], colors.background[2], colors.background[3],
      data.unavailable and 0.35 or 0.9
    )
    back:Show()

    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", back, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(data.kind == "STACK" and 26 or 20)
    fill:SetVertexColor(
      colors.accent[1], colors.accent[2], colors.accent[3],
      data.unavailable and 0.35 or 0.9
    )
    fill:Show()

    dividerOne:ClearAllPoints()
    dividerOne:SetPoint("TOP", back, "TOP", 0, -1)
    dividerOne:SetPoint("BOTTOM", back, "BOTTOM", 0, 1)
    dividerOne:SetWidth(1)
    dividerOne:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.75)
    dividerOne:Show()

    if data.kind == "STACK" then
      dividerOne:ClearAllPoints()
      dividerOne:SetPoint("TOP", back, "TOP", -7, -1)
      dividerOne:SetPoint("BOTTOM", back, "BOTTOM", -7, 1)

      dividerTwo:ClearAllPoints()
      dividerTwo:SetPoint("TOP", back, "TOP", 7, -1)
      dividerTwo:SetPoint("BOTTOM", back, "BOTTOM", 7, 1)
      dividerTwo:SetWidth(1)
      dividerTwo:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.75)
      dividerTwo:Show()
    end
  end

  if not button.__puiPCMTrackerTitle then
    button.__puiPCMTrackerTitle = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.__puiPCMTrackerTitle.__puiOptionsFontOwned = true
    button.__puiPCMTrackerTitle:SetJustifyH("LEFT")
    button.__puiPCMTrackerTitle:SetJustifyV("MIDDLE")
    Theme.MarkCreatedWidgetChrome(button.__puiPCMTrackerTitle)
  end
  local title = button.__puiPCMTrackerTitle
  Theme.ApplyFont(title, "nav", 11)
  title:ClearAllPoints()
  if data.kind == "ICON" then
    title:SetPoint("LEFT", previewIcon, "RIGHT", 10, 0)
  else
    title:SetPoint("LEFT", back, "RIGHT", 10, 0)
  end
  title:SetPoint("RIGHT", button, "RIGHT", -10, 0)
  title:SetText(data.label)
  if data.unavailable then
    title:SetTextColor(
      colors.text[1], colors.text[2], colors.text[3], colors.text[4] * 0.45
    )
  else
    title:SetTextColor(
      colors.text[1], colors.text[2], colors.text[3],
      isSelected and colors.text[4] or colors.text[4] * 0.86
    )
  end
  title:Show()

  button.text:Hide()
  button.toggle:ClearAllPoints()
  button.toggle:SetPoint("RIGHT", button, "RIGHT", -8, 0)
  button.toggle:SetSize(12, 12)
end

function WidgetSkins.TreeButton(button, isSelected)
  local trackerData = _PUI_GetPCMTrackerTreeData(button)
  if button.__puiUseTreeCards == true and trackerData then
    button.__puiTreeCardLayoutKey = nil
    return _PUI_SkinPCMTrackerTreeButton(button, isSelected, trackerData)
  end

  _PUI_HidePCMTrackerTreeCard(button)
  button.text:Show()

  if button.__puiUseTreeCards ~= true then
    button.__puiTreeCardLayoutKey = nil
    return _PUI_SkinGenericTreeButton(button, isSelected)
  end

  local colors = Theme.GetColors()
  local edge = math.max(Theme.GetEdgeSize(), 2)

  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")

  local currentHeight = math.floor((tonumber(button:GetHeight()) or 0) + 0.5)
  if currentHeight ~= 46 then
    button:SetHeight(46)
  end

  if button.__puiTreeCardHitRectSet ~= true then
    button.__puiTreeCardHitRectSet = true
    button:SetHitRectInsets(0, 0, 0, 0)
  end

  local labelText = _PUI_GetTreeButtonText(button)
  local description = _PUI_GetTreeButtonDescription(labelText)
  local glyph = string.sub(labelText ~= "" and labelText or "?", 1, 1)
  local buttonWidth = math.floor((tonumber(button:GetWidth()) or 0) + 0.5)

  local layoutKey = table.concat({
    tostring(buttonWidth),
    tostring(labelText),
    tostring(description),
    tostring(button.toggle ~= nil),
  }, "\030")

  local layoutChanged = button.__puiTreeCardLayoutKey ~= layoutKey

  button.__puiUseTextureBackdrop = true
  Theme.SetSquareBackdrop(button, {
    bg = isSelected
      and { colors.control[1], colors.control[2], colors.control[3], 0.92 }
      or { colors.control[1], colors.control[2], colors.control[3], 0.56 },
    border = isSelected
      and { colors.accent[1], colors.accent[2], colors.accent[3], 1 }
      or { colors.border[1], colors.border[2], colors.border[3], 0.38 },
  }, edge)

  if not button.__puiTreeIconBack then
    button.__puiTreeIconBack = button:CreateTexture(nil, "ARTWORK")
    button.__puiTreeIconBack:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.MarkCreatedWidgetChrome(button.__puiTreeIconBack)
    layoutChanged = true
  end

  if layoutChanged then
    button.__puiTreeIconBack:ClearAllPoints()
    button.__puiTreeIconBack:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.__puiTreeIconBack:SetSize(22, 22)
  end

  button.__puiTreeIconBack:SetVertexColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    isSelected and 0.28 or 0.12
  )
  button.__puiTreeIconBack:Show()

  if not button.__puiTreeGlyph then
    button.__puiTreeGlyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.__puiTreeGlyph.__puiOptionsFontOwned = true
    Theme.MarkCreatedWidgetChrome(button.__puiTreeGlyph)
    button.__puiTreeGlyph:SetJustifyH("CENTER")
    button.__puiTreeGlyph:SetJustifyV("MIDDLE")
    Theme.ApplyFont(button.__puiTreeGlyph, "nav", 10)
    layoutChanged = true
  end

  if layoutChanged then
    button.__puiTreeGlyph:ClearAllPoints()
    button.__puiTreeGlyph:SetPoint("CENTER", button.__puiTreeIconBack, "CENTER", 0, 0)
  end

  if button.__puiTreeGlyph:GetText() ~= glyph then
    button.__puiTreeGlyph:SetText(glyph)
  end

  button.__puiTreeGlyph:SetTextColor(
    colors.accent[1],
    colors.accent[2],
    colors.accent[3],
    isSelected and 1 or 0.84
  )
  button.__puiTreeGlyph:Show()

  if not button.__puiSelectedAccent then
    button.__puiSelectedAccent = button:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(button.__puiSelectedAccent)
    layoutChanged = true
  end

  if layoutChanged then
    button.__puiSelectedAccent:ClearAllPoints()
    button.__puiSelectedAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.__puiSelectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.__puiSelectedAccent:SetWidth(3)
    button.__puiSelectedAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
  end

  if isSelected then
    local accent = colors.accent
    button.__puiSelectedAccent:SetVertexColor(accent[1], accent[2], accent[3], 1)
    button.__puiSelectedAccent:Show()
  else
    button.__puiSelectedAccent:Hide()
  end

  if layoutChanged then
    button.toggle:ClearAllPoints()
    button.toggle:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.toggle:SetSize(12, 12)
  end

  local normal = button.toggle:GetNormalTexture()
  if normal then
    local accent = colors.accent
    normal:SetVertexColor(accent[1], accent[2], accent[3], accent[4])
  end

  local pushed = button.toggle:GetPushedTexture()
  if pushed then
    local accent = colors.accent
    pushed:SetVertexColor(accent[1], accent[2], accent[3], accent[4])
  end

  local text = button.text
  text.__puiOptionsFontOwned = true

  if layoutChanged or text.__puiTreeCardFontApplied ~= true then
    text.__puiTreeCardFontApplied = true
    Theme.ApplyFont(text, "nav", 12)
  end

  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], isSelected and colors.text[4] or colors.text[4] * 0.86)

  if layoutChanged then
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", button.__puiTreeIconBack, "TOPRIGHT", 10, 5)
    text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
  end

  text:SetJustifyH("LEFT")

  if text.__puiTreeCardShadowApplied ~= true then
    text.__puiTreeCardShadowApplied = true
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
  end

  if not button.__puiTreeDescription then
    button.__puiTreeDescription = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.__puiTreeDescription.__puiOptionsFontOwned = true
    Theme.MarkCreatedWidgetChrome(button.__puiTreeDescription)
    button.__puiTreeDescription:SetJustifyH("LEFT")
    button.__puiTreeDescription:SetJustifyV("TOP")
    button.__puiTreeDescription:SetWordWrap(true)
    Theme.ApplyFont(button.__puiTreeDescription, "tiny", 9)
    layoutChanged = true
  end

  if layoutChanged then
    button.__puiTreeDescription:ClearAllPoints()
    button.__puiTreeDescription:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    button.__puiTreeDescription:SetPoint("RIGHT", text, "RIGHT", 0, 0)
    button.__puiTreeDescription:SetHeight(20)
  end

  if button.__puiTreeDescription:GetText() ~= description then
    button.__puiTreeDescription:SetText(description)
  end

  button.__puiTreeDescription:SetTextColor(
    colors.text[1],
    colors.text[2],
    colors.text[3],
    isSelected and colors.text[4] * 0.52 or colors.text[4] * 0.38
  )
  button.__puiTreeDescription:SetShown(description ~= "")
  button.__puiTreeCardLayoutKey = layoutKey
end

function WidgetSkins.InlineGroup(widget)
  local colors = Theme.GetColors()
  local metrics = Theme.GetControlMetrics()
  local edge = math.max(Theme.GetEdgeSize(), 2)
  local frame = widget.frame
  local outer = widget.content:GetParent()
  local title = widget.titletext
  local padX = metrics.inlineGroupPaddingX
  local padY = metrics.inlineGroupPaddingY
  local hasTitle = title:GetText() ~= ""
  local contentTopInset = hasTitle and (padY + 4) or padY

  outer:SetBackdrop(nil)
  outer:SetBackdropColor(0, 0, 0, 0)
  outer:SetBackdropBorderColor(0, 0, 0, 0)

  local bg = Theme.EnsureBackdropFrame(outer)
  Theme.SetSquareBackdrop(outer, {
    bg = { 0, 0, 0, 0 },
    border = { 0, 0, 0, 0 },
  }, edge)

  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  bg:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", 0, 0)
  bg:SetFrameLevel(math.max(outer:GetFrameLevel() - 1, 0))

  local accent = outer.__puiInlineAccent
  if not accent then
    accent = outer:CreateTexture(nil, "ARTWORK")
    Theme.MarkCreatedWidgetChrome(accent)
    outer.__puiInlineAccent = accent
  end

  accent:ClearAllPoints()
  accent:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  accent:SetPoint("TOPRIGHT", outer, "TOPRIGHT", 0, 0)
  accent:SetHeight(2)
  accent:SetTexture("Interface\\Buttons\\WHITE8x8")
  accent:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.35)
  accent:Show()

  if outer.__puiInlineDivider then
    outer.__puiInlineDivider:Hide()
  end

  widget.content:ClearAllPoints()
  widget.content:SetPoint("TOPLEFT", outer, "TOPLEFT", padX, -contentTopInset)
  widget.content:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -padX, -padY)

  title:ClearAllPoints()
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", padX, 0)
  title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padX, 0)
  title.__puiOptionsFontOwned = true
  title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  title:SetJustifyH("LEFT")
  title:SetJustifyV("MIDDLE")
  Theme.ApplyFont(title, "header")
  title:SetHeight(math.max(18, math.ceil(title:GetStringHeight() or 0) + 2))
  title:SetShown(hasTitle)
end

local function _PUI_StyleTreeButtons(widget)
  local colors = Theme.GetColors()
  local accent = colors.accent
  local metrics = Theme.GetControlMetrics()
  local buttonGap = metrics.treeButtonGap
  local topInset = metrics.treeGroupTopInset
  local useCustomCards = _PUI_TreeGroupUsesCustomCards(widget)
  local buttons = widget.buttons
  local prev
  local treeWidth = math.floor((tonumber(widget.treeframe:GetWidth()) or 0) + 0.5)
  local treeLayoutKey = table.concat({
    tostring(useCustomCards == true),
    tostring(widget.showscroll == true),
    tostring(buttonGap),
    tostring(topInset),
    tostring(treeWidth),
    tostring(#buttons),
  }, "\030")

  for i = 1, #buttons do
    local button = buttons[i]

    Theme.CaptureCreatedWidgetFrameTree(widget, button)

    if button:GetParent() ~= widget.treeframe then
      button:SetParent(widget.treeframe)
      button.__puiTreeButtonLayoutKey = nil
    end

    if button:IsShown() and useCustomCards then
      local buttonLayoutKey = treeLayoutKey .. "\030" .. tostring(i) .. "\030" .. tostring(prev or "root")
      if button.__puiTreeButtonLayoutKey ~= buttonLayoutKey then
        button.__puiTreeButtonLayoutKey = buttonLayoutKey
        button:ClearAllPoints()

        if prev then
          button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -buttonGap)
          button:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -buttonGap)
        elseif widget.showscroll then
          button:SetPoint("TOPLEFT", widget.treeframe, "TOPLEFT", 0, -topInset)
          button:SetPoint("TOPRIGHT", widget.treeframe, "TOPRIGHT", -22, -topInset)
        else
          button:SetPoint("TOPLEFT", widget.treeframe, "TOPLEFT", 0, -topInset)
          button:SetPoint("TOPRIGHT", widget.treeframe, "TOPRIGHT", 0, -topInset)
        end
      end

      prev = button
    else
      button.__puiTreeButtonLayoutKey = nil
    end

    button.__puiUseTreeCards = useCustomCards
    WidgetSkins.TreeButton(button, button.selected == true)

    local normal = button.toggle:GetNormalTexture()
    if normal then
      normal:SetVertexColor(accent[1], accent[2], accent[3], accent[4])
    end

    local pushed = button.toggle:GetPushedTexture()
    if pushed then
      pushed:SetVertexColor(accent[1], accent[2], accent[3], accent[4])
    end
  end
end

local function _PUI_HandleTreeGroupClick(widget, _, uniquevalue, wasSelected)
  if not wasSelected then
    Addon:HandleOptionsGroupSelection(widget, uniquevalue)
  end
end

function WidgetSkins.TreeGroup(widget)
  if widget.__puiAceGUIOwnedByPleebUI ~= true then
    return
  end

  widget:SetCallback("OnClick", _PUI_HandleTreeGroupClick)

  if not widget.__puiTreeRefreshHooked then
    widget.__puiTreeRefreshHooked = true
    hooksecurefunc(widget, "RefreshTree", function(self)
      if self.__puiAceGUIOwnedByPleebUI == true then
        WidgetSkins.TreeGroup(self)
      end
    end)
  end

  local treeframe = widget.treeframe
  local border = widget.border
  local metrics = Theme.GetControlMetrics()
  local status = widget.status or widget.localstatus
  local treeWidth = status.treewidth or metrics.treeGroupWidth

  border:SetBackdrop(nil)
  border:SetBackdropColor(0, 0, 0, 0)
  border:SetBackdropBorderColor(0, 0, 0, 0)

  treeframe:SetWidth(treeWidth)
  treeframe:SetBackdrop(nil)
  treeframe:SetBackdropColor(0, 0, 0, 0)
  treeframe:SetBackdropBorderColor(0, 0, 0, 0)

  for i = 1, treeframe:GetNumRegions() do
    local region = select(i, treeframe:GetRegions())
    if region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end

  WidgetSkins.Scrollbar(widget.scrollbar)
  widget.__puiTreeChromeHooked = true
  _PUI_StyleTreeButtons(widget)
end
