local _, ns = ...

local Addon = ns.Addon
local Motion = {}
ns.OptionsMotion = Motion

local states = setmetatable({}, { __mode = "k" })
local active = {}
local groupTypes = { TreeGroup = true, TabGroup = true, DropdownGroup = true }

function Motion.IsEnabled()
  return Addon:GetOptionsDB().animateOptions ~= false
end

local function Finish(state, alpha)
  state.group:Stop()
  active[state] = nil
  state.target = alpha
  state.region:SetAlpha(alpha)
end

local function GetState(region, owner, restingAlpha)
  local state = states[region]
  if state then return state end

  local group = region:CreateAnimationGroup()
  local alpha = group:CreateAnimation("Alpha")
  state = { region = region, group = group, alpha = alpha, target = restingAlpha, restingAlpha = restingAlpha }
  states[region] = state
  group:SetScript("OnFinished", function()
    active[state] = nil
    region:SetAlpha(state.target)
  end)
  owner:HookScript("OnHide", function() Finish(state, restingAlpha) end)
  return state
end

local function Play(state, fromAlpha, targetAlpha, duration, smoothing)
  state.group:Stop()
  state.from = fromAlpha
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

local function FinishReveals()
  for state in pairs(active) do
    if state.restingAlpha == 1 then Finish(state, 1) end
  end
end

function Motion.Reveal(region)
  FinishReveals()
  if not region:IsShown() or not Motion.IsEnabled() then return end
  Play(GetState(region, region, 1), 0, 1, 0.15, "OUT")
end

function Motion.Stop(region)
  local state = states[region]
  if state then Finish(state, state.restingAlpha) end
end

function Motion.SetHoverColor(texture, color)
  -- Vertex color also writes opacity; recoloring must preserve the fade state.
  texture:SetVertexColor(color[1], color[2], color[3], texture:GetAlpha())
end

function Motion.Hover(owner, texture, hovered)
  local state = GetState(texture, owner, 0)
  local targetAlpha = hovered and 0.10 or 0
  texture:Show()
  if state.target == targetAlpha then return end

  local fromAlpha = texture:GetAlpha()
  if state.group:IsPlaying() then
    local progress = state.alpha:GetSmoothProgress()
    fromAlpha = state.from + (state.target - state.from) * progress
  end
  Play(state, fromAlpha, targetAlpha, hovered and 0.18 or 0.22, "IN_OUT")
end

function Motion.StyleTreeHover(button)
  local texture = button.__puiOptionsHover
  if not texture then
    texture = button:CreateTexture(nil, "BORDER")
    texture:SetAllPoints(button)
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetAlpha(0)
    ns.Theme.MarkCreatedWidgetChrome(texture)
    button.__puiOptionsHover = texture
    button:HookScript("OnEnter", function()
      if button.obj.__puiAceGUIOwnedByPleebUI == true then
        Motion.Hover(button, texture, true)
      end
    end)
    button:HookScript("OnLeave", function()
      if button.obj.__puiAceGUIOwnedByPleebUI == true then
        Motion.Hover(button, texture, false)
      end
    end)
  end
  local accent = ns.Theme.GetColors().accent
  Motion.SetHoverColor(texture, accent)
  texture:Show()
end

function Motion.BindGroup(widget)
  if not groupTypes[widget.type] or widget.__puiMotionOriginalFire then return end

  local originalFire = widget.Fire
  widget.__puiMotionOriginalFire = originalFire
  widget.__puiMotionSelection = (widget.status or widget.localstatus).selected
  widget.Fire = function(self, event, ...)
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
  end
end

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

function Motion.Reset()
  for state in pairs(active) do Finish(state, state.restingAlpha) end
end

function Motion.SetEnabled(enabled)
  Addon:GetOptionsDB().animateOptions = enabled == true
  if not enabled then
    for state in pairs(active) do Finish(state, state.target) end
  end
end
