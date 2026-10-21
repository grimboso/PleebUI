local _, ns = ...

local Core = ns.ActionBarsCore
local Theme = ns.Theme
local Preview = {}
ns.ActionBarsPreview = Preview
local P = select(1, ns.Pleebug:DropIn(Preview))
local SAMPLE_KEYS = {
  "1", "SHIFT-2", "ALT-3", "CTRL-4", "SHIFT-ALT-5", "SHIFT-CTRL-6",
  "ALT-CTRL-7", "SHIFT-ALT-CTRL-8", "9", "10", "1", "2",
}

local function StyleSampleText(text, skin, prefix)
  ns.Theme.SetRuntimeFont(
    text,
    Core:ResolveFont(skin[prefix .. "FontFace"]),
    Theme.ResolveFontSize(skin[prefix .. "FontSize"], "actionBars"),
    skin[prefix .. "FontOutline"] or ""
  )
  text:SetTextColor(unpack(skin[prefix .. "FontColor"]))
end

function Preview.RefreshIcons()
  local box = Preview.box
  if not box or not box:IsVisible() then return end

  local sourceKey = box.barKey == "shared" and "1" or box.barKey
  local sourceBar
  for _, bar in pairs(Core.bars) do
    if bar.dbKey == sourceKey then
      sourceBar = bar
      break
    end
  end
  if sourceKey == "stance" and GetNumShapeshiftForms() == 0 then
    sourceBar = nil
  end

  local special = box.barKey == "pet" or box.barKey == "stance"
  local hasBindings = false
  local hasMacros = false
  for index, button in ipairs(box.buttons) do
    local source = sourceBar and sourceBar.buttons[index]
    local key = source and source:GetHotkey()
    button.previewHotkey = key
    if index <= box.previewCount and key and key ~= "" then
      hasBindings = true
    end
    if source then
      button.icon:SetTexture(source.icon:GetTexture())
      button.icon:SetShown(source.icon:IsShown())
    else
      button.icon:SetTexture(nil)
      button.icon:Hide()
    end
    if source and not special then
      local macroName = source.Name:GetText()
      button.macro:SetText(macroName)
      -- Restricted text is forwarded unchanged; only ordinary text can be checked for emptiness.
      if index <= box.previewCount
        and (issecretvalue(macroName) or (macroName and macroName ~= ""))
      then
        hasMacros = true
      end
    else
      button.macro:SetText("")
    end
  end

  if not special and not hasMacros then
    box.buttons[1].macro:SetText("Macro")
  end

  for index, button in ipairs(box.buttons) do
    button.hotkey:SetText(hasBindings and (button.previewHotkey or "")
      or Core.LibKeyBound:ToShortKey(SAMPLE_KEYS[index]))
    button.macro:SetShown(not special and box.skin.showMacroText)
  end
end

function Preview.QueueIconRefresh(barKey)
  local box = Preview.box
  if not box or not box:IsVisible() then return end
  if barKey == "standard" then
    if box.barKey == "pet" or box.barKey == "stance" then return end
  elseif box.barKey ~= barKey then
    return
  end
  if box.iconsPending then return end

  box.iconsPending = true
  box:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    self.iconsPending = nil
    if self.barKey == "stance" and self.previewCount ~= math.max(1, GetNumShapeshiftForms()) then
      Preview.Refresh()
    else
      Preview.RefreshIcons()
    end
  end)
end

function Preview.Refresh()
  local box = Preview.box
  if not box or not box:IsVisible() then return end

  local db = Core:GetDB()
  local barKey = box.barKey
  local special = barKey == "pet" or barKey == "stance"
  local skin
  if special then
    skin = Core:GetSpecialSkin(barKey, barKey == "pet" and 17 or 23)
  else
    skin = Core:GetEffectiveSkin(barKey, 35)
  end

  local count = barKey == "pet" and db.bars.pet.buttonCount
    or barKey == "stance" and math.max(1, GetNumShapeshiftForms())
    or skin.iconsPerBar
  local columns = barKey == "stance" and count or math.min(skin.iconsPerRow, count)
  local rows = math.ceil(count / columns)
  local paddingX = skin.showBarBackground and ns.Pixel.Round(Core.PADDING_X) or 0
  local paddingY = skin.showBarBackground and ns.Pixel.Round(Core.PADDING_Y) or 0
  local width = columns * skin.iconSize + (columns - 1) * skin.iconSpacing + paddingX * 2
  local height = rows * skin.iconSize + (rows - 1) * skin.iconSpacing + paddingY * 2
  local canvas = box:GetCanvas()
  local bar = box.sampleBar
  local host = box:GetParent()
  local strata = host:GetFrameStrata()
  box:SetFrameStrata(strata)
  box:SetFrameLevel(host:GetFrameLevel() + 1)
  canvas:SetFrameStrata(strata)
  canvas:SetFrameLevel(box:GetFrameLevel() + 2)
  bar:SetFrameStrata(strata)
  bar:SetFrameLevel(canvas:GetFrameLevel() + 2)
  Theme.SyncBackdropFrame(box, box._puiBg)
  Theme.SyncBackdropFrame(canvas, canvas._puiBg)
  -- Live bars inherit UIParent scale; previews also inherit the options window scale.
  local runtimeScale = UIParent:GetEffectiveScale() / canvas:GetEffectiveScale()
  local fitScale = math.min(1, math.max(1, canvas:GetWidth() - 20) / (width * runtimeScale),
    math.max(1, canvas:GetHeight() - 20) / (height * runtimeScale))

  bar:SetSize(width, height)
  bar:SetScale(runtimeScale * fitScale)
  Core:ApplyBackdrop(box.sample, skin)
  box.sample.backdrop:SetFrameStrata(strata)
  box.sample.backdrop:SetFrameLevel(bar:GetFrameLevel() - 1)

  local override = db.overrides[barKey]
  local title = barKey == "shared" and "Shared action bar preview"
    or barKey == "pet" and "Pet bar preview"
    or barKey == "stance" and "Stance bar preview"
    or "Bar " .. barKey .. " preview"
  box:SetTitle(title)
  local description = override and override.useCustom == true and "Custom settings." or "Shared settings."
  description = description .. (barKey == "shared" and " Main Action Bar icons and keybinds."
    or " Live bar icons and keybinds.") .. " Unbound bars use sample keybinds."
  if barKey == "stance" and GetNumShapeshiftForms() == 0 then
    description = description .. " No stances available."
  end
  if fitScale < 1 then
    description = description .. " Scaled to " .. math.floor(fitScale * 100 + 0.5) .. "% to fit."
  end
  box:SetDescription(description)

  local showCooldown = barKey ~= "pet" or db.bars.pet.showCooldowns ~= false
  for index, button in ipairs(box.buttons) do
    button:SetFrameStrata(strata)
    button:SetFrameLevel(bar:GetFrameLevel() + 1)
    button:SetShown(index <= count)
    if index <= count then
      local column = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      button:ClearAllPoints()
      button:SetSize(skin.iconSize, skin.iconSize)
      button:SetPoint("TOPLEFT", bar, "TOPLEFT",
        paddingX + column * (skin.iconSize + skin.iconSpacing),
        -paddingY - row * (skin.iconSize + skin.iconSpacing))
      ns.IconSkin.ApplyBorder(button, {
        thickness = skin.borderSize,
        useThemeColor = false,
        colorOverride = skin.borderColor,
      })
      StyleSampleText(button.hotkey, skin, "hotkey")
      StyleSampleText(button.macro, skin, "macro")
      StyleSampleText(button.count, skin, "charge")
      button.hotkey:SetShown(skin.showHotkeyText)
      button.count:SetShown(not special and skin.showChargeText and index == math.min(count, 3))
    end
  end

  box.skin = skin
  box.previewCount = count
  Preview.RefreshIcons()
  local firstButton = math.min(count, 4)
  for index, cooldown in ipairs(box.sampleCooldowns) do
    cooldown.previewEnabled = false
    cooldown:Clear()
    local buttonIndex = index == 1 and firstButton or (firstButton < count and firstButton + 1 or 1)
    local cooldownButton = box.buttons[buttonIndex]
    cooldown:SetParent(cooldownButton)
    cooldown:SetFrameStrata(strata)
    cooldown:SetFrameLevel(cooldownButton:GetFrameLevel() + 1)
    ns.IconSkin.SquareCooldown(cooldown)
    ns.IconSkin.StyleCooldownText(cooldown, {
      font = Core:ResolveFont(skin.cooldownFontFace),
      size = skin.cooldownFontSize,
      flags = skin.cooldownFontOutline or "",
      color = skin.cooldownFontColor,
      scope = "actionBars",
    })
    cooldown:SetHideCountdownNumbers(not skin.showCooldownText)
    cooldown.previewEnabled = showCooldown and index <= box.sampleCooldownCount and (index == 1 or count > 1)
    cooldown.previewDuration = index == 1 and 5 or 8
    if cooldown.previewEnabled then
      cooldown:SetCooldown(GetTime() - (index - 1) * 2, cooldown.previewDuration)
    else
      cooldown:Hide()
    end
  end
  bar:SetAlpha(skin.fadeOutEnabled and not box.hovered and skin.fadeOutAlpha or skin.alpha)
end

local PREVIEW_TEXT = {
  hotkey = { region = "hotkey", visible = "showHotkeyText" },
  macro = { region = "macro", visible = "showMacroText" },
  charge = { region = "count", visible = "showChargeText" },
}

local function ApplyPreviewText(box, changes)
  local skin = box.skin
  local special = box.barKey == "pet" or box.barKey == "stance"
  for role, change in pairs(changes) do
    if role == "cooldown" then
      for _, cooldown in ipairs(box.sampleCooldowns) do
        if change.font then
          ns.IconSkin.StyleCooldownText(cooldown, {
            font = Core:ResolveFont(skin.cooldownFontFace), size = skin.cooldownFontSize,
            flags = skin.cooldownFontOutline or "", color = skin.cooldownFontColor, scope = "actionBars",
          })
        end
        if change.visibility then cooldown:SetHideCountdownNumbers(not skin.showCooldownText) end
      end
    else
      local definition = PREVIEW_TEXT[role]
      for index, button in ipairs(box.buttons) do
        local text = button[definition.region]
        if change.font then StyleSampleText(text, skin, role) end
        if change.visibility then
          local visible = skin[definition.visible]
          if role == "macro" then visible = visible and not special
          elseif role == "charge" then visible = visible and not special and index == math.min(box.previewCount, 3) end
          text:SetShown(visible)
        end
      end
    end
  end
end

function Preview.ApplyOptions(flags)
  local box = Preview.box
  if not box or not box:IsVisible() then return end
  local selected = flags.bars and flags.bars[box.barKey]
  for key in pairs(flags) do
    if key ~= "bars" and key ~= "text" and key ~= "buttonLock" and key ~= "keyDown"
      and key ~= "grid" and key ~= "countdown" and key ~= "tooltips" and key ~= "alpha" and key ~= "spellUI"
    then
      Preview.Refresh()
      return
    end
  end
  if selected then
    for key in pairs(selected) do
      if key ~= "text" and key ~= "petCooldowns" and key ~= "alpha" then
        Preview.Refresh()
        return
      end
    end
  end
  if flags.text or flags.alpha or selected and (selected.text or selected.alpha) then
    local special = box.barKey == "pet" or box.barKey == "stance"
    box.skin = special and Core:GetSpecialSkin(box.barKey, box.barKey == "pet" and 17 or 23)
      or Core:GetEffectiveSkin(box.barKey, 35)
    if flags.text then ApplyPreviewText(box, flags.text) end
    if selected and selected.text then ApplyPreviewText(box, selected.text) end
    if flags.alpha or selected and selected.alpha then
      local skin = box.skin
      box.sampleBar:SetAlpha(skin.fadeOutEnabled and not box.hovered and skin.fadeOutAlpha or skin.alpha)
    end
  end
  if selected and selected.petCooldowns then
    for index, cooldown in ipairs(box.sampleCooldowns) do
      cooldown.previewEnabled = Core:GetDB().bars.pet.showCooldowns ~= false
        and index <= box.sampleCooldownCount and (index == 1 or box.previewCount > 1)
      if cooldown.previewEnabled then cooldown:SetCooldown(GetTime(), cooldown.previewDuration)
      else cooldown:Clear(); cooldown:Hide() end
    end
  end
end

function Preview.Build(addon, optionsFrame, shell, path, sampleCooldownCount)
  local host = shell.previewHost
  local box = shell.__puiActionBarsPreviewBox
  if not box then
    box = ns.PreviewBox.Create(host)
    box:Hide()
    shell.__puiActionBarsPreviewBox = box
    box.buttons = {}
    local canvas = box:GetCanvas()
    canvas:SetClipsChildren(true)
    local bar = CreateFrame("Frame", nil, canvas)
    bar:SetPoint("CENTER", canvas, "CENTER")
    box.sampleBar = bar
    box.sample = { frame = bar }
    bar:SetMouseMotionEnabled(true)
    bar:SetMouseClickEnabled(false)
    bar:SetScript("OnEnter", function()
      box.hovered = true
      bar:SetAlpha(box.skin.alpha)
    end)
    bar:SetScript("OnLeave", function()
      box.hovered = false
      bar:SetAlpha(box.skin.fadeOutEnabled and box.skin.fadeOutAlpha or box.skin.alpha)
    end)
    box:SetScript("OnShow", function(self)
      self:RegisterEvent("UPDATE_BINDINGS")
      self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
      Preview.Refresh()
    end)
    box:SetScript("OnEvent", Preview.RefreshIcons)
    box:SetScript("OnHide", function(self)
      self:UnregisterAllEvents()
      for _, cooldown in ipairs(self.sampleCooldowns) do
        cooldown.previewEnabled = false
        cooldown:Clear()
      end
      self.hovered = false
      self.iconsPending = nil
      self:SetScript("OnUpdate", nil)
    end)
    canvas:SetScript("OnSizeChanged", Preview.Refresh)

    for index = 1, 12 do
      local button = CreateFrame("Frame", nil, bar)
      local icon = button:CreateTexture(nil, "ARTWORK")
      button.icon = icon
      icon:SetAllPoints(button)
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      button.hotkey = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
      button.macro = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
      button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
      button.count:SetText("3")
      box.buttons[index] = button
    end

    box.sampleCooldowns = {}
    for index = 1, 2 do
      local cooldown = CreateFrame("Cooldown", nil, box.buttons[index], "CooldownFrameTemplate")
      cooldown:SetDrawSwipe(true)
      cooldown:SetDrawEdge(false)
      cooldown:SetDrawBling(false)
      cooldown:SetMinimumCountdownDuration(0)
      cooldown:SetScript("OnCooldownDone", function(self)
        if self.previewEnabled and box:IsVisible() then
          self:SetCooldown(GetTime(), self.previewDuration)
        end
      end)
      box.sampleCooldowns[index] = cooldown
    end
  end

  box.barKey = path[2] == "special" and (path[3] or "pet")
    or path[2] == "general" and "shared"
    or path[2] or "shared"
  box.sampleCooldownCount = sampleCooldownCount or 1
  box:SetParent(host)
  box:ClearAllPoints()
  box:SetAllPoints(host)
  Preview.box = box
  box:Show()
  Preview.Refresh()
  return true
end

StyleSampleText = P:Def("StyleSampleText", StyleSampleText)
Preview.RefreshIcons = P:Def("Preview.RefreshIcons", Preview.RefreshIcons)
Preview.QueueIconRefresh = P:Def("Preview.QueueIconRefresh", Preview.QueueIconRefresh)
Preview.Refresh = P:Def("Preview.Refresh", Preview.Refresh)
Preview.ApplyOptions = P:Def("Preview.ApplyOptions", Preview.ApplyOptions)
ApplyPreviewText = P:Def("ApplyPreviewText", ApplyPreviewText)
Preview.Build = P:Def("Preview.Build", Preview.Build)
