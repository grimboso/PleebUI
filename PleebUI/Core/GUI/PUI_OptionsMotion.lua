local _, ns = ...
local PUI_OptionsProfiler = select(1, ns.Pleebug:DropIn({}))

local Addon = ns.Addon
local Motion = {}
ns.OptionsMotion = Motion

local states = setmetatable({}, { __mode = "k" })
local active = {}
local groupTypes = { TreeGroup = true, TabGroup = true, DropdownGroup = true }
local HOVER_ALPHA = 0.26

function Motion.IsEnabled()
  return Addon:GetOptionsDB().animateOptions ~= false
end
Motion.IsEnabled = PUI_OptionsProfiler:Def("Motion.IsEnabled", Motion.IsEnabled)


local function Finish(state, alpha)
  state.group:Stop()
  active[state] = nil
  state.target = alpha
  state.hovered = nil
  state.hoverPending = nil
  state.region:SetAlpha(alpha)
end
Finish = PUI_OptionsProfiler:Def("Finish", Finish)


local function Play(state, fromAlpha, targetAlpha, duration, smoothing)
  state.group:Stop()
  state.target = targetAlpha
  state.region:SetAlpha(fromAlpha)
  if not Motion.IsEnabled() or fromAlpha == targetAlpha then
    Finish(state, targetAlpha)
    return
  end
  state.alpha:SetFromAlpha(fromAlpha)
  state.alpha:SetToAlpha(targetAlpha)
  state.alpha:SetDuration(duration)
  state.alpha:SetSmoothing(smoothing)
  active[state] = true
  state.group:Play()
end
Play = PUI_OptionsProfiler:Def("Play", Play)


local function GetState(region, owner, restingAlpha)
  local state = states[region]
  if state then return state end

  local group = region:CreateAnimationGroup()
  local alpha = group:CreateAnimation("Alpha")
  state = { region = region, group = group, alpha = alpha, target = restingAlpha, restingAlpha = restingAlpha }
  states[region] = state
  group:SetScript("OnFinished", PUI_OptionsProfiler:DefCallback("GetState > group.SetScript OnFinished", function()
    active[state] = nil
    region:SetAlpha(state.target)
    if restingAlpha == 0 then
      if state.target == 0 and state.hoverPending then
        state.hoverPending = nil
        Play(state, 0, HOVER_ALPHA, 0.18, "IN_OUT")
      elseif state.target ~= 0 and state.hovered == false then
        Play(state, state.target, 0, 0.22, "IN_OUT")
      end
    end
  end))
  owner:HookScript("OnHide", PUI_OptionsProfiler:DefCallback("GetState > owner.HookScript OnHide", function() Finish(state, restingAlpha) end))
  return state
end
GetState = PUI_OptionsProfiler:Def("GetState", GetState)


local function FinishReveals()
  for state in pairs(active) do
    if state.restingAlpha == 1 then Finish(state, 1) end
  end
end
FinishReveals = PUI_OptionsProfiler:Def("FinishReveals", FinishReveals)


function Motion.Reveal(region)
  FinishReveals()
  if not region:IsShown() or not Motion.IsEnabled() then return end
  Play(GetState(region, region, 1), 0, 1, 0.30, "OUT")
end
Motion.Reveal = PUI_OptionsProfiler:Def("Motion.Reveal", Motion.Reveal)


function Motion.Stop(region)
  local state = states[region]
  if state then Finish(state, state.restingAlpha) end
end
Motion.Stop = PUI_OptionsProfiler:Def("Motion.Stop", Motion.Stop)


function Motion.SetHoverColor(texture, color)
  -- Vertex color also writes opacity; recoloring must preserve the fade state.
  texture:SetVertexColor(color[1], color[2], color[3], texture:GetAlpha())
end
Motion.SetHoverColor = PUI_OptionsProfiler:Def("Motion.SetHoverColor", Motion.SetHoverColor)


function Motion.Hover(owner, texture, hovered)
  local state = GetState(texture, owner, 0)
  local wasHovered = state.hovered
  state.hovered = hovered == true
  local targetAlpha = hovered and HOVER_ALPHA or 0
  texture:Show()
  if state.group:IsPlaying() and Motion.IsEnabled() then
    if hovered and not wasHovered and state.target == 0 then
      state.hoverPending = true
    end
    return
  end
  if state.target == targetAlpha then return end
  Play(state, texture:GetAlpha(), targetAlpha, hovered and 0.18 or 0.22, "IN_OUT")
end
Motion.Hover = PUI_OptionsProfiler:Def("Motion.Hover", Motion.Hover)


function Motion.StyleTreeHover(button)
  local texture = button.__puiOptionsHover
  if not texture then
    texture = button:CreateTexture(nil, "BORDER")
    texture:SetAllPoints(button)
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetAlpha(0)
    ns.Theme.MarkCreatedWidgetChrome(texture)
    button.__puiOptionsHover = texture
    button:HookScript("OnEnter", PUI_OptionsProfiler:DefCallback("Motion.StyleTreeHover > button.HookScript OnEnter", function()
      if button.obj.__puiAceGUIOwnedByPleebUI == true then
        Motion.Hover(button, texture, true)
      end
    end))
    button:HookScript("OnLeave", PUI_OptionsProfiler:DefCallback("Motion.StyleTreeHover > button.HookScript OnLeave", function()
      if button.obj.__puiAceGUIOwnedByPleebUI == true then
        Motion.Hover(button, texture, false)
      end
    end))
  end
  local accent = ns.Theme.GetColors().accent
  Motion.SetHoverColor(texture, accent)
  texture:Show()
end
Motion.StyleTreeHover = PUI_OptionsProfiler:Def("Motion.StyleTreeHover", Motion.StyleTreeHover)


function Motion.BindGroup(widget)
  if not groupTypes[widget.type] or widget.__puiMotionOriginalFire then return end

  local originalFire = widget.Fire
  widget.__puiMotionOriginalFire = originalFire
  widget.__puiMotionSelection = (widget.status or widget.localstatus).selected
  widget.Fire = PUI_OptionsProfiler:DefCallback("Motion.BindGroup > widget.Fire", function(self, event, ...)
    if event ~= "OnGroupSelected" then return originalFire(self, event, ...) end

    local value = ...
    local changed = self.__puiMotionSelection ~= value
    local serial = self.__puiAceGUIOwnershipSerial
    local state = states[self.content]
    if state then Finish(state, 1) end
    local result = originalFire(self, event, ...)

    -- AceGUI can release and reuse containers while feeding a selected group.
    if self.__puiAceGUIOwnedByPleebUI == true and self.__puiAceGUIOwnershipSerial == serial then
      self.__puiMotionSelection = value
      local frame = Addon._OptionsWindow
      if changed and self:GetUserData("appName") == "PleebUI"
        and frame and frame:IsShown() and not frame.__puiRenderingOptionsPath
      then
        Motion.Reveal(self.content)
      end
    end
    return result
  end)
end
Motion.BindGroup = PUI_OptionsProfiler:Def("Motion.BindGroup", Motion.BindGroup)


function Motion.ReleaseWidget(widget)
  if widget.__puiMotionOriginalFire then
    widget.Fire = widget.__puiMotionOriginalFire
    widget.__puiMotionOriginalFire = nil
    widget.__puiMotionSelection = nil
  end
  local state = widget.content and states[widget.content]
  if state then Finish(state, 1) end
  for _, button in ipairs(widget.buttons or {}) do
    local hover = button.__puiOptionsHover
    local hoverState = hover and states[hover]
    if hoverState then Finish(hoverState, 0) end
    if hover then hover:Hide() end
  end
end
Motion.ReleaseWidget = PUI_OptionsProfiler:Def("Motion.ReleaseWidget", Motion.ReleaseWidget)


function Motion.Reset()
  for state in pairs(active) do Finish(state, state.restingAlpha) end
end
Motion.Reset = PUI_OptionsProfiler:Def("Motion.Reset", Motion.Reset)


function Motion.SetEnabled(enabled)
  Addon:GetOptionsDB().animateOptions = enabled == true
  if not enabled then
    for state in pairs(active) do
      local alpha = state.restingAlpha == 0 and (state.hovered and HOVER_ALPHA or 0) or state.target
      Finish(state, alpha)
    end
  end
end
Motion.SetEnabled = PUI_OptionsProfiler:Def("Motion.SetEnabled", Motion.SetEnabled)
