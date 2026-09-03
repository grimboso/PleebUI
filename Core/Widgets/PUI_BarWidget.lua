local _, ns = ...

local BarWidget = {}
ns.BarWidget = BarWidget

local C_DurationUtil = C_DurationUtil
local C_StringUtil = C_StringUtil

local DurationFormatter

function BarWidget.GetDurationFormatter()
  if not DurationFormatter then
    DurationFormatter = C_StringUtil.CreateNumericRuleFormatter()
    DurationFormatter:AddBreakpoint({ threshold = 0, format = "%.0f" })
  end

  return DurationFormatter
end

function BarWidget.CreateDurationBinding(fontString)
  local binding = C_DurationUtil.CreateDurationTextBinding()
  binding:SetFontString(fontString)
  binding:SetFormatter(BarWidget.GetDurationFormatter())
  binding:SetUpdateInterval(0.1)
  binding:SetZeroDurationText("")
  binding:SetExpiredText("")
  binding:Disable()
  return binding
end

function BarWidget.StopTimerBar(bar)
  if bar.Clear then
    bar:Clear()
  else
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
  end
end

function BarWidget.ResolveStatusBarTexture(key, fallback)
  if type(key) == "string" and key ~= "" then
    local path = ns.LSM:Fetch("statusbar", key, true)
    if type(path) == "string" and path ~= "" then
      return path
    end

    if key:find("\\", 1, true) or key:find("/", 1, true) then
      return key
    end
  end

  return fallback or ns.Theme.GetBarTexture()
end

function BarWidget.BindDurationBarFrame(frame, state)
  state = state or {}
  local barFrame = frame.PUIBarFrame
  local textHolder = barFrame.PUITextHolder
  local iconFrame = frame.PUIIconFrame

  state.frame = frame
  state.barFrame = barFrame
  state.bg = barFrame.PUIBackground
  state.cooldownBar = barFrame.PUIStatusBar
  state.textFrame = textHolder
  state.text = textHolder.PUIDurationText
  state.iconFrame = iconFrame
  state.icon = iconFrame.PUIIcon
  return state
end

function BarWidget.BindChargeBarFrame(frame, state)
  state = state or {}
  local iconFrame = frame.PUIIconFrame
  local slotsContainer = frame.PUISlotsContainer
  local textHolder = slotsContainer.PUIDurationTextHolder

  state.frame = frame
  state.iconFrame = iconFrame
  state.icon = iconFrame.PUIIcon
  state.slotsContainer = slotsContainer
  state.chargeTrackerBar = slotsContainer.PUIChargeTracker
  state.chargeTrackerTexture = state.chargeTrackerBar:GetStatusBarTexture()
  state.timerTextContainer = textHolder
  state.timerText = textHolder.PUIDurationText
  return state
end

function BarWidget.BindChargeSlotFrame(frame, state)
  state = state or {}
  local border = frame.PUIBorder

  state.frame = frame
  state.background = frame.PUIBackground
  state.rechargeBar = frame.PUIRechargeBar
  state.fullBar = frame.PUIFullBar
  state.borderFrame = border
  border.top = border.Top
  border.bottom = border.Bottom
  border.left = border.Left
  border.right = border.Right
  return state
end

function BarWidget.ApplyBorder(frame, thickness, color)
  ns.IconSkin.ApplyBorder(frame, {
    enabled = (tonumber(thickness) or 0) > 0,
    thickness = thickness,
    color = color,
  })
end

local P = select(1, ns.Pleebug:DropIn(BarWidget, { name = "Core.BarWidget" }))
BarWidget.GetDurationFormatter = P:Def("BarWidget.GetDurationFormatter", BarWidget.GetDurationFormatter)
BarWidget.CreateDurationBinding = P:Def("BarWidget.CreateDurationBinding", BarWidget.CreateDurationBinding)
BarWidget.StopTimerBar = P:Def("BarWidget.StopTimerBar", BarWidget.StopTimerBar)
BarWidget.ResolveStatusBarTexture = P:Def(
  "BarWidget.ResolveStatusBarTexture",
  BarWidget.ResolveStatusBarTexture
)
BarWidget.BindDurationBarFrame = P:Def(
  "BarWidget.BindDurationBarFrame",
  BarWidget.BindDurationBarFrame
)
BarWidget.BindChargeBarFrame = P:Def("BarWidget.BindChargeBarFrame", BarWidget.BindChargeBarFrame)
BarWidget.BindChargeSlotFrame = P:Def("BarWidget.BindChargeSlotFrame", BarWidget.BindChargeSlotFrame)
BarWidget.ApplyBorder = P:Def("BarWidget.ApplyBorder", BarWidget.ApplyBorder)
