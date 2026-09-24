local ADDON_NAME, ns = ...

local Addon = ns.Addon
local Buffs = Addon:NewModule("PCM_Buffs")
ns.Modules.PCM_Buffs = Buffs

local P = select(1, ns.Pleebug:DropIn(Buffs, { name = "PCM", bucket = "BuffsIconViewer" }))

local _G = _G
local IsSecret = issecretvalue
local Hooks = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local IconSettings = ns.PCMIconSettings
local Cooldowns = ns.Modules.CooldownManager
local Pixel = ns.Pixel
local Round = Pixel.Round

local IconSkin = ns.IconSkin
local FrameUtil = ns.FrameUtil
local VIEWER_KEY = "BuffIconCooldownViewer"

local function _PCM_BuffsEnabled()
  if ns.PCM_IsTransitionPending() then
    return false
  end

  return ns.PCM_IsModuleEnabledFast() == true
end

local _cache = {
  viewer      = nil,

  cm          = nil,

  fontDB      = nil,

  spacing     = nil,
  iconSize    = nil,
  columns     = nil,
  growth      = nil,

  buffContainer = nil,
}

local function _InvalidateBuffsCache()
  _cache.cm = nil

  _cache.fontDB = nil

  _cache.spacing = nil
  _cache.iconSize = nil
  _cache.columns = nil
  _cache.growth = nil

  _cache.buffContainer = nil

  _cache.readyViewer = nil
  _cache.viewerReady = nil
end


local function _GetBuffsDB()
  if _cache.cm then
    return _cache.cm
  end

  local cm = ns.PCM_DBExports.GetProfileBuffsDB()
  _cache.cm = cm
  return cm
end


local function _GetViewerFontDB()
  if _cache.fontDB then
    return _cache.fontDB
  end

  local v = ns.PCM_DBExports.GetProfileBuffsViewerFontDB(VIEWER_KEY)
  _cache.fontDB = v
  return v
end

-- Font/stack sizing is safe to update in combat; apply via IconSkin helpers.
local _fontRev = 0
local _styleRev = 0

-- Runtime cached values (prime on init/settings, never pull DB in the hot driver).
local _rt_scaleFn = nil
local _rt_fontDB = nil
local _rt_spacing = 1
local _rt_iconSize = 36
local _rt_columns = 0
local _rt_growth = "CENTER"



local function _GetViewer()
  local viewer = PCMRuntime:GetViewer(VIEWER_KEY)
  _cache.viewer = viewer
  return viewer
end

local function _ViewerIsReady(viewer)
  if not viewer then
    return false
  end

  if _cache.readyViewer == viewer and _cache.viewerReady == true then
    return true
  end

  if viewer.IsForbidden and viewer:IsForbidden() then
    return false
  end

  local container = viewer:GetItemContainerFrame()
  if not container or (container.IsForbidden and container:IsForbidden()) then
    return false
  end

  if viewer.IsInitialized and not viewer:IsInitialized() then
    return false
  end

  _cache.readyViewer = viewer
  _cache.viewerReady = true
  return true
end

local buffHolder = nil

local function _EnsureBuffHolder()
  if buffHolder then
    buffHolder:Show()
    return buffHolder
  end

  buffHolder = _G.CreateFrame("Frame", nil, UIParent)
  local moverSize = Round(_rt_iconSize or 36)
  buffHolder:SetSize(moverSize, moverSize)
  buffHolder.__puiBuffCenterW = moverSize
  buffHolder.__puiBuffCenterH = moverSize
  buffHolder:Show()

  return buffHolder
end


local wipe = wipe
local sort = table.sort
local insert = table.insert
local remove = table.remove
local GetTime = GetTime
local _buffIconObjectID = setmetatable({}, { __mode = "k" })
local _buffIconObjectIDSeed = 0

local function _GetStableBuffIconID(icon)
  local id = _buffIconObjectID[icon]
  if id then
    return id
  end

  _buffIconObjectIDSeed = _buffIconObjectIDSeed + 1
  id = _buffIconObjectIDSeed
  _buffIconObjectID[icon] = id
  return id
end

local function _GetLayoutSortKey(icon)
  if not icon then
    return 0
  end

  local fd = Hooks.GetFrameData(icon)
  local key = fd.__puiLayoutSortKey
  if key ~= nil then
    return key
  end

  key = icon.layoutIndex
  if IsSecret(key) then
    key = nil
  elseif key == nil and icon.GetID then
    key = icon:GetID()
    if IsSecret(key) then
      key = nil
    end
  end

  if type(key) == "string" then
    key = tonumber(key) or 0
  elseif type(key) ~= "number" then
    key = _GetStableBuffIconID(icon)
  end

  fd.__puiLayoutSortKey = key
  return key
end

local function _SortByLayoutIndex(a, b)
  return _GetLayoutSortKey(a) < _GetLayoutSortKey(b)
end

local buffCenterBuffer = {}
local _buffCenterIndex = setmetatable({}, { __mode = "k" })
local pendingRecenter = true

local _centerForceLayout = false
local _centerSnapshot = {}
local _centerSnapshotCount = 0
local _centerListDirty = true
local _centerVisibilityNeedsRebuild = true

local _MarkBuffItemListDirty
local _AddBuffItem
local _RemoveBuffItem
local _RefreshBuffIconVisibility
local _RequestUnifiedBuffRefresh
local CenterVisibleBuffs


local function _IsIconFrame(f)
  if not f then
    return false
  end

  local fd = Hooks.GetFrameData(f)
  if fd.__puiIsBuffIconFrame == nil then
    fd.__puiIsBuffIconFrame = f.Icon ~= nil
  end

  return fd.__puiIsBuffIconFrame
end


local _prepNeeded = true
local _rt_lastMoverTotal = 0
local _buffItemListDirty = true
local _buffItemList = {}
local _buffItemSet = setmetatable({}, { __mode = "k" })
local _buffItemListViewer = nil

local function _ClearBuffVisibleList()
  for index = 1, #buffCenterBuffer do
    local icon = buffCenterBuffer[index]
    if icon then
      _buffCenterIndex[icon] = nil
    end
    buffCenterBuffer[index] = nil
  end
end

local function _MarkBuffCenterDirty()
  _centerListDirty = true
end

_MarkBuffItemListDirty = function(viewer)
  _buffItemListDirty = true
  _centerVisibilityNeedsRebuild = true
  _centerListDirty = true

  if not viewer or _buffItemListViewer ~= viewer then
    wipe(_buffItemList)
    wipe(_buffItemSet)
    _ClearBuffVisibleList()
    _buffItemListViewer = viewer
  end
end

local function _GetViewerItemList(viewer)
  if not viewer then
    wipe(_buffItemList)
    wipe(_buffItemSet)
    _ClearBuffVisibleList()
    _buffItemListViewer = nil
    _buffItemListDirty = true
    _centerVisibilityNeedsRebuild = true
    return _buffItemList
  end

  if (not _buffItemListDirty) and _buffItemListViewer == viewer then
    return _buffItemList
  end

  wipe(_buffItemList)
  wipe(_buffItemSet)
  _buffItemListViewer = viewer

  local lastKey = -1
  local needsSort = false

  local function AddIcon(icon)
    if not (icon and _IsIconFrame(icon) and (not (icon.IsForbidden and icon:IsForbidden()))) then
      return
    end

    local key = _GetLayoutSortKey(icon)

    if key < lastKey then
      needsSort = true
    end
    lastKey = key

    _buffItemList[#_buffItemList + 1] = icon
    _buffItemSet[icon] = true
  end

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    AddIcon(items[index])
  end

  if needsSort and #_buffItemList > 1 then
    sort(_buffItemList, _SortByLayoutIndex)
  end

  _buffItemListDirty = false
  _centerVisibilityNeedsRebuild = true
  return _buffItemList
end

local _ApplyLiveIconFonts
local _ApplyManualHiddenState
local _Buffs_ApplyCentered

local function _PrepareBuffIcon(icon, desiredSize, fontDB, IS)
  if not _IsIconFrame(icon) then
    return
  end
  if PCMRuntime:IsPresentationSuspended() then
    return
  end

  local iconFd = Hooks.GetFrameData(icon)

  if desiredSize and desiredSize > 0 and iconFd.__puiBuffPreparedSize ~= desiredSize then
    iconFd.iconSize = desiredSize
    Cooldowns._ApplyIconSizeToItemFrame(icon, VIEWER_KEY, desiredSize)

    icon.Cooldown:ClearAllPoints()
    icon.Cooldown:SetAllPoints(icon)

    iconFd.__puiBuffPreparedSize = desiredSize
    iconFd.__puiBuffPrepared = true
  end

  if iconFd.__puiBuffStyleRev ~= _styleRev then
    iconFd.__puiBuffStyleRev = _styleRev
    iconFd.__puiBuffSkinned = true
    IS.SkinCooldownViewerItem(icon)
  end

  if fontDB then
    if iconFd.__puiBuffFontRev ~= _fontRev then
      iconFd.__puiBuffFontRev = _fontRev
      iconFd.__puiBuffViewerFontRev = _fontRev
      _ApplyLiveIconFonts(icon, fontDB)
      iconFd.__puiBuffPrepared = true
    end
  end

  if not iconFd.__puiBuffAuraHooked then
    iconFd.__puiBuffAuraHooked = true

    local function QueueBuffIconVisibilityRefresh(self)
      if PCMRuntime:IsPresentationSuspended() then
        return
      end

      _RefreshBuffIconVisibility(self)
      _RequestUnifiedBuffRefresh("layout", self:GetViewerFrame())
    end

    Hooks.HookScript(icon, "OnShow", "BUFFS_Icon_OnShow", QueueBuffIconVisibilityRefresh)
    Hooks.HookScript(icon, "OnHide", "BUFFS_Icon_OnHide", QueueBuffIconVisibilityRefresh)
  end

  if not PCMRuntime:IsDataRestricted() then
    if iconFd.iconTextureRestorePending == true then
      icon:RefreshSpellTexture()
      iconFd.iconTextureRestorePending = nil
    end
    Cooldowns:ApplyNativeIndividualIconSettings(icon, VIEWER_KEY, "AURA")
  end
end

local function _PrepareBuffIcons(iconList, desiredSize, fontDB, IS)
  if not _PCM_BuffsEnabled() then
    return
  end

  for i = 1, #iconList do
    _PrepareBuffIcon(iconList[i], desiredSize, fontDB, IS)
  end
end


local function _GetViewerStyleSizing()
  if (_cache.spacing ~= nil) and (_cache.iconSize ~= nil) and (_cache.columns ~= nil) and (_cache.growth ~= nil) then
    return _cache.spacing, _cache.iconSize, _cache.columns, _cache.growth
  end

  local cm = _GetBuffsDB()
  local style = cm and cm.style or {}

  -- Match PCM settings behavior: viewerSizes[VIEWER_KEY] is stored as a NUMBER (not a table).
  style.viewerSizes = style.viewerSizes or {}
  style.viewerColumns = style.viewerColumns or {}
  style.viewerGrowth = style.viewerGrowth or {}

  local spacingValue =
    (style.viewerSpacing and style.viewerSpacing[VIEWER_KEY]) or
    style.iconSpacing or
    1

  spacingValue = tonumber(spacingValue) or 1
  if spacingValue < 0 then spacingValue = 0 end
  if spacingValue > 128 then spacingValue = 128 end

  local iconSize =
    style.viewerSizes[VIEWER_KEY] or
    style.iconSize or
    36

  iconSize = tonumber(iconSize) or 36
  if iconSize < 12 then iconSize = 12 end
  if iconSize > 86 then iconSize = 86 end

  local columns = style.viewerColumns[VIEWER_KEY]
  columns = tonumber(columns) or 0
  if columns < 0 then columns = 0 end
  if columns > 40 then columns = 40 end

  local growth = style.viewerGrowth[VIEWER_KEY]
  if growth ~= "RIGHT" and growth ~= "LEFT" then
    growth = "CENTER"
  end

  -- Write back normalized/clamped values so UI widgets always reflect the live value.
  style.viewerSizes[VIEWER_KEY] = iconSize
  style.viewerColumns[VIEWER_KEY] = columns
  style.viewerGrowth[VIEWER_KEY] = growth

  _cache.spacing = spacingValue
  _cache.iconSize = iconSize
  _cache.columns = columns
  _cache.growth = growth
  return spacingValue, iconSize, columns, growth
end

_ApplyLiveIconFonts = function(icon, fontDB)
  if not icon or (icon.IsForbidden and icon:IsForbidden()) then return end

  local cooldownOpts = IconSettings:ResolveFontOptions(
    icon,
    VIEWER_KEY,
    "cooldown",
    fontDB.cooldown
  )
  local cd = icon.Cooldown or icon.cooldown
  if cd and cooldownOpts then
    IconSkin.StyleCooldownText(cd, cooldownOpts)
  end

  local chargeOpts = IconSettings:ResolveFontOptions(
    icon,
    VIEWER_KEY,
    "charge",
    fontDB.charge
  )
  IconSkin.StyleChargeText(icon, chargeOpts or { role = "charge" })
end


_ApplyManualHiddenState = function(icon, fd)
  if not icon or (icon.IsForbidden and icon:IsForbidden()) then
    return false
  end

  fd = fd or Hooks.GetFrameData(icon)

  local bbHidden = fd.__puiBBHidden
  if bbHidden == nil and fd.__puiBBHiddenKnown ~= true then
    local wasShown
    bbHidden, wasShown = Hooks.GetBBIconHidden(icon)
    fd.__puiBBHiddenKnown = true
    fd.__puiBBHidden = bbHidden and true or false

    if wasShown ~= nil then
      fd.__puiBBWasShown = wasShown and true or false
    end
  end

  bbHidden = fd.__puiBBHidden

  local shouldHide = (bbHidden == true)

  if (fd.manualHidden == true) == shouldHide and (fd.hidden == true) == shouldHide then
    return shouldHide
  end

  fd.manualHidden = shouldHide or nil
  fd.hidden = shouldHide or nil
  _centerListDirty = true

  if shouldHide then
    fd.anchor = nil
    if icon.SetAlpha then
      icon:SetAlpha(0)
    end
    return true
  end

  return false
end

-- Public API (wire to config later)
-- Forward declare so calls above the definition don't become global lookups.


local function _PrepareBuffIconsForViewer(viewer, desiredSize)
  if not _prepNeeded or not viewer then
    return
  end

  local fontDB = _rt_fontDB
  if not fontDB then
    fontDB = _GetViewerFontDB()
    _rt_fontDB = fontDB
  end

  local iconList = _GetViewerItemList(viewer)
  _PrepareBuffIcons(iconList, desiredSize, fontDB, IconSkin)
  _prepNeeded = false
end

local function _SkinAndParkBuffIcon(viewer, itemFrame)
  if not _PCM_BuffsEnabled() then
    return
  end
  if PCMRuntime:IsPresentationSuspended() then
    return
  end

  if not (viewer and itemFrame and _IsIconFrame(itemFrame)) then
    return
  end

  local holder = _EnsureBuffHolder()
  if not holder then
    return
  end

  local scale = _rt_scaleFn or Round
  local desiredSize = scale(_rt_iconSize or 36)

  local fontDB = _rt_fontDB
  if not fontDB then
    fontDB = _GetViewerFontDB()
    _rt_fontDB = fontDB
  end

  _PrepareBuffIcon(itemFrame, desiredSize, fontDB, IconSkin)
  Hooks.SetItemViewerKey(itemFrame, VIEWER_KEY)

  local fd = Hooks.GetFrameData(itemFrame)
  _ApplyManualHiddenState(itemFrame, fd)

  fd.anchor = holder
  fd.posX = 0
  fd.posY = 0
  fd.sizeW = desiredSize
  fd.sizeH = desiredSize
  fd.parked = true

  fd.locking = true
  if itemFrame.SetAlpha then
    itemFrame:SetAlpha(0)
  end
  if itemFrame.ClearAllPoints and itemFrame.SetPoint then
    itemFrame:ClearAllPoints()
    itemFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
  end
  if itemFrame.SetSize then
    itemFrame:SetSize(desiredSize, desiredSize)
  end
  fd.locking = false
end

local function _RefreshReboundBuffIcon(viewer, itemFrame)
  if not _PCM_BuffsEnabled() or not (viewer and itemFrame and _IsIconFrame(itemFrame)) then
    return
  end

  local fd = Hooks.GetFrameData(itemFrame)
  fd.__puiBuffPreparedSize = nil
  fd.__puiBuffStyleRev = nil
  fd.__puiBuffFontRev = nil
  fd.__puiBuffViewerFontRev = nil

  Cooldowns:ClearNativeIndividualIconSettings(itemFrame, VIEWER_KEY)
  _SkinAndParkBuffIcon(viewer, itemFrame)
  _AddBuffItem(viewer, itemFrame)
  _RefreshBuffIconVisibility(itemFrame)
end

local function _ResolveViewerAndContainer(viewer)
  local holder = _EnsureBuffHolder()

  local container = viewer:GetItemContainerFrame()

  -- One-time prep per container swap.
  if _cache.buffContainer ~= container then
    _cache.buffContainer = container
    _prepNeeded = true
    _MarkBuffItemListDirty(viewer)
  end

  local scale = _rt_scaleFn or Round
  local spacingValue = _rt_spacing or 1
  local padX = scale(spacingValue or 1)
  local desiredSize = scale(_rt_iconSize or 36)

  return holder, padX, desiredSize
end

local function _BuffIconIsCenterVisible(icon)
  if not icon or not icon.IsShown or not icon:IsShown() then
    return false
  end

  local fd = Hooks.GetFrameData(icon)
  return not fd.hidden
end

local function _RemoveVisibleBuffIcon(icon)
  local index = icon and _buffCenterIndex[icon] or nil
  if not index then
    return false
  end

  remove(buffCenterBuffer, index)
  _buffCenterIndex[icon] = nil

  for i = index, #buffCenterBuffer do
    _buffCenterIndex[buffCenterBuffer[i]] = i
  end

  return true
end

local function _InsertVisibleBuffIcon(icon)
  if not icon or _buffCenterIndex[icon] then
    return false
  end

  local key = _GetLayoutSortKey(icon)
  local insertAt = #buffCenterBuffer + 1

  for i = 1, #buffCenterBuffer do
    if key < _GetLayoutSortKey(buffCenterBuffer[i]) then
      insertAt = i
      break
    end
  end

  insert(buffCenterBuffer, insertAt, icon)
  for i = insertAt, #buffCenterBuffer do
    _buffCenterIndex[buffCenterBuffer[i]] = i
  end

  return true
end

_RefreshBuffIconVisibility = function(icon)
  if not icon
    or _buffItemSet[icon] ~= true
  then
    return false
  end

  local fd = Hooks.GetFrameData(icon)
  _ApplyManualHiddenState(icon, fd)

  local changed
  if _BuffIconIsCenterVisible(icon) then
    changed = _InsertVisibleBuffIcon(icon)
  else
    changed = _RemoveVisibleBuffIcon(icon)
  end

  if changed then
    _centerListDirty = true
  end

  return changed
end

local function _RebuildVisibleBuffIcons(iconList)
  _ClearBuffVisibleList()

  for i = 1, #iconList do
    local icon = iconList[i]
    local fd = Hooks.GetFrameData(icon)
    _ApplyManualHiddenState(icon, fd)

    if _BuffIconIsCenterVisible(icon) then
      local index = #buffCenterBuffer + 1
      buffCenterBuffer[index] = icon
      _buffCenterIndex[icon] = index
    end
  end

  _centerVisibilityNeedsRebuild = false
  _centerListDirty = true
end

_AddBuffItem = function(viewer, icon)
  if not viewer or not icon or not _IsIconFrame(icon) or (icon.IsForbidden and icon:IsForbidden()) then
    return
  end

  if _buffItemListDirty or _buffItemListViewer ~= viewer then
    _centerVisibilityNeedsRebuild = true
    return
  end

  if _buffItemSet[icon] == true then
    _RefreshBuffIconVisibility(icon)
    return
  end

  local fd = Hooks.GetFrameData(icon)
  fd.__puiLayoutSortKey = nil

  local key = _GetLayoutSortKey(icon)
  local insertAt = #_buffItemList + 1
  for i = 1, #_buffItemList do
    if key < _GetLayoutSortKey(_buffItemList[i]) then
      insertAt = i
      break
    end
  end

  insert(_buffItemList, insertAt, icon)
  _buffItemSet[icon] = true
  _RefreshBuffIconVisibility(icon)
  _centerListDirty = true
end

_RemoveBuffItem = function(icon)
  if not icon or _buffItemSet[icon] ~= true then
    return
  end

  _buffItemSet[icon] = nil
  for i = 1, #_buffItemList do
    if _buffItemList[i] == icon then
      remove(_buffItemList, i)
      break
    end
  end

  _RemoveVisibleBuffIcon(icon)
  Hooks.GetFrameData(icon).__puiLayoutSortKey = nil
  _centerListDirty = true
end

local function _CenteredSnapshotMatches(icons)
  if _centerSnapshotCount ~= #icons then
    return false
  end

  for i = 1, #icons do
    if _centerSnapshot[i] ~= icons[i] then
      return false
    end
  end

  return true
end

local function _UpdateCenteredSnapshot(icons)
  for i = 1, #icons do
    _centerSnapshot[i] = icons[i]
  end

  for i = #icons + 1, #_centerSnapshot do
    _centerSnapshot[i] = nil
  end

  _centerSnapshotCount = #icons
end

local function _PositionCenteredBuffIcon(icon, holder, desiredSize, x, y)
  local fd = Hooks.GetFrameData(icon)

  local prevAnchor = fd.anchor
  local prevX = fd.posX
  local prevY = fd.posY
  local prevW = fd.sizeW
  local prevH = fd.sizeH
  local wasParked = fd.parked == true
  local alpha = 1
  if icon.GetAlpha then
    alpha = icon:GetAlpha()
  end
  local alphaIsSecret = IsSecret(alpha)
  local targetAlpha = fd.iconAppliedAlpha
  if targetAlpha == nil then
    targetAlpha = 1
  end

  local needsSize = prevW ~= desiredSize or prevH ~= desiredSize
  local needsPoint = prevAnchor ~= holder or prevX ~= x or prevY ~= y or wasParked
  local needsAlpha = wasParked or (not alphaIsSecret and alpha ~= targetAlpha)

  fd.anchor = holder
  fd.posX = x
  fd.posY = y
  fd.sizeW = desiredSize
  fd.sizeH = desiredSize

  if needsSize or needsPoint or needsAlpha then
    fd.locking = true
    if needsSize and icon.SetSize then
      icon:SetSize(desiredSize, desiredSize)
    end
    if needsPoint and icon.ClearAllPoints and icon.SetPoint then
      icon:ClearAllPoints()
      icon:SetPoint("CENTER", holder, "CENTER", x, y)
    end
    if needsAlpha and icon.SetAlpha then
      icon:SetAlpha(targetAlpha)
    end
    fd.locking = false
  end

  fd.parked = nil
end

local function _GetBuffIconRowPlacement(iconCount, slotW, gap)
  if _rt_growth == "RIGHT" then
    return 0, 1
  elseif _rt_growth == "LEFT" then
    return 0, -1
  end

  local rowW = iconCount * slotW + (iconCount - 1) * gap
  return -rowW / 2 + slotW / 2, 1
end

local function _ApplyBuffIconLayout(viewer, holder, icons, padX, desiredSize, totalSlots)
  local visibleCount = #icons

  local gap = padX or 0
  local slotW = desiredSize
  local slotH = desiredSize

  if visibleCount > 0 then
    local first = icons[1]
    local actualW
    local actualH
    if first and first.GetWidth then
      actualW = first:GetWidth()
    end
    if first and first.GetHeight then
      actualH = first:GetHeight()
    end
    if IsSecret(actualW) then
      actualW = nil
    end
    if IsSecret(actualH) then
      actualH = nil
    end
    slotW = tonumber(actualW) or desiredSize
    slotH = tonumber(actualH) or desiredSize
  end

  if not slotW or slotW <= 0 or not slotH or slotH <= 0 then
    return false
  end

  local slots = tonumber(totalSlots) or visibleCount
  if slots < visibleCount then
    slots = visibleCount
  elseif slots < 0 then
    slots = 0
  end
  _rt_lastMoverTotal = slots

  local columns = tonumber(_rt_columns) or 0
  if columns < 0 then
    columns = 0
  end

  local holderW = 1
  local holderH = 1

  if slots > 0 then
    if columns > 0 then
      local widestRow = math.min(slots, columns)
      local rows = math.ceil(slots / columns)
      holderW = widestRow * slotW + (widestRow - 1) * gap
      holderH = rows * slotH + (rows - 1) * gap
    else
      holderW = slots * slotW + (slots - 1) * gap
      holderH = slotH
    end
  end

  if holder.__puiBuffCenterW ~= holderW or holder.__puiBuffCenterH ~= holderH then
    holder:SetSize(holderW, holderH)
    holder.__puiBuffCenterW = holderW
    holder.__puiBuffCenterH = holderH
    FrameUtil.RefreshSmartSnapRuntimeLayout(VIEWER_KEY)
  end

  if columns <= 0 then
    local startX, direction = _GetBuffIconRowPlacement(visibleCount, slotW, gap)

    for i = 1, visibleCount do
      local icon = icons[i]
      local x = startX + (i - 1) * (slotW + gap) * direction
      _PositionCenteredBuffIcon(icon, holder, desiredSize, x, 0)
    end

    _UpdateCenteredSnapshot(icons)
    return true
  end

  local rowCount = math.ceil(visibleCount / columns)
  local iconIndex = 1
  local topY = ((rowCount - 1) * (slotH + gap)) / 2

  for row = 1, rowCount do
    local remaining = visibleCount - iconIndex + 1
    local thisRowCount = math.min(columns, remaining)
    local startX, direction = _GetBuffIconRowPlacement(thisRowCount, slotW, gap)
    local y = topY - ((row - 1) * (slotH + gap))

    for col = 1, thisRowCount do
      local icon = icons[iconIndex]
      local x = startX + (col - 1) * (slotW + gap) * direction
      _PositionCenteredBuffIcon(icon, holder, desiredSize, x, y)
      iconIndex = iconIndex + 1
    end
  end

  _UpdateCenteredSnapshot(icons)
  return true
end

CenterVisibleBuffs = function(force)
  if PCMRuntime:IsPresentationSuspended() then
    pendingRecenter = true
    return
  end

  if Hooks.InBlizzardEditMode() then
    pendingRecenter = true
    return
  end

  local viewer = _cache.viewer or _GetViewer()
  if not viewer then
    return
  end
  if not _ViewerIsReady(viewer) then
    return
  end

  local holder, padX, desiredSize = _ResolveViewerAndContainer(viewer)
  if not holder then
    return
  end

  if _prepNeeded then
    _PrepareBuffIconsForViewer(viewer, desiredSize)
  end

  if (not force)
    and (not _centerForceLayout)
    and (not _centerListDirty)
    and (not _buffItemListDirty)
    and (not _centerVisibilityNeedsRebuild)
  then
    pendingRecenter = false
    return
  end

  local iconList = _GetViewerItemList(viewer)
  if _centerVisibilityNeedsRebuild then
    _RebuildVisibleBuffIcons(iconList)
  end

  local totalSlots = #iconList
  local visibleCount = #buffCenterBuffer
  local moverSizeChanged = totalSlots ~= _rt_lastMoverTotal

  if visibleCount == 0 then
    _ApplyBuffIconLayout(viewer, holder, buffCenterBuffer, padX, desiredSize, totalSlots)
    _centerForceLayout = false
    holder:Hide()
    _centerListDirty = false
    pendingRecenter = false
    return
  end

  holder:Show()

  if (not force)
    and (not _centerForceLayout)
    and (not moverSizeChanged)
    and _CenteredSnapshotMatches(buffCenterBuffer)
  then
    _centerListDirty = false
    pendingRecenter = false
    return
  end

  _centerForceLayout = false
  _ApplyBuffIconLayout(viewer, holder, buffCenterBuffer, padX, desiredSize, totalSlots)
  _centerListDirty = false
  pendingRecenter = false
end

_RequestUnifiedBuffRefresh = function(mode, viewer)
  if not _PCM_BuffsEnabled() then
    return
  end

  local v = viewer or _cache.viewer or _GetViewer()
  if viewer then
    _cache.viewer = viewer
  elseif v then
    _cache.viewer = v
  end

  local mask = PCMRuntime.Dirty.LAYOUT
  if mode == "icons" or mode == "all" then
    _prepNeeded = true
    _centerForceLayout = true
    mask = mask + PCMRuntime.Dirty.SKIN + PCMRuntime.Dirty.FONT
  elseif mode == "force" then
    _centerForceLayout = true
  elseif mode ~= "layout" then
    _MarkBuffItemListDirty(v)
    mask = mask + PCMRuntime.Dirty.ITEMS
  elseif (not _prepNeeded)
    and (not _centerForceLayout)
    and (not _centerListDirty)
    and (not _buffItemListDirty)
    and (not _centerVisibilityNeedsRebuild)
  then
    return
  end

  pendingRecenter = true
  PCMRuntime:MarkViewerDirty(VIEWER_KEY, mask, "buff-icons")
end



local function _Buffs_SavePosition(frame, key, db)
  if key ~= VIEWER_KEY then return false end
  if not (frame and frame.GetCenter and UIParent and UIParent.GetCenter) then return false end
  if not db then return false end

  local fx, fy = frame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if fx and fy and ux and uy then
    local absX = Round((fx - ux) or 0)
    local absY = Round((fy - uy) or 0)

    db[key] = {
      point    = "CENTER",
      rel      = "UIParent",
      relPoint = "CENTER",
      x        = absX,
      y        = absY,
    }
    return true
  end

  return false
end

local function _Buffs_NormalizeSavedAnchor(frame, key, db, pos)
  if key ~= VIEWER_KEY then return pos end
  if not (frame and frame.GetCenter and UIParent and UIParent.GetCenter) then return pos end
  if not (db and pos and pos.point) then return pos end

  if pos.point ~= "CENTER" then
    local fx, fy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if fx and fy and ux and uy then
      pos = {
        point    = "CENTER",
        rel      = "UIParent",
        relPoint = "CENTER",
        x        = Round((fx - ux) or 0),
        y        = Round((fy - uy) or 0),
      }
      db[key] = pos
    end
  end

  return pos
end

local function _Buffs_EnsureDefaultAnchor(key, db)
  if key ~= VIEWER_KEY then
    return nil
  end

  if not db then
    return nil
  end

  local cur = db[key]
  if cur and cur.point and cur.rel and cur.relPoint then
    return cur
  end

  db[key] = {
    point    = "CENTER",
    rel      = "UIParent",
    relPoint = "CENTER",
    x        = 0,
    y        = -180,
  }

  return db[key]
end

local function _ApplyViewerAnchorFromDB(viewer)
  if not viewer then
    return
  end

  local target = _EnsureBuffHolder()

  local anchorDB = ns.PCM_DBExports.GetProfileBuffsAnchorDB()
  local pos = anchorDB and anchorDB[VIEWER_KEY] or nil

  if not pos then
    pos = _Buffs_EnsureDefaultAnchor(VIEWER_KEY, anchorDB)
  end

  if not pos then
    return
  end

  pos = _Buffs_NormalizeSavedAnchor(viewer, VIEWER_KEY, anchorDB, pos)

  local x = tonumber(pos.x) or 0
  local y = tonumber(pos.y) or 0



  if target.__puiBuffAnchorX == x and target.__puiBuffAnchorY == y then
    return
  end

  target.__puiApplyingAnchor = true
  target:ClearAllPoints()
  target:SetPoint("CENTER", UIParent, "CENTER", x, y)
  target.__puiApplyingAnchor = nil
  target.__puiBuffAnchorX = x
  target.__puiBuffAnchorY = y

end

local function _RegisterBuffIconMover()
  if not _PCM_BuffsEnabled() then
    return
  end

  local viewer = _GetViewer()
  if not viewer then
    return
  end

  _InvalidateBuffsCache()

  local holder = _EnsureBuffHolder()

  _ApplyViewerAnchorFromDB(viewer)

  local function SavePosition()
    local anchorDB = ns.PCM_DBExports.GetProfileBuffsAnchorDB()
    if not anchorDB then
      return
    end

    _Buffs_SavePosition(holder, VIEWER_KEY, anchorDB)
    _ApplyViewerAnchorFromDB(viewer)
  end

  FrameUtil:RegisterMover(VIEWER_KEY, holder, {
    label = "Tracked Icons",
    optionsString = "CooldownManager,buff_icons",
    useOverlayDrag = true,
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
    },
    savePosition = SavePosition,
    resetPosition = function()
      local anchorDB = ns.PCM_DBExports.GetProfileBuffsAnchorDB()
      if anchorDB then
        anchorDB[VIEWER_KEY] = {
          point    = "CENTER",
          rel      = "UIParent",
          relPoint = "CENTER",
          x        = 0,
          y        = -180,
        }
      end

      _ApplyViewerAnchorFromDB(viewer)
    end,
    quickSettings = function()
      local cm = _GetBuffsDB()
      cm.style = cm.style or {}
      local style = cm.style
      style.viewerSizes = style.viewerSizes or {}
      style.viewerSpacing = style.viewerSpacing or {}

      local function Refresh()
        Buffs:_PrimeRuntimeFromDB()
      end

      return {
        ownerKey = VIEWER_KEY,
        title = "Tracked Icons",
        description = "Live Cooldown Manager settings.",
        controls = {
          {
            type = "slider",
            label = "Icon size",
            min = 12,
            max = 86,
            step = 1,
            get = function() return style.viewerSizes[VIEWER_KEY] or style.iconSize or 36 end,
            set = function(value)
              style.viewerSizes[VIEWER_KEY] = Round(value)
              Refresh()
            end,
          },
          {
            type = "slider",
            label = "Icon spacing",
            min = 0,
            max = 8,
            step = 1,
            get = function() return style.viewerSpacing[VIEWER_KEY] or style.iconSpacing or 2 end,
            set = function(value)
              style.viewerSpacing[VIEWER_KEY] = Round(value)
              Refresh()
            end,
          },
          {
            type = "toggle",
            label = "Show tooltips",
            get = function() return Cooldowns:GetViewerTooltipsEnabled(VIEWER_KEY) end,
            set = function(value)
              Cooldowns:SetViewerTooltipsEnabled(VIEWER_KEY, value)
              Cooldowns:FlushPendingEditModeChanges()
            end,
          },
          {
            type = "toggle",
            label = "Hide when inactive",
            get = function() return Cooldowns:GetViewerHideWhenInactive(VIEWER_KEY) end,
            set = function(value)
              Cooldowns:SetViewerHideWhenInactive(VIEWER_KEY, value)
              Cooldowns:FlushPendingEditModeChanges()
            end,
          },
        },
      }
    end,
  })
end


_Buffs_ApplyCentered = function(viewer)
  _RequestUnifiedBuffRefresh("force", viewer)
end

local function _Buffs_InitOnce()
  if not _PCM_BuffsEnabled() then
    return false
  end

  local viewer = _GetViewer()
  if not viewer or not _ViewerIsReady(viewer) then
    return false
  end

  if Buffs.__puiPCM_BuffsInited == viewer then
    return true
  end

  _RegisterBuffIconMover()

  _InvalidateBuffsCache()
  _cache.viewer = viewer
  _rt_scaleFn = Round
  _rt_fontDB = _GetViewerFontDB()

  local spacing, iconSize, columns, growth = _GetViewerStyleSizing()
  _rt_spacing = tonumber(spacing) or 1
  _rt_iconSize = tonumber(iconSize) or 36
  _rt_columns = tonumber(columns) or 0
  _rt_growth = growth or "CENTER"

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    _SkinAndParkBuffIcon(viewer, items[index])
  end

  _prepNeeded = true
  pendingRecenter = true

  Buffs.__puiPCM_BuffsInited = viewer
  Buffs:ApplySettings()

  return true
end

function Buffs:RetakeBlizzardEditModeOwnership()
  if not _PCM_BuffsEnabled() then
    return
  end

  local viewer = _cache.viewer or _GetViewer()
  if not viewer or not _ViewerIsReady(viewer) then
    return
  end

  _ApplyViewerAnchorFromDB(viewer)

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    _SkinAndParkBuffIcon(viewer, items[index])
  end

  _MarkBuffItemListDirty(viewer)
  _prepNeeded = true
  _centerForceLayout = true
  CenterVisibleBuffs(true)
end

function Buffs:OnInitialize()
  self:SetEnabledState(_PCM_BuffsEnabled())
end

function Buffs:_PrimeRuntimeFromDB()
  if not _PCM_BuffsEnabled() then
    return
  end

  _InvalidateBuffsCache()

  local oldScaleFn = _rt_scaleFn
  local oldFontDB = _rt_fontDB
  local oldSpacing = _rt_spacing
  local oldIconSize = _rt_iconSize

  _rt_scaleFn = Round
  _rt_fontDB = _GetViewerFontDB()
  local oldColumns = _rt_columns
  local oldGrowth = _rt_growth

  do
    local sp, sz, cols, growth = _GetViewerStyleSizing()
    _rt_spacing = tonumber(sp) or 1
    _rt_iconSize = tonumber(sz) or 36
    _rt_columns = tonumber(cols) or 0
    _rt_growth = growth or "CENTER"
  end

  if oldScaleFn ~= _rt_scaleFn
    or oldFontDB ~= _rt_fontDB
    or oldSpacing ~= _rt_spacing
    or oldIconSize ~= _rt_iconSize then
    _prepNeeded = true
  end

  if oldColumns ~= _rt_columns or oldGrowth ~= _rt_growth then
    _centerForceLayout = true
  end

  _RequestUnifiedBuffRefresh(_prepNeeded and "icons" or "layout")
end

function Buffs:_RebuildRuntimeFromDB(viewer)
  if not _PCM_BuffsEnabled() then
    return
  end

  self:_PrimeRuntimeFromDB()

  _cache.buffContainer = nil
  _MarkBuffItemListDirty(viewer or _cache.viewer or _GetViewer())

  local v = viewer or _cache.viewer or _GetViewer()
  if v and _ViewerIsReady(v) then
    _ApplyViewerAnchorFromDB(v)
  end

  _RequestUnifiedBuffRefresh("all", v)
end

function Buffs:_OnProfileChanged()
  self:ApplySettings({ profile = true })
  self:SoftRebuild({ profile = true, movers = true, layout = true })
end

function Buffs:OnEnable()
  if not _PCM_BuffsEnabled() then
    self:Disable()
    return
  end

  PCMRuntime:SetSubscriberEnabled("BuffIcons", true)
  _Buffs_InitOnce()
end

function Buffs:OnDisable()
  local viewer = _cache.viewer or _GetViewer()
  if viewer then
    local items = PCMRuntime:GetViewerItems(viewer)
    for index = 1, #items do
      Cooldowns:ClearNativeIndividualIconSettings(items[index], VIEWER_KEY)
    end
  end

  PCMRuntime:SetSubscriberEnabled("BuffIcons", false)
  Buffs.__puiPCM_BuffsInited = nil
  _cache.viewer = nil
  _prepNeeded = true
  _centerForceLayout = false
  _centerListDirty = true
  pendingRecenter = false
  _MarkBuffItemListDirty(nil)

  if buffHolder then
    buffHolder:Hide()
  end
end

function Buffs:PLAYER_REGEN_DISABLED()
  local viewer = _cache.viewer or _GetViewer()
  if viewer then
    _Buffs_ApplyCentered(viewer)
  end
end

function Buffs:ApplySettings(flags)
  if not _PCM_BuffsEnabled() then
    return
  end

  if flags and not (flags.profile == true or flags.layout == true or flags.movers == true or flags.fonts == true or flags.theme == true) then
    return
  end

  self:_PrimeRuntimeFromDB()

  if flags then
    if flags.profile == true then
      _styleRev = _styleRev + 1
      _fontRev = _fontRev + 1
      _prepNeeded = true
    else
      if flags.theme == true then
        _styleRev = _styleRev + 1
        _prepNeeded = true
      end

      if flags.fonts == true then
        _fontRev = _fontRev + 1
        _prepNeeded = true
      end
    end
  end

  local v = _cache.viewer or _GetViewer()
  if v and _ViewerIsReady(v) then
    _RequestUnifiedBuffRefresh((_prepNeeded and "icons") or "layout", v)
  end
end

function Buffs:SoftRebuild(flags)
  if not _PCM_BuffsEnabled() then
    return
  end

  if not flags then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    self:_RebuildRuntimeFromDB()
  end
end

function Buffs:ScheduleRecenter(viewer, itemFrame)
  if not _PCM_BuffsEnabled() then
    return
  end

  local v = viewer or _cache.viewer or _GetViewer()
  if viewer then
    _cache.viewer = viewer
  end

  if v and _cache.buffContainer ~= v:GetItemContainerFrame() then
    _cache.buffContainer = nil
    _prepNeeded = true
  end

  if itemFrame then
    _RefreshBuffIconVisibility(itemFrame)
  else
    _MarkBuffCenterDirty()
  end
  _RequestUnifiedBuffRefresh("layout", v)
end

function Buffs:RefreshAfterTalentSwap()
  if not _PCM_BuffsEnabled() then
    return
  end
  if PCMRuntime:IsPresentationSuspended() then
    _RequestUnifiedBuffRefresh("all")
    return
  end

  local viewer = _cache.viewer or _GetViewer()
  if not viewer or not _ViewerIsReady(viewer) then
    return
  end

  _styleRev = _styleRev + 1
  _fontRev = _fontRev + 1
  _cache.buffContainer = nil
  _MarkBuffItemListDirty(viewer)
  _prepNeeded = true

  _ApplyViewerAnchorFromDB(viewer)

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    Cooldowns:ClearNativeIndividualIconSettings(items[index], VIEWER_KEY)
    _SkinAndParkBuffIcon(viewer, items[index])
  end

  _RequestUnifiedBuffRefresh("all", viewer)
end

function Buffs:RefreshIndividualIconSettings()
  if not _PCM_BuffsEnabled() then
    return
  end
  if PCMRuntime:IsPresentationSuspended() then
    _fontRev = _fontRev + 1
    _prepNeeded = true
    _MarkBuffCenterDirty()
    _RequestUnifiedBuffRefresh("icons")
    return
  end

  local viewer = _cache.viewer or _GetViewer()
  if not viewer or not _ViewerIsReady(viewer) then
    return
  end

  _fontRev = _fontRev + 1
  _prepNeeded = true
  _MarkBuffCenterDirty()

  local fontDB = _rt_fontDB or _GetViewerFontDB()
  _rt_fontDB = fontDB
  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    local itemFrame = items[index]
    _ApplyLiveIconFonts(itemFrame, fontDB)
    Cooldowns:ApplyNativeIndividualIconSettings(itemFrame, VIEWER_KEY, "AURA")
  end

  _RequestUnifiedBuffRefresh("layout", viewer)
end

local function _ApplyBuffIconViewerDirty(key, viewer, mask, reason)
  if key ~= VIEWER_KEY or not _PCM_BuffsEnabled() then
    return
  end

  local dirtyMask = mask or 0
  if PCMRuntime:MaskHas(dirtyMask, PCMRuntime.Dirty.SKIN)
    or PCMRuntime:MaskHas(dirtyMask, PCMRuntime.Dirty.FONT)
  then
    _prepNeeded = true
    _centerForceLayout = true
  end

  if PCMRuntime:MaskHas(dirtyMask, PCMRuntime.Dirty.ITEMS) then
    _centerForceLayout = true
  end

  if reason == "viewer-layout" then
    _MarkBuffItemListDirty(viewer)
  end

  if PCMRuntime:MaskHas(dirtyMask, PCMRuntime.Dirty.VISIBILITY) then
    _MarkBuffCenterDirty()
  end

  CenterVisibleBuffs(false)
end

PCMRuntime:RegisterSubscriber("BuffIcons", {
  OnViewerChanged = function(key, viewer)
    if key ~= VIEWER_KEY then
      return
    end

    _cache.viewer = viewer
    _cache.readyViewer = nil
    _cache.viewerReady = nil
    _cache.buffContainer = nil
    Buffs.__puiPCM_BuffsInited = nil
    _MarkBuffItemListDirty(viewer)

    if viewer then
      _Buffs_InitOnce()
    end
  end,

  OnItemTracked = function(key, viewer, itemFrame)
    if key == VIEWER_KEY and _PCM_BuffsEnabled() then
      Cooldowns:ClearNativeIndividualIconSettings(itemFrame, VIEWER_KEY)
      _SkinAndParkBuffIcon(viewer, itemFrame)
      _AddBuffItem(viewer, itemFrame)
    end
  end,

  OnItemReleased = function(key, viewer, itemFrame)
    if key == VIEWER_KEY then
      Cooldowns:ClearNativeIndividualIconSettings(itemFrame, VIEWER_KEY)
      _RemoveBuffItem(itemFrame)
    end
  end,

  OnItemRebound = function(key, viewer, itemFrame)
    if key == VIEWER_KEY and _PCM_BuffsEnabled() then
      _RefreshReboundBuffIcon(viewer, itemFrame)
    end
  end,

  OnViewerDirty = _ApplyBuffIconViewerDirty,

  OnViewerTargetChanged = function(key, viewer)
    if key == VIEWER_KEY then
      _RequestUnifiedBuffRefresh("layout", viewer)
    end
  end,

  OnLifecycleEvent = function(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
      _Buffs_InitOnce()
    elseif event == "PLAYER_REGEN_DISABLED" then
      Buffs:PLAYER_REGEN_DISABLED()
    end
  end,
})

  _PCM_BuffsEnabled = P:Def('_PCM_BuffsEnabled', _PCM_BuffsEnabled)
  _InvalidateBuffsCache = P:Def('_InvalidateBuffsCache', _InvalidateBuffsCache)
  _GetBuffsDB = P:Def('_GetBuffsDB', _GetBuffsDB)
  _GetViewerFontDB = P:Def('_GetViewerFontDB', _GetViewerFontDB)
  _GetViewer = P:Def('_GetViewer', _GetViewer)
  _ViewerIsReady = P:Def('_ViewerIsReady', _ViewerIsReady)
  _EnsureBuffHolder = P:Def('_EnsureBuffHolder', _EnsureBuffHolder)
  _GetStableBuffIconID = P:Def('_GetStableBuffIconID', _GetStableBuffIconID)
  _SortByLayoutIndex = P:Def('_SortByLayoutIndex', _SortByLayoutIndex)
  _IsIconFrame = P:Def('_IsIconFrame', _IsIconFrame)
  _GetViewerItemList = P:Def('_GetViewerItemList', _GetViewerItemList)
  _PrepareBuffIcon = P:Def('_PrepareBuffIcon', _PrepareBuffIcon)
  _PrepareBuffIcons = P:Def('_PrepareBuffIcons', _PrepareBuffIcons)
  _GetViewerStyleSizing = P:Def('_GetViewerStyleSizing', _GetViewerStyleSizing)
  _ApplyManualHiddenState = P:Def('_ApplyManualHiddenState', _ApplyManualHiddenState)
  _PrepareBuffIconsForViewer = P:Def('_PrepareBuffIconsForViewer', _PrepareBuffIconsForViewer)
  _SkinAndParkBuffIcon = P:Def('_SkinAndParkBuffIcon', _SkinAndParkBuffIcon)
  _RefreshReboundBuffIcon = P:Def('_RefreshReboundBuffIcon', _RefreshReboundBuffIcon)
  _ResolveViewerAndContainer = P:Def('_ResolveViewerAndContainer', _ResolveViewerAndContainer)
  _AddBuffItem = P:Def('_AddBuffItem', _AddBuffItem)
  _RemoveBuffItem = P:Def('_RemoveBuffItem', _RemoveBuffItem)
  _RefreshBuffIconVisibility = P:Def('_RefreshBuffIconVisibility', _RefreshBuffIconVisibility)
  _RebuildVisibleBuffIcons = P:Def('_RebuildVisibleBuffIcons', _RebuildVisibleBuffIcons)
  _CenteredSnapshotMatches = P:Def('_CenteredSnapshotMatches', _CenteredSnapshotMatches)
  _UpdateCenteredSnapshot = P:Def('_UpdateCenteredSnapshot', _UpdateCenteredSnapshot)
  _PositionCenteredBuffIcon = P:Def('_PositionCenteredBuffIcon', _PositionCenteredBuffIcon)
  _GetBuffIconRowPlacement = P:Def('_GetBuffIconRowPlacement', _GetBuffIconRowPlacement)
  _ApplyBuffIconLayout = P:Def('_ApplyBuffIconLayout', _ApplyBuffIconLayout)
  _Buffs_SavePosition = P:Def('_Buffs_SavePosition', _Buffs_SavePosition)
  _Buffs_NormalizeSavedAnchor = P:Def('_Buffs_NormalizeSavedAnchor', _Buffs_NormalizeSavedAnchor)
  _Buffs_EnsureDefaultAnchor = P:Def('_Buffs_EnsureDefaultAnchor', _Buffs_EnsureDefaultAnchor)
  _ApplyViewerAnchorFromDB = P:Def('_ApplyViewerAnchorFromDB', _ApplyViewerAnchorFromDB)
  _RegisterBuffIconMover = P:Def('_RegisterBuffIconMover', _RegisterBuffIconMover)
  _Buffs_InitOnce = P:Def('_Buffs_InitOnce', _Buffs_InitOnce)
  Buffs.RetakeBlizzardEditModeOwnership = P:Def('Buffs:RetakeBlizzardEditModeOwnership', Buffs.RetakeBlizzardEditModeOwnership)
  Buffs.OnInitialize = P:Def('Buffs:OnInitialize', Buffs.OnInitialize)
  Buffs._PrimeRuntimeFromDB = P:Def('Buffs:_PrimeRuntimeFromDB', Buffs._PrimeRuntimeFromDB)
  Buffs._RebuildRuntimeFromDB = P:Def('Buffs:_RebuildRuntimeFromDB', Buffs._RebuildRuntimeFromDB)
  Buffs._OnProfileChanged = P:Def('Buffs:_OnProfileChanged', Buffs._OnProfileChanged)
  Buffs.OnEnable = P:Def('Buffs:OnEnable', Buffs.OnEnable)
  Buffs.OnDisable = P:Def('Buffs:OnDisable', Buffs.OnDisable)
  Buffs.PLAYER_REGEN_DISABLED = P:Def('Buffs:PLAYER_REGEN_DISABLED', Buffs.PLAYER_REGEN_DISABLED)
  Buffs.ApplySettings = P:Def('Buffs:ApplySettings', Buffs.ApplySettings)
  Buffs.RefreshIndividualIconSettings = P:Def('Buffs:RefreshIndividualIconSettings', Buffs.RefreshIndividualIconSettings)
  Buffs.SoftRebuild = P:Def('Buffs:SoftRebuild', Buffs.SoftRebuild)
  Buffs.ScheduleRecenter = P:Def('Buffs:ScheduleRecenter', Buffs.ScheduleRecenter)
  Buffs.RefreshAfterTalentSwap = P:Def('Buffs:RefreshAfterTalentSwap', Buffs.RefreshAfterTalentSwap)
  _MarkBuffCenterDirty = P:Def('_MarkBuffCenterDirty', _MarkBuffCenterDirty)
  _MarkBuffItemListDirty = P:Def('_MarkBuffItemListDirty', _MarkBuffItemListDirty)
  _BuffIconIsCenterVisible = P:Def('_BuffIconIsCenterVisible', _BuffIconIsCenterVisible)
  _ApplyLiveIconFonts = P:Def('_ApplyLiveIconFonts', _ApplyLiveIconFonts)
  CenterVisibleBuffs = P:Def('CenterVisibleBuffs', CenterVisibleBuffs)
  _RequestUnifiedBuffRefresh = P:Def('_RequestUnifiedBuffRefresh', _RequestUnifiedBuffRefresh)
  _GetLayoutSortKey = P:Def('_GetLayoutSortKey', _GetLayoutSortKey)
  _ApplyBuffIconViewerDirty = P:Def('_ApplyBuffIconViewerDirty', _ApplyBuffIconViewerDirty)

