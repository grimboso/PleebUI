local _, ns = ...

local Core = ns.ActionBarsCore
local Theme = ns.Theme
local Preview = {}
ns.ActionBarsPreview = Preview
local P = select(1, ns.Pleebug:DropIn(Preview))

local function StyleSampleText(text, skin, prefix)
  text:SetFont(
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

  for index, button in ipairs(box.buttons) do
    local source = sourceBar and sourceBar.buttons[index]
    if source then
      button.icon:SetTexture(source.icon:GetTexture())
      button.icon:SetShown(source.icon:IsShown())
    else
      button.icon:SetTexture(nil)
      button.icon:Hide()
    end
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
  local paddingX = skin.showBarBackground and Core.PADDING_X or 0
  local paddingY = skin.showBarBackground and Core.PADDING_Y or 0
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
  local scale = math.min(1, math.max(1, canvas:GetWidth() - 20) / width,
    math.max(1, canvas:GetHeight() - 20) / height)

  bar:SetSize(width, height)
  bar:SetScale(scale)
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
  description = description .. (barKey == "shared" and " Main Action Bar icons. Sample text."
    or " Live bar icons. Sample text.")
  if barKey == "stance" and GetNumShapeshiftForms() == 0 then
    description = description .. " No stances available."
  end
  if scale < 1 then
    description = description .. " Scaled to " .. math.floor(scale * 100 + 0.5) .. "% to fit."
  end
  box:SetDescription(description)

  local showCooldown = skin.showCooldownText
    and (barKey ~= "pet" or db.bars.pet.showCooldowns ~= false)
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
      StyleSampleText(button.cooldownText, skin, "cooldown")
      button.hotkey:SetShown(skin.showHotkeyText)
      button.macro:SetShown(not special and skin.showMacroText and index == 1)
      button.count:SetShown(not special and skin.showChargeText and index == math.min(count, 3))
      button.cooldownText:SetShown(showCooldown and index == math.min(count, 4))
    end
  end

  box.skin = skin
  box.previewCount = count
  Preview.RefreshIcons()
  bar:SetAlpha(skin.fadeOutEnabled and not box.hovered and skin.fadeOutAlpha or skin.alpha)
end

function Preview.Build(addon, optionsFrame, shell, path)
  local host = shell.previewHost
  local box = shell.__puiActionBarsPreviewBox
  if not box then
    box = ns.PreviewBox.Create(host)
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
    box:SetScript("OnShow", Preview.Refresh)
    box:SetScript("OnHide", function(self)
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
      button.hotkey:SetText(index == 1 and "S-1" or tostring(index))
      button.macro = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
      button.macro:SetText("Macro")
      button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
      button.count:SetText("3")
      button.cooldownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.cooldownText:SetPoint("CENTER", button, "CENTER")
      button.cooldownText:SetText("8.5")
      box.buttons[index] = button
    end
  end

  box.barKey = path[2] == "special" and (path[3] or "pet")
    or path[2] == "general" and "shared"
    or path[2] or "shared"
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
Preview.Build = P:Def("Preview.Build", Preview.Build)
