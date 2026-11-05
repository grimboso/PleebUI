local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local Core = ns.ActionBarsCore
local FrameUtil = ns.FrameUtil
local Theme = ns.Theme
local ExperienceBar = {}
local moverKey = "PUI_ExperienceBar"
local position = {
  moverKey = moverKey,
  defaultPoint = { "BOTTOM", "UIParent", "BOTTOM", 0, 30 },
}

local slots = {}
local running = false
local combatEvents = CreateFrame("Frame")

local function GetSettings()
  return Core:GetDB().experienceBar
end

local function ApplyFill(slot)
  local status = slot.bar.StatusBar
  status:SetStatusBarTexture(slot.fillTexture)
  status:SetStatusBarColor(slot.fillRed, slot.fillGreen, slot.fillBlue, slot.fillAlpha)
end

local function ApplyText(bar)
  local mode = GetSettings().text
  if mode ~= "blizzard" then
    bar.OverlayFrame.Text:SetShown(mode == "always")
  end
end

local function HideChrome(slot)
  local container = slot.container
  container.BarFrameTexture:Hide()
  local dividers = container.HorizontalDividersPool
  if not dividers then return end
  for divider in dividers:EnumerateActive() do
    local texture = divider.BarDividerTexture
    if slot.dividerShown[texture] == nil then
      slot.dividerShown[texture] = texture:IsShown()
    end
    texture:Hide()
  end
end

local function UpdateTicks(slot, settings)
  if not settings.showTicks then
    if slot.ticks then
      for _, tick in ipairs(slot.ticks) do
        tick:Hide()
      end
    end
    return
  end

  local backdrop = slot.backdrop
  local pixel = ns.Pixel.GetOnePixel()
  slot.ticks = slot.ticks or {}
  for index = 1, 9 do
    local tick = slot.ticks[index]
    if not tick then
      tick = backdrop:CreateTexture(nil, "OVERLAY")
      tick:SetColorTexture(0, 0, 0, 0.55)
      slot.ticks[index] = tick
    end
    local x = ns.Pixel.Round(settings.width * index / 10)
    tick:ClearAllPoints()
    tick:SetPoint("TOPLEFT", backdrop, "TOPLEFT", x, 0)
    tick:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", x, 0)
    tick:SetWidth(pixel)
    tick:Show()
  end
end

local function ApplyGeometry(slot)
  local bar = slot.bar
  local settings = GetSettings()
  UpdateTicks(slot, settings)
  bar:SetSize(settings.width, settings.height)
  bar.StatusBar:SetSize(settings.width, settings.height)
  bar.ExhaustionLevelFillBar:SetHeight(settings.height)
  position.frame = bar
  Core:ApplyBarPosition(position)
  position.frame = nil
  bar:UpdateTick()
end

local function RestoreSlot(slot)
  local original = slot.original
  if not original then return end
  slot.original = nil

  local container, bar = slot.container, slot.bar
  local status = bar.StatusBar
  bar:ClearAllPoints()
  bar:SetPoint(unpack(original.point))
  bar:SetSize(unpack(original.size))
  status:SetSize(unpack(original.statusSize))

  container.BarFrameTexture:SetShown(original.frameShown)
  for texture, shown in pairs(slot.dividerShown) do
    texture:SetShown(shown)
  end
  wipe(slot.dividerShown)
  status.Background:SetAlpha(original.backgroundAlpha)
  status:SetStatusBarTexture(original.fill)
  status:SetStatusBarColor(unpack(original.fillColor))

  local rested = bar.ExhaustionLevelFillBar
  rested:SetAtlas(original.restedAtlas)
  rested:SetHeight(original.restedHeight)
  rested:SetVertexColor(unpack(original.restedColor))
  bar.OverlayFrame.Text:SetFont(unpack(original.font))
  slot.backdrop:Hide()
  slot.background:Hide()
  bar:UpdateTick()
  bar:UpdateTextVisibility()
end

local function StyleSlot(slot)
  local bar = slot.bar
  local status = bar.StatusBar
  local rested = bar.ExhaustionLevelFillBar
  local label = bar.OverlayFrame.Text

  if not slot.original then
    local fill = status:GetStatusBarTexture()
    slot.original = {
      point = { bar:GetPoint(1) },
      size = { bar:GetSize() },
      statusSize = { status:GetSize() },
      frameShown = slot.container.BarFrameTexture:IsShown(),
      backgroundAlpha = status.Background:GetAlpha(),
      fill = fill:GetAtlas() or fill:GetTexture(),
      fillColor = { status:GetStatusBarColor() },
      restedAtlas = rested:GetAtlas(),
      restedHeight = rested:GetHeight(),
      restedColor = { rested:GetVertexColor() },
      font = { label:GetFont() },
    }
  end

  local settings = GetSettings()
  local skin = Core:GetDB().skin
  -- Blizzard can reapply the XP texture between PleebUI refreshes.
  slot.fillTexture = Theme.GetBarTexture()
  slot.fillRed, slot.fillGreen, slot.fillBlue, slot.fillAlpha = unpack(settings.fillColor)
  if not slot.backdrop then
    local backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    backdrop:SetAllPoints(bar)
    backdrop:SetFrameLevel(bar:GetFrameLevel() + 1)
    local background = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetAllPoints(bar)
    slot.backdrop = backdrop
    slot.background = background
  end

  HideChrome(slot)
  status.Background:SetAlpha(0)
  slot.background:SetColorTexture(unpack(skin.frameBgColor))
  local borderSize = skin.frameBorderSize
  if borderSize > 0 then
    slot.backdrop:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = borderSize,
    })
    slot.backdrop:SetBackdropBorderColor(unpack(skin.frameBorderColor))
  else
    slot.backdrop:SetBackdrop(nil)
  end
  slot.backdrop:Show()
  slot.background:Show()
  rested:SetTexture(slot.fillTexture)
  rested:SetVertexColor(unpack(settings.restedColor))
  label:SetFont(Core:ResolveFont(), skin.fontSize, skin.fontOutline)
  ApplyGeometry(slot)
  ApplyFill(slot)
  bar:UpdateTextVisibility()
end

local function SyncSlot(slot)
  local wanted = running and GetSettings().enabled and slot.container:GetShownBar() == slot.bar
  if not wanted and not slot.original then return end
  if InCombatLockdown() then
    combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if wanted then
    StyleSlot(slot)
  else
    RestoreSlot(slot)
  end
end

combatEvents:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for _, slot in ipairs(slots) do
    SyncSlot(slot)
  end
  FrameUtil:RefreshGhostMover(moverKey)
end)

local function AttachSlots(manager)
  for _, container in ipairs(manager.barContainers) do
    local bar = container.bars[StatusTrackingBarInfo.BarsEnum.Experience]
    local slot = { container = container, bar = bar, dividerShown = {} }
    slots[#slots + 1] = slot

    hooksecurefunc(container, "ApplyPendingBarToShow", function()
      if (container:GetShownBar() == bar) ~= (slot.original ~= nil) then
        SyncSlot(slot)
      end
    end)
    hooksecurefunc(container, "UpdateShownState", function()
      if slot.original and container:GetShownBar() == bar then
        HideChrome(slot)
      end
    end)
    if container.ResizeContainerBars then
      hooksecurefunc(container, "ResizeContainerBars", function()
        local original = slot.original
        if not original then return end
        original.size[1], original.size[2] = bar:GetSize()
        original.statusSize[1], original.statusSize[2] = bar.StatusBar:GetSize()
        if container:GetShownBar() == bar then
          if InCombatLockdown() then
            combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
          else
            ApplyGeometry(slot)
          end
        end
      end)
    end
    if container.UpdateDividers then
      hooksecurefunc(container, "UpdateDividers", function()
        if slot.original and container:GetShownBar() == bar then
          HideChrome(slot)
        end
      end)
    end
    hooksecurefunc(bar, "UpdateStatusBarTextures", function()
      if slot.original then
        local fill = bar.StatusBar:GetStatusBarTexture()
        slot.original.fill = fill:GetAtlas() or fill:GetTexture()
        ApplyFill(slot)
      end
    end)
    hooksecurefunc(bar, "UpdateTextVisibility", function()
      if slot.original then
        ApplyText(bar)
      end
    end)
  end
end

function ExperienceBar:Update()
  for _, slot in ipairs(slots) do
    SyncSlot(slot)
  end
  if not InCombatLockdown() then
    FrameUtil:RefreshGhostMover(moverKey)
  end
end

function ExperienceBar:Refresh()
  running = true
  local manager = StatusTrackingBarManager
  if not manager then return end

  if #slots == 0 then
    AttachSlots(manager)
    FrameUtil:EnsureGhostMover(moverKey, {
      frameName = "PUI_ExperienceBarMover",
      label = "Experience Bar",
      moduleKey = "actionBars",
      moduleLabel = "Action Bars",
      optionsString = "ACTIONBARS,experienceBar",
      getSize = function()
        local settings = GetSettings()
        return settings.width, settings.height
      end,
      getPoint = function()
        return Core:GetSavedPoint(position)
      end,
      shouldShow = function()
        return running and GetSettings().enabled and ns.Flags.IsEditing
      end,
      savePosition = function(mover)
        position.frame = mover
        Core:SaveMoverPosition(position, mover)
        position.frame = nil
        self:Update()
      end,
      resetPosition = function()
        Core:GetDB().movers[moverKey] = nil
        self:Update()
      end,
    })
  end

  self:Update()
end

function ExperienceBar:Disable()
  running = false
  self:Update()
end

ns.ExperienceBar = ExperienceBar
Core:RegisterSubsystem("experienceBar", ExperienceBar)
