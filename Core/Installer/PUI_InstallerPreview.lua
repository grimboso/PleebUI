local _, ns = ...
local Preview = {}
ns.InstallerPreview = Preview
local owners = { unitframes = {}, actionbars = {}, cooldowns = {}, prd = {}, quality = {}, meters = {}, everyday = {} }
local settingsRoots = { unitframes = "unitframes", actionbars = "ACTIONBARS", cooldowns = "CooldownManager", prd = "PRD", quality = "Quality" }
local current
local openOptions
local draftTimer
local events = CreateFrame("Frame")
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

local function HideCurrent()
  StopDraftTimer()
  if not current then return end
  if current.box then current.box:Hide() end
  if current.draft then ns.PCMPreview.HideInstallerDraft(current.host) end
end

function Preview.Hide()
  HideCurrent()
  current = nil
end

local function ShieldUnitFrame(box)
  local shield = box.__puiInstallerShield
  if not shield then
    shield = CreateFrame("Frame", nil, box)
    shield:SetAllPoints(box)
    shield:EnableMouse(true)
    box.__puiInstallerShield = shield
  end
  shield:SetFrameLevel(box:GetFrameLevel() + 400)
  shield:Show()
  box:SetDescription("Sample frame. Use the settings below to change its layout, text, and auras.")
end

local function BuildCurrent()
  if not current or not current.host:IsVisible() or InCombatLockdown() then return end
  local request = current
  if request.draft then
    ns.PCMPreview.RenderInstallerDraft(request.host, request.draft, request.state)
    return
  end
  local owner = owners[request.kind]
  owner.previewHost = request.host
  if request.kind == "unitframes" then
    ns.UFPreview.BuildUnitFramePreview(navigation, owner, owner, request.path)
    request.box = owner.__puiAuraManagerPreviewBox
    ShieldUnitFrame(request.box)
  elseif request.kind == "actionbars" then
    ns.ActionBarsPreview.Build(navigation, owner, owner, request.path)
    request.box = owner.__puiActionBarsPreviewBox
  elseif request.kind == "cooldowns" then
    ns.PCMPreview.Build(navigation, owner, owner, request.path)
    request.box = owner.__puiPCMPreviewBox
  elseif request.kind == "prd" then
    ns.PRDPreview.Build(navigation, owner, owner)
    request.box = owner.__puiPRDPreviewBox
  elseif request.kind == "quality" then
    ns.Registry.Options.Quality.meta.page.buildPreview(navigation, owner, owner, request.path)
    request.box = owner.__puiQualityPreviewRoot
  elseif request.kind == "meters" then
    request.box = ns.DamageMeterWindows.BuildPreview(request.host, owner)
  elseif request.kind == "everyday" then
    request.box = ns.InstallerExamples.Show(request.host, request.path[1])
  end
end

function Preview.Show(host, kind, path)
  Preview.Hide()
  current = { host = host, kind = kind, path = path }
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

local function AdvanceDraft()
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
  draftTimer = C_Timer.NewTimer(3, AdvanceDraft)
end

function Preview.ToggleDraftAnimation()
  if not current or not current.draft then return end
  StopDraftTimer()
  current.playing = not current.playing
  if current.playing then AdvanceDraft() end
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
