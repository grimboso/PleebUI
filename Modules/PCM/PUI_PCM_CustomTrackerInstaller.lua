local _, ns = ...

local Addon = ns.Addon
local Cooldowns = ns.Modules.CooldownManager
local Theme = ns.Theme
local OptionsUtil = ns.OptionsUtil
local AceHooks = ns.AceHooks
local AceGUI = LibStub("AceGUI-3.0")

local Installer = {}
ns.PCMCustomTrackerInstaller = Installer

local frame
local controls
local draft
local page = 1
local previewState = "COOLDOWN"
local previewTimer
local SchedulePreviewAdvance
local closeCallback
local createdTrackerKey
local PREVIEW_SECONDS = 3

local PAGES = {
  "Choose a widget",
  "Choose what to track",
  "Choose a spell",
  "Style",
  "Behavior",
  "Active glow",
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
    orientation = "horizontal",
    fillDirection = "RIGHT",
    barMode = "fill",
    texture = "Pleebar",
    showText = true,
    showBarIcon = true,
    combatOnly = false,
    showOnlyWhenActive = false,
    showReady = true,
    showCooldown = true,
    showActive = true,
    customGlowEnabled = true,
    customGlowThickness = 2,
    readyAlpha = 100,
    cooldownAlpha = 35,
    activeAlpha = 100,
    desaturateReady = false,
    desaturateCooldown = true,
    desaturateActive = false,
    readyGlowStyle = "NONE",
    cooldownGlowStyle = "NONE",
    activeGlowStyle = "PROC",
    activeAuraSource = "CDM",
    activeAuraSpellID = nil,
    activeAuraHideViewerIcon = false,
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

local function DefaultPreviewState()
  if draft.kind == "charge" then
    return "RECHARGING"
  elseif draft.kind == "duration" or draft.kind == "stack" then
    return "ACTIVE"
  end
  return "COOLDOWN"
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
  previewState = state
  frame.PreviewState:SetText(PreviewStateLabel(state))
  ns.PCMPreview.RenderInstallerDraft(frame.PreviewHost, draft, state)
  SchedulePreviewAdvance()
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

SchedulePreviewAdvance = function()
  if previewTimer then
    previewTimer:Cancel()
    previewTimer = nil
  end

  if not frame or not frame:IsShown() or not draft then
    return
  end

  previewTimer = C_Timer.NewTimer(PREVIEW_SECONDS, function()
    previewTimer = nil
    if frame:IsShown() and draft then
      NextPreviewState()
    end
  end)
end

local function StopPreviewAdvance()
  if previewTimer then
    previewTimer:Cancel()
    previewTimer = nil
  end
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

local function AddEditBox(label, value, callback, state)
  local widget = AceGUI:Create("PUI_EditBox")
  widget:SetLabel(label)
  widget:SetText(value or "")
  widget:SetWidth(235)
  widget:SetCallback("OnEnterPressed", function(_, _, entered)
    callback(entered)
    PreviewChanged(state)
  end)
  controls:AddChild(widget)
  return widget
end

local function AddColor(label, color, callback, state)
  local widget = AceGUI:Create("ColorPicker")
  widget:SetLabel(label)
  widget:SetHasAlpha(true)
  local r, g, b, a = CopyColor(color, { 1, 0.55, 0.1, 1 })
  widget:SetColor(r, g, b, a)
  widget:SetWidth(235)
  widget:SetCallback("OnValueChanged", function(_, _, red, green, blue, alpha)
    callback({ red, green, blue, alpha or 1 })
    PreviewChanged(state)
  end)
  controls:AddChild(widget)
  return widget
end

local function BuildStatusbarList()
  local values = OptionsUtil.BuildStatusbarValues(false)
  local sorting = {}
  for key in pairs(values) do
    sorting[#sorting + 1] = key
  end
  table.sort(sorting, function(a, b)
    return tostring(values[a]) < tostring(values[b])
  end)
  return values, sorting
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
      PreviewChanged(DefaultPreviewState())
      SetPage(2)
    end)
    AddButton("Bar", function()
      draft.presentation = "BAR"
      PreviewChanged(DefaultPreviewState())
      SetPage(2)
    end)
    AddButton("Start over", function()
      draft = NewDraft()
      PreviewChanged(DefaultPreviewState())
      SetPage(1)
    end)
  elseif page == 2 then
    AddHeading("What to track")
    AddDescription("Cooldown tracks one spell cooldown. Charge cooldown also shows recharge progress and available charges. Aura stacks tracks stack count with optional duration. Aura duration tracks the remaining time of a buff or debuff.")
    AddButton("Cooldown", function() draft.kind = "cooldown" draft.maximum = 1 PreviewChanged(DefaultPreviewState()) SetPage(3) end)
    AddButton("Charge cooldown", function() draft.kind = "charge" draft.maximum = 2 PreviewChanged(DefaultPreviewState()) SetPage(3) end)
    AddButton("Aura stacks", function() draft.kind = "stack" draft.maximum = 3 PreviewChanged(DefaultPreviewState()) SetPage(3) end)
    AddButton("Aura duration", function() draft.kind = "duration" draft.maximum = 1 PreviewChanged(DefaultPreviewState()) SetPage(3) end)
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
      AddDropdown("Track aura on", {
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
      local timedState = draft.kind == "charge" and "RECHARGING"
        or (draft.kind == "duration" or draft.kind == "stack") and "ACTIVE"
        or "COOLDOWN"
      AddSlider("Button size", draft.icon.size, 20, 96, 1, function(value) draft.icon.size = math.floor(value + 0.5) end)
      AddCheckbox("Show cooldown swipe", draft.icon.showSwipe, function(value) draft.icon.showSwipe = value end, timedState)
      AddCheckbox("Show countdown", draft.icon.showDuration, function(value) draft.icon.showDuration = value end, timedState)
      AddCheckbox("Show tooltip on hover", draft.icon.showTooltip, function(value) draft.icon.showTooltip = value end)
      AddDescription("Tooltips apply to the live tracker. The setup preview stays display-only.")
      if draft.kind == "charge" or draft.kind == "stack" then
        AddCheckbox(draft.kind == "charge" and "Show charge count" or "Show stack count", draft.icon.showCount, function(value) draft.icon.showCount = value end, draft.kind == "charge" and "RECHARGING" or "ACTIVE")
      end
      if draft.kind == "charge" then
        AddCheckbox("Show charge pips", draft.icon.showPips, function(value) draft.icon.showPips = value end, "RECHARGING")
      end
    else
      AddSlider("Bar width", draft.width, 80, 600, 1, function(value) draft.width = math.floor(value + 0.5) end)
      AddSlider("Bar height", draft.height, 6, 50, 1, function(value) draft.height = math.floor(value + 0.5) end)
      AddDropdown("Orientation", {
        horizontal = "Horizontal",
        vertical = "Vertical",
      }, { "horizontal", "vertical" }, draft.orientation, function(value)
        draft.orientation = value == "vertical" and "vertical" or "horizontal"
        draft.fillDirection = draft.orientation == "vertical" and "UP" or "RIGHT"
        PreviewChanged(DefaultPreviewState())
        SetPage(4)
      end)
      AddDropdown("Fill direction", draft.orientation == "vertical" and {
        UP = "Up",
        DOWN = "Down",
      } or {
        LEFT = "Left",
        RIGHT = "Right",
      }, draft.orientation == "vertical" and { "UP", "DOWN" } or { "LEFT", "RIGHT" }, draft.fillDirection, function(value)
        draft.fillDirection = value
      end)
      AddDropdown("Timer fill", {
        fill = "Fill as time passes",
        drain = "Drain as time runs out",
      }, { "fill", "drain" }, draft.barMode, function(value) draft.barMode = value == "drain" and "drain" or "fill" end)
      local textures, textureOrder = BuildStatusbarList()
      AddDropdown("Bar texture", textures, textureOrder, draft.texture, function(value) draft.texture = value end)
      AddCheckbox("Show text", draft.showText, function(value) draft.showText = value end)
      AddCheckbox(draft.kind == "duration" and "Show aura icon beside bar" or "Show icon beside bar", draft.showBarIcon, function(value) draft.showBarIcon = value end)
    end
    if draft.kind == "stack" then
      AddCheckbox("Add stack color threshold", draft.addColorShift, function(value) draft.addColorShift = value end, "ACTIVE")
      AddDescription("Creates a starter stack-color threshold. You can edit its stack count and color after creating the tracker.")
    end
  elseif page == 5 then
    AddHeading("Visibility and states")
    AddDescription("The preview rotates through each supported state every three seconds. Changing a state option immediately previews that state. Alpha 0 fully hides that state. Combat-only visibility applies to the live tracker; the setup preview stays visible while you configure it.")
    AddCheckbox("Only show in combat", draft.combatOnly, function(value) draft.combatOnly = value end)
    if draft.kind == "cooldown" or draft.kind == "charge" then
      AddCheckbox("Show while ready", draft.showReady, function(value) draft.showReady = value end, "READY")
      AddSlider("Ready alpha", draft.readyAlpha, 0, 100, 1, function(value) draft.readyAlpha = value end, "READY")
      AddCheckbox("Desaturate while ready", draft.desaturateReady, function(value) draft.desaturateReady = value end, "READY")
      AddDropdown("Ready glow", GLOW_STYLES, GLOW_ORDER, draft.readyGlowStyle, function(value) draft.readyGlowStyle = value end, "READY")

      AddCheckbox(draft.kind == "charge" and "Show while recharging" or "Show while on cooldown", draft.showCooldown, function(value) draft.showCooldown = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")
      AddSlider(draft.kind == "charge" and "Recharging alpha" or "On cooldown alpha", draft.cooldownAlpha, 0, 100, 1, function(value) draft.cooldownAlpha = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")
      AddCheckbox(draft.kind == "charge" and "Desaturate while recharging" or "Desaturate while on cooldown", draft.desaturateCooldown, function(value) draft.desaturateCooldown = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")
      AddDropdown(draft.kind == "charge" and "Recharging glow" or "On cooldown glow", GLOW_STYLES, GLOW_ORDER, draft.cooldownGlowStyle, function(value) draft.cooldownGlowStyle = value end, draft.kind == "charge" and "RECHARGING" or "COOLDOWN")

      AddCheckbox("Show while aura is active", draft.showActive, function(value)
        draft.showActive = value
        if not value then
          draft.customGlowEnabled = false
        end
      end, "ACTIVE")
      AddDescription("Choose the active buff and glow on the Active glow page.")
    else
      draft.showActive = true
      AddCheckbox("Show only while aura is active", draft.showOnlyWhenActive, function(value) draft.showOnlyWhenActive = value end, "ACTIVE")
      if draft.kind == "stack" then
        AddCheckbox("Hide tracked aura in Buff Icon Viewer", draft.hideViewerIcon, function(value) draft.hideViewerIcon = value end)
      end
      AddSlider("Inactive alpha", draft.readyAlpha, 0, 100, 1, function(value) draft.readyAlpha = value end, "INACTIVE")
      AddCheckbox("Desaturate while inactive", draft.desaturateReady, function(value) draft.desaturateReady = value end, "INACTIVE")
    end
    AddSlider("Active alpha", draft.activeAlpha, 0, 100, 1, function(value) draft.activeAlpha = value end, "ACTIVE")
    AddCheckbox("Desaturate while active", draft.desaturateActive, function(value) draft.desaturateActive = value end, "ACTIVE")
  elseif page == 6 then
    AddHeading("Active glow")
    AddDescription("Choose the glow used while the tracked aura or configured active buff is active. Ready and cooldown/recharging glows are configured separately on the previous page.")
    AddCheckbox("Glow while active", draft.customGlowEnabled, function(value)
      draft.customGlowEnabled = value
      if value then
        draft.showActive = true
      end
    end, "ACTIVE")

    if draft.customGlowEnabled then
      if draft.kind == "cooldown" or draft.kind == "charge" then
        AddDropdown("Buff source", {
          CDM = "Cooldown Manager buff",
          CUSTOM = "Custom player buff",
        }, { "CDM", "CUSTOM" }, draft.activeAuraSource, function(value)
          draft.activeAuraSource = value == "CUSTOM" and "CUSTOM" or "CDM"
          draft.activeAuraSpellID = nil
          SetPage(6)
        end, "ACTIVE")

        if draft.activeAuraSource == "CUSTOM" then
          AddEditBox("Custom buff spell ID", draft.activeAuraSpellID and tostring(draft.activeAuraSpellID) or "", function(value)
            local spellID = tonumber(value)
            draft.activeAuraSpellID = spellID and spellID > 0 and math.floor(spellID) or nil
            SetPage(6)
          end, "ACTIVE")
        else
          local values, sorting = Cooldowns:GetCustomBarSpellDropdown("aura")
          AddDescription("Select the Cooldown Manager buff that triggers the active state and glow. Buffs shown in the Cooldown Manager are listed first.")
          AddDropdown("Cooldown Manager buff", values, sorting, draft.activeAuraSpellID and tostring(draft.activeAuraSpellID) or "none", function(value)
            draft.activeAuraSpellID = value ~= "none" and tonumber(value) or nil
            SetPage(6)
          end, "ACTIVE")
        end
      else
        AddDescription("This tracker uses its tracked aura as the glow trigger.")
      end

      AddDropdown("Glow style", GLOW_STYLES, GLOW_ORDER, draft.activeGlowStyle, function(value)
        draft.activeGlowStyle = value
      end, "ACTIVE")
      AddSlider("Glow thickness", draft.customGlowThickness, 1, 8, 1, function(value)
        draft.customGlowThickness = math.floor(value + 0.5)
      end, "ACTIVE")
      AddColor("Glow color", draft.icon.activeAuraGlowColor, function(color)
        draft.icon.activeAuraGlowColor = color
      end, "ACTIVE")
      AddCheckbox("Hide active buff in Buff Icon Viewer", draft.activeAuraHideViewerIcon, function(value)
        draft.activeAuraHideViewerIcon = value
      end, "ACTIVE")
    end
  end

  frame.Previous:SetDisabled(page <= 1)
  frame.Next.frame:SetShown(page < #PAGES)
  frame.Finish.frame:SetShown(page == #PAGES)
  local activeAuraRequired = (draft.kind == "cooldown" or draft.kind == "charge")
    and draft.customGlowEnabled == true
    and tonumber(draft.activeAuraSpellID) == nil
  frame.Finish:SetDisabled(draft.spellID == nil or activeAuraRequired)
  ApplyPreviewState(previewState)
end

local function CreatePreview(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  host:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -88)
  host:SetSize(600, 390)
  Theme.WidgetSkins.Frame(host)
  parent.PreviewHost = host

  local title = host:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOP", host, "TOP", 0, -18)
  Theme.ApplyFont(title, "title")
  title:SetText("Live preview")

  local state = host:CreateFontString(nil, "OVERLAY")
  state:SetPoint("TOP", title, "BOTTOM", 0, -8)
  Theme.ApplyFont(state, "body")
  parent.PreviewState = state
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
  window:SetSize(1220, 570)
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
  controls.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -620, 66)
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
    local key = ns.PCM_CreateCustomTrackerFromDraft(draft)
    if key then
      local returnToCustomTrackerPage = closeCallback ~= nil
      createdTrackerKey = key
      draft = nil
      page = 1
      window:Hide()

      C_Timer.After(0, function()
        local path = { "CooldownManager", "custom_bars" }
        if not returnToCustomTrackerPage then
          path[3] = key
        end
        if not Addon:NavigateOpenOptionsPath(path) then
          Addon:OpenOptions(path, false, true)
        end
      end)
    end
  end)
  finish.frame:ClearAllPoints()
  finish.frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -24, 22)
  window.Finish = finish

  CreatePreview(window)
  window:SetScript("OnHide", function()
    StopPreviewAdvance()
    ns.PCMPreview.HideInstallerDraft(window.PreviewHost)

    local callback = closeCallback
    local key = createdTrackerKey
    closeCallback = nil
    createdTrackerKey = nil
    if callback then
      C_Timer.After(0, function()
        callback(key)
      end)
    end
  end)
  return window
end

function Installer:Open(onClose)
  if not draft then
    draft = NewDraft()
    page = 1
  end
  closeCallback = onClose
  frame = frame or BuildFrame()
  ApplyWindowSkin(frame)
  frame:Show()
  frame:Raise()
  previewState = DefaultPreviewState()
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
