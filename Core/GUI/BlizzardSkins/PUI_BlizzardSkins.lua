local _, ns = ...
local Theme = ns.Theme
local Skins = {}
ns.BlizzardSkins = Skins

local windows = {}
local navigationBars = setmetatable({}, { __mode = "k" })
local surfaces = setmetatable({}, { __mode = "k" })
local surfaceRoles = setmetatable({}, { __mode = "k" })
local styledTexts = setmetatable({}, { __mode = "k" })
local styledButtons = setmetatable({}, { __mode = "k" })
local selections = setmetatable({}, { __mode = "k" })
local checkedTextures = setmetatable({}, { __mode = "k" })
local scrollRows = setmetatable({}, { __mode = "k" })
local hooks = setmetatable({}, { __mode = "k" })
local driver = CreateFrame("Frame")
local loggedIn = false
local pending = false
local pendingTheme = false

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
    styledTexts[text] = true
    Theme.ApplyFont(text, role or "body")
    local color = Theme.GetColors().text
    text:SetTextColor(color[1], color[2], color[3], color[4])
  end
end

function Skins.Chrome(frame)
  if not frame then return end
  if frame.SetBackdrop then frame:SetBackdrop(nil) end
  Skins.Hide(frame.NineSlice)
  Skins.Hide(frame.BorderBox)
  Skins.Hide(frame.BG)
  Skins.Hide(frame.Underlay)
  Skins.Hide(frame.InsetBorderTop)
  for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopBorder", "BottomBorder", "LeftBorder", "RightBorder" }) do
    Skins.Hide(frame[key])
  end
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
  surfaceRoles[frame] = control and "control" or "background"
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

function Skins.StripRegions(frame, keep)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") and not (keep and keep[region]) then
      Skins.Hide(region)
    end
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
    selections[texture] = 0.2
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

local function RefreshButtonState(button)
  if not Skins.CanStyle() then return end
  local enabled = button:IsEnabled()
  if issecretvalue(enabled) then return end
  local colors = Theme.GetColors()
  local host = surfaces[button]
  if host then
    Theme.SetSquareBackdrop(host, {
      bg = enabled and colors.control or colors.disabledControl,
      border = enabled and colors.border or colors.disabledBorder,
    }, Theme.GetEdgeSize())
  end
  local text = button:GetFontString()
  if text then
    local color = enabled and colors.text or colors.disabledText
    text:SetTextColor(color[1], color[2], color[3], color[4])
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
  Skins.Hide(button:GetDisabledTexture())
  local highlight = button:GetHighlightTexture()
  if highlight then
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAlpha(1)
    highlight:SetAllPoints(button)
  end
  Skins.Font(button:GetFontString(), "button")
  if not styledButtons[button] then
    styledButtons[button] = true
    button:HookScript("OnEnable", RefreshButtonState)
    button:HookScript("OnDisable", RefreshButtonState)
  end
  RefreshButtonState(button)
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
  Skins.Button(button)
  Skins.Icon(icon)
end

function Skins.CheckBox(button)
  if not button then return end
  Skins.Surface(button, true)
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  Skins.Hide(button:GetDisabledTexture())
  Skins.Hide(button:GetHighlightTexture())
  local color = Theme.GetColors().accent
  local checked = button:GetCheckedTexture()
  if checked then
    checkedTextures[checked] = true
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
    selections[active] = 0.25
    local color = Theme.GetColors().accent
    active:SetColorTexture(color[1], color[2], color[3], 0.25)
    active:ClearAllPoints()
    active:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
    active:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
  end
  local highlight = tab.MiddleHighlight
  if highlight then
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAlpha(1)
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
  if scrollbar.Back then Skins.Arrow(scrollbar.Back, "^") end
  if scrollbar.Forward then Skins.Arrow(scrollbar.Forward, "v") end
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
    surfaceRoles[thumb] = "accent"
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

function Skins.Arrow(button, text)
  Skins.Button(button)
  Skins.Hide(button.Texture)
  local host = surfaces[button]
  if not host.label then
    host.label = button:CreateFontString(nil, "OVERLAY")
    host.label:SetPoint("CENTER")
  end
  host.label:SetText(text)
  Skins.Font(host.label)
end

function Skins.Paging(frame)
  if not frame then return end
  for _, entry in ipairs({ { frame.PrevPageButton, "<" }, { frame.NextPageButton, ">" } }) do
    local button = entry[1]
    if button then
      Skins.Arrow(button, entry[2])
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

function Skins.ScrollRows(scrollBox, skin, repaint)
  if not scrollBox then return end
  local state = scrollRows[scrollBox]
  if not state then
    local seen = setmetatable({}, { __mode = "k" })
    local function SkinRow(row, elementData)
      if not seen[row] then
        skin(row, elementData)
        seen[row] = true
      elseif repaint == nil then
        skin(row, elementData)
      elseif repaint then
        repaint(row, elementData)
      end
    end
    state = function(box)
      if Skins.CanStyle() then box:ForEachFrame(SkinRow) end
    end
    scrollRows[scrollBox] = state
    Skins.Hook(scrollBox, "Update", state)
  end
  state(scrollBox)
end

function Skins.TabSystem(system)
  for _, tab in ipairs({ system:GetChildren() }) do
    if tab:IsObjectType("Button") then Skins.Tab(tab) end
  end
end

function Skins.Navigation(bar)
  navigationBars[bar] = true
  Skins.StripRegions(bar)
  Skins.StripRegions(bar.overlay)
  for _, button in ipairs(bar.navList) do
    for _, region in ipairs({ button:GetRegions() }) do
      if region:IsObjectType("Texture") and region ~= button.selected
        and region ~= button:GetHighlightTexture() then
        Skins.Hide(region)
      end
    end
    Skins.Button(button)
    Skins.Selection(button.selected)
    if button.MenuArrowButton then
      local menu = button.MenuArrowButton
      Skins.Button(menu)
      -- The native hover script restores alpha on these two square borders.
      menu:GetNormalTexture():SetTexture(nil)
      menu:GetPushedTexture():SetTexture(nil)
    end
  end
  Skins.Arrow(bar.overflowButton, ">")
  Skins.Hook(_G, "NavBar_AddButton", function(nav)
    if navigationBars[nav] and Skins.CanStyle() then Skins.Navigation(nav) end
  end)
end

function Skins.Register(addonName, frameName, callbacks)
  local legacy = type(callbacks) == "function"
  if legacy then
    callbacks = { onShow = callbacks }
  end
  windows[#windows + 1] = {
    addon = addonName,
    name = frameName,
    install = callbacks.install,
    onShow = callbacks.onShow,
    onTheme = callbacks.onTheme,
    legacy = legacy,
  }
end

local function SkinWindow(window, frame)
  if not Skins.CanStyle() then return end
  if not window.initialized then
    if window.install then window.install(frame) end
    window.initialized = true
    ns.BlizzardWindowControls.Install(frame, nil, window.name)
  end
  if window.onShow then window.onShow(frame) end
end

local function ObserveWindow(window)
  local frame = _G
  for key in window.name:gmatch("[^.]+") do
    frame = frame[key]
    if not frame then return end
  end
  if frame:IsForbidden() then return end
  if window.frame ~= frame then
    window.frame = frame
    window.initialized = false
    frame:HookScript("OnShow", function(shown)
      if window.frame == shown then SkinWindow(window, shown) end
    end)
  end
  local shown = frame:IsVisible()
  if not issecretvalue(shown) and shown then SkinWindow(window, frame) end
end

function Skins.RefreshTheme(refreshWindows)
  if not loggedIn then return end
  if not Skins.CanStyle() then
    pendingTheme = refreshWindows ~= false or pendingTheme
    return
  end
  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()
  for frame, host in pairs(surfaces) do
    if not styledButtons[frame] then
      local role = surfaceRoles[frame]
      Theme.SetSquareBackdrop(host, {
        bg = role == "accent" and colors.accent or (role == "control" and colors.control or colors.background),
        border = colors.border,
      }, edge)
    end
  end
  for text in pairs(styledTexts) do
    local color = colors.text
    text:SetTextColor(color[1], color[2], color[3], color[4])
  end
  for texture, alpha in pairs(selections) do
    texture:SetColorTexture(colors.accent[1], colors.accent[2], colors.accent[3], alpha)
  end
  for texture in pairs(checkedTextures) do
    texture:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
  end
  for button in pairs(styledButtons) do RefreshButtonState(button) end
  ns.BlizzardWindowControls.RefreshTheme()
  if refreshWindows == false then return end
  for _, window in ipairs(windows) do
    local frame = window.frame
    if frame and window.initialized then
      if window.onTheme then
        window.onTheme(frame)
      elseif window.legacy then
        local shown = frame:IsVisible()
        if not issecretvalue(shown) and shown then window.onShow(frame) end
      end
    end
  end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_LOGIN" then
    loggedIn = true
    self:UnregisterEvent("PLAYER_LOGIN")
    for _, window in ipairs(windows) do ObserveWindow(window) end
  elseif event == "ADDON_LOADED" and loggedIn then
    if not Skins.CanStyle() then return end
    for _, window in ipairs(windows) do
      if window.addon == addonName then ObserveWindow(window) end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending then
      pending = false
      local refreshThemeCallbacks = pendingTheme
      pendingTheme = false
      for _, window in ipairs(windows) do ObserveWindow(window) end
      Skins.RefreshTheme(false)
      if refreshThemeCallbacks then
        for _, window in ipairs(windows) do
          if window.frame and window.initialized and window.onTheme then
            window.onTheme(window.frame)
          end
        end
      end
    end
  end
end)

hooksecurefunc(Theme, "RefreshAppliedFonts", Skins.RefreshTheme)
