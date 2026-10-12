local _, ns = ...
local Controls = {}
ns.BlizzardWindowControls = Controls

local windows = setmetatable({}, { __mode = "k" })
local controlFrames = setmetatable({}, { __mode = "k" })
local embedded = {
  ChallengesFrame = true,
  PVPQueueFrame = true,
  QuestMapFrame = true,
  ["PlayerSpellsFrame.TalentsFrame"] = true,
  ["CommunitiesFrame.GuildFinderFrame"] = true,
  ["CommunitiesFrame.CommunityFinderFrame"] = true,
}
local enabled = true
local active
local driver = CreateFrame("Frame")

local function StopInteraction()
  if active then
    active.control:SetScript("OnUpdate", nil)
    active = nil
  end
  driver:UnregisterEvent("PLAYER_REGEN_DISABLED")
end

local function SetTopLeft(frame, left, top)
  local scale = frame:GetEffectiveScale()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
end

local function ApplyWindow(frame)
  local state = windows[frame]
  if state.applying or not enabled then return end
  if InCombatLockdown() then
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  local maximized = frame == _G.WorldMapFrame and frame:IsMaximized()
  state.drag:SetShown(not maximized)
  state.grip:SetShown(not maximized)
  state.applying = true
  if maximized then
    frame:SetScale(state.baseScale)
  elseif state.left then
    frame:SetScale(state.scale)
    SetTopLeft(frame, state.left, state.top)
  end
  state.applying = false
end

local function UpdateInteraction()
  if InCombatLockdown() then
    StopInteraction()
    return
  end
  local interaction = active
  local frame = interaction.frame
  local state = windows[frame]
  local x, y = GetCursorPosition()
  local dx, dy = x - interaction.x, y - interaction.y
  if interaction.resize then
    local width, height = interaction.width, interaction.height
    local ratio = 1 + (dx * width - dy * height) / (width * width + height * height)
    state.scale = math.max(state.baseScale * 0.75, math.min(state.baseScale * 1.5, interaction.scale * ratio))
    state.left, state.top = interaction.left, interaction.top
  else
    state.scale = interaction.scale
    state.left, state.top = interaction.left + dx, interaction.top + dy
  end
  ApplyWindow(frame)
  -- Clamping may adjust the requested anchor at a screen edge.
  local left, bottom, _, height = frame:GetScaledRect()
  state.left, state.top = left, bottom + height
end

local function BeginInteraction(frame, control, resize)
  if not enabled or InCombatLockdown() then return end
  if frame == _G.WorldMapFrame and frame:IsMaximized() then return end
  StopInteraction()
  local left, bottom, width, height = frame:GetScaledRect()
  if not left or not bottom or not width or not height or width <= 0 or height <= 0 then return end
  local state = windows[frame]
  local visualWidth, visualHeight = state.visualRoot:GetSize()
  local effectiveScale = state.visualRoot:GetEffectiveScale()
  local x, y = GetCursorPosition()
  active = {
    frame = frame, control = control, resize = resize,
    left = left, top = bottom + height, scale = frame:GetScale(),
    width = visualWidth * effectiveScale, height = visualHeight * effectiveScale,
    x = x, y = y,
  }
  control:SetScript("OnUpdate", UpdateInteraction)
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function Controls.IsControl(frame)
  return controlFrames[frame] == true
end

function Controls.Install(frame, visualRoot, name)
  if embedded[name] then return end
  if InCombatLockdown() then return end
  local state = windows[frame]
  if not state then
    state = { baseScale = frame:GetScale(), visualRoot = visualRoot or frame }
    windows[frame] = state
    -- Cursor-driven anchors never mark a frame user-placed or write layout-cache positions.
    frame:SetDontSavePosition(true)
    frame:SetClampedToScreen(true)

    local drag = CreateFrame("Frame", nil, frame)
    state.drag = drag
    controlFrames[drag] = true
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -4)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -80, -4)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() BeginInteraction(frame, drag, false) end)
    drag:SetScript("OnDragStop", StopInteraction)
    drag:SetScript("OnMouseUp", StopInteraction)

    local grip = CreateFrame("Frame", nil, frame)
    state.grip = grip
    state.lines = {}
    controlFrames[grip] = true
    grip:SetSize(18, 18)
    grip:EnableMouse(true)
    for i = 0, 2 do
      local length, offset = 12 - i * 4, 2 + i * 4
      local horizontal = grip:CreateTexture(nil, "OVERLAY")
      horizontal:SetSize(length, 2)
      horizontal:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -2, offset)
      state.lines[#state.lines + 1] = horizontal
      local vertical = grip:CreateTexture(nil, "OVERLAY")
      vertical:SetSize(2, length)
      vertical:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -offset, 2)
      state.lines[#state.lines + 1] = vertical
    end
    grip:SetScript("OnMouseDown", function(_, button)
      if button == "LeftButton" then BeginInteraction(frame, grip, true) end
    end)
    grip:SetScript("OnMouseUp", StopInteraction)
    frame:HookScript("OnHide", function()
      if active and active.frame == frame then StopInteraction() end
    end)
    frame:HookScript("OnShow", function() ApplyWindow(frame) end)
    -- Blizzard reanchors dialogs after OnShow, including windows outside the UIPanel manager.
    hooksecurefunc(frame, "SetPoint", function() ApplyWindow(frame) end)
    hooksecurefunc(frame, "SetScale", function() ApplyWindow(frame) end)
    if frame == _G.WorldMapFrame then
      hooksecurefunc(frame, "Maximize", function()
        if active and active.frame == frame then StopInteraction() end
        ApplyWindow(frame)
      end)
      hooksecurefunc(frame, "Minimize", function() ApplyWindow(frame) end)
    end
  end
  if visualRoot then state.visualRoot = visualRoot end
  local controlRoot = frame == _G.WorldMapFrame and frame.BorderFrame or frame
  state.drag:SetFrameStrata(controlRoot:GetFrameStrata())
  state.grip:SetFrameStrata(controlRoot:GetFrameStrata())
  state.drag:SetFrameLevel(controlRoot:GetFrameLevel() + 100)
  state.grip:SetFrameLevel(controlRoot:GetFrameLevel() + 100)
  state.grip:ClearAllPoints()
  local rightInset = frame == _G.WorldMapFrame and 28 or 4
  state.grip:SetPoint("BOTTOMRIGHT", state.visualRoot, "BOTTOMRIGHT", -rightInset, 4)
  local accent = ns.Theme.GetColors().accent
  for _, line in ipairs(state.lines) do
    line:SetColorTexture(accent[1], accent[2], accent[3], 0.75)
  end
  state.drag:SetShown(enabled)
  state.grip:SetShown(enabled)
  ApplyWindow(frame)
end

driver:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_DISABLED" then
    StopInteraction()
  else
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for frame in pairs(windows) do
      if frame:IsShown() then ApplyWindow(frame) end
    end
  end
end)

function Controls.RefreshTheme()
  local accent = ns.Theme.GetColors().accent
  for _, state in pairs(windows) do
    for _, line in ipairs(state.lines) do
      line:SetColorTexture(accent[1], accent[2], accent[3], 0.75)
    end
  end
end

function Controls:GetOptions()
  return {
    type = "group", name = "Blizzard windows",
    args = {
      moveAndResize = {
        type = "toggle", name = "Move and resize windows", order = 1, width = "full",
        desc = "Drag the title area to move a window. Drag its bottom-right corner to change its size. Position and size reset on login or reload.",
        disabled = function() return InCombatLockdown() end,
        get = function() return enabled end,
        set = function(_, value)
          if InCombatLockdown() then return end
          enabled = value
          StopInteraction()
          if not value then driver:UnregisterEvent("PLAYER_REGEN_ENABLED") end
          for frame, state in pairs(windows) do
            state.drag:SetShown(value)
            state.grip:SetShown(value)
            ApplyWindow(frame)
          end
        end,
      },
    },
  }
end

ns.Addon:RegisterOptionsSection("BlizzardWindows", function() return Controls end, 17, "Blizzard windows", nil, {
  preview = false, navSection = "General",
  navDescription = "Move and resize skinned game windows for this session.",
})
