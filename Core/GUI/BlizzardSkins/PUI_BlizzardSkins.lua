local _, ns = ...
local Theme = ns.Theme
local Skins = {}
ns.BlizzardSkins = Skins

local windows = {}
local surfaces = setmetatable({}, { __mode = "k" })
local hooks = setmetatable({}, { __mode = "k" })
local driver = CreateFrame("Frame")
local loggedIn = false
local pending = false

function Skins.CanStyle()
  if InCombatLockdown() then
    pending = true
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
  end
  return true
end

function Skins.Hide(region)
  if region then
    region:SetAlpha(0)
  end
end

function Skins.Font(text, role)
  if text then
    Theme.ApplyFont(text, role or "body")
    local color = Theme.GetColors().text
    text:SetTextColor(color[1], color[2], color[3], color[4])
  end
end

function Skins.Chrome(frame)
  if not frame then return end
  Skins.Hide(frame.NineSlice)
  Skins.Hide(frame.Border)
  Skins.Hide(frame.BorderFrame)
  Skins.Hide(frame.Background)
  Skins.Hide(frame.Bg)
  Skins.Hide(frame.TopTileStreaks)
  Skins.Hide(frame.TitleBg)
end

function Skins.Surface(frame, control)
  if not frame then return end
  local host = surfaces[frame]
  if not host then
    host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(frame)
    host:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    host:EnableMouse(false)
    surfaces[frame] = host
  end
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(host, {
    bg = control and colors.control or colors.background,
    border = colors.border,
  }, Theme.GetEdgeSize())
  return host
end

function Skins.Panel(frame)
  if not frame then return end
  Skins.Chrome(frame)
  Skins.Surface(frame)
end

function Skins.StripRegions(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then Skins.Hide(region) end
  end
  Skins.Panel(frame)
end

function Skins.Texts(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("FontString") then Skins.Font(region) end
  end
end

function Skins.Selection(texture)
  if texture then
    local color = Theme.GetColors().accent
    texture:SetColorTexture(color[1], color[2], color[3], 0.2)
  end
end

function Skins.Shell(frame)
  Skins.Panel(frame)
  Skins.Chrome(frame.Inset)
  if frame.TitleContainer then
    Skins.Font(frame.TitleContainer.TitleText, "title")
  end
  if frame.CloseButton then
    Theme.WidgetSkins.CloseButton(frame.CloseButton)
  end
  local container = frame.PortraitContainer
  if container then
    local portrait = container.portrait
    if container.CircleMask then
      portrait:RemoveMaskTexture(container.CircleMask)
    end
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    portrait:SetSize(36, 36)
    portrait:SetAlpha(1)
    local holder = Skins.Surface(container, true)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", portrait, "TOPLEFT", -2, 2)
    holder:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 2, -2)
  end
end

function Skins.Button(button)
  Skins.Chrome(button)
  Skins.Surface(button, true)
  for _, key in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
    Skins.Hide(button[key])
  end
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  local highlight = button:GetHighlightTexture()
  if highlight then
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAllPoints(button)
  end
  Skins.Font(button:GetFontString(), "button")
end

function Skins.EditBox(edit)
  for _, key in ipairs({ "Left", "Middle", "Right", "left", "middle", "right",
    "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
    Skins.Hide(edit[key])
  end
  Skins.Chrome(edit)
  Skins.Surface(edit, true)
  Skins.Font(edit)
  Skins.Font(edit.Instructions)
end

function Skins.Icon(icon)
  if not icon then return end
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function Skins.IconButton(button, icon)
  if not button then return end
  Skins.Chrome(button)
  Skins.Surface(button, true)
  Skins.Icon(icon)
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  local highlight = button:GetHighlightTexture()
  if highlight then
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAllPoints(button)
  end
end

function Skins.CheckBox(button)
  if not button then return end
  Skins.Surface(button, true)
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  Skins.Hide(button:GetHighlightTexture())
  local color = Theme.GetColors().accent
  local checked = button:GetCheckedTexture()
  if checked then
    checked:SetVertexColor(color[1], color[2], color[3], 1)
  end
  Skins.Font(button.Text)
end

function Skins.Dropdown(dropdown)
  if not dropdown then return end
  Skins.Chrome(dropdown)
  Skins.Hide(dropdown.Left)
  Skins.Hide(dropdown.Middle)
  Skins.Hide(dropdown.Right)
  Skins.Surface(dropdown, true)
  Skins.Font(dropdown.Text)
end

function Skins.Tab(tab)
  if not tab then return end
  Skins.Surface(tab, true)
  for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "RightActive",
    "LeftHighlight", "RightHighlight" }) do
    Skins.Hide(tab[key])
  end
  local active = tab.MiddleActive
  if active then
    local color = Theme.GetColors().accent
    active:SetColorTexture(color[1], color[2], color[3], 0.25)
    active:ClearAllPoints()
    active:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
    active:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
  end
  local highlight = tab.MiddleHighlight
  if highlight then
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAllPoints(tab)
  end
  Skins.Font(tab:GetFontString())
  Skins.Hook(tab, "SetNormalFontObject", function(button)
    if Skins.CanStyle() then Skins.Font(button:GetFontString()) end
  end)
end

function Skins.ScrollBar(scrollbar)
  if not scrollbar then return end
  Skins.Chrome(scrollbar)
  local track = scrollbar.Track
  if track then
    Skins.Surface(track, true)
    for _, region in ipairs({ track:GetRegions() }) do
      if region:IsObjectType("Texture") then
        Skins.Hide(region)
      end
    end
  end
  local thumb = track and track.Thumb
  if thumb then
    local colors = Theme.GetColors()
    local host = Skins.Surface(thumb, true)
    Theme.SetSquareBackdrop(host, { bg = colors.accent, border = colors.border }, Theme.GetEdgeSize())
    -- Blizzard sizes the thumb from its atlases; keep those assigned under our surface.
    for _, region in ipairs({ thumb:GetRegions() }) do
      if region:IsObjectType("Texture") then
        Skins.Hide(region)
      end
    end
  end
end

function Skins.Apply(root, layout)
  for style, paths in pairs(layout) do
    for _, path in ipairs(paths) do
      local target = root
      for key in path:gmatch("[^.]+") do
        target = target[key]
        if not target then break end
      end
      if target then Skins[style](target) end
    end
  end
end

function Skins.Bar(bar)
  if not bar then return end
  Skins.Hide(bar.border)
  Skins.Hide(bar.Border)
  Theme.SkinStatusBar(bar)
end

function Skins.Paging(frame)
  if not frame then return end
  for _, entry in ipairs({ { frame.PrevPageButton, "<" }, { frame.NextPageButton, ">" } }) do
    local button = entry[1]
    if button then
      Skins.Button(button)
      local host = surfaces[button]
      if not host then host = Skins.Surface(button, true) end
      if not host.label then
        host.label = button:CreateFontString(nil, "OVERLAY")
        host.label:SetPoint("CENTER")
        host.label:SetText(entry[2])
      end
      Skins.Font(host.label)
    end
  end
  Skins.Font(frame.PageText)
end

function Skins.Hook(object, method, callback)
  local installed = hooks[object]
  if not installed then
    installed = {}
    hooks[object] = installed
  end
  if not installed[method] then
    installed[method] = true
    hooksecurefunc(object, method, callback)
  end
end

function Skins.ScrollRows(scrollBox, callback)
  if not scrollBox then return end
  Skins.Hook(scrollBox, "Update", function(box)
    if Skins.CanStyle() then box:ForEachFrame(callback) end
  end)
  scrollBox:ForEachFrame(callback)
end

function Skins.TabSystem(system)
  for _, tab in ipairs({ system:GetChildren() }) do
    if tab:IsObjectType("Button") then Skins.Tab(tab) end
  end
end

function Skins.Register(addonName, frameName, refresh)
  windows[#windows + 1] = { addon = addonName, name = frameName, refresh = refresh }
end

local function RefreshWindow(window)
  local frame = _G
  for key in window.name:gmatch("[^.]+") do
    frame = frame[key]
    if not frame then return end
  end
  if not window.installed then
    window.installed = true
    frame:HookScript("OnShow", function()
      if Skins.CanStyle() then window.refresh(frame) end
    end)
  end
  window.refresh(frame)
end

function Skins.RefreshTheme()
  if not loggedIn or not Skins.CanStyle() then return end
  for _, window in ipairs(windows) do
    RefreshWindow(window)
  end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_LOGIN" then
    loggedIn = true
    self:UnregisterEvent("PLAYER_LOGIN")
    Skins.RefreshTheme()
  elseif event == "ADDON_LOADED" and loggedIn then
    if not Skins.CanStyle() then return end
    for _, window in ipairs(windows) do
      if window.addon == addonName then RefreshWindow(window) end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending then
      pending = false
      Skins.RefreshTheme()
    end
  end
end)

hooksecurefunc(Theme, "RefreshAppliedFonts", Skins.RefreshTheme)
