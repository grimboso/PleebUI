
local ADDON_NAME, ns = ...

local CastBar = ns.Modules.CastBar
local Theme = ns.Theme
local LSM = ns.LSM
local FrameUtil = ns.FrameUtil

local CreateFrame = CreateFrame
local tonumber = tonumber
local tostring = tostring
local type = type

local Round = ns.Pixel.Round

local function CB_GetBossMove(cfg, unit)
  if not cfg then
    return nil
  end

  cfg.positions = cfg.positions or {}
  if not cfg.positions[unit] then
    cfg.positions[unit] = {
      offsetX = cfg.offsetX or -8,
      offsetY = cfg.offsetY or 0,
      userMoved = false,
    }
  end

  return cfg.positions[unit]
end

local function CB_RefreshTestMode()
  local testMode = ns.TestMode
  if testMode:IsActive() then
    testMode:Refresh("unitframes", "castbar-mover", "uf.castbars")
  end
end

local function CB_ResolveFontPath(fontKey)
  if fontKey == ns.FontDropdown.STANDARD_FONT_KEY or not fontKey or fontKey == "" then
    fontKey = Theme.GetFont("body")
  end

  return LSM:Fetch("font", fontKey, true)
end

local function CB_SetFont(fs, fontKey, size, flags)
  local fontPath = CB_ResolveFontPath(fontKey)
  if not fontPath then
    return
  end

  fs:SetFont(fontPath, Theme.ResolveFontSize(tonumber(size) or 14, "unitFrames"), flags or "")
end

local function CB_GetBorder(frame, cfg)
  if not frame then
    return nil
  end

  local logicalThickness = tonumber(
    (cfg and cfg.borderSize)
    or frame.__puiLogicalBorderSize
    or 1
  ) or 1

  if logicalThickness < 0 then
    logicalThickness = 0
  elseif logicalThickness > 32 then
    logicalThickness = 32
  end

  local thickness = Round(
    logicalThickness * ns.FrameScale:BestOnePixel()
  )

  if not frame.border or not frame.border.SetBackdrop then
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetFrameStrata(frame:GetFrameStrata() or "HIGH")
    border:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
    frame.border = border
  end

  local border = frame.border
  frame.__puiLogicalBorderSize = logicalThickness
  frame.__puiBorderSize = thickness

  if thickness <= 0 then
    border.__puiWanted = false
    border:Hide()

    if frame.__puiBorderGlow then
      frame.__puiBorderGlow.__puiWanted = false
      frame.__puiBorderGlow:Hide()
    end

    return border
  end

  border:Show()
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -thickness, thickness)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", thickness, -thickness)

  border.__puiBackdrop = border.__puiBackdrop or {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = thickness,
  }

  if border.__puiBackdrop.edgeSize ~= thickness then
    border.__puiBackdrop.edgeSize = thickness
  end

  border:SetBackdrop(border.__puiBackdrop)
  border:SetBackdropBorderColor(0, 0, 0, 1)

  return border
end

local function CB_CreateCastBarFrame(frame, unit, options)
  local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  holder:SetSize(Round(240), Round(20))
  holder:SetFrameStrata(frame:GetFrameStrata())
  holder:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
  holder.__puiIsIdle = true
  holder.__puiUnitFrame = frame
  holder.__puiUnit = unit
  holder.__puiState = {
    unit = unit,
    cfg = CastBar:GetUnitConfig(unit),
  }
  holder:Hide()

  frame.__puiCastbarHolder = holder

  local element = CreateFrame("StatusBar", nil, holder)
  element:SetAllPoints(holder)
  element:SetMinMaxValues(0, 1)
  element:SetValue(0)
  element:SetStatusBarTexture(ns.BarWidget.ResolveStatusBarTexture("Pleebar"))

  holder.status = element

  holder.bg = holder:CreateTexture(nil, "BACKGROUND")
  holder.bg:SetAllPoints(element)
  holder.bg:SetColorTexture(0, 0, 0, 0.40)

  holder.spark = element:CreateTexture(nil, "OVERLAY", nil, 7)
  holder.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  holder.spark:SetBlendMode("ADD")
  holder.spark:SetWidth(Round(16))
  holder.spark:Hide()

  holder.icon = holder:CreateTexture(nil, "ARTWORK")
  holder.icon:SetSize(Round(20), Round(20))
  holder.icon:SetPoint("LEFT", holder, "LEFT", 0, 0)
  holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  holder.spellName = element:CreateFontString(nil, "OVERLAY")
  holder.spellName:SetPoint("LEFT", element, "LEFT", Round(6), 0)
  holder.spellName:SetJustifyH("LEFT")
  CB_SetFont(holder.spellName, nil, 14, "OUTLINE")

  holder.timeText = element:CreateFontString(nil, "OVERLAY")
  holder.timeText:SetPoint("RIGHT", element, "RIGHT", -Round(6), 0)
  holder.timeText:SetJustifyH("RIGHT")
  CB_SetFont(holder.timeText, nil, 14, "OUTLINE")
  holder.timeTextBinding = CastBar.CreateTimeTextBinding(holder.timeText)

  holder.delayText = element:CreateFontString(nil, "OVERLAY")
  CB_SetFont(holder.delayText, nil, 14, "OUTLINE")
  holder.delayText:Hide()

  holder.messageText = element:CreateFontString(nil, "OVERLAY")
  holder.messageText:SetPoint("CENTER", element, "CENTER", 0, 0)
  holder.messageText:SetJustifyH("CENTER")
  CB_SetFont(holder.messageText, nil, 14, "OUTLINE")
  holder.messageText:Hide()

  holder.stopOverlay = element:CreateTexture(nil, "OVERLAY")
  holder.stopOverlay:SetAllPoints(element)
  holder.stopOverlay:SetColorTexture(1, 0.10, 0.10, 0.00)
  holder.stopOverlay:Hide()

  holder.uninterrupt = CreateFrame("Frame", nil, holder)
  holder.uninterrupt:SetAllPoints(holder)
  holder.uninterrupt:SetAlpha(0)
  holder.uninterrupt:EnableMouse(false)
  holder.uninterrupt:Hide()

  holder.uninterruptLeft = holder.uninterrupt:CreateTexture(nil, "OVERLAY")
  holder.uninterruptLeft:SetSize(Round(16), Round(16))
  holder.uninterruptLeft:SetPoint("LEFT", holder, "LEFT", -Round(18), 0)
  holder.uninterruptLeft:SetAtlas("UI-CastingBar-Shield", true)
  holder.uninterruptLeft:Hide()

  holder.uninterruptRight = holder.uninterrupt:CreateTexture(nil, "OVERLAY")
  holder.uninterruptRight:SetSize(Round(16), Round(16))
  holder.uninterruptRight:SetPoint("RIGHT", holder, "RIGHT", Round(18), 0)
  holder.uninterruptRight:SetAtlas("UI-CastingBar-Shield", true)
  holder.uninterruptRight:Hide()

  element.Icon = holder.icon
  element.Text = holder.spellName
  element.Time = holder.timeText
  element.Shield = holder.uninterrupt
  element.Spark = holder.spark
  element.__puiOwnerBar = holder

  holder.Castbar = element
  frame.Castbar = element

  ns.PUICastBarEmpower:OnCreate(holder, holder, element, unit)

  if unit == "player" then
    CastBar:CreatePlayerCastbarExtras(holder, holder, element, unit)
  end

  CB_GetBorder(holder)

  if not (options and options.skipMover == true)
    and not (type(unit) == "string" and unit:match("^boss%d"))
  then
    FrameUtil:RegisterMover("CastBar_" .. tostring(unit), holder, {
      label = "CastBar: " .. unit,
      useOverlayDrag = true,
      optionsString = "unitframes," .. (
        (unit == "target" and "target")
        or (unit == "focus" and "focus")
        or (unit == "pet" and "pet")
        or "player"
      ) .. ",castbar",
      overlayBelowFrame = true,
      smartSnap = (
        (unit == "player" and {
          family = "unitFramesPlayer",
          families = { combatBars = true },
          syncAxis = "WIDTH",
          syncWidthMin = 80,
          syncWidthMax = 800,
          getSyncWidth = function()
            local cfg = CastBar:GetUnitConfig("player")
            return cfg and cfg.width or nil
          end,
          applySyncWidth = function(width)
            local cfg = CastBar:GetUnitConfig("player")
            if not cfg then
              return
            end
            cfg.width = Round(width)
            CastBar:UpdateUnitLayout("player")
            CB_RefreshTestMode()
          end,
        })
        or (unit == "target" and { family = "unitFramesTarget" })
        or (unit == "focus" and { family = "unitFramesFocus" })
        or (unit == "pet" and {
          family = "unitFramesPet",
          isRuntimeActive = function()
            local cfg = CastBar:GetUnitConfig("pet")
            local unitFrame = holder.__puiUnitFrame
            return CastBar.db.profile.enabled ~= false
              and cfg.enabled ~= false
              and (ns.Flags.IsEditing == true or unitFrame:IsVisible())
          end,
        })
        or nil
      ),
      quickSettings = function()
        local cfg = CastBar:GetUnitConfig(unit)
        local function Refresh()
          CastBar:UpdateUnitLayout(unit)
          CB_RefreshTestMode()
        end

        local controls = {}

        controls[#controls + 1] = {
          type = "slider",
          label = "Width",
          min = 80,
          max = 800,
          step = 1,
          commitOnRelease = true,
          get = function() return cfg.width end,
          set = function(value)
            cfg.width = Round(value)
            Refresh()
            FrameUtil.RefreshSmartSnapState("CastBar_" .. tostring(unit))
          end,
        }
        controls[#controls + 1] = {
          type = "slider",
          label = "Height",
          min = 6,
          max = 80,
          step = 1,
          get = function() return cfg.height end,
          set = function(value)
            cfg.height = Round(value)
            Refresh()
            FrameUtil.RefreshSmartSnapState("CastBar_" .. tostring(unit))
          end,
        }
        controls[#controls + 1] = {
          type = "statusbar",
          label = "Texture",
          values = ns.OptionsUtil.BuildStatusbarValues(false),
          get = function() return cfg.texture end,
          set = function(value)
            cfg.texture = value
            Refresh()
          end,
        }
        controls[#controls + 1] = {
          type = "slider",
          label = "Border size",
          min = 0,
          max = 10,
          step = 1,
          get = function() return cfg.borderSize end,
          set = function(value)
            cfg.borderSize = Round(value)
            Refresh()
          end,
        }
        controls[#controls + 1] = {
          type = "slider",
          label = "Font size",
          min = 6,
          max = 32,
          step = 1,
          get = function() return cfg.text.size end,
          set = function(value)
            cfg.text.size = Round(value)
            Refresh()
          end,
        }

        return {
          ownerKey = "CastBar_" .. tostring(unit),
          title = "CastBar: " .. unit,
          description = "Live cast bar settings.",
          controls = controls,
        }
      end,
      onDragStop = function(mover)
        local cfg = CastBar:GetUnitConfig(unit)
        if not cfg then
          return
        end

        local x, y = FrameUtil.GetMoverOffsets(mover)

        cfg.offsetX = Round(x)
        cfg.offsetY = Round(y)
        cfg.userMoved = true

        CastBar:UpdateUnitLayout(unit)
        CB_RefreshTestMode()
      end,
      resetPosition = function()
        local cfg = CastBar:GetUnitConfig(unit)
        if not cfg then
          return
        end

        if unit == "player" then
          cfg.offsetX = 0
          cfg.offsetY = -72
          cfg.userMoved = false
        elseif unit == "target" or unit == "focus" then
          cfg.offsetX = 0
          cfg.offsetY = 30
          cfg.userMoved = false
        else
          cfg.offsetX = 0
          cfg.offsetY = -12
          cfg.userMoved = false
        end

        CastBar:UpdateUnitLayout(unit)
        CB_RefreshTestMode()
      end,
    })

  end

  return holder
end

function CastBar:AttachToUnitFrame(frame, unit)
  self.bars = self.bars or {}

  local holder = frame.__puiCastbarHolder or CB_CreateCastBarFrame(frame, unit)
  local element = frame.Castbar

  self.bars[unit] = holder

  holder.__puiState.unit = unit
  holder.__puiState.cfg = self:GetUnitConfig(unit)

  self:BindCallbacks(holder, element, unit)

  if unit == "player" and self:IsEnabled() then
    self:EnablePlayerCastbarEvents()
  end

  return holder
end

CastBar.SetFont = CB_SetFont
CastBar.GetBorder = CB_GetBorder
CastBar.GetBossMove = CB_GetBossMove
CastBar.CreateCastBarFrame = CB_CreateCastBarFrame


local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Construct" }))


  CB_GetBossMove = P:Def("CB_GetBossMove", CB_GetBossMove)
  CB_RefreshTestMode = P:Def("CB_RefreshTestMode", CB_RefreshTestMode)
  CB_ResolveFontPath = P:Def("CB_ResolveFontPath", CB_ResolveFontPath)
  CB_SetFont = P:Def("CB_SetFont", CB_SetFont)
  CB_GetBorder = P:Def("CB_GetBorder", CB_GetBorder)
  CB_CreateCastBarFrame = P:Def("CB_CreateCastBarFrame", CB_CreateCastBarFrame)
  CastBar.AttachToUnitFrame = P:Def("CastBar.AttachToUnitFrame", CastBar.AttachToUnitFrame)

  CastBar.SetFont = CB_SetFont
  CastBar.GetBorder = CB_GetBorder
  CastBar.GetBossMove = CB_GetBossMove
  CastBar.CreateCastBarFrame = CB_CreateCastBarFrame
