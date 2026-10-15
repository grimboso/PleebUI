local _, ns = ...
local Preview = {}
ns.InstallerPreview = Preview
Preview.SampleStates = {
  unitframes = { values = { [25] = "Low: 25%", [60] = "Medium: 60%", [100] = "Full: 100%" }, order = { 25, 60, 100 }, initial = 60 },
  auras = { values = { ACTIVE = "Active", EXPIRING = "Expiring: 1 second left", INACTIVE = "Inactive: no auras" }, order = { "ACTIVE", "EXPIRING", "INACTIVE" }, initial = "ACTIVE", animated = true },
  prd = { values = { [0] = "Empty", [0.5] = "Half full", [1] = "Full" }, order = { 0, 0.5, 1 }, initial = 0.5, animated = true },
  actionbars = { animated = true },
  cooldowns = { values = { [0] = "Start of sample", [4] = "4 seconds into sample", [8] = "8 seconds into sample" }, order = { 0, 4, 8 }, initial = 4, animated = true },
}

function Preview.GetSampleStates(kind, path)
  return Preview.SampleStates[kind == "unitframes" and path[4] == "customDisplays" and "auras" or kind]
end

local owners = { unitframes = {}, actionbars = {}, cooldowns = {}, prd = {}, quality = {}, meters = {}, everyday = {}, movement = {} }
local settingsRoots = { unitframes = "unitframes", actionbars = "ACTIONBARS", cooldowns = "CooldownManager", prd = "PRD", quality = "Quality" }
local current
local openOptions
local draftTimer
local events = CreateFrame("Frame")
local pausedUpdates, pausedCooldowns, pausedAnimations = {}, {}, {}
local AdvanceDraft
local navigation = {
  NavigateOpenOptionsPath = function(_, path) openOptions(path); return true end,
  OpenOptions = function(_, path) openOptions(path) end,
  SelectOptionsPath = function(_, path) openOptions(path) end,
}

for _, owner in pairs(owners) do
  owner.state = { zoom = 1, pcmZooms = {} }
  function owner:GetPreviewState() return self.state end
end
owners.prd.state.allowReorder = false

function Preview.SetOpenOptions(callback)
  openOptions = callback
end

local function StopDraftTimer()
  if draftTimer then draftTimer:Cancel(); draftTimer = nil end
end

local function ResumePresentation()
  for frame, callback in pairs(pausedUpdates) do frame:SetScript("OnUpdate", callback) end
  for frame, paused in pairs(pausedCooldowns) do frame:SetPaused(paused) end
  for animation in pairs(pausedAnimations) do animation:Play() end
  wipe(pausedUpdates)
  wipe(pausedCooldowns)
  wipe(pausedAnimations)
end

local function PauseAnimations(region)
  for _, animation in ipairs({ region:GetAnimationGroups() }) do
    if animation:IsPlaying() then pausedAnimations[animation] = true; animation:Pause() end
  end
end

local function PausePresentation(frame)
  local callback = frame:GetScript("OnUpdate")
  if callback then pausedUpdates[frame] = callback; frame:SetScript("OnUpdate", nil) end
  if frame:GetObjectType() == "Cooldown" then
    pausedCooldowns[frame] = frame:IsPaused()
    frame:SetPaused(true)
  end
  PauseAnimations(frame)
  for _, region in ipairs({ frame:GetRegions() }) do PauseAnimations(region) end
  for _, child in ipairs({ frame:GetChildren() }) do PausePresentation(child) end
end

local function HideCurrent()
  StopDraftTimer()
  if not current then return end
  ResumePresentation()
  if current.box then current.box:Hide() end
  if current.draft then ns.PCMPreview.HideInstallerDraft(current.host) end
end

function Preview.Hide()
  HideCurrent()
  current = nil
end

local function BuildCurrent()
  if not current or not current.host:IsVisible() or InCombatLockdown() then return end
  local request = current
  ResumePresentation()
  if not ns.OptionsMotion.IsEnabled() then request.playing = false; StopDraftTimer() end
  if request.draft then
    ns.PCMPreview.RenderInstallerDraft(request.host, request.draft, request.state)
    if not request.playing then PausePresentation(request.host) end
    return
  end
  local owner = owners[request.kind]
  owner.previewHost = request.host
  if request.kind == "unitframes" then
    request.box = ns.UFPreview.BuildInstallerPreview(request.host, owner, request.path)
    if request.path[4] == "customDisplays" then
      if not request.playing then
        for index = 1, request.box.__puiAuraPreviewIconPoolIndex do
          local icon = request.box.__puiAuraPreviewIconPool[index]
          local duration = icon.__puiAuraPreviewDurationValue
          local remaining = request.sample == "EXPIRING" and 1 or duration * 0.75
          icon.__puiAuraPreviewExpiration = GetTime() + remaining
          icon.Cooldown:SetCooldown(GetTime() - duration + remaining, duration)
          icon.Duration:SetText(ns.UFAuraButtons.DurationFormatter:FormatNumber(remaining))
          icon:SetShown(request.sample ~= "INACTIVE")
        end
      end
    else
      for _, frame in ipairs(request.box.__puiAuraPreviewFramePool) do
        if frame:IsShown() then
          local provider = frame.__puiPresentationProvider
          provider.health, provider.power = request.sample, request.sample
          provider.healthText, provider.powerText = request.sample .. "%", request.sample .. "%"
          ns.UFPresentation.ApplyVisibility(frame, { config = frame.config, forceShown = true })
        end
      end
    end
  elseif request.kind == "actionbars" then
    ns.ActionBarsPreview.Build(navigation, owner, owner, request.path, 2)
    request.box = owner.__puiActionBarsPreviewBox
  elseif request.kind == "cooldowns" then
    ns.PCMPreview.Build(navigation, owner, owner, request.path)
    request.box = owner.__puiPCMPreviewBox
    if not request.playing then
      request.box.__puiPCMPreviewPhase = request.sample
      ns.PCMPreview.RefreshBox(request.box)
    end
  elseif request.kind == "prd" then
    owner.state.paused = not request.playing
    owner.state.sample = nil
    if not request.playing then owner.state.sample = request.sample end
    ns.PRDPreview.Build(navigation, owner, owner)
    request.box = owner.__puiPRDPreviewBox
    request.box.__puiPRDPreviewPauseButton:Hide()
    request.box.__puiPRDPreviewSampleButton:Hide()
    request.box:SetDescription("Sample values only. Choose a state below; your real resources are unchanged.")
  elseif request.kind == "quality" then
    ns.Registry.Options.Quality.meta.page.buildPreview(navigation, owner, owner, request.path)
    request.box = owner.__puiQualityPreviewRoot
  elseif request.kind == "meters" then
    request.box = ns.DamageMeterWindows.BuildPreview(request.host, owner)
  elseif request.kind == "everyday" then
    request.box = ns.InstallerExamples.Show(request.host, request.path[1])
  elseif request.kind == "movement" then
    ns.Registry.Options.MovementWarning.meta.page.buildPreview(navigation, owner, owner, request.path)
    request.box = owner.__puiMovementWarningPreviewRoot
  end
  if not request.playing then PausePresentation(request.box) end
end

function Preview.Show(host, kind, path)
  Preview.Hide()
  local states = Preview.GetSampleStates(kind, path)
  current = { host = host, kind = kind, path = path, playing = false, sample = states and states.initial }
  BuildCurrent()
end

function Preview.Refresh()
  BuildCurrent()
end

function Preview.SetSettingsPath(path)
  if not current or current.draft then return end
  if settingsRoots[current.kind] == path[1] then current.path = CopyTable(path) end
end

function Preview.ShowDraft(host, draft)
  Preview.Hide()
  current = { host = host, draft = draft, playing = false,
    state = draft.kind == "charge" and "RECHARGING"
      or (draft.kind == "stack" or draft.kind == "duration") and "ACTIVE" or "COOLDOWN" }
  BuildCurrent()
end

function Preview.SetDraftState(state)
  if not current or not current.draft then return end
  StopDraftTimer()
  current.playing = false
  current.state = state
  BuildCurrent()
end

function Preview.GetDraftState()
  return current and current.state
end

function Preview.SetSample(value)
  StopDraftTimer()
  current.playing, current.sample = false, value
  BuildCurrent()
end

AdvanceDraft = function()
  draftTimer = nil
  if not current or not current.draft or not current.playing
    or not current.host:IsVisible() or InCombatLockdown() then return end
  local kind = current.draft.kind
  local states = kind == "charge" and { "READY", "RECHARGING", "EMPTY" }
    or (kind == "stack" or kind == "duration") and { "ACTIVE", "INACTIVE" }
    or { "READY", "COOLDOWN", "ACTIVE" }
  local nextIndex = 1
  for index, state in ipairs(states) do
    if state == current.state then nextIndex = index % #states + 1 break end
  end
  current.state = states[nextIndex]
  BuildCurrent()
  if current.playing then draftTimer = C_Timer.NewTimer(3, AdvanceDraft) end
end

function Preview.SetPlaying(enabled)
  if not current then return end
  StopDraftTimer()
  local states = Preview.GetSampleStates(current.kind, current.path)
  current.playing = enabled == true and ns.OptionsMotion.IsEnabled() and (current.draft ~= nil or states and states.animated == true) or false
  if current.playing and current.draft then AdvanceDraft() else BuildCurrent() end
  return current.playing
end

events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then HideCurrent()
  elseif current and current.host:IsVisible() then BuildCurrent() end
end)

function Preview.Activate()
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Preview.Deactivate()
  events:UnregisterAllEvents()
  Preview.Hide()
end
