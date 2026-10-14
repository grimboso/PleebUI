local _, ns = ...
local Theme = ns.Theme
local Skins = {}
ns.BlizzardSkins = Skins

local windows = {}
local navigationBars = setmetatable({}, { __mode = "k" })
local surfaces = setmetatable({}, { __mode = "k" })
local surfaceRoles = setmetatable({}, { __mode = "k" })
local styledTexts = setmetatable({}, { __mode = "k" })
local htmlFonts = setmetatable({}, { __mode = "k" })
local htmlFontCount = 0
local htmlTextTypes = { "p", "h1", "h2", "h3" }
local styledButtons = setmetatable({}, { __mode = "k" })
local selections = setmetatable({}, { __mode = "k" })
local checkedTextures = setmetatable({}, { __mode = "k" })
local styledTabs = setmetatable({}, { __mode = "k" })
local windowHeaders = setmetatable({}, { __mode = "k" })
local scrollRows = setmetatable({}, { __mode = "k" })
local scrollBars = setmetatable({}, { __mode = "k" })
local hooks = setmetatable({}, { __mode = "k" })
local driver = CreateFrame("Frame")
local loggedIn = false
local transparentBorder = { 0, 0, 0, 0 }

function Skins.Hide(region)
  if region then
    region:SetAlpha(0)
  end
end

local function RefreshTextColor(text)
  local color = Theme.GetColors().text
  if htmlFonts[text] then
    for _, textType in ipairs(htmlTextTypes) do
      text:SetTextColor(textType, color[1], color[2], color[3], color[4])
    end
  else
    text:SetTextColor(color[1], color[2], color[3], color[4])
  end
end

function Skins.Font(text, role)
  if text then
    styledTexts[text] = true
    if text:IsObjectType("SimpleHTML") then
      local font = htmlFonts[text]
      if not font then
        htmlFontCount = htmlFontCount + 1
        font = CreateFont("PleebUIBlizzardHTMLFont" .. htmlFontCount)
        htmlFonts[text] = font
      end
      -- Theme owns font settings; SimpleHTML binds them through typed font slots.
      Theme.ApplyFont(font, role or "body")
      for _, textType in ipairs(htmlTextTypes) do text:SetFontObject(textType, font) end
    else
      Theme.ApplyFont(text, role or "body")
    end
    RefreshTextColor(text)
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

function Skins.Surface(frame, control, borderless)
  if not frame then return end
  local host = surfaces[frame]
  if not host then
    host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(frame)
    host:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    host:EnableMouse(false)
    surfaces[frame] = host
  end
  surfaceRoles[frame] = borderless and (control and "flatControl" or "flatBackground") or (control and "control" or "background")
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(host, {
    bg = control and colors.control or colors.background,
    border = borderless and transparentBorder or (control and colors.controlBorder or colors.border),
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

function Skins.Selection(texture, alpha)
  if texture then
    alpha = alpha or 0.2
    selections[texture] = alpha
    local color = Theme.GetColors().accent
    texture:SetColorTexture(color[1], color[2], color[3], alpha)
  end
end

function Skins.WindowTitle(frame, title, surface)
  title = title or (frame.TitleContainer and frame.TitleContainer.TitleText)
  if not title then return end

  local header = windowHeaders[frame]
  if not header then
    header = surface:CreateTexture(nil, "ARTWORK", nil, 1)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(32)
    windowHeaders[frame] = header
  end

  local color = Theme.GetColors().control
  header:SetColorTexture(color[1], color[2], color[3], color[4])

  Skins.Font(title, "title")
  title:ClearAllPoints()
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 56, -1)
  title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -56, -1)
  title:SetHeight(32)
  title:SetJustifyH("CENTER")
  title:SetJustifyV("MIDDLE")
end

function Skins.Shell(frame, backgroundFrame)
  Skins.Chrome(frame)
  local surface = Skins.Surface(backgroundFrame or frame)
  Skins.Chrome(frame.Inset)
  Skins.WindowTitle(frame, nil, surface)
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
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    portrait:SetSize(38, 38)
    portrait:SetAlpha(1)
    Skins.Icon(portrait)
    local holder = Skins.Surface(container, true)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", portrait, "TOPLEFT", -1, 1)
    holder:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 1, -1)
  end
end

local function RefreshButtonState(button)
  local enabled = button:IsEnabled()
  if issecretvalue(enabled) then return end
  local colors = Theme.GetColors()
  local state = styledButtons[button]
  local host = surfaces[button]
  if host then
    Theme.SetSquareBackdrop(host, {
      bg = enabled and colors.control or colors.disabledControl,
      border = state.borderless and transparentBorder or (enabled and colors.controlBorder or colors.disabledControlBorder),
    }, state.edge or Theme.GetEdgeSize())
  end
  local text = state.label or button:GetFontString()
  if text then
    if state.navigation then Theme.ApplyFont(text, "button") end
    local color = (enabled or state.navigation) and colors.text or colors.disabledText
    text:SetTextColor(color[1], color[2], color[3], color[4])
  end
  if state.arrow then
    local color = enabled and colors.text or colors.disabledText
    state.arrow:SetTextColor(color[1], color[2], color[3], color[4])
  end
  if state.dropdown then
    if state.label then Theme.ApplyFont(state.label, "body") end
    Skins.Hide(button.Arrow)
    Skins.Hide(button.Background)
  end
end

local function InstallButtonState(button)
  if not styledButtons[button] then
    styledButtons[button] = {}
    button:HookScript("OnEnable", RefreshButtonState)
    button:HookScript("OnDisable", RefreshButtonState)
    button:HookScript("OnShow", RefreshButtonState)
  end
  return styledButtons[button]
end

function Skins.Button(button, borderless)
  Skins.Chrome(button)
  Skins.Surface(button, true, borderless)
  for _, key in ipairs({ "Left", "Middle", "Center", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
    Skins.Hide(button[key])
  end
  Skins.Hide(button:GetNormalTexture())
  local pushed = button:GetPushedTexture()
  if not pushed then
    pushed = button:CreateTexture(nil, "ARTWORK")
    button:SetPushedTexture(pushed)
  end
  pushed:SetColorTexture(1, 1, 1, 0.18)
  pushed:SetAlpha(1)
  pushed:SetAllPoints(button)
  Skins.Hide(button:GetDisabledTexture())
  local highlight = button:GetHighlightTexture()
  if not highlight then
    highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button:SetHighlightTexture(highlight)
  end
  highlight:SetColorTexture(1, 1, 1, 0.12)
  highlight:SetAlpha(1)
  highlight:SetAllPoints(button)
  Skins.Font(button:GetFontString(), "button")
  InstallButtonState(button).borderless = borderless
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

function Skins.IconButton(button, icon, borderless)
  if not button then return end
  Skins.Button(button, borderless)
  Skins.Icon(icon)
end

function Skins.CheckBox(button)
  if not button then return end
  if button.CheckMark then
    -- QuestLogTrackCheckboxTemplate is a Frame; Blizzard owns checkmark visibility.
    local checked = button.CheckMark
    Skins.StripRegions(button, { [checked] = true })
    checkedTextures[checked] = "accent"
    checked:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checked:SetTexCoord(0, 1, 0, 1)
    checked:SetAllPoints(button)
    local color = Theme.GetColors().accent
    checked:SetVertexColor(color[1], color[2], color[3], color[4])
    return
  end
  Skins.Chrome(button)
  Skins.Surface(button, true)
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  Skins.Hide(button:GetDisabledTexture())
  Skins.Hide(button:GetHighlightTexture())
  local colors = Theme.GetColors()
  -- Native checked slots render restricted checked state without reading it in Lua.
  for _, disabled in ipairs({ false, true }) do
    local texture
    if disabled then texture = button:GetDisabledCheckedTexture() else texture = button:GetCheckedTexture() end
    if not texture then
      texture = button:CreateTexture(nil, "ARTWORK")
      if disabled then button:SetDisabledCheckedTexture(texture) else button:SetCheckedTexture(texture) end
    end
    checkedTextures[texture] = disabled and "disabledText" or "accent"
    texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetAllPoints(button)
    texture:SetAlpha(1)
    local color = colors[checkedTextures[texture]]
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
  end
  Skins.Font(button.Text)
  InstallButtonState(button).label = button.Text
  RefreshButtonState(button)
end

function Skins.Dropdown(dropdown)
  if not dropdown then return end
  Skins.Chrome(dropdown)
  for _, key in ipairs({ "Left", "Middle", "Right" }) do Skins.Hide(dropdown[key]) end
  Skins.Surface(dropdown, true)
  Skins.Font(dropdown.Text)
  if dropdown:IsObjectType("Button") then
    Skins.Button(dropdown)
    local state = InstallButtonState(dropdown)
    state.dropdown = true
    if dropdown.Arrow or dropdown.Text then
      if not state.arrow then
        state.arrow = dropdown:CreateFontString(nil, "OVERLAY")
        if dropdown.Arrow then
          state.arrow:SetPoint("CENTER", dropdown.Arrow, "CENTER")
        else
          state.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
        end
      end
      Skins.Font(state.arrow, "button")
      state.arrow:SetText("v")
    end
    state.label = dropdown.Text
    if dropdown.OnButtonStateChanged then
      Skins.Hook(dropdown, "OnButtonStateChanged", RefreshButtonState)
    end
    RefreshButtonState(dropdown)
    if dropdown.ResetButton then Skins.Button(dropdown.ResetButton) end
  elseif dropdown.Button then
    -- UIDropDownMenuTemplate owns a separate arrow button.
    Skins.Arrow(dropdown.Button, "v")
  end
end

local function RefreshTabState(tab)
  local state = styledTabs[tab]
  local selected = false
  if tab.MiddleActive then selected = tab.MiddleActive:IsShown() end
  local enabled = tab:IsEnabled()
  if issecretvalue(selected) or issecretvalue(enabled) then return end
  local available = enabled or selected
  if tab.IsForceDisabled then
    local disabled = tab:IsForceDisabled()
    if issecretvalue(disabled) then return end
    available = not disabled
  end
  local colors = Theme.GetColors()
  state.selection:SetShown(selected)
  local color = available and colors.text or colors.disabledText
  local text = tab:GetFontString()
  if text then
    Theme.ApplyFont(text, "body")
    text:SetTextColor(color[1], color[2], color[3], color[4])
    text:ClearAllPoints()
    text:SetPoint("CENTER", tab, "CENTER")
    text:SetWidth(0)
    local textWidth = text:GetStringWidth()
    local _, fontSize = text:GetFont()
    local oldWidth = tab:GetWidth()
    if not issecretvalue(textWidth) and not issecretvalue(fontSize) and not issecretvalue(oldWidth) then
      local width = textWidth + 32
      tab:SetWidth(width)
      tab:SetHeight(math.max(state.height, fontSize + 12))
      if tab.GetTabSystem and oldWidth ~= width then tab:GetTabSystem():MarkDirty() end
    end
  end
  Theme.SetSquareBackdrop(surfaces[tab], {
    bg = available and colors.control or colors.disabledControl,
    border = available and colors.controlBorder or colors.disabledControlBorder,
  }, Theme.GetEdgeSize())
end

function Skins.Tab(tab)
  if not tab then return end
  Skins.Surface(tab, true)
  for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftDisabled", "MiddleDisabled", "RightDisabled", "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
    Skins.Hide(tab[key])
  end
  Skins.Hide(tab:GetNormalTexture())
  Skins.Hide(tab:GetDisabledTexture())
  Skins.Hide(tab:GetHighlightTexture())
  local state = styledTabs[tab]
  if not state then
    state = { selection = tab:CreateTexture(nil, "BACKGROUND"), highlight = tab:CreateTexture(nil, "HIGHLIGHT"), height = tab:GetHeight() }
    styledTabs[tab] = state
    state.selection:SetAllPoints(tab)
    state.highlight:SetAllPoints(tab)
    state.highlight:SetColorTexture(1, 1, 1, 0.12)
    selections[state.selection] = 0.25
    tab:HookScript("OnEnable", RefreshTabState)
    tab:HookScript("OnDisable", RefreshTabState)
    tab:HookScript("OnShow", RefreshTabState)
    -- Both PanelTemplates and TabSystem templates own active artwork visibility.
    -- Keep its geometry intact, including top-tab rotations, and mirror only visibility.
    if tab.MiddleActive then
      for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        Skins.Hook(tab.MiddleActive, method, function() RefreshTabState(tab) end)
      end
    end
    Skins.Hook(tab, "SetNormalFontObject", RefreshTabState)
    Skins.Hook(tab, "SetDisabledFontObject", RefreshTabState)
    if tab.SetTabEnabled then Skins.Hook(tab, "SetTabEnabled", RefreshTabState) end
    if tab.SetTabSelected then Skins.Hook(tab, "SetTabSelected", RefreshTabState) end
    if tab.UpdateTabWidth then Skins.Hook(tab, "UpdateTabWidth", RefreshTabState) end
  end
  local accent = Theme.GetColors().accent
  state.selection:SetColorTexture(accent[1], accent[2], accent[3], 0.25)
  Skins.Font(tab:GetFontString())
  RefreshTabState(tab)
end

function Skins.WindowTabs(frame, tabs)
  local previous

  for _, tab in ipairs(tabs) do
    Skins.Tab(tab)

    tab:ClearAllPoints()
    if previous then
      tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
    else
      tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
    end

    previous = tab
  end
end

function Skins.WidenScrollBar(scrollbar)
  local width = Theme.GetOptionsPointerTargetSize(20)
  scrollbar:SetWidth(width)
  local track = scrollbar.Track
  if track then
    local height = Theme.GetOptionsPointerTargetSize(24)
    scrollbar.Back:SetSize(width - 2, height)
    scrollbar.Forward:SetSize(width - 2, height)
    scrollbar.Back:ClearAllPoints()
    scrollbar.Back:SetPoint("TOPLEFT", scrollbar, "TOPLEFT", 1, -1)
    scrollbar.Forward:ClearAllPoints()
    scrollbar.Forward:SetPoint("BOTTOMLEFT", scrollbar, "BOTTOMLEFT", 1, 1)
    track:ClearAllPoints()
    track:SetPoint("TOPLEFT", scrollbar.Back, "BOTTOMLEFT")
    track:SetPoint("BOTTOMRIGHT", scrollbar.Forward, "TOPRIGHT")
    track:SetWidth(width - 2)
    track.Thumb:SetWidth(width - 4)
    track.Thumb:SetHitRectInsets(0, 0, 0, 0)
    scrollbar.thumbAnchor = "TOP"
  end
end

local function RefreshScrollBar(scrollbar)
  Skins.WidenScrollBar(scrollbar)
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(surfaces[scrollbar], {
    bg = colors.control, border = colors.controlBorder,
  }, Theme.ControlBorderSize)
  Theme.SetSquareBackdrop(surfaces[scrollbar.Track.Thumb], {
    bg = colors.accent, border = transparentBorder,
  }, 0)
  for _, divider in ipairs(scrollBars[scrollbar]) do
    divider:SetHeight(Theme.ControlBorderSize)
    divider:SetColorTexture(unpack(colors.controlBorder))
  end
  Theme.ApplyScrollArrow(scrollbar.Back, "up")
  Theme.ApplyScrollArrow(scrollbar.Forward, "down")
end

function Skins.ScrollBar(scrollbar)
  if not scrollbar then return end
  if scrollbar.ScrollUpButton then
    Theme.WidgetSkins.Scrollbar(scrollbar)
    return
  end
  if scrollBars[scrollbar] then
    RefreshScrollBar(scrollbar)
    return
  end
  local dividers = {}
  scrollBars[scrollbar] = dividers
  Skins.Chrome(scrollbar)
  Skins.Surface(scrollbar, true)
  for _, button in ipairs({ scrollbar.Back, scrollbar.Forward }) do
    Skins.Button(button, true)
    Skins.Hide(button.Texture)
    InstallButtonState(button).edge = Theme.ControlBorderSize
    button:SetHitRectInsets(0, 0, 0, 0)
    local divider = button:CreateTexture(nil, "OVERLAY")
    local edge = button == scrollbar.Back and "BOTTOM" or "TOP"
    divider:SetPoint(edge .. "LEFT", button, edge .. "LEFT")
    divider:SetPoint(edge .. "RIGHT", button, edge .. "RIGHT")
    dividers[#dividers + 1] = divider
  end
  local track = scrollbar.Track
  if track then
    for _, region in ipairs({ track:GetRegions() }) do
      if region:IsObjectType("Texture") then
        Skins.Hide(region)
      end
    end
  end
  local thumb = track and track.Thumb
  if thumb then
    Skins.Surface(thumb, true)
    -- Blizzard sizes the thumb from its atlases; keep those assigned under our surface.
    for _, region in ipairs({ thumb:GetRegions() }) do
      if region:IsObjectType("Texture") then
        Skins.Hide(region)
      end
    end
  end
  RefreshScrollBar(scrollbar)
  scrollbar:SetHideIfUnscrollable(true)
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
  Skins.Font(host.label)
  host.label:SetText(text)
  InstallButtonState(button).label = host.label
  RefreshButtonState(button)
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
      if box:HasView() then box:ForEachFrame(SkinRow) end
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
  if not navigationBars[bar] then
    navigationBars[bar] = true
    for _, region in ipairs({ bar:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Chrome(bar)
    Skins.Surface(bar, false, true)
    -- The level-50 overlay is decorative and must not cover the navigation buttons.
    Skins.Hide(bar.overlay)
    Skins.Arrow(bar.overflowButton, ">")
    bar.overflowButton:SetWidth(30)
  end
  for _, button in ipairs(bar.navList) do
    if not styledButtons[button] or not styledButtons[button].navigation then
      for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= button.selected
          and region ~= button:GetHighlightTexture() then
          Skins.Hide(region)
        end
      end
      Skins.Button(button)
      InstallButtonState(button).navigation = true
      RefreshButtonState(button)
      button:GetFontString():SetDrawLayer("OVERLAY", 7)
      if button.selected then button.selected:SetDrawLayer("BACKGROUND", 1) end
      Skins.Selection(button.selected, 0.06)
      if button.MenuArrowButton then
        local menu = button.MenuArrowButton
        Skins.Button(menu)
        menu:SetWidth(24)
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -1)
        menu:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 1)
        -- Native hover restores alpha on these borders, so retain empty texture slots.
        menu:GetNormalTexture():SetTexture(nil)
        menu:GetPushedTexture():SetTexture(nil)
      end
    end
  end
  Skins.Hook(_G, "NavBar_AddButton", function(nav)
    if navigationBars[nav] then Skins.Navigation(nav) end
  end)
end

function Skins.Register(addonName, frameName, callbacks)
  local legacy = type(callbacks) == "function"
  if legacy then
    callbacks = { onShow = callbacks }
  end
  ns.BlizzardSkinOptions.Register(frameName, callbacks.label, callbacks.category)
  windows[#windows + 1] = {
    addon = addonName,
    name = frameName,
    install = callbacks.install,
    onShow = callbacks.onShow,
    onTheme = callbacks.onTheme,
    controlsRoot = callbacks.controlsRoot,
    controlsFrame = callbacks.controlsFrame,
    controlsParent = callbacks.controlsParent,
    manageControls = callbacks.manageControls ~= false,
    installOnLoad = callbacks.installOnLoad == true,
    legacy = legacy,
  }
end

local function SkinWindow(window, frame)
  if not window.initialized then
    if window.install then window.install(frame) end
    window.initialized = true
    if window.manageControls then
      local controlsFrame = window.controlsFrame and window.controlsFrame(frame) or frame
      local controlsRoot = window.controlsRoot and window.controlsRoot(frame) or nil
      local controlsParent = window.controlsParent and window.controlsParent(frame) or nil
      ns.BlizzardWindowControls.Install(controlsFrame, controlsRoot, window.name, controlsParent)
    end
  end
  if window.onShow then window.onShow(frame) end
end

local function ObserveWindow(window)
  if not ns.BlizzardSkinOptions.IsEnabled(window.name) then return end
  local frame = _G
  for key in window.name:gmatch("[^.]+") do
    frame = frame[key]
    if not frame then return end
  end
  if frame:IsForbidden() then return end
  if window.installOnLoad then
    window.frame = frame
    if not window.initialized then SkinWindow(window, frame) end
    return
  end
  if window.frame ~= frame then
    window.frame = frame
    window.initialized = false
    frame:HookScript("OnShow", function(shown)
      if window.frame == shown then SkinWindow(window, shown) end
    end)
  end
  local shown = frame:IsShown()
  if not issecretvalue(shown) and shown then SkinWindow(window, frame) end
end

function Skins.ObserveAddon(addonName)
  if not loggedIn then return end
  for _, window in ipairs(windows) do
    if window.addon == addonName then ObserveWindow(window) end
  end
end

function Skins.RefreshTheme(refreshWindows)
  if not loggedIn then return end
  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()
  for frame, host in pairs(surfaces) do
    if not styledButtons[frame] then
      local role = surfaceRoles[frame]
      local isControl = role == "control" or role == "flatControl"
      local isBorderless = role == "flatControl" or role == "flatBackground"

      Theme.SetSquareBackdrop(host, {
        bg = role == "accent" and colors.accent or (isControl and colors.control or colors.background),
        border = isBorderless and transparentBorder or (isControl and colors.controlBorder or colors.border),
      }, edge)
    end
  end
  for _, header in pairs(windowHeaders) do
    local color = colors.control
    header:SetColorTexture(color[1], color[2], color[3], color[4])
  end
  for text in pairs(styledTexts) do RefreshTextColor(text) end
  for texture, alpha in pairs(selections) do
    texture:SetColorTexture(colors.accent[1], colors.accent[2], colors.accent[3], alpha)
  end
  for texture, role in pairs(checkedTextures) do
    local color = colors[role]
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
  end
  for tab in pairs(styledTabs) do RefreshTabState(tab) end
  for button in pairs(styledButtons) do RefreshButtonState(button) end
  for scrollbar in pairs(scrollBars) do RefreshScrollBar(scrollbar) end
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
    Skins.ObserveAddon(addonName)
  end
end)

Skins.Hook(_G, "PanelTemplates_TabResize", function(tab)
  if styledTabs[tab] then RefreshTabState(tab) end
end)

hooksecurefunc(Theme, "RefreshAppliedFonts", Skins.RefreshTheme)
