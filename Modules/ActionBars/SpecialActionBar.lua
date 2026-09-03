local ADDON_NAME, ns = ...

local Core = ns.ActionBarsCore

local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc
local math_max = math.max
local tonumber = tonumber

local SpecialBar = {
  enabled = false,
}
local P = select(1, ns.Pleebug:DropIn(SpecialBar))

local function GetVehicleDefaultPoint()
  local mainBar = _G.PUI_MainBar
  if mainBar then
    return { "RIGHT", mainBar, "LEFT", -10, 0 }
  end
  return { "CENTER", UIParent, "CENTER", 120, 27 }
end

local EXTRA_DEFAULT_POINT = { "CENTER", UIParent, "CENTER", -350, -300 }
local ZONE_DEFAULT_POINT = { "CENTER", UIParent, "CENTER", 350, -300 }

function SpecialBar:EnsureEventFrame()
  self.enabled = true

  if not self.eventFrame then
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
      SpecialBar:OnEvent(event)
    end)
  end

  if self.eventsRegistered then
    return
  end

  local frame = self.eventFrame
  frame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
  frame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
  frame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
  frame:RegisterEvent("PLAYER_CONTROL_GAINED")
  frame:RegisterEvent("PLAYER_CONTROL_LOST")
  self.eventsRegistered = true
end

local function GetFrameSize(frame, fallback)
  if not frame then
    return fallback, fallback
  end

  local width, height = frame:GetSize()
  width = tonumber(width) or fallback
  height = tonumber(height) or fallback
  return math_max(1, width), math_max(1, height)
end

local function GetExtraActionButton(frame)
  return frame and frame.button
end

function SpecialBar:QueueExtraActionRefresh()
  if self.extraActionRefreshQueued then
    return
  end

  self.extraActionRefreshQueued = true
  Core:QueueSubsystemRefresh("special", "extraAction")
end

function SpecialBar:QueueZoneAbilityRefresh()
  if self.zoneAbilityRefreshQueued then
    return
  end

  self.zoneAbilityRefreshQueued = true
  Core:QueueSubsystemRefresh("special", "zoneAbility")
end

function SpecialBar:QueueVehicleRefresh()
  if self.vehicleRefreshQueued then
    return
  end

  self.vehicleRefreshQueued = true
  Core:QueueSubsystemRefresh("special", "vehicle")
end

function SpecialBar:StyleExtraActionFrame(frame, force)
  if InCombatLockdown() then
    self:QueueExtraActionRefresh()
    return
  end

  local button = GetExtraActionButton(frame)
  if not button then
    return
  end

  local width, height = GetFrameSize(button, 52)
  local skin = Core:GetSpecialSkin("extraAbility", math_max(width, height))
  if force or button.__puiActionBarExtraSkinVersion ~= skin.version then
    button.__puiActionBarExtraSkinVersion = skin.version
    Core:ApplyButtonAppearance(button, skin)

    if button.style then
      button.style:SetAlpha(0)
    end
  end
end

function SpecialBar:StyleZoneAbilityButtons(force)
  if InCombatLockdown() then
    self:QueueZoneAbilityRefresh()
    return
  end

  local frame = _G.ZoneAbilityFrame
  local container = frame and frame.SpellButtonContainer
  if not container then
    return
  end

  for button in container:EnumerateActive() do
    if button then
      local width, height = GetFrameSize(button, 52)
      local skin = Core:GetSpecialSkin("zoneAbility", math_max(width, height))
      if force or button.__puiActionBarZoneSkinVersion ~= skin.version then
        button.__puiActionBarZoneSkinVersion = skin.version
        Core:ApplyButtonAppearance(button, skin)
      end
    end
  end

  if frame.Style and not frame.__puiActionBarStyleHidden then
    frame.__puiActionBarStyleHidden = true
    frame.Style:SetAlpha(0)
  end
end

function SpecialBar:InstallExtraAbilityContainerHook()
  local container = _G.ExtraAbilityContainer
  if not container or container.__puiActionBarsHookInstalled then
    return
  end

  container.__puiActionBarsHookInstalled = true

  hooksecurefunc(container, "AddFrame", function(_, frame)
    if SpecialBar.enabled then
      SpecialBar:StyleExtraActionFrame(frame)
    end
  end)
end

function SpecialBar:AnchorExtraActionFrame()
  local bar = self.extraBar
  local frame = bar and bar.content
  if not bar or not frame then
    return
  end

  if InCombatLockdown() then
    self:QueueExtraActionRefresh()
    return
  end

  local button = GetExtraActionButton(frame)
  local width, height = GetFrameSize(button or frame, 52)
  bar.frame:SetSize(width, height)

  self.anchoringExtraAction = true
  frame:SetParent(bar.frame)
  frame:ClearAllPoints()
  frame:SetAllPoints(bar.frame)
  self.anchoringExtraAction = nil
end

function SpecialBar:InstallExtraActionHooks(frame)
  if not frame or frame.__puiActionBarsHolderHooksInstalled then
    return
  end

  frame.__puiActionBarsHolderHooksInstalled = true
  hooksecurefunc(frame, "SetParent", function(_, parent)
    local bar = SpecialBar.extraBar
    if SpecialBar.enabled
      and not SpecialBar.anchoringExtraAction
      and bar
      and parent ~= bar.frame
    then
      SpecialBar:AnchorExtraActionFrame()
    end
  end)
end

function SpecialBar:EnsureExtraBar()
  if InCombatLockdown() then
    self:QueueExtraActionRefresh()
    return self.extraBar
  end

  local frame = _G.ExtraActionBarFrame
  if not frame then
    return nil
  end

  local bar = self.extraBar
  if not bar then
    bar = Core:CreateBar(
      "extraAbility",
      "PUI_ExtraActionButtonHolder",
      "ACTIONBAR_EXTRA",
      "Extra Action Button",
      EXTRA_DEFAULT_POINT,
      "extraAbility"
    )
    bar.enabled = true
    self.extraBar = bar
  end

  bar.content = frame
  bar.frame:Show()

  self:InstallExtraAbilityContainerHook()
  self:InstallExtraActionHooks(frame)
  self:StyleExtraActionFrame(frame)
  self:AnchorExtraActionFrame()

  Core:ApplyBarPosition(bar)
  Core:RegisterMover(bar)
  return bar
end

function SpecialBar:UpdateZoneBarSize()
  if InCombatLockdown() then
    self:QueueZoneAbilityRefresh()
    return
  end

  local bar = self.zoneBar
  local frame = bar and bar.content
  local container = frame and frame.SpellButtonContainer
  if not bar or not container then
    return
  end

  local width, height = GetFrameSize(container, 52)
  local skin = Core:GetSpecialSkin("zoneAbility", 52)
  local minimumSize = math_max(1, tonumber(skin.iconSize) or 52)
  width = math_max(width, minimumSize)
  height = math_max(height, minimumSize)

  if bar.zoneWidth == width and bar.zoneHeight == height then
    return
  end

  bar.zoneWidth = width
  bar.zoneHeight = height
  bar.frame:SetSize(width, height)
end

function SpecialBar:AnchorZoneAbilityFrame()
  local bar = self.zoneBar
  local frame = bar and bar.content
  if not bar or not frame then
    return
  end

  if InCombatLockdown() then
    self:QueueZoneAbilityRefresh()
    return
  end

  self:UpdateZoneBarSize()

  self.anchoringZoneAbility = true
  frame:SetParent(bar.frame)
  frame:ClearAllPoints()
  frame:SetAllPoints(bar.frame)
  self.anchoringZoneAbility = nil
end

function SpecialBar:InstallZoneAbilityHooks(frame)
  if not frame or frame.__puiActionBarsHolderHooksInstalled then
    return
  end

  frame.__puiActionBarsHolderHooksInstalled = true

  hooksecurefunc(frame, "SetParent", function(_, parent)
    local bar = SpecialBar.zoneBar
    if SpecialBar.enabled
      and not SpecialBar.anchoringZoneAbility
      and bar
      and parent ~= bar.frame
    then
      SpecialBar:AnchorZoneAbilityFrame()
    end
  end)

  local container = frame.SpellButtonContainer
  if container then
    hooksecurefunc(container, "SetSize", function()
      if SpecialBar.enabled then
        SpecialBar:UpdateZoneBarSize()
      end
    end)
    hooksecurefunc(container, "SetContents", function()
      if SpecialBar.enabled then
        SpecialBar:StyleZoneAbilityButtons(false)
        SpecialBar:UpdateZoneBarSize()
      end
    end)
  end
end

function SpecialBar:EnsureZoneBar()
  if InCombatLockdown() then
    self:QueueZoneAbilityRefresh()
    return self.zoneBar
  end

  local frame = _G.ZoneAbilityFrame
  if not frame then
    return nil
  end

  local bar = self.zoneBar
  if not bar then
    bar = Core:CreateBar(
      "zoneAbility",
      "PUI_ZoneAbilityButtonHolder",
      "ACTIONBAR_ZONE",
      "Zone Ability",
      ZONE_DEFAULT_POINT,
      "zoneAbility"
    )
    bar.enabled = true
    self.zoneBar = bar
  end

  bar.content = frame
  bar.frame:Show()

  self:InstallZoneAbilityHooks(frame)
  self:StyleZoneAbilityButtons()
  self:AnchorZoneAbilityFrame()

  Core:ApplyBarPosition(bar)
  Core:RegisterMover(bar)
  return bar
end

function SpecialBar:AnchorVehicleButton()
  local bar = self.vehicleBar
  local button = bar and bar.content
  if not bar or not button then
    return
  end

  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
end

function SpecialBar:InstallVehicleHooks(button)
  if self.vehicleHooksInstalled then
    return
  end
  self.vehicleHooksInstalled = true

  hooksecurefunc(button, "Update", function()
    if SpecialBar.enabled then
      SpecialBar:UpdateVehicleButton()
    end
  end)

  if button.ApplySystemAnchor then
    hooksecurefunc(button, "ApplySystemAnchor", function()
      if SpecialBar.enabled and not Core.useBlizzardVehicleUI then
        SpecialBar:AnchorVehicleButton()
      end
    end)
  end

  if button.HighlightSystem then
    hooksecurefunc(button, "HighlightSystem", function()
      if SpecialBar.enabled and not Core.useBlizzardVehicleUI then
        button.Selection:Hide()
        EditModeMagnetismManager:UnregisterFrame(button)
        SpecialBar:AnchorVehicleButton()
      end
    end)
  end

  local editModeManager = _G.EditModeManagerFrame
  if editModeManager and editModeManager.UpdateBottomActionBarPositions then
    hooksecurefunc(editModeManager, "UpdateBottomActionBarPositions", function()
      if SpecialBar.enabled and not Core.useBlizzardVehicleUI then
        SpecialBar:AnchorVehicleButton()
      end
    end)
  end
end

function SpecialBar:StyleVehicleButton(button, skin)
  local normal = button:GetNormalTexture()
  if normal then
    button.icon = normal
  end

  Core:ApplyButtonAppearance(button, skin)

  if normal then
    normal:SetAlpha(1)
    normal:Show()
    normal:SetTexCoord(0.20, 0.80, 0.20, 0.80)
  end
end

function SpecialBar:UpdateVehicleButton()
  local bar = self.vehicleBar
  local button = bar and bar.content
  if not button then return end

  if Core.useBlizzardVehicleUI then
    button:Hide()
    return
  end

  local shown = CanExitVehicle()

  if shown then
    button:Show()
    button:Enable()
  else
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:UnlockHighlight()
    button:Hide()
  end
end

function SpecialBar:EnsureVehicleBar()
  if InCombatLockdown() then
    self:QueueVehicleRefresh()
    return self.vehicleBar
  end

  if Core.useBlizzardVehicleUI then
    if self.vehicleBar then
      self.vehicleBar.frame:Hide()
      self.vehicleBar.content:Hide()
    end
    return self.vehicleBar
  end

  local button = _G.MainMenuBarVehicleLeaveButton
  if not button then
    return nil
  end

  local bar = self.vehicleBar
  if not bar then
    bar = Core:CreateBar(
      "vehicleExit",
      "PUI_VehicleExitButtonHolder",
      "ACTIONBAR_VEHICLEEXIT",
      "Vehicle Exit Button",
      GetVehicleDefaultPoint,
      "vehicleExit"
    )
    bar.enabled = true
    self.vehicleBar = bar
  end

  local skin = Core:GetSpecialSkin("vehicleExit", 36)
  local size = math_max(1, tonumber(skin.iconSize) or 36)

  bar.content = button
  bar.frame:SetSize(size, size)
  bar.frame:Show()

  if not self.vehicleButtonOwned then
    self.vehicleButtonOwned = true
    button.ClearAllPoints = nil
    button.SetPoint = nil
    button.SetScale = nil
    button:SetParent(bar.frame)
    button:SetScript("OnShow", nil)
    button:SetScript("OnHide", nil)

    local managedFrames = _G.UIParentBottomManagedFrameContainer
    if managedFrames then
      managedFrames.showingFrames[button] = nil
    end
  end

  button:SetSize(size, size)
  button:SetFrameStrata(bar.frame:GetFrameStrata())
  button:SetFrameLevel(bar.frame:GetFrameLevel() + 1)

  self:InstallVehicleHooks(button)
  self:StyleVehicleButton(button, skin)
  self:AnchorVehicleButton()
  self:UpdateVehicleButton()

  Core:ApplyBarPosition(bar)
  Core:RegisterMover(bar)
  return bar
end

function SpecialBar:RefreshSkin()
  if self.extraBar then
    self:StyleExtraActionFrame(self.extraBar.content, true)
  end
  if self.zoneBar then
    self:StyleZoneAbilityButtons(true)
  end
  if self.vehicleBar and self.vehicleBar.content then
    self:StyleVehicleButton(self.vehicleBar.content, Core:GetSpecialSkin("vehicleExit", 36))
  end
end

function SpecialBar:RefreshLayout()
  self:EnsureExtraBar()
  self:EnsureZoneBar()
  self:EnsureVehicleBar()
end

function SpecialBar:RefreshFull()
  self:EnsureEventFrame()
  self:EnsureExtraBar()
  self:EnsureZoneBar()
  self:EnsureVehicleBar()
end

function SpecialBar:ReconcileWorldState()
  self:EnsureEventFrame()
  self:EnsureExtraBar()
  self:EnsureZoneBar()
  self:EnsureVehicleBar()
end

function SpecialBar:Refresh(flags)
  if InCombatLockdown() then
    Core:QueueRefresh(flags)
    return
  end

  if flags.full then
    self:RefreshFull()
    return
  end

  if flags.skin then
    self:RefreshSkin()
  end
  if flags.layout then
    self:RefreshLayout()
  end
end

function SpecialBar:RefreshDeferred(pending)
  if pending.extraAction then
    self.extraActionRefreshQueued = nil
  end
  if pending.zoneAbility then
    self.zoneAbilityRefreshQueued = nil
  end
  if pending.vehicle then
    self.vehicleRefreshQueued = nil
  end

  if not self.enabled then return end

  if pending.extraAction then
    self:EnsureExtraBar()
  end
  if pending.zoneAbility then
    self:EnsureZoneBar()
  end
  if pending.vehicle then
    self:EnsureVehicleBar()
    self:UpdateVehicleButton()
  end
end

function SpecialBar:OnEvent(event)
  if not self.enabled then return end

  if event == "UPDATE_EXTRA_ACTIONBAR" then
    if InCombatLockdown() then
      self:QueueExtraActionRefresh()
    else
      self:EnsureExtraBar()
    end
  elseif event == "UPDATE_VEHICLE_ACTIONBAR"
    or event == "UPDATE_OVERRIDE_ACTIONBAR"
    or event == "PLAYER_CONTROL_GAINED"
    or event == "PLAYER_CONTROL_LOST"
  then
    if InCombatLockdown() then
      self:QueueVehicleRefresh()
    else
      self:EnsureVehicleBar()
      self:UpdateVehicleButton()
    end
  end
end

function SpecialBar:Disable()
  self.enabled = false
  self.extraActionRefreshQueued = nil
  self.zoneAbilityRefreshQueued = nil
  self.vehicleRefreshQueued = nil

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    self.eventsRegistered = nil
  end

  if self.extraBar then
    self.extraBar.frame:Hide()
  end
  if self.zoneBar then
    self.zoneBar.frame:Hide()
  end
  if self.vehicleBar then
    self.vehicleBar.frame:Hide()
    if self.vehicleBar.content and not InCombatLockdown() then
      self.vehicleBar.content:Hide()
    end
  end
end

SpecialBar.EnsureEventFrame = P:Def("SpecialBar:EnsureEventFrame", SpecialBar.EnsureEventFrame)
SpecialBar.QueueExtraActionRefresh = P:Def("SpecialBar:QueueExtraActionRefresh", SpecialBar.QueueExtraActionRefresh)
SpecialBar.QueueZoneAbilityRefresh = P:Def("SpecialBar:QueueZoneAbilityRefresh", SpecialBar.QueueZoneAbilityRefresh)
SpecialBar.QueueVehicleRefresh = P:Def("SpecialBar:QueueVehicleRefresh", SpecialBar.QueueVehicleRefresh)
SpecialBar.StyleExtraActionFrame = P:Def("SpecialBar:StyleExtraActionFrame", SpecialBar.StyleExtraActionFrame)
SpecialBar.StyleZoneAbilityButtons = P:Def("SpecialBar:StyleZoneAbilityButtons", SpecialBar.StyleZoneAbilityButtons)
SpecialBar.InstallExtraAbilityContainerHook = P:Def("SpecialBar:InstallExtraAbilityContainerHook", SpecialBar.InstallExtraAbilityContainerHook)
SpecialBar.AnchorExtraActionFrame = P:Def("SpecialBar:AnchorExtraActionFrame", SpecialBar.AnchorExtraActionFrame)
SpecialBar.InstallExtraActionHooks = P:Def("SpecialBar:InstallExtraActionHooks", SpecialBar.InstallExtraActionHooks)
SpecialBar.EnsureExtraBar = P:Def("SpecialBar:EnsureExtraBar", SpecialBar.EnsureExtraBar)
SpecialBar.UpdateZoneBarSize = P:Def("SpecialBar:UpdateZoneBarSize", SpecialBar.UpdateZoneBarSize)
SpecialBar.AnchorZoneAbilityFrame = P:Def("SpecialBar:AnchorZoneAbilityFrame", SpecialBar.AnchorZoneAbilityFrame)
SpecialBar.InstallZoneAbilityHooks = P:Def("SpecialBar:InstallZoneAbilityHooks", SpecialBar.InstallZoneAbilityHooks)
SpecialBar.EnsureZoneBar = P:Def("SpecialBar:EnsureZoneBar", SpecialBar.EnsureZoneBar)
SpecialBar.AnchorVehicleButton = P:Def("SpecialBar:AnchorVehicleButton", SpecialBar.AnchorVehicleButton)
SpecialBar.InstallVehicleHooks = P:Def("SpecialBar:InstallVehicleHooks", SpecialBar.InstallVehicleHooks)
SpecialBar.StyleVehicleButton = P:Def("SpecialBar:StyleVehicleButton", SpecialBar.StyleVehicleButton)
SpecialBar.UpdateVehicleButton = P:Def("SpecialBar:UpdateVehicleButton", SpecialBar.UpdateVehicleButton)
SpecialBar.EnsureVehicleBar = P:Def("SpecialBar:EnsureVehicleBar", SpecialBar.EnsureVehicleBar)
SpecialBar.RefreshSkin = P:Def("SpecialBar:RefreshSkin", SpecialBar.RefreshSkin)
SpecialBar.RefreshLayout = P:Def("SpecialBar:RefreshLayout", SpecialBar.RefreshLayout)
SpecialBar.RefreshFull = P:Def("SpecialBar:RefreshFull", SpecialBar.RefreshFull)
SpecialBar.ReconcileWorldState = P:Def("SpecialBar:ReconcileWorldState", SpecialBar.ReconcileWorldState)
SpecialBar.Refresh = P:Def("SpecialBar:Refresh", SpecialBar.Refresh)
SpecialBar.RefreshDeferred = P:Def("SpecialBar:RefreshDeferred", SpecialBar.RefreshDeferred)
SpecialBar.OnEvent = P:Def("SpecialBar:OnEvent", SpecialBar.OnEvent)
SpecialBar.Disable = P:Def("SpecialBar:Disable", SpecialBar.Disable)
GetVehicleDefaultPoint = P:Def("GetVehicleDefaultPoint", GetVehicleDefaultPoint)
GetFrameSize = P:Def("GetFrameSize", GetFrameSize)
GetExtraActionButton = P:Def("GetExtraActionButton", GetExtraActionButton)

Core:RegisterSubsystem("special", SpecialBar)
