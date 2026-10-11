local _, ns = ...

local Practice = {}
ns.EditModeGuidePractice = Practice

function Practice.ApplyReadingFont(text, role, minimumSize)
  local Theme = ns.Theme
  local settings = Theme.GetOptionsFontSettings(role)
  local size = Theme.ResolveFontSize(math.max(minimumSize, settings.size) + Theme.GetOptionsFontSize() - 14, "options")
  text:SetFont(ns.LSM:Fetch(ns.LSM.MediaType.FONT, settings.font), size, "")
  text:SetShadowOffset(0, 0)
  text:SetTextColor(unpack(Theme.GetColors().text))
end

local function Snapshot(self)
  local points = {}
  for index, point in ipairs(self.points) do points[index] = { x = point.x, y = point.y } end
  return points
end

local function PlaceMovers(self)
  for index, button in ipairs(self.movers) do
    local point = self.points[index]
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", self.arena, "BOTTOMLEFT", point.x, point.y)
    button:SetText(self.names[index] .. (self.selected[index] and "\n[Selected]" or ""))
  end
  self.status:SetText(string.format("%s · Step: %d px · Undo: %d · Redo: %d",
    self.keyboardMode and "Mover keys active · F6 for controls" or "Practice controls · F6 for mover keys",
    self.step, #self.undo, #self.redo))
end

local function SelectMover(self, index, additive)
  if not additive then self.selected = {} end
  self.selected[index] = not additive or not self.selected[index]
  self.selectedIndex = index
  PlaceMovers(self)
end

local function RecordMove(self, before)
  local after = Snapshot(self)
  for index, point in ipairs(before) do
    if point.x ~= after[index].x or point.y ~= after[index].y then
      self.undo[#self.undo + 1] = { before = before, after = after }
      if #self.undo > 50 then table.remove(self.undo, 1) end
      self.redo = {}
      break
    end
  end
  PlaceMovers(self)
end

local function MoveSelection(self, origin, dx, dy)
  local minX, maxX, minY, maxY = -math.huge, math.huge, -math.huge, math.huge
  for index, point in ipairs(origin) do
    if self.selected[index] then
      minX, maxX = math.max(minX, -point.x), math.min(maxX, self.arena:GetWidth() - self.moverWidth - point.x)
      minY, maxY = math.max(minY, -point.y), math.min(maxY, self.arena:GetHeight() - self.moverHeight - point.y)
    end
  end
  dx, dy = math.max(minX, math.min(maxX, dx)), math.max(minY, math.min(maxY, dy))
  for index, point in ipairs(origin) do
    if self.selected[index] then
      self.points[index].x, self.points[index].y = point.x + dx, point.y + dy
    end
  end
  PlaceMovers(self)
end

function Practice:StopDrag(cancel)
  self.arena:SetScript("OnUpdate", nil)
  local drag = self.drag
  self.drag = nil
  if not drag then return end
  if cancel then self.points = drag.before; PlaceMovers(self)
  else RecordMove(self, drag.before) end
end

function Practice:Replay(redo)
  self:StopDrag(false)
  local source, destination = redo and self.redo or self.undo, redo and self.undo or self.redo
  local move = table.remove(source)
  if not move then return end
  local points = redo and move.after or move.before
  self.points = {}
  for index, point in ipairs(points) do self.points[index] = { x = point.x, y = point.y } end
  destination[#destination + 1] = move
  PlaceMovers(self)
end

function Practice:HandleKey(key, keyboardInput)
  if not self.frame:IsVisible() or self.kind == "navigation" then return false end
  if key == "GLOBAL_MOUSE_DOWN" then
    self.keyboardMode = false
    PlaceMovers(self)
    return false
  end
  if IsControlKeyDown() and (key == "Z" or key == "Y") then
    self:Replay(key == "Y" or IsShiftKeyDown())
    return true
  end
  if key == "F6" then
    self:StopDrag(false)
    self.keyboardMode = not self.keyboardMode
    PlaceMovers(self)
    return true
  end
  if not self.keyboardMode or not keyboardInput then return false end
  if key == "TAB" then
    local direction = IsShiftKeyDown() and -1 or 1
    SelectMover(self, (self.selectedIndex - 1 + direction) % #self.movers + 1, false)
    return true
  end
  if key:match("^[1-9]$") then self.step = tonumber(key); PlaceMovers(self); return true end
  local dx = key == "LEFT" and -self.step or key == "RIGHT" and self.step or 0
  local dy = key == "DOWN" and -self.step or key == "UP" and self.step or 0
  if dx == 0 and dy == 0 then return false end
  local before = Snapshot(self)
  MoveSelection(self, before, dx, dy)
  RecordMove(self, before)
  return true
end

function Practice:Show(kind, width)
  self:StopDrag(true)
  self.kind, self.keyboardMode, self.step = kind, false, 1
  self.undo, self.redo, self.selected, self.selectedIndex = {}, {}, { true }, 1
  self.categoryGroup.status, self.tabGroup.status = {}, {}
  local Theme = ns.Theme
  local colors = Theme.GetColors()
  self.frame:SetWidth(width)
  self.navigation:SetShown(kind == "navigation")
  self.arena:SetShown(kind ~= "navigation")
  self.status:SetShown(kind ~= "navigation")
  self.undoButton:SetShown(kind ~= "navigation")
  self.redoButton:SetShown(kind ~= "navigation")
  self.reset:SetShown(kind ~= "navigation")
  for _, button in ipairs(self.buttons) do Theme.WidgetSkins.UIButton(button) end
  Theme.SetSquareBackdrop(self.frame, { bg = colors.control, border = colors.controlBorder }, Theme.ControlBorderSize)
  for _, text in ipairs({ self.heading, self.navResult, self.status }) do
    Practice.ApplyReadingFont(text, "body", 18)
  end
  self.heading:SetText("Practice area · sample controls only")
  self.heading:SetWidth(width - 32)
  self.navigation:SetSize(width - 32, 270)
  local rowHeight = math.max(38, Theme.GetOptionsPointerTargetSize(0), Theme.GetOptionsFontHeight("button") * 2 + 12)
  local headingHeight = self.heading:GetStringHeight()
  self.navigation:ClearAllPoints()
  self.navigation:SetPoint("TOPLEFT", 16, -headingHeight - 32)
  local menuWidth = math.min(220, (width - 48) * 0.4)
  for index, button in ipairs(self.categories) do
    button:SetSize(menuWidth, rowHeight)
    button.selected = false
    button:SetText(button.practiceLabel)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", 0, -(index - 1) * (rowHeight + 10))
    ns.KeyboardNavigation.RegisterFrame(button, "list", "practiceCategory" .. index, self.categoryGroup)
  end
  for index, button in ipairs(self.tabs) do
    button:SetSize((width - menuWidth - 56) / 2, rowHeight)
    button.selected = false
    button:SetText(button.practiceLabel)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", menuWidth + 16 + (index - 1) * (width - menuWidth - 40) / 2, 0)
    ns.KeyboardNavigation.RegisterFrame(button, "tabs", "practiceTab" .. index, self.tabGroup)
  end
  self.sampleToggle:SetSize(width - menuWidth - 48, rowHeight)
  self.sampleToggle:ClearAllPoints()
  self.sampleToggle:SetPoint("TOPLEFT", menuWidth + 16, -rowHeight - 16)
  self.navResult:ClearAllPoints()
  self.navResult:SetPoint("TOPLEFT", menuWidth + 16, -(rowHeight + 16) * 2)
  self.navResult:SetWidth(width - menuWidth - 48)
  self.navResult:SetText("Choose a sample category and tab, then toggle Show sample text.")
  self.sampleToggle:SetText("Show sample text: Off")
  self.sampleOn = false
  self.moverWidth = math.min(190, (width - 56) / 3)
  self.moverHeight = rowHeight
  self.arena:SetSize(width - 32, self.moverHeight + 150)
  self.arena:ClearAllPoints()
  self.arena:SetPoint("TOPLEFT", 16, -headingHeight - 32)
  self.points = { { x = 8, y = 120 }, { x = (width - 32 - self.moverWidth) / 2, y = 70 },
    { x = width - 40 - self.moverWidth, y = 20 } }
  for index, button in ipairs(self.movers) do
    button:SetSize(self.moverWidth, self.moverHeight)
    ns.KeyboardNavigation.RegisterFrame(button, "button", "practiceMover" .. index, nil, nil, nil, {
      activate = function() SelectMover(self, index, false) end,
    })
  end
  local actionWidth = (width - 48) / 3
  for index, button in ipairs({ self.undoButton, self.redoButton, self.reset }) do
    button:SetSize(actionWidth, rowHeight)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", 16 + (index - 1) * (actionWidth + 8), 16)
  end
  self.status:SetWidth(width - 32)
  for _, button in ipairs(self.buttons) do
    button:GetFontString():SetWordWrap(true)
    button:GetFontString():SetWidth(math.max(1, button:GetWidth() - 16))
  end
  PlaceMovers(self)
  local height = kind == "navigation" and headingHeight + rowHeight * 4 + 100
    or headingHeight + self.arena:GetHeight() + self.status:GetStringHeight() + rowHeight + 80
  self.frame:SetHeight(height)
  self.frame:Show()
end

function Practice.Create(parent)
  local self = setmetatable({ buttons = {}, movers = {}, names = { "Player", "Target", "Resources" },
    categoryGroup = { status = {} }, tabGroup = { status = {} } }, { __index = Practice })
  self.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  self.frame:Hide()
  self.frame:EnableMouse(true)
  self.frame:SetScript("OnHide", function() self:StopDrag(true); self.keyboardMode = false end)
  self.frame:SetScript("OnMouseDown", function() self.keyboardMode = false; PlaceMovers(self) end)
  local function Text(host)
    local text = host:CreateFontString(nil, "OVERLAY")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
  end
  local function Button(host, label, action)
    local button = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
    button:SetText(label)
    button.practiceLabel = label
    button:SetScript("OnClick", action)
    self.buttons[#self.buttons + 1] = button
    return button
  end
  self.heading = Text(self.frame)
  self.heading:SetPoint("TOPLEFT", 16, -16)
  self.navigation = CreateFrame("Frame", nil, self.frame)
  self.navigation:SetPoint("TOPLEFT", 16, -58)
  self.categories, self.tabs = {}, {}
  for index, label in ipairs({ "Display", "Resources", "Accessibility" }) do
    self.categories[index] = Button(self.navigation, label, function()
      for i, button in ipairs(self.categories) do
        button.selected = i == index
        button:SetText((i == index and "[Open]\n" or "") .. button.practiceLabel)
      end
      self.navResult:SetText("Opened sample category: " .. label .. "\nYour real settings have not changed.")
    end)
  end
  for index, label in ipairs({ "General", "Text" }) do
    self.tabs[index] = Button(self.navigation, label, function()
      for i, button in ipairs(self.tabs) do
        button.selected = i == index
        button:SetText((i == index and "[Open]\n" or "") .. button.practiceLabel)
      end
      self.tabGroup.status.selected = index
      self.navResult:SetText("Opened sample tab: " .. label .. "\nTry the sample toggle below.")
    end)
    self.tabs[index].__puiValue = index
  end
  self.sampleToggle = Button(self.navigation, "", function()
    self.sampleOn = not self.sampleOn
    self.sampleToggle:SetText("Show sample text: " .. (self.sampleOn and "On" or "Off"))
    self.navResult:SetText(self.sampleOn and "Sample text is visible.\nThis toggle only affects this exercise." or "Sample text is hidden.")
  end)
  self.navResult = Text(self.navigation)
  self.arena = CreateFrame("Frame", nil, self.frame)
  self.arena:SetPoint("TOPLEFT", 16, -58)
  for index, label in ipairs(self.names) do
    local button = Button(self.arena, label, nil)
    self.movers[index] = button
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function(_, key)
      if key ~= "LeftButton" then return end
      self.keyboardMode = false
      SelectMover(self, index, IsControlKeyDown())
    end)
    button:SetScript("OnDragStart", function()
      if not self.selected[index] then SelectMover(self, index, false) end
      local x, y = GetCursorPosition()
      self.drag = { before = Snapshot(self), x = x, y = y }
      self.arena:SetScript("OnUpdate", function()
        local cx, cy = GetCursorPosition()
        local scale = self.arena:GetEffectiveScale()
        MoveSelection(self, self.drag.before, (cx - self.drag.x) / scale, (cy - self.drag.y) / scale)
      end)
    end)
    button:SetScript("OnDragStop", function() self:StopDrag(false) end)
    button:SetScript("OnMouseUp", function() self:StopDrag(false) end)
  end
  self.status = Text(self.frame)
  self.status:SetPoint("TOPLEFT", self.arena, "BOTTOMLEFT", 0, -12)
  self.undoButton = Button(self.frame, "Undo\nCtrl+Z", function() self:Replay(false) end)
  self.redoButton = Button(self.frame, "Redo\nCtrl+Y", function() self:Replay(true) end)
  self.reset = Button(self.frame, "Reset practice", function() self:Show(self.kind, self.frame:GetWidth()) end)
  return self
end
