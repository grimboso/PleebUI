local _, ns = ...
local Preview = {}
ns.InstallerPreview = Preview
Preview.AnimatedKinds = { unitframes = true, prd = true, actionbars = true, cooldowns = true }
local owners = { unitframes = {}, actionbars = {}, cooldowns = {}, prd = {}, quality = {}, meters = {}, everyday = {}, movement = {} }
local settingsRoots = { unitframes = "unitframes", actionbars = "ACTIONBARS", cooldowns = "CooldownManager", prd = "PRD", quality = "Quality" }
local current
local openOptions
local draftTimer
local events = CreateFrame("Frame")
local pausedUpdates, pausedCooldowns, pausedAnimations = {}, {}, {}
local AdvanceDraft
local unitFrameSampleState = { forceShown = true }
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
  if current.box then
    if current.kind == "unitframes" then current.box:SetScript("OnUpdate", nil) end
    current.box:Hide()
  end
  if current.draft then ns.PCMPreview.HideInstallerDraft(current.host) end
end

function Preview.Hide()
  HideCurrent()
  current = nil
end

local function AnimateUnitFrames(box, elapsed)
  box.animationTime = box.animationTime + elapsed
  box.animationElapsed = box.animationElapsed + elapsed
  if box.animationElapsed < 0.1 then return end
  box.animationElapsed = 0
  for index, frame in ipairs(box.__puiAuraPreviewFramePool) do
    if frame:IsShown() then
      local provider = frame.__puiPresentationProvider
      local phase = box.animationTime + index * 0.7
      provider.health = math.floor(65 + 30 * math.sin(phase))
      provider.power = math.floor(50 + 45 * math.sin(phase * 0.7))
      provider.healthText, provider.powerText = provider.health .. "%", provider.power .. "%"
      ns.UFPresentation.ApplyVisibility(frame, unitFrameSampleState)
    end
  end
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
    request.box.animationTime, request.box.animationElapsed = 0, 0
    request.box:SetScript("OnUpdate", request.playing and request.path[4] ~= "customDisplays" and AnimateUnitFrames or nil)
  elseif request.kind == "actionbars" then
    if ns.ActionBarsPreview then
      ns.ActionBarsPreview.Build(navigation, owner, owner, request.path, 2)
      request.box = owner.__puiActionBarsPreviewBox
    else
      local box = owner.disabledBox
      if not box then
        box = ns.PreviewBox.Create(request.host)
        owner.disabledBox = box
      end
      box:SetParent(request.host)
      box:ClearAllPoints()
      box:SetAllPoints(request.host)
      box:SetTitle("Addon disabled")
      box:SetDescription("")
      box:SetAlpha(0.5)
      box:Show()
      request.box = box
    end
  elseif request.kind == "cooldowns" then
    ns.PCMPreview.Build(navigation, owner, owner, request.path)
    request.box = owner.__puiPCMPreviewBox
  elseif request.kind == "prd" then
    owner.state.paused = not request.playing
    owner.state.sample = nil
    if not request.playing then owner.state.sample = 0.5 end
    ns.PRDPreview.Build(navigation, owner, owner)
    request.box = owner.__puiPRDPreviewBox
    request.box.__puiPRDPreviewPauseButton:Hide()
    request.box.__puiPRDPreviewSampleButton:Hide()
    request.box:SetDescription("Sample values only. Use Animate this example below; your real resources are unchanged.")
  elseif request.kind == "quality" then
    ns.Registry.Options.Quality.meta.page.buildPreview(navigation, owner, owner, request.path)
    request.box = owner.__puiQualityPreviewRoot
  elseif request.kind == "meters" then
    if ns.DamageMeterWindows then
      request.box = ns.DamageMeterWindows.BuildPreview(request.host, owner)
    else
      local box = owner.disabledBox
      if not box then
        box = ns.PreviewBox.Create(request.host)
        owner.disabledBox = box
      end
      box:SetParent(request.host)
      box:ClearAllPoints()
      box:SetAllPoints(request.host)
      box:SetTitle("Addon disabled")
      box:SetDescription("")
      box:SetAlpha(0.5)
      box:Show()
      request.box = box
    end
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
  current = { host = host, kind = kind, path = path, playing = false }
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
  current.playing = enabled == true and ns.OptionsMotion.IsEnabled() and (current.draft ~= nil or Preview.AnimatedKinds[current.kind] == true)
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
