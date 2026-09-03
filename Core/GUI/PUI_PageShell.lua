local _, ns = ...

local PageShell = {}
ns.PageShell = PageShell

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local tonumber = tonumber
local type = type

local Theme = ns.Theme
local AceGUI = LibStub("AceGUI-3.0")

local PUI_PAGE_HEADER_HEIGHT = 78
local PUI_PAGE_GAP = 10
local PUI_PREVIEW_MIN_HEIGHT = 140
local PUI_PREVIEW_CONTENT_MIN_HEIGHT = 120

local function PUI_PageShell_ApplyBackdrop(frame, bgColor, borderColor, edge)
  Theme.SetSquareBackdrop(frame, {
    bg = bgColor,
    border = borderColor,
  }, edge)
end

local function PUI_PageShell_ClearHostChildren(host, preserve)
  for _, child in ipairs({ host:GetChildren() }) do
    if child ~= preserve then
      child:Hide()
      child:ClearAllPoints()
      child:SetParent(nil)
    end
  end

  for _, region in ipairs({ host:GetRegions() }) do
    if region ~= preserve then
      region:Hide()
      region:ClearAllPoints()
      region:SetParent(nil)
    end
  end
end

local function PUI_PageShell_GetBodyHeight(self)
  local height = tonumber(self.body:GetHeight()) or 0

  if height <= 2 then
    height = tonumber(self:GetHeight()) or 0
  end

  if height <= 2 then
    height = 520
  end

  return height
end

local function PUI_PageShell_GetPreviewHeightBounds(self)
  local reservedHeight = PUI_PREVIEW_CONTENT_MIN_HEIGHT

  if self.__puiTitleText ~= ""
    or self.__puiDescriptionText ~= ""
    or self.__puiHelpText ~= ""
    or self.headerActions:IsShown()
  then
    reservedHeight = reservedHeight + PUI_PAGE_HEADER_HEIGHT + PUI_PAGE_GAP
  end

  if self.stickyStrip:IsShown() then
    reservedHeight = reservedHeight
      + (tonumber(self.stickyStrip.__puiDesiredHeight) or 36)
      + PUI_PAGE_GAP
  end

  reservedHeight = reservedHeight + PUI_PAGE_GAP

  return PUI_PREVIEW_MIN_HEIGHT,
    math_max(
      PUI_PREVIEW_MIN_HEIGHT,
      math_floor(PUI_PageShell_GetBodyHeight(self) - reservedHeight + 0.5)
    )
end

local function PUI_PageShell_SyncACDContainer(self)
  local parent = self.acdHost
  local container = self.acdContainer

  if not container then
    return
  end

  if container.frame.__puiACDAnchorParent ~= parent then
    container.frame:ClearAllPoints()
    container.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    container.frame.__puiACDAnchorParent = parent
  end

  container.frame:SetClipsChildren(true)
end

local function PUI_PageShell_RebuildLayout(self)
  if self.__puiLayoutBuilding then
    return
  end

  self.__puiLayoutBuilding = true

  local hasTitle = self.__puiTitleText ~= ""
  local hasDescription = self.__puiDescriptionText ~= ""
  local hasHelp = self.__puiHelpText ~= ""
  local hasHeaderActions = self.headerActions:IsShown()
  local hasSticky = self.stickyStrip:IsShown()
  local showPreview = self.previewDock:IsShown()
  local gap = PUI_PAGE_GAP
  local shellLevel = self:GetFrameLevel()

  self.body:SetFrameLevel(shellLevel + 2)
  self.header:SetFrameLevel(shellLevel + 10)
  self.stickyStrip:SetFrameLevel(shellLevel + 12)
  self.contentHost:SetFrameLevel(shellLevel + 14)
  self.previewDock:SetFrameLevel(shellLevel + 60)
  self.previewHost:SetFrameLevel(shellLevel + 61)
  self.headerActions:SetFrameLevel(shellLevel + 80)

  self.body:SetParent(self)
  self.body:ClearAllPoints()
  self.body:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
  self.body:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
  self.body:Show()

  self.contentHost:ClearAllPoints()
  self.header:ClearAllPoints()
  self.stickyStrip:ClearAllPoints()

  self.header:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
  self.header:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, 0)

  local textRightInset = hasHeaderActions and 190 or 16

  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self.header, "TOPLEFT", 16, -9)
  self.title:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -textRightInset, -9)
  self.title:SetHeight(20)

  self.description:ClearAllPoints()
  if hasTitle then
    self.description:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -1)
    self.description:SetPoint("TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -1)
  else
    self.description:SetPoint("TOPLEFT", self.header, "TOPLEFT", 16, -9)
    self.description:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -textRightInset, -9)
  end
  self.description:SetHeight(16)

  self.helpLine:ClearAllPoints()
  if hasDescription then
    self.helpLine:SetPoint("TOPLEFT", self.description, "BOTTOMLEFT", 0, -1)
    self.helpLine:SetPoint("TOPRIGHT", self.description, "BOTTOMRIGHT", 0, -1)
  elseif hasTitle then
    self.helpLine:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -1)
    self.helpLine:SetPoint("TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -1)
  else
    self.helpLine:SetPoint("TOPLEFT", self.header, "TOPLEFT", 16, -9)
    self.helpLine:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -textRightInset, -9)
  end
  self.helpLine:SetHeight(14)

  self.headerActions:ClearAllPoints()
  self.headerActions:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -16, -10)
  self.headerActions:SetSize(160, 22)

  local headerHeight = 0
  if hasTitle or hasDescription or hasHelp or hasHeaderActions then
    headerHeight = PUI_PAGE_HEADER_HEIGHT
  end

  if headerHeight > 0 then
    self.header:SetHeight(headerHeight)
    self.header:Show()
  else
    self.header:SetHeight(1)
    self.header:Hide()
  end

  local contentTopOffset = 0
  if self.header:IsShown() then
    contentTopOffset = headerHeight + gap
  end

  local stickyHeight = tonumber(self.stickyStrip.__puiDesiredHeight) or 36
  self.stickyStrip:SetHeight(stickyHeight)

  if hasSticky then
    self.stickyStrip:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -contentTopOffset)
    self.stickyStrip:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, -contentTopOffset)
    self.stickyStrip:Show()
    contentTopOffset = contentTopOffset + stickyHeight + gap
  else
    self.stickyStrip:Hide()
  end

  local previewHeight = tonumber(self.__puiPreviewHeight) or 168
  self.previewDock:SetHeight(previewHeight)

  if showPreview then
    local previewAnchorOffsetY = -contentTopOffset

    if self.__puiPreviewAnchorOffsetY ~= previewAnchorOffsetY then
      self.previewDock:ClearAllPoints()
      self.previewDock:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, previewAnchorOffsetY)
      self.previewDock:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, previewAnchorOffsetY)
      self.__puiPreviewAnchorOffsetY = previewAnchorOffsetY
    end

    self.previewDock:Show()
    contentTopOffset = contentTopOffset + previewHeight + gap
  else
    self.previewDock:Hide()
  end

  local bodyHeight = PUI_PageShell_GetBodyHeight(self)
  local contentHeight = math_max(120, bodyHeight - contentTopOffset)

  self.contentHost.__puiMinimumHeight = contentHeight
  self.contentHost:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -contentTopOffset)
  self.contentHost:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, -contentTopOffset)
  self.contentHost:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", 0, 0)
  self.contentHost:Show()

  self.acdHost:ClearAllPoints()
  self.acdHost:SetPoint("TOPLEFT", self.contentHost, "TOPLEFT", 10, -10)
  self.acdHost:SetPoint("BOTTOMRIGHT", self.contentHost, "BOTTOMRIGHT", -10, 10)
  self.acdHost:SetClipsChildren(true)
  self.acdHost:Show()

  PUI_PageShell_SyncACDContainer(self)

  self.__puiLayoutDirty = nil
  self.__puiACDContainerLayoutReady = true
  self.__puiLayoutBuilding = nil
end

local function PUI_PageShell_RequestLayout(self)
  if self.__puiLayoutSuspended then
    self.__puiLayoutDirty = true
    return
  end

  self.__puiLayoutDirty = nil
  PUI_PageShell_RebuildLayout(self)
end

local function PUI_PageShell_QueueResizeLayout(self)
  self.__puiLayoutDirty = true

  if self.__puiLayoutQueued then
    return
  end

  self.__puiLayoutQueued = true

  C_Timer.After(0, function()
    self.__puiLayoutQueued = nil

    if not self.__puiLayoutDirty or self.__puiLayoutSuspended then
      return
    end

    self.__puiLayoutDirty = nil
    PUI_PageShell_RebuildLayout(self)
  end)
end

local function PUI_PageShell_RefreshTheme(self)
  local colors = Theme.GetColors()
  local edge = Theme.GetEdgeSize()
  local textColor = colors.text

  PUI_PageShell_ApplyBackdrop(self.header, colors.background, colors.border, edge)
  PUI_PageShell_ApplyBackdrop(self.stickyStrip, colors.background, colors.border, edge)
  PUI_PageShell_ApplyBackdrop(self.previewDock, colors.background, colors.border, edge)
  PUI_PageShell_ApplyBackdrop(self.contentHost, colors.background, colors.border, edge)


  Theme.ApplyFont(self.title, "title", 16)
  Theme.ApplyFont(self.description, "body", 11)
  Theme.ApplyFont(self.helpLine, "tiny", 10)

  self.title:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  self.description:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] * 0.72)
  self.helpLine:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] * 0.58)
end

function PageShell.Create(parent)
  local shell = CreateFrame("Frame", nil, parent)
  shell:SetAllPoints(parent)
  shell:SetScript("OnSizeChanged", function(self, width, height)
    local roundedWidth = math.floor(width + 0.5)
    local roundedHeight = math.floor(height + 0.5)
    local widthChanged = self.__puiLastLayoutWidth ~= roundedWidth
    local heightChanged = self.__puiLastLayoutHeight ~= roundedHeight

    if not widthChanged and not heightChanged then
      return
    end

    self.__puiLastLayoutWidth = roundedWidth
    self.__puiLastLayoutHeight = roundedHeight

    if widthChanged or heightChanged then
      PUI_PageShell_QueueResizeLayout(self)
    end
  end)

  shell.body = CreateFrame("Frame", nil, shell)

  shell.contentHeader = CreateFrame("Frame", nil, shell.body)
  shell.topTabBar = CreateFrame("Frame", nil, shell.body)
  shell.previewDock = CreateFrame("Frame", nil, shell.body)
  shell.scrollContent = CreateFrame("Frame", nil, shell.body)
  shell.acdHost = CreateFrame("Frame", nil, shell.scrollContent)

  shell.scrollContent.__puiACDHostContainer = true
  shell.scrollContent.__puiAceGUIOwnedByPleebUI = true
  shell.acdHost.__puiACDHostContainer = true
  shell.acdHost.__puiAceGUIOwnedByPleebUI = true

  shell.header = shell.contentHeader
  shell.stickyStrip = shell.topTabBar
  shell.contentHost = shell.scrollContent

  shell.title = shell.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  shell.title.__puiOptionsFontOwned = true
  shell.title:SetJustifyH("LEFT")
  shell.title:SetJustifyV("MIDDLE")

  shell.description = shell.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  shell.description.__puiOptionsFontOwned = true
  shell.description:SetJustifyH("LEFT")
  shell.description:SetJustifyV("MIDDLE")
  shell.description:SetWordWrap(false)

  shell.helpLine = shell.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  shell.helpLine.__puiOptionsFontOwned = true
  shell.helpLine:SetJustifyH("LEFT")
  shell.helpLine:SetJustifyV("MIDDLE")
  shell.helpLine:SetWordWrap(false)

  shell.headerActions = CreateFrame("Frame", nil, shell.header)
  shell.headerActions:Hide()
  shell.header:SetClipsChildren(true)

  shell.contentHost:SetPoint("TOPLEFT", shell.body, "TOPLEFT", 0, 0)
  shell.contentHost:SetPoint("TOPRIGHT", shell.body, "TOPRIGHT", 0, 0)
  shell.contentHost:SetHeight(1)
  shell.contentHost:SetClipsChildren(true)
  shell.contentHost:Show()

  shell.acdHost:SetPoint("TOPLEFT", shell.contentHost, "TOPLEFT", 10, -10)
  shell.acdHost:SetPoint("TOPRIGHT", shell.contentHost, "TOPRIGHT", -10, -10)
  shell.acdHost:SetHeight(1)
  shell.acdHost:SetClipsChildren(true)
  shell.acdHost:Show()

  shell.previewHost = CreateFrame("Frame", nil, shell.previewDock)
  shell.previewHost:SetPoint("TOPLEFT", shell.previewDock, "TOPLEFT", 0, 0)
  shell.previewHost:SetPoint("BOTTOMRIGHT", shell.previewDock, "BOTTOMRIGHT", 0, 0)



  shell.__puiTitleText = ""
  shell.__puiDescriptionText = ""
  shell.__puiHelpText = ""
  shell.__puiPreviewWidth = 280
  shell.__puiPreviewHeight = 168

  PUI_PageShell_RefreshTheme(shell)

  function shell:RefreshTheme()
    PUI_PageShell_RefreshTheme(self)
  end

  function shell:SetTitle(text)
    local shown = text ~= ""
    if self.__puiTitleText == text and self.title:IsShown() == shown then
      return
    end

    self.__puiTitleText = text
    self.title:SetText(text)
    self.title:SetShown(shown)
    PUI_PageShell_RequestLayout(self)
  end

  function shell:SetDescription(text)
    local shown = text ~= ""
    if self.__puiDescriptionText == text and self.description:IsShown() == shown then
      return
    end

    self.__puiDescriptionText = text
    self.description:SetText(text)
    self.description:SetShown(shown)
    PUI_PageShell_RequestLayout(self)
  end

  function shell:SetHelpText(text)
    local shown = text ~= ""
    if self.__puiHelpText == text and self.helpLine:IsShown() == shown then
      return
    end

    self.__puiHelpText = text
    self.helpLine:SetText(text)
    self.helpLine:SetShown(shown)
    PUI_PageShell_RequestLayout(self)
  end


  function shell:BeginLayoutBatch()
    self.__puiLayoutBatchDepth = (self.__puiLayoutBatchDepth or 0) + 1
    self.__puiLayoutSuspended = true
  end

  function shell:EndLayoutBatch()
    local depth = (self.__puiLayoutBatchDepth or 1) - 1
    self.__puiLayoutBatchDepth = depth > 0 and depth or nil

    if self.__puiLayoutBatchDepth then
      return
    end

    self.__puiLayoutSuspended = nil

    if self.__puiLayoutDirty then
      self.__puiLayoutDirty = nil
      PUI_PageShell_RebuildLayout(self)
    end
  end

  function shell:GetACDContainer()
    if self.__puiLayoutDirty == true or self.__puiACDContainerLayoutReady ~= true then
      self.__puiLayoutDirty = nil
      PUI_PageShell_RebuildLayout(self)
    end

    local parent = self.acdHost
    local container = self.acdContainer

    if not container then
      container = AceGUI:Create("SimpleGroup")
      container.parent = nil
      container.__puiACDHostContainer = true
      container.__puiAceGUIOwnedByPleebUI = true
      container.frame.__puiACDHostContainer = true
      container.frame.__puiAceGUIOwnedByPleebUI = true
      container.content.__puiACDHostContainer = true
      container.content.__puiAceGUIOwnedByPleebUI = true
      container:SetLayout("Fill")
      container:SetAutoAdjustHeight(false)
      container:SetFullWidth(true)
      container:SetFullHeight(true)

      parent:SetClipsChildren(true)
      container.frame:SetParent(parent)
      container.frame.__puiACDAnchorParent = nil

      self.acdContainer = container
    end

    container.frame:SetFrameStrata(parent:GetFrameStrata())
    container.frame:SetFrameLevel(parent:GetFrameLevel() + 1)

    PUI_PageShell_SyncACDContainer(self)
    container.frame:Show()

    return container
  end

  function shell:SetHeaderActionsShown(enabled)
    enabled = enabled == true

    if self.headerActions:IsShown() == enabled then
      return
    end

    self.headerActions:SetShown(enabled)
    PUI_PageShell_RequestLayout(self)
  end

  function shell:SetStickyShown(enabled)
    enabled = enabled == true

    if self.stickyStrip:IsShown() == enabled then
      return
    end

    self.stickyStrip:SetShown(enabled)
    PUI_PageShell_RequestLayout(self)
  end

  function shell:SetPreviewState(state)
    self.__puiPreviewState = type(state) == "table" and state or nil
  end

  function shell:GetPreviewState()
    return self.__puiPreviewState
  end

  function shell:SetPreviewShown(enabled, width, height)
    enabled = enabled == true

    local changed = self.previewDock:IsShown() ~= enabled
    if width ~= nil then
      changed = changed or self.__puiPreviewWidth ~= width
      self.__puiPreviewWidth = width
    end

    if height ~= nil then
      local minimumHeight, maximumHeight = PUI_PageShell_GetPreviewHeightBounds(self)
      local nextHeight = math_floor(
        math_min(
          maximumHeight,
          math_max(minimumHeight, tonumber(height) or 168)
        )
        + 0.5
      )

      changed = changed or self.__puiPreviewHeight ~= nextHeight
      self.__puiPreviewHeight = nextHeight
    end

    if not changed then
      return
    end

    self.previewDock:SetShown(enabled)
    PUI_PageShell_RequestLayout(self)
  end

  function shell:Reset()
    local wasSuspended = self.__puiLayoutSuspended

    self.__puiLayoutSuspended = true
    self.__puiLayoutDirty = nil

    self:SetTitle("")
    self:SetDescription("")
    self:SetHelpText("")
    self:SetHeaderActionsShown(false)
    self:SetStickyShown(false)
    self:SetPreviewShown(false, self.__puiPreviewWidth)
    PUI_PageShell_ClearHostChildren(self.headerActions)
    PUI_PageShell_ClearHostChildren(self.stickyStrip)
    PUI_PageShell_ClearHostChildren(self.previewHost)
    PUI_PageShell_ClearHostChildren(self.acdHost, self.acdContainer and self.acdContainer.frame or nil)

    self.__puiLayoutSuspended = wasSuspended or nil
    PUI_PageShell_RequestLayout(self)
  end

  function shell:ResetPageContent(preserveSticky)
    local wasSuspended = self.__puiLayoutSuspended

    self.__puiLayoutSuspended = true
    self.__puiLayoutDirty = nil

    self:SetHeaderActionsShown(false)
    self:SetPreviewShown(false, self.__puiPreviewWidth)
    PUI_PageShell_ClearHostChildren(self.headerActions)
    PUI_PageShell_ClearHostChildren(self.previewHost)
    PUI_PageShell_ClearHostChildren(self.acdHost, self.acdContainer and self.acdContainer.frame or nil)

    if preserveSticky ~= true then
      self:SetStickyShown(false)
      PUI_PageShell_ClearHostChildren(self.stickyStrip)
    end

    self.__puiLayoutSuspended = wasSuspended or nil
    PUI_PageShell_RequestLayout(self)
  end


  shell.headerActions:Hide()
  shell.stickyStrip:Hide()
  shell.previewDock:Hide()
  shell.title:Hide()
  shell.description:Hide()
  shell.helpLine:Hide()

  PUI_PageShell_RebuildLayout(shell)

  return shell
end

function PageShell.Ensure(parent)
  local shell = parent.__puiPageShell
  if shell then
    shell:SetParent(parent)
    shell:ClearAllPoints()
    shell:SetAllPoints(parent)
    return shell
  end

  shell = PageShell.Create(parent)
  parent.__puiPageShell = shell
  return shell
end
