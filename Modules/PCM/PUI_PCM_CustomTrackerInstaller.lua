local _, ns = ...

local Addon = ns.Addon
local Cooldowns = ns.Modules.CooldownManager
local Theme = ns.Theme
local AceHooks = ns.AceHooks
local AceGUI = LibStub("AceGUI-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

local Installer = {}
ns.PCMCustomTrackerInstaller = Installer

local frame
local controls
local draft
local page = 1
local previewState = "COOLDOWN"
local previewStartedAt = 0
local PREVIEW_SECONDS = 3
local PREVIEW_GLOW_KEY = "PUI_CustomTrackerInstaller"

local PAGES = {
  "Choose a widget",
  "Choose what to track",
  "Choose a spell",
  "Style",
  "Behavior",
}

local GLOW_STYLES = {
  NONE = "None",
  PROC = "Proc",
  PIXEL = "Pixel",
  AUTOCAST = "Autocast",
}

local GLOW_ORDER = { "NONE", "PROC", "PIXEL", "AUTOCAST" }

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or fallback
  return {
    tonumber(color[1] or color.r) or 1,
    tonumber(color[2] or color.g) or 1,
    tonumber(color[3] or color.b) or 1,
    tonumber(color[4] or color.a) or 1,
  }
end

local function NewDraft()
  return {
    presentation = "BUTTON",
    kind = "cooldown",
    auraTrackMode = "player_buff",
    spellID = nil,
    maximum = 3,
    width = 250,
    height = 25,
    showBarIcon = true,
    combatOnly = false,
    showOnlyWhenActive = false,
    showReady = true,
    showCooldown = true,
    showActive = true,
    readyAlpha = 100,
    cooldownAlpha = 35,
    activeAlpha = 100,
    desaturateReady = false,
    desaturateCooldown = true,
    desaturateActive = false,
    readyGlowStyle = "NONE",
    cooldownGlowStyle = "NONE",
    activeGlowStyle = "PROC",
    addColorShift = false,
    hideViewerIcon = false,
    icon = {
      size = 40,
      group = 0,
      visibility = "ALWAYS",
      combatOnly = false,
      outOfCombatAlpha = 0,
      readyAlpha = 100,
      onCooldownAlpha = 35,
      desaturateReady = false,
      desaturateCooldown = true,
      showSwipe = true,
      showDuration = true,
      showCount = true,
      showPips = false,
      showStackStrip = true,
      showTooltip = true,
      readyGlowStyle = "NONE",
      cooldownGlowStyle = "NONE",
      activeAuraEnabled = true,
      activeAuraAlpha = 100,
      activeAuraDesaturate = false,
      activeAuraGlowStyle = "PROC",
      readyGlowColor = { 0.25, 0.75, 1, 1 },
      cooldownGlowColor = { 1, 0.55, 0.1, 1 },
      activeAuraGlowColor = { 1, 0.55, 0.1, 1 },
    },
  }
end

local function StopPreviewGlow()
  if not frame then return end
  for _, target in ipairs({ frame.PreviewButton, frame.PreviewBar }) do
    LCG.PixelGlow_Stop(target, PREVIEW_GLOW_KEY)
    LCG.AutoCastGlow_Stop(target, PREVIEW_GLOW_KEY)
    LCG.ProcGlow_Stop(target, PREVIEW_GLOW_KEY)
  end
end

local function StartPreviewGlow(target, style, color)
  StopPreviewGlow()
  if style == "NONE" then return end
  color = CopyColor(color, { 1, 0.55, 0.1, 1 })
  if style == "PIXEL" then
    LCG.PixelGlow_Start(target, color, 8, 0.25, nil, 2, 0, 0, true, PREVIEW_GLOW_KEY, 8)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(target, color, 8, 0.25, 1, 0, 0, PREVIEW_GLOW_KEY, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(target, {
      key = PREVIEW_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  end
end

local function GetSpellTexture()
  local spellID = tonumber(draft.spellID)
  return spellID and C_Spell.GetSpellTexture(spellID) or 134400
end

local function ApplyDraftToIcon()
  local icon = draft.icon
  icon.readyAlpha = draft.showReady and draft.readyAlpha or 0
  icon.onCooldownAlpha = draft.showCooldown and draft.cooldownAlpha or 0
  icon.desaturateReady = draft.desaturateReady == true
  icon.desaturateCooldown = draft.desaturateCooldown == true
  icon.readyGlowStyle = draft.readyGlowStyle
  icon.cooldownGlowStyle = draft.cooldownGlowStyle
  icon.activeAuraEnabled = (draft.kind == "cooldown" or draft.kind == "charge")
    and draft.showActive == true
  icon.activeAuraAlpha = draft.activeAlpha
  icon.activeAuraDesaturate = draft.desaturateActive == true
  icon.activeAuraGlowStyle = draft.activeGlowStyle
  icon.combatOnly = draft.combatOnly == true
  icon.visibility = (draft.kind == "duration" or draft.kind == "stack")
    and draft.showOnlyWhenActive == true and "ACTIVE" or "ALWAYS"
  icon.showCount = draft.kind == "charge" or draft.kind == "stack"
  icon.showStackStrip = draft.kind == "stack" and draft.addColorShift == true
end

local function PreviewStates()
  if draft.kind == "duration" or draft.kind == "stack" then
    return { "ACTIVE", "INACTIVE" }
  end
  return { draft.kind == "charge" and "RECHARGING" or "COOLDOWN", "READY", "ACTIVE" }
end

local function PreviewStateLabel(state)
  if state == "ACTIVE" then return "Aura active" end
  if state == "READY" then return draft.kind == "charge" and "Full charges" or "Ready" end
  if state == "RECHARGING" then return "Recharging" end
  if state == "INACTIVE" then return "Aura inactive" end
  return "On cooldown"
end

local function ApplyPreviewState(state)
  if not frame or not draft then return end
  ApplyDraftToIcon()
  previewState = state
  previewStartedAt = GetTime()
  frame.PreviewState:SetText(PreviewStateLabel(state))

  local button = frame.PreviewButton
  local bar = frame.PreviewBar
  local isButton = draft.presentation == "BUTTON"
  button:SetShown(isButton)
  bar:SetShown(not isButton)
  StopPreviewGlow()

  local texture = GetSpellTexture()
  local active = state == "ACTIVE"
  local ready = state == "READY" or state == "INACTIVE"
  local alpha = active and draft.activeAlpha or ready and draft.readyAlpha or draft.cooldownAlpha
  local shown = active and draft.showActive or ready and draft.showReady or draft.showCooldown
  if state == "INACTIVE" and (draft.kind == "duration" or draft.kind == "stack") then
    shown = draft.showOnlyWhenActive ~= true
  end
  local desaturated = active and draft.desaturateActive
    or ready and draft.desaturateReady
    or not active and not ready and draft.desaturateCooldown
  local glowStyle = active and draft.activeGlowStyle
    or ready and draft.readyGlowStyle
    or draft.cooldownGlowStyle

  if isButton then
    local size = tonumber(draft.icon.size) or 40
    button:SetSize(size, size)
    button.Icon:SetTexture(texture)
    button.Icon:SetDesaturated(desaturated == true)
    button:SetAlpha(shown and alpha / 100 or 0)
    button.Count:SetShown(draft.icon.showCount == true
      and (draft.kind == "charge" or draft.kind == "stack"))
    button.Count:SetText(draft.kind == "charge" and "2" or draft.kind == "stack" and "3" or "")
    button.Cooldown:SetDrawSwipe(draft.icon.showSwipe == true)
    button.Cooldown:SetDrawEdge(draft.icon.showSwipe == true)
    button.Cooldown:SetHideCountdownNumbers(draft.icon.showDuration ~= true)
    if ready then
      button.Cooldown:Clear()
    else
      button.Cooldown:SetCooldown(previewStartedAt, PREVIEW_SECONDS)
    end
    StartPreviewGlow(button, shown and glowStyle or "NONE", active and draft.icon.activeAuraGlowColor
      or ready and draft.icon.readyGlowColor or draft.icon.cooldownGlowColor)
  else
    local width = tonumber(draft.width) or 250
    local height = tonumber(draft.height) or 25
    bar:SetSize(math.min(width, 250), height)
    bar.Icon:SetTexture(texture)
    bar.Icon:SetShown(draft.showBarIcon == true)
    bar:SetAlpha(shown and alpha / 100 or 0)
    bar.Fill:GetStatusBarTexture():SetDesaturated(desaturated == true)
    bar.Fill:SetValue(ready and 1 or 0)
    bar.Text:SetText(state == "INACTIVE" and "Inactive" or ready and "Ready" or active and "Active" or "3.0")
    StartPreviewGlow(bar, shown and glowStyle or "NONE", active and draft.icon.activeAuraGlowColor
      or ready and draft.icon.readyGlowColor or draft.icon.cooldownGlowColor)
  end
end

local function PreviewChanged(state)
  ApplyPreviewState(state or previewState)
end

local function NextPreviewState()
  local states = PreviewStates()
  local nextIndex = 1
  for index = 1, #states do
    if states[index] == previewState then
      nextIndex = index % #states + 1
      break
    end
  end
  ApplyPreviewState(states[nextIndex])
end

local function AddHeading(text)
  local widget = AceGUI:Create("PUI_Heading")
  widget:SetText(text)
  widget:SetFullWidth(true)
  controls:AddChild(widget)
end

local function AddDescription(text)
  local widget = AceGUI:Create("PUI_Label")
  widget:SetText(text)
  widget:SetFullWidth(true)
  controls:AddChild(widget)
end

local function AddButton(text, callback, width)
  local widget = AceGUI:Create("PUI_Button")
  widget:SetText(text)
  widget:SetWidth(width or 190)
  widget:SetCallback("OnClick", callback)
  controls:AddChild(widget)
  return widget
end

local function AddCheckbox(label, value, callback, state)
  local widget = AceGUI:Create("PUI_Checkbox")
  widget:SetLabel(label)
  widget:SetValue(value == true)
  widget:SetWidth(235)
  widget:SetCallback("OnValueChanged", function(_, _, checked)
    callback(checked == true)
    PreviewChanged(state)
  end)
  controls:AddChild(widget)
  return widget
end

local function AddSlider(label, value, minimum, maximum, step, callback, state)
  local widget = AceGUI:Create("PUI_Slider")
  widget:SetLabel(label)
  widget:SetSliderValues(minimum, maximum, step)
  widget:SetValue(value)
  widget:SetWidth(235)
  widget:SetCallback("OnValueChanged", function(_, _, selected)
    callback(selected)
    PreviewChanged(state)
  end)
  controls:AddChild(widget)
  return widget
end

local function AddDropdown(label, values, sorting, value, callback, state)
  local widget = AceGUI:Create("PUI_Dropdown")
  widget:SetLabel(label)
  widget:SetList(values, sorting)
  widget:SetValue(value)
  widget:SetWidth(235)
  widget:SetCallback("OnValueChanged", function(_, _, selected)
    callback(selected)
    PreviewChanged(state)
  end)
  controls:AddChild(widget)
  return widget
end

local function CreateWindowButton(parent, text, width, callback)
  local widget = AceGUI:Create("PUI_Button")
  widget:SetText(text)
  widget:SetWidth(width)
  widget:SetHeight(24)
  widget:SetCallback("OnClick", callback)
  widget.frame:SetParent(parent)
  widget.frame:Show()
  AceHooks.TakeOwnership(widget)
  return widget
end

local function SetPage(newPage)
  page = math.max(1, math.min(#PAGES, newPage))
  frame.PageTitle:SetText(string.format("Step %d of %d — %s", page, #PAGES, PAGES[page]))
  controls:ReleaseChildren()
  controls:SetScroll(0)

  if page == 1 then
    AddHeading("Button or bar")
    AddDescription("Buttons and bars are independent trackers with their own settings and mover. You can create both for the same spell if you want both presentations.")
    AddButton("Button", function()
      draft.presentation = "BUTTON"
      PreviewChanged("COOLDOWN")
      SetPage(2)
    end)
    AddButton("Bar", function()
      draft.presentation = "BAR"
      PreviewChanged("COOLDOWN")
      SetPage(2)
    end)
    AddButton("Start over", function()
      draft = NewDraft()
      PreviewChanged("COOLDOWN")
      SetPage(1)
    end)
  elseif page == 2 then
    AddHeading("Tracking intention")
    AddDescription("Cooldown tracks one spell cooldown. Charge cooldown also shows recharge progress and available charges. Aura stacks tracks stack count with optional duration. Aura duration tracks the remaining time of a buff or debuff.")
    AddButton("Cooldown", function() draft.kind = "cooldown" draft.maximum = 1 SetPage(3) end)
    AddButton("Charge cooldown", function() draft.kind = "charge" draft.maximum = 2 SetPage(3) end)
    AddButton("Aura stacks", function() draft.kind = "stack" draft.maximum = 3 SetPage(3) end)
    AddButton("Aura duration", function() draft.kind = "duration" draft.maximum = 1 SetPage(3) end)
  elseif page == 3 then
    AddHeading("Spell")
    if draft.kind == "cooldown" or draft.kind == "charge" then
      AddDescription("Choose a spell found by Blizzard's Cooldown Manager or enter a spell ID. This creates a PleebUI tracker; use /cd if you also want to change Blizzard's Cooldown Manager lists.")
    else
      AddDescription("Choose an aura found by the Cooldown Manager or enter its spell ID, then choose whether it belongs to you or your target.")
    end
    local listKind = (draft.kind == "cooldown" or draft.kind == "charge") and "cooldown" or "aura"
    local values, sorting = Cooldowns:GetCustomBarSpellDropdown(listKind)
    values = values or {}
    values.none = "-- Select --"
    sorting = sorting or {}
    if sorting[1] ~= "none" then
      table.insert(sorting, 1, "none")
    end
    AddDropdown("Tracked spell", values, sorting, draft.spellID and tostring(draft.spellID) or "none", function(value)
      draft.spellID = value ~= "none" and tonumber(value) or nil
    end, "ACTIVE")

    local spellID = AceGUI:Create("PUI_EditBox")
    spellID:SetLabel("Spell ID")
    spellID:SetText(draft.spellID and tostring(draft.spellID) or "")
    spellID:SetWidth(235)
    spellID:SetCallback("OnEnterPressed", function(_, _, value)
      value = tonumber(value)
      draft.spellID = value and value > 0 and value or nil
      PreviewChanged("ACTIVE")
      SetPage(3)
    end)
    controls:AddChild(spellID)

    if draft.kind == "duration" or draft.kind == "stack" then
      AddDropdown("Aura owner", {
        player_buff = "Player buff",
        target_debuff = "Target debuff",
      }, { "player_buff", "target_debuff" }, draft.auraTrackMode, function(value)
        draft.auraTrackMode = value == "target_debuff" and "target_debuff" or "player_buff"
      end, "ACTIVE")
    end

    if draft.kind == "charge" then
      AddSlider("Charges", draft.maximum, 2, 3, 1, function(value) draft.maximum = math.floor(value + 0.5) end, "RECHARGING")
    elseif draft.kind == "stack" then
      AddSlider("Maximum stacks", draft.maximum, 2, 60, 1, function(value) draft.maximum = math.floor(value + 0.5) end, "ACTIVE")
    end
  elseif page == 4 then
    AddHeading(draft.presentation == "BUTTON" and "Button style" or "Bar style")
    AddDescription("This controls the tracker's appearance. After finishing, use /pe to position the tracker and Smart Snap it to other buttons if wanted.")
    if draft.presentation == "BUTTON" then
      AddSlider("Button size", draft.icon.size, 20, 96, 1, function(value) draft.icon.size = math.floor(value + 0.5) end)
      AddCheckbox("Show swipe", draft.icon.showSwipe, function(value) draft.icon.showSwipe = value end, "COOLDOWN")
      AddCheckbox("Show countdown", draft.icon.showDuration, function(value) draft.icon.showDuration = value end, "COOLDOWN")
      if draft.kind == "charge" or draft.kind == "stack" then
        AddCheckbox(draft.kind == "charge" and "Show charge count" or "Show stack count", draft.icon.showCount, function(value) draft.icon.showCount = value end, "ACTIVE")
      end
    else
      AddSlider("Bar width", draft.width, 80, 600, 1, function(value) draft.width = math.floor(value + 0.5) end)
      AddSlider("Bar height", draft.height, 6, 50, 1, function(value) draft.height = math.floor(value + 0.5) end)
      AddCheckbox("Show icon beside bar", draft.showBarIcon, function(value) draft.showBarIcon = value end)
    end
    if draft.kind == "stack" then
      AddCheckbox("Add stack color shift", draft.addColorShift, function(value) draft.addColorShift = value end, "ACTIVE")
    end
  else
    AddHeading("Visibility and states")
    AddDescription("The preview rotates through each supported state every three seconds. Changing a state option immediately previews that state. Alpha 0 fully hides that layer and disables its tooltip and glow.")
    AddCheckbox("Only show in combat", draft.combatOnly, function(value) draft.combatOnly = value end)
    if draft.kind == "cooldown" or draft.kind == "charge" then
      AddCheckbox("Show while ready", draft.showReady, function(value) draft.showReady = value end, "READY")
      AddSlider("Ready alpha", draft.readyAlpha, 0, 100, 1, function(value) draft.readyAlpha = value end, "READY")
      AddCheckbox("Desaturate while ready", draft.desaturateReady, function(value) draft.desaturateReady = value end, "READY")
      AddDropdown("Ready glow", GLOW_STYLES, GLOW_ORDER, draft.readyGlowStyle, function(value) draft.readyGlowStyle = value end, "READY")

      AddCheckbox(draft.kind == "charge" and "Show while recharging" or "Show while on cooldown", draft.showCooldown, function(value) draft.showCooldown = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")
      AddSlider(draft.kind == "charge" and "Recharging alpha" or "On cooldown alpha", draft.cooldownAlpha, 0, 100, 1, function(value) draft.cooldownAlpha = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")
      AddCheckbox(draft.kind == "charge" and "Desaturate while recharging" or "Desaturate while on cooldown", draft.desaturateCooldown, function(value) draft.desaturateCooldown = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")

      AddCheckbox("Show while aura is active", draft.showActive, function(value) draft.showActive = value end, "ACTIVE")
    else
      draft.showActive = true
      AddCheckbox("Show only while aura is active", draft.showOnlyWhenActive, function(value) draft.showOnlyWhenActive = value end, "ACTIVE")
      if draft.kind == "stack" then
        AddCheckbox("Hide buff icon", draft.hideViewerIcon, function(value) draft.hideViewerIcon = value end)
      end
      AddSlider("Inactive alpha", draft.readyAlpha, 0, 100, 1, function(value) draft.readyAlpha = value end, "INACTIVE")
      AddCheckbox("Desaturate while inactive", draft.desaturateReady, function(value) draft.desaturateReady = value end, "INACTIVE")
    end
    AddSlider("Active alpha", draft.activeAlpha, 0, 100, 1, function(value) draft.activeAlpha = value end, "ACTIVE")
    AddCheckbox("Desaturate while active", draft.desaturateActive, function(value) draft.desaturateActive = value end, "ACTIVE")
    AddDropdown("Active glow", GLOW_STYLES, GLOW_ORDER, draft.activeGlowStyle, function(value) draft.activeGlowStyle = value end, "ACTIVE")
  end

  frame.Previous:SetDisabled(page <= 1)
  frame.Next.frame:SetShown(page < #PAGES)
  frame.Finish.frame:SetShown(page == #PAGES)
  frame.Finish:SetDisabled(draft.spellID == nil)
  ApplyPreviewState(previewState)
end

local function CreatePreview(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  host:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -88)
  host:SetSize(290, 390)
  Theme.WidgetSkins.Frame(host)

  local title = host:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOP", host, "TOP", 0, -18)
  Theme.ApplyFont(title, "title")
  title:SetText("Live preview")

  local state = host:CreateFontString(nil, "OVERLAY")
  state:SetPoint("TOP", title, "BOTTOM", 0, -8)
  Theme.ApplyFont(state, "body")
  parent.PreviewState = state

  local button = CreateFrame("Frame", nil, host, "BackdropTemplate")
  button:SetPoint("CENTER", host, "CENTER", 0, 12)
  button:SetSize(40, 40)
  Theme.WidgetSkins.Frame(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.Icon = icon
  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(icon)
  cooldown:SetDrawEdge(true)
  button.Cooldown = cooldown
  local count = button:CreateFontString(nil, "OVERLAY")
  count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  Theme.ApplyFont(count, "cooldown")
  button.Count = count
  parent.PreviewButton = button

  local bar = CreateFrame("Frame", nil, host, "BackdropTemplate")
  bar:SetPoint("CENTER", host, "CENTER", 0, 12)
  bar:SetSize(250, 25)
  Theme.WidgetSkins.Frame(bar)
  local fill = CreateFrame("StatusBar", nil, bar)
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  fill:SetStatusBarTexture(Theme.GetBarTexture())
  fill:SetStatusBarColor(0.25, 0.75, 1, 1)
  fill:SetMinMaxValues(0, 1)
  bar.Fill = fill
  local barIcon = bar:CreateTexture(nil, "OVERLAY")
  barIcon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
  barIcon:SetSize(25, 25)
  barIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  bar.Icon = barIcon
  local text = bar:CreateFontString(nil, "OVERLAY")
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  Theme.ApplyFont(text, "cooldown")
  bar.Text = text
  parent.PreviewBar = bar
end

local function ApplyWindowSkin(window)
  Theme.WidgetSkins.Frame(window)

  local colors = Theme.GetColors()
  local background = colors.background
  Theme.SetSquareBackdrop(window, {
    bg = { background[1], background[2], background[3], 1 },
    border = colors.border,
  })
end

local function BuildFrame()
  local window = CreateFrame("Frame", "PleebUI_PCM_CustomTrackerInstaller", UIParent, "BackdropTemplate")
  window:SetSize(920, 570)
  window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  window:SetFrameStrata("DIALOG")
  window:SetFrameLevel(180)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  ApplyWindowSkin(window)

  local title = window:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -20)
  Theme.ApplyFont(title, "title")
  title:SetText("Create custom tracker")

  local pageTitle = window:CreateFontString(nil, "OVERLAY")
  pageTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
  Theme.ApplyFont(pageTitle, "body")
  window.PageTitle = pageTitle

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() window:Hide() end)
  Theme.WidgetSkins.CloseButton(close)

  controls = AceGUI:Create("ScrollFrame")
  controls:SetLayout("Flow")
  controls.frame:SetParent(window)
  AceHooks.TakeOwnership(controls)
  controls.frame:ClearAllPoints()
  controls.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -86)
  controls.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -340, 66)
  controls:SetWidth(540)
  controls:SetHeight(410)

  local previous = CreateWindowButton(window, "Previous", 110, function()
    SetPage(page - 1)
  end)
  previous.frame:ClearAllPoints()
  previous.frame:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 24, 22)
  window.Previous = previous

  local discard = CreateWindowButton(window, "Discard draft", 110, function()
    draft = nil
    page = 1
    window:Hide()
  end)
  discard.frame:ClearAllPoints()
  discard.frame:SetPoint("BOTTOM", window, "BOTTOM", 0, 22)
  window.Discard = discard

  local nextButton = CreateWindowButton(window, "Next", 110, function()
    SetPage(page + 1)
  end)
  nextButton.frame:ClearAllPoints()
  nextButton.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -24, 22)
  window.Next = nextButton

  local finish = CreateWindowButton(window, "Finish tracker", 130, function()
    ApplyDraftToIcon()
    local key = ns.PCM_CreateCustomTrackerFromDraft(draft)
    if key then
      draft = nil
      page = 1
      window:Hide()
    end
  end)
  finish.frame:ClearAllPoints()
  finish.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -24, 22)
  window.Finish = finish

  CreatePreview(window)
  window:SetScript("OnUpdate", function()
    if GetTime() - previewStartedAt >= PREVIEW_SECONDS then
      NextPreviewState()
    elseif draft and draft.presentation == "BAR" and frame.PreviewBar:IsShown() then
      local progress = math.min(1, (GetTime() - previewStartedAt) / PREVIEW_SECONDS)
      frame.PreviewBar.Fill:SetValue(
        (previewState == "READY" or previewState == "INACTIVE") and 1 or progress
      )
    end
  end)
  window:SetScript("OnHide", StopPreviewGlow)
  return window
end

function Installer:Open()
  if not draft then
    draft = NewDraft()
    page = 1
  end
  frame = frame or BuildFrame()
  ApplyWindowSkin(frame)
  frame:Show()
  frame:Raise()
  SetPage(page)
end

function Installer:HasDraft()
  return draft ~= nil
end

function Installer:RefreshTheme()
  if frame then
    ApplyWindowSkin(frame)
  end
end

function Addon:HandleOptionsPathOpened(path)
  if type(path) ~= "table" or path[1] ~= "CooldownManager" or path[2] ~= "custom_bars" then
    return
  end

  if Installer:HasDraft() then
    C_Timer.After(0, function()
      Installer:Open()
    end)
  end
end
