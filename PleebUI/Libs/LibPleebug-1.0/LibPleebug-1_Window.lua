
local LibStub = _G.LibStub
if not LibStub then return end
local Pleebug, minor = LibStub("LibPleebug-1", true)
-- Components must match the core selected by LibStub across bundled copies.
if not Pleebug or minor ~= 11 then return end

-- Backwards-compatible alias (rest of file can keep using MemDebug)
local MemDebug = Pleebug

local W = MemDebug.Window or {}
MemDebug.Window = W


local _wipe = _G.wipe or (table and table.wipe) or function(t)
  if not t then return end
  for k in pairs(t) do
    t[k] = nil
  end
end



W.frame = W.frame or nil
W.rows = W.rows or {}
W.expanded = W.expanded or {}
local displaySettings = MemDebug:GetDB()
if type(displaySettings.showRowsWithNoCalls) ~= "boolean" then
  displaySettings.showRowsWithNoCalls = false
end

local function _showRowsWithNoCalls()
  return displaySettings.showRowsWithNoCalls == true
end

local SORT_LABELS = { total = "Total time", average = "Average", peak = "Peak", calls = "Calls", name = "Name" }
if not SORT_LABELS[displaySettings.sortBy] then displaySettings.sortBy = "total" end
if type(displaySettings.sortDescending) ~= "boolean" then displaySettings.sortDescending = true end
if type(displaySettings.showAllocations) ~= "boolean" then displaySettings.showAllocations = false end
W.searchText = W.searchText or ""
W._sortVersion = W._sortVersion or 0

local function _rowVisible(node, showRowsWithNoCalls)
  return node.matchesSearch ~= false
    and ((node.kind == "addon" and node.registered and not node.synthetic) or showRowsWithNoCalls or node.hasCalls)
end

local function _updateSearch(node, inherited)
  local matches = inherited or W.searchText == ""
    or (node.path ~= "" and (node.name .. " " .. node.path):lower():find(W.searchText, 1, true) ~= nil)
  local descendant = false
  for _, child in pairs(node.children) do
    if _updateSearch(child, matches) then descendant = true end
  end
  node.matchesSearch = matches or descendant
  return node.matchesSearch
end

function W:SetSearch(text)
  self.searchText = tostring(text or ""):lower():match("^%s*(.-)%s*$")
  if self.frame then self.frame._scroll:SetVerticalScroll(0) end
  self:Refresh()
end

function W:SetSort(key)
  if not SORT_LABELS[key] then return end
  if displaySettings.sortBy == key then
    displaySettings.sortDescending = not displaySettings.sortDescending
  else
    displaySettings.sortBy = key
    displaySettings.sortDescending = key ~= "name"
  end
  self:Resort()
end

function W:Resort()
  self._sortVersion = self._sortVersion + 1
  self:Refresh()
end

local function _updateRowActivity(node, cpu)
  local hasCalls = (node.count or 0) > 0
  if node.statKey then
    local stat = cpu:GetStat(node.statKey)
    hasCalls = hasCalls or (stat and stat.n and stat.n > 0) or false
  end
  for _, child in pairs(node.children) do
    if _updateRowActivity(child, cpu) then hasCalls = true end
  end
  node.hasCalls = hasCalls
  return hasCalls
end

-- UI tuning (dev window only)
W.uiScale = W.uiScale or 1.25     -- increase for readability/clicking
W.fontSize = W.fontSize or (MemDebug.GetFontSize and MemDebug:GetFontSize()) or 14
W.titleFontSize = W.titleFontSize or 18
local function _nowPrecise()
  if GetTimePreciseSec then
    return GetTimePreciseSec()
  end
  return (GetTime and GetTime()) or 0
end

-- Hard rule for this dev window:
-- No host-theme dependencies. Library provides a small internal palette.
local function _getPalette()
  -- Defaults: square, dark, readable, accent highlight
  local accent = { 0.20, 0.60, 1.00, 1.00 }
  local border = { 0.20, 0.20, 0.20, 1.00 }
  local text   = { 1.00, 1.00, 1.00, 1.00 }
  local bgWin  = { 0.00, 0.00, 0.00, 0.88 }
  local bgPane = { 0.00, 0.00, 0.00, 0.35 }

  if MemDebug and type(MemDebug.GetThemeColors) == "function" then
    local a, b, t, w, p = MemDebug:GetThemeColors()
    if type(a) == "table" then accent = a end
    if type(b) == "table" then border = b end
    if type(t) == "table" then text = t end
    if type(w) == "table" then bgWin = w end
    if type(p) == "table" then bgPane = p end
  end

  return accent, border, text, bgWin, bgPane
end

local function _applyFontSafe(fs, size, flags)
  if not fs or not fs.SetFont then return end
  size = tonumber(size) or 12
  size = math.floor(size * (W.uiScale or 1) + 0.5)
  flags = flags or ""

  local path = fs.GetFont and select(1, fs:GetFont()) or nil
  if not path or path == "" then
    path = (STANDARD_TEXT_FONT and STANDARD_TEXT_FONT ~= "" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
  end
  fs:SetFont(path, size, flags)
end

local function _colorText(fs)
  if not fs or not fs.SetTextColor then return end
  local _, _, t = _getPalette()
  fs:SetTextColor(t[1], t[2], t[3], t[4] or 1)
end


local function _sortValue(node)
  local stat = node.statKey and MemDebug.CPU:GetStat(node.statKey)
  if displaySettings.sortBy == "calls" then return stat and stat.n or node.count or 0 end
  if not stat or not stat.n or stat.n == 0 then return 0 end
  if displaySettings.sortBy == "average" then return (stat.timeSum or 0) / stat.n end
  if displaySettings.sortBy == "peak" then return stat.timeMax or 0 end
  return stat.timeSum or 0
end

local function _compareNodes(parent, a, b)
  if parent.path == "" then
    local aOrder = MemDebug:GetAddonSortOrder(a.key)
    local bOrder = MemDebug:GetAddonSortOrder(b.key)
    if aOrder ~= bOrder then return aOrder < bOrder end
  elseif displaySettings.sortBy == "calls" or (displaySettings.sortBy ~= "name" and a.statKey and b.statKey) then
    local av, bv = _sortValue(a), _sortValue(b)
    if av ~= bv then
      if displaySettings.sortDescending then return av > bv end
      return av < bv
    end
  end
  if a.name ~= b.name then
    if parent.path ~= "" and displaySettings.sortBy == "name" and displaySettings.sortDescending then
      return a.name > b.name
    end
    return a.name < b.name
  end
  return a.key < b.key
end

local function _sortedChildList(node, showRowsWithNoCalls)
  local order = node._orderedChildren
  local live = MemDebug:IsEnabled()
  if not order or not live or node._sortVersion ~= W._sortVersion then
    order = {}
    for _, child in pairs(node.children) do order[#order + 1] = child end
    table.sort(order, function(a, b) return _compareNodes(node, a, b) end)
    node._orderedChildren = order
    node._sortVersion = W._sortVersion
    node._orderDirty = nil
  elseif node._orderDirty then
    local known, added = {}, {}
    for i = 1, #order do known[order[i].key] = true end
    for key, child in pairs(node.children) do
      if not known[key] then added[#added + 1] = child end
    end
    table.sort(added, function(a, b) return _compareNodes(node, a, b) end)
    for i = 1, #added do order[#order + 1] = added[i] end
    node._orderDirty = nil
  end
  local list = {}
  for i = 1, #order do
    local child = order[i]
    child.orderIndex = i
    if _rowVisible(child, showRowsWithNoCalls) then list[#list + 1] = child end
  end
  return list
end

local function _flatten(node, out, depth, expanded, showRowsWithNoCalls)
  depth = depth or 0
  out = out or {}

  if node.path ~= "" then
    if not _rowVisible(node, showRowsWithNoCalls) then return out end
    out[#out + 1] = { node = node, depth = depth }
  end

  local hasChildren = node.children and next(node.children) ~= nil
  if not hasChildren then
    return out
  end

  if node.path == "" or not expanded or expanded[node.path] or W.searchText ~= "" then
    local kids = _sortedChildList(node, showRowsWithNoCalls)
    for i = 1, #kids do
      _flatten(kids[i], out, depth + 1, expanded, showRowsWithNoCalls)
    end
  end

  return out
end
-- Deferred tree building (prevents /pleebug freeze on large snapshots)
W._buildInProgress = W._buildInProgress or false
W._buildIterKey = W._buildIterKey or nil
W._buildRoot = W._buildRoot or nil
W._pendingSnapshot = W._pendingSnapshot or nil
W._pendingInterval = W._pendingInterval or nil
W._pendingEnabled = W._pendingEnabled or nil
W._pendingLiveMode = W._pendingLiveMode or nil

W._flat = W._flat or {}
W._treeIndex = W._treeIndex or nil
W._countedNodes = W._countedNodes or {}
W._countedNodeSet = W._countedNodeSet or {}
W._builtRegistrationVersion = W._builtRegistrationVersion or nil

local function _treeEnsureChild(parent, key, name, path, index, kind)
  local child = parent.children[key]
  if not child then
    child = { key = key, name = name, path = path, kind = kind,
      count = 0, children = {}, parent = parent }
    parent.children[key] = child
    parent._orderDirty = true
    local root = parent
    while root.parent do root = root.parent end
    root._searchDirty = true
    index[path] = child
  end
  return child
end

local function _seedRegisteredAddons(root, index)
  for addonName in pairs(MemDebug:GetRegisteredAddons()) do
    local addon = _treeEnsureChild(root, addonName,
      MemDebug:GetAddonDisplayName(addonName), addonName, index, "addon")
    addon.loaded = C_AddOns.IsAddOnLoaded(addonName)
    addon.registered = true
  end
end

local function _treeEnsureMetric(root, index, sourcePath)
  if type(sourcePath) ~= "string" or sourcePath == "" then return nil end

  local moduleName, functionName = sourcePath:match("^Funcs%.([^.]+)%.(.+)$")
  local owner, bucketName, leafName, kind, statKey
  if moduleName then
    owner = MemDebug:GetModuleAddon(moduleName) or "Unattributed"
    bucketName = MemDebug:GetProfilerBucketName(moduleName)
    leafName = functionName
    kind = "function"
    statKey = moduleName .. "." .. functionName
  else
    local eventName = sourcePath:match("^Events%.Global%.(.+)$")
    if not eventName then return nil end
    owner = "Pleebug"
    moduleName = "GlobalEvents"
    bucketName = "Global Events (not addon-owned)"
    leafName = eventName
    kind = "event"
    statKey = sourcePath
  end

  local ownerNode = _treeEnsureChild(root, owner,
    MemDebug:GetAddonDisplayName(owner), owner, index, "addon")
  if kind == "event" then ownerNode.synthetic = true end
  local bucketPath = owner .. "." .. moduleName
  local bucketNode = _treeEnsureChild(ownerNode, moduleName,
    bucketName, bucketPath, index, "bucket")
  local leafPath = bucketPath .. "." .. leafName
  local leaf = _treeEnsureChild(bucketNode, leafName,
    leafName, leafPath, index, kind)
  leaf.statKey = statKey
  index[sourcePath] = leaf
  return leaf
end

local function _applyTreeSnapshot(root, index, snapshot, countedNodes, countedNodeSet)
  for i = 1, #countedNodes do
    local node = countedNodes[i]
    node.count = 0
    countedNodeSet[node] = nil
    countedNodes[i] = nil
  end

  if not (root and index and type(snapshot) == "table") then
    return
  end

  local function addCount(node, value)
    while node do
      if not countedNodeSet[node] then
        countedNodeSet[node] = true
        countedNodes[#countedNodes + 1] = node
        node.count = value
      else
        node.count = (node.count or 0) + value
      end
      node = node.parent
    end
  end

  for key, value in pairs(snapshot) do
    if type(key) == "string" and not key:match("^__")
      and key ~= "Funcs.Total" and key ~= "Events.Total"
      and type(value) == "number" and value > 0
    then
      local node = index[key]
      if not node then
        node = _treeEnsureMetric(root, index, key)
      end
      if node then
        addCount(node, value)
      end
    end
  end

end

local function _updateGroupSelections(root)
  for _, addon in pairs(root.children) do addon.fileCount = 0; addon.selectedFiles = 0 end
  local db = MemDebug:GetDB()
  for moduleName, known in pairs(db.knownModules) do
    local addon = known and root.children[db.moduleAddon[moduleName]]
    if addon then
      addon.fileCount = addon.fileCount + 1
      if db.modules[moduleName] ~= false then addon.selectedFiles = addon.selectedFiles + 1 end
    end
  end
  root._selectionVersion = MemDebug._selectionVersion or 0
end

function W:_ApplySnapshot(snapshot)
  _applyTreeSnapshot(self._buildRoot, self._treeIndex, snapshot, self._countedNodes, self._countedNodeSet)
  if not self._buildRoot then return end
  _updateRowActivity(self._buildRoot, MemDebug.CPU)
  if self._buildRoot._selectionVersion ~= (MemDebug._selectionVersion or 0) then
    _updateGroupSelections(self._buildRoot)
  end
  if self._buildRoot._searchDirty or self._buildRoot._searchText ~= self.searchText then
    _updateSearch(self._buildRoot, false)
    self._buildRoot._searchDirty = nil
    self._buildRoot._searchText = self.searchText
  end
  _wipe(self._flat)
  _flatten(self._buildRoot, self._flat, 0, self.expanded, _showRowsWithNoCalls())
end

local function _setAllBranches(node, expanded)
  for _, child in pairs(node.children or {}) do
    if child.kind == "addon" or child.kind == "bucket" then
      W.expanded[child.path] = expanded and true or nil
    end
    _setAllBranches(child, expanded)
  end
end

function W:SetAllExpanded(expanded)
  if self._buildInProgress or not self._buildRoot then
    self._expandAfterBuild = expanded and true or false
    return
  end
  _setAllBranches(self._buildRoot, expanded)
  self:_ApplySnapshot(self._pendingSnapshot or self.lastSnapshot or {})
  self:_RenderFlat()
end

function W:AreAddonChildrenExpanded(node)
  if not node or node.kind ~= "addon" then return false end
  local found = false
  for _, bucket in pairs(node.children or {}) do
    if bucket.children and next(bucket.children) then
      found = true
      if not self.expanded[bucket.path] then return false end
    end
  end
  return found
end

function W:SetAddonChildrenExpanded(node, expanded)
  if not node or node.kind ~= "addon" then return end
  self.expanded[node.path] = true
  for _, bucket in pairs(node.children or {}) do
    if bucket.children and next(bucket.children) then
      self.expanded[bucket.path] = expanded and true or nil
    end
  end
  self:_ApplySnapshot(self._pendingSnapshot or self.lastSnapshot or {})
  self:_RenderFlat()
end

function W:_FilterExportText(text)
  local lines, entries, parents = {}, {}, {}
  local root = { children = {}, name = "", path = "" }
  parents[0] = root
  for line in text:gmatch("[^\n]+") do
    if #lines == 0 then
      lines[1] = line
    else
      local path, name, depth, calls = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
      depth = tonumber(depth)
      local parent = parents[depth - 1]
      local entry = {
        path = path, name = name, parent = parent, children = {}, line = line,
        kind = depth == 1 and "addon" or depth == 2 and "bucket" or "function",
        registered = depth == 1 and MemDebug:GetRegisteredAddons()[path] ~= nil,
        synthetic = self._treeIndex and self._treeIndex[path] and self._treeIndex[path].synthetic,
        hasCalls = (tonumber(calls) or 0) > 0,
        sourceOrder = #entries + 1,
      }
      parent.children[#parent.children + 1] = entry
      parents[depth] = entry
      entries[#entries + 1] = entry
      if entry.hasCalls then
        local ancestor = parent
        while ancestor and not ancestor.hasCalls do
          ancestor.hasCalls = true
          ancestor = ancestor.parent
        end
      end
    end
  end
  _updateSearch(root, false)
  local function append(parent)
    table.sort(parent.children, function(a, b)
      local an = W._treeIndex and W._treeIndex[a.path]
      local bn = W._treeIndex and W._treeIndex[b.path]
      local av = an and an.orderIndex or a.sourceOrder
      local bv = bn and bn.orderIndex or b.sourceOrder
      if av == bv then return a.path < b.path end
      return av < bv
    end)
    for _, entry in ipairs(parent.children) do
      if _rowVisible(entry, _showRowsWithNoCalls()) then
        lines[#lines + 1] = entry.line
        if W.searchText ~= "" or W.expanded[entry.path] then append(entry) end
      end
    end
  end
  append(root)
  return table.concat(lines, "\n")
end

function W:_BuildExportRows(snapshot)
  local root = { name = "root", path = "", count = 0, children = {} }
  local index = {}
  _seedRegisteredAddons(root, index)
  local cpu = MemDebug.CPU
  local registeredFunctions = cpu and cpu._nativeFuncs or {}
  local registeredEvents = cpu and cpu._nativeEvents or {}

  for path in pairs(registeredFunctions) do
    _treeEnsureMetric(root, index, "Funcs." .. path)
  end
  for eventName in pairs(registeredEvents) do
    _treeEnsureMetric(root, index, "Events.Global." .. eventName)
  end
  _applyTreeSnapshot(root, index, snapshot, {}, {})
  _updateRowActivity(root, cpu)
  _updateGroupSelections(root)
  return _flatten(root, {}, 0, nil, true)
end

-- Safe deferral: never use C_Timer.After(0) (can spinlock WoW)
local function _Defer(fn)
  if not fn then return end
  C_Timer.After(0.01, fn)
end


function W:_StartDeferredBuild(snapshot)
  self._pendingSnapshot = snapshot or {}
  self._previousTreeIndex = self._treeIndex
  self._previousRoot = self._buildRoot
  self._buildRoot = { name = "root", path = "", count = 0, children = {} }
  self._treeIndex = {}
  _seedRegisteredAddons(self._buildRoot, self._treeIndex)
  self._countedNodes = {}
  self._countedNodeSet = {}
  self._buildRegistrationKey = nil
  self._buildEventKey = nil
  self._buildPhase = "functions"
  self._buildInProgress = true

  local cpu = MemDebug and MemDebug.CPU
  self._buildingRegistrationVersion = cpu and cpu._registrationVersion or 0
  self._buildingAddonRegistrationVersion = MemDebug._addonRegistrationVersion

  if C_Timer and C_Timer.After then
    _Defer(function()
      if W and W._BuildDeferredStep then
        W:_BuildDeferredStep()
      end
    end)
  else
    self:_BuildDeferredStep()
  end
end

function W:_BuildDeferredStep()
  if not self._buildInProgress then return end
  local snap = self._pendingSnapshot
  if type(snap) ~= "table" then
    self._buildInProgress = false
    return
  end

  local root = self._buildRoot
  if not root then
    self._buildInProgress = false
    return
  end

  local startMs = (debugprofilestop and debugprofilestop()) or nil
  local budgetMs = 6
  local cpu = MemDebug and MemDebug.CPU
  local registeredFunctions = cpu and cpu._nativeFuncs or {}
  local registeredEvents = cpu and cpu._nativeEvents or {}

  while true do
    if self._buildPhase == "functions" then
      local path = next(registeredFunctions, self._buildRegistrationKey)
      if path then
        self._buildRegistrationKey = path
        _treeEnsureMetric(root, self._treeIndex, "Funcs." .. tostring(path))
      else
        self._buildPhase = "events"
      end
    elseif self._buildPhase == "events" then
      local eventName = next(registeredEvents, self._buildEventKey)
      if eventName then
        self._buildEventKey = eventName
        _treeEnsureMetric(root, self._treeIndex, "Events.Global." .. tostring(eventName))
      else
        self._buildPhase = "complete"
      end
    else
      self._buildInProgress = false
      self._builtRegistrationVersion = self._buildingRegistrationVersion
      self._builtAddonRegistrationVersion = self._buildingAddonRegistrationVersion
      self._buildingRegistrationVersion = nil
      self._buildingAddonRegistrationVersion = nil
      if self._expandAfterBuild ~= nil then
        _setAllBranches(self._buildRoot, self._expandAfterBuild)
        self._expandAfterBuild = nil
      end
      if MemDebug:IsEnabled() and self._previousTreeIndex then
        local function inheritOrder(node)
          local previous = node.path == "" and self._previousRoot or self._previousTreeIndex[node.path]
          if previous and previous._orderedChildren then
            node._orderedChildren = {}
            for _, child in ipairs(previous._orderedChildren) do
              local replacement = node.children[child.key]
              if replacement then node._orderedChildren[#node._orderedChildren + 1] = replacement end
            end
            node._sortVersion = previous._sortVersion
            node._orderDirty = true
          end
          for _, child in pairs(node.children) do inheritOrder(child) end
        end
        inheritOrder(self._buildRoot)
      end
      self._previousTreeIndex = nil
      self._previousRoot = nil
      self:_ApplySnapshot(snap)
      self:_RenderFlat()
      self:_RenderSummary()
      return
    end

    if startMs and (debugprofilestop() - startMs) >= budgetMs then
      break
    end
  end

  if C_Timer and C_Timer.After then
    _Defer(function()
      if W and W._BuildDeferredStep then
        W:_BuildDeferredStep()
      end
    end)
  end
end

local _ensureRow

local function _nodeState(node)
  local addon = node.kind == "addon" and node or node.kind == "bucket" and node.parent
    or node.parent and node.parent.parent
  if addon and not addon.synthetic and addon.loaded == false then return "Addon not loaded" end
  if not MemDebug:IsDebuggingEnabled() then return "Debugging disabled" end
  if node.kind == "addon" and not node.synthetic then
    if (node.fileCount or 0) > 0 and node.selectedFiles == 0 then return "Excluded from tracking" end
  elseif node.kind == "bucket" and not MemDebug:IsModuleEnabled(node.key) then
    return "Excluded from tracking"
  elseif node.kind == "function" then
    local rec, alias = MemDebug.CPU:GetFunctionRegistration(node.statKey)
    if alias and not MemDebug:IsModuleEnabled(alias.moduleName) then return "Excluded from tracking" end
    if MemDebug:GetLoadMode() == "full" and alias and alias.kind ~= "wrapped" then
      local measured = false
      for _, other in pairs(rec.aliases) do
        if other.kind == "wrapped" then measured = true; break end
      end
      if not measured then return "Unwrapped function" end
    end
  end
  if node.kind == "addon" or node.kind == "bucket" then
    if not next(node.children) then return "No registered functions" end
  end
  if not node.hasCalls then return "No calls in this window" end
end

local COLUMNS = {
  { key = "calls", title = "Calls", width = 110 },
  { key = "total", title = "Total ms", width = 100 },
  { key = "average", title = "Avg ms", width = 100 },
  { key = "peak", title = "Peak ms", width = 110 },
  { key = "allocation", title = "Alloc KiB", width = 120 },
}

function W:_LayoutColumns()
  local f = self.frame
  f._sortText:SetText("Sort: " .. SORT_LABELS[displaySettings.sortBy] .. (MemDebug:IsEnabled() and " (held)" or ""))
  local layoutKey = tostring(self.fontSize) .. ":" .. tostring(displaySettings.showAllocations)
    .. ":" .. displaySettings.sortBy .. ":" .. tostring(displaySettings.sortDescending) .. ":" .. MemDebug:GetLoadMode()
  if self._layoutKey == layoutKey then return end
  self._layoutKey = layoutKey
  local scale = math.max(1, (self.fontSize or 14) / 14)
  local right = 8
  self._columnLayout = {}
  for i = #COLUMNS, 1, -1 do
    local column = COLUMNS[i]
    local visible = column.key ~= "allocation" or displaySettings.showAllocations
    local width = math.ceil(column.width * scale)
    self._columnLayout[column.key] = { right = right, width = width, visible = visible }
    if visible then right = right + width + 8 end
  end
  self._metricWidth = right
  self.rowHeight = math.max(28, math.ceil((self.fontSize or 14) * self.uiScale) + 10)
  local minimumWidth = math.ceil(right + 420 * scale)
  f:SetResizeBounds(minimumWidth, 620, math.max(1800, minimumWidth), 1200)
  if f:GetWidth() < minimumWidth then f:SetWidth(minimumWidth) end
  f._listHeader:SetHeight(self.rowHeight)
  for _, column in ipairs(COLUMNS) do
    local cell = f._listHeader.cells[column.key]
    local layout = self._columnLayout[column.key]
    cell:ClearAllPoints()
    cell:SetPoint("RIGHT", f._listHeader, "RIGHT", -layout.right, 0)
    cell:SetSize(layout.width, self.rowHeight)
    cell:SetShown(layout.visible)
    local label = column.title
    if column.key == "peak" and MemDebug:GetLoadMode() == "light" then label = "Sample ms" end
    if displaySettings.sortBy == column.key then
      label = label .. (displaySettings.sortDescending and " v" or " ^")
    end
    cell.text:SetText(label)
    _applyFontSafe(cell.text, math.max(12, (self.fontSize or 14) - 1))
  end
  local name = f._listHeader.nameButton
  name:ClearAllPoints()
  name:SetPoint("LEFT", f._listHeader, "LEFT", 6, 0)
  name:SetPoint("RIGHT", f._listHeader, "RIGHT", -right - 6, 0)
  name:SetHeight(self.rowHeight)
  name.text:SetText("Operation" .. (displaySettings.sortBy == "name" and (displaySettings.sortDescending and " v" or " ^") or ""))
  _applyFontSafe(name.text, math.max(12, (self.fontSize or 14) - 1))
end

function W:_RenderFlat()
  local f = self.frame
  if not f or not f:IsShown() or self._rendering then return end
  self._rendering = true
  self:_LayoutColumns()
  local flat = self._flat or {}
  local cpu = MemDebug.CPU
  local rowH = self.rowHeight
  local parent = f._content
  parent:SetHeight((#flat + 1) * rowH)
  local scroll = f._scroll
  local offset = scroll:GetVerticalScroll()
  local maxOffset = math.max(0, (#flat + 1) * rowH - scroll:GetHeight())
  if offset > maxOffset then offset = maxOffset; scroll:SetVerticalScroll(offset) end
  local firstIndex = math.max(1, math.floor(offset / rowH) + 1)
  local capacity = math.ceil(scroll:GetHeight() / rowH) + 3
  local visibleCount = math.min(capacity, math.max(0, #flat - firstIndex + 1))
  for rowIndex = 1, visibleCount do
    local i = firstIndex + rowIndex - 1
    local entry = flat[i]
    local node = entry.node
    local row = _ensureRow(rowIndex)
    row._data = entry
    row:Show()
    row:SetHeight(rowH)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2 - (i - 1) * rowH)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -2 - (i - 1) * rowH)
    if node.kind == "addon" then row.BG:SetColorTexture(0.10, 0.20, 0.28, 0.95)
    elseif node.kind == "bucket" then row.BG:SetColorTexture(0.13, 0.14, 0.17, 0.9)
    else row.BG:SetColorTexture(0.08, 0.08, 0.09, i % 2 == 0 and 0.65 or 0.35) end
    local indent = 8 + math.max(0, entry.depth - 1) * 20
    local expandable = node.kind == "addon" or node.kind == "bucket"
    row.chevron:ClearAllPoints()
    row.chevron:SetPoint("LEFT", row, "LEFT", indent, 0)
    row.chevron:SetText(expandable and (self.searchText ~= "" or self.expanded[node.path]) and "-" or expandable and "+" or "")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", indent + 18, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -self._metricWidth - (node.kind == "addon" and 140 or 6), 0)
    row.label:SetText(node.name)
    _applyFontSafe(row.label, self.fontSize, node.kind == "addon" and "OUTLINE" or nil)
    if node.kind == "addon" then row.label:SetTextColor(0.6, 0.85, 1)
    elseif node.kind == "bucket" then row.label:SetTextColor(0.92, 0.92, 0.95)
    else _colorText(row.label) end
    row.childAction:ClearAllPoints()
    row.childAction:SetPoint("RIGHT", row, "RIGHT", -self._metricWidth - 6, 0)
    row.childAction:SetShown(node.kind == "addon" and next(node.children) ~= nil)
    local childrenExpanded = self.expanded[node.path] and self:AreAddonChildrenExpanded(node)
    row.childAction:SetText(childrenExpanded and "Collapse children" or "Expand children")
    for _, column in ipairs(COLUMNS) do
      local cell = row.cells[column.key]
      local layout = self._columnLayout[column.key]
      cell:ClearAllPoints()
      cell:SetPoint("RIGHT", row, "RIGHT", -layout.right, 0)
      cell:SetWidth(layout.width)
      cell:SetShown(layout.visible)
      cell:SetText("")
      _applyFontSafe(cell, self.fontSize)
      _colorText(cell)
    end
    local stat = node.statKey and cpu:GetStat(node.statKey)
    row.cells.calls:SetText(tostring(stat and stat.n or node.count or 0))
    if stat and stat.n and stat.n > 0 then
      row.cells.total:SetText(string.format("%.3f", stat.timeSum or 0))
      row.cells.average:SetText(string.format("%.3f", (stat.timeSum or 0) / stat.n))
      row.cells.peak:SetText(string.format("%.3f", stat.timeMax or stat.timeLast or 0))
      if not stat.native and stat.allocN and stat.allocN > 0 then
        row.cells.allocation:SetText(string.format("%.2f", stat.allocSum / stat.allocN / 1024))
      end
    end
    local state = _nodeState(node)
    row.state:ClearAllPoints()
    row.state:SetPoint("LEFT", row, "RIGHT", -self._metricWidth, 0)
    row.state:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    _applyFontSafe(row.state, math.max(11, self.fontSize - 1))
    row.state:SetText(state or "")
    row.state:SetShown(state ~= nil and not node.hasCalls)
    if state and not node.hasCalls then
      for _, cell in pairs(row.cells) do cell:Hide() end
    end
    row.notice:SetShown(state ~= nil and node.hasCalls)
  end
  for i = visibleCount + 1, #self.rows do self.rows[i]:Hide(); self.rows[i]._data = nil end
  f._emptyText:SetText(self.searchText ~= "" and "No matching rows. Try another search or show rows with no calls in Settings."
    or "No addons have registered with Pleebug.")
  f._emptyText:SetShown(#flat == 0)
  self._rendering = nil
end

local function _applyBackdrop(frame, bg, border, inset)
  if not frame or not frame.SetBackdrop then return end
  inset = tonumber(inset) or 1
  frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = inset, right = inset, top = inset, bottom = inset },
  })
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function _skinFrame(frame, kind)
  if not frame then return end
  local _, border, _, bgWin, bgPane = _getPalette()
  local bg = (kind == "pane") and bgPane or bgWin
  _applyBackdrop(frame, bg, border, 1)
end

local function _hookAccentBorder(frame)
  if not frame or frame.__pleebugAccentHooked then return end
  frame.__pleebugAccentHooked = true

  local accent, border = _getPalette()
  frame:HookScript("OnEnter", function(self)
    if self.SetBackdropBorderColor then
      self:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
    end
  end)
  frame:HookScript("OnLeave", function(self)
    if self.SetBackdropBorderColor then
      self:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end
  end)
end

local function _skinButton(btn)
  if not btn then return end
  if not btn.SetBackdrop then
    -- ensure BackdropTemplate behavior without changing the template used
    local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    bg:SetAllPoints(btn)
    bg:SetFrameLevel((btn:GetFrameLevel() or 0) - 1)
    btn._pleebugBg = bg
    _skinFrame(bg, "pane")
    _hookAccentBorder(bg)
    if bg.EnableMouse then bg:EnableMouse(false) end
  else
    _skinFrame(btn, "pane")
    _hookAccentBorder(btn)
  end
end

local function _makeLabeledSlider(parent, label, minV, maxV, stepV, valueV, onChanged)
  local wrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  wrap:SetHeight(46)
  wrap:SetWidth(360)
  _skinFrame(wrap, "pane")
  _hookAccentBorder(wrap)

  local lbl = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("TOPLEFT", wrap, "TOPLEFT", 8, -6)
  lbl:SetText(label or "")
  _applyFontSafe(lbl, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(lbl)
  wrap._label = lbl

  local valText = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  valText:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", -8, -6)
  _applyFontSafe(valText, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(valText)
  wrap._valText = valText

  local slider = CreateFrame("Slider", nil, wrap)
  slider:SetPoint("BOTTOMLEFT", wrap, "BOTTOMLEFT", 10, 8)
  slider:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -10, 8)
  slider:SetHeight(14)
  slider:SetOrientation("HORIZONTAL")

  minV = tonumber(minV) or 0
  maxV = tonumber(maxV) or 1
  stepV = tonumber(stepV) or 1
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(stepV)
  slider:SetObeyStepOnDrag(true)

  local accent = _getPalette()
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
  thumb:SetSize(10, 16)
  thumb:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, 1)
  slider:SetThumbTexture(thumb)


  local track = slider:CreateTexture(nil, "ARTWORK")
  track:SetTexture("Interface\\Buttons\\WHITE8x8")
  track:SetPoint("CENTER", slider, "CENTER", 0, 0)
  track:SetSize(1, 4)
  track:SetVertexColor(1, 1, 1, 0.10)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  wrap._track = track

  local function setValueText(v)
    if wrap._valText then
      wrap._valText:SetText(tostring(v))
    end
  end

  slider:SetScript("OnValueChanged", function(_, v)
    v = tonumber(v) or 0
    v = math.floor(v + 0.5)
    setValueText(v)
    if type(onChanged) == "function" then
      onChanged(v)
    end
  end)

  valueV = tonumber(valueV) or minV
  if valueV < minV then valueV = minV end
  if valueV > maxV then valueV = maxV end
  slider:SetValue(valueV)
  setValueText(math.floor(valueV + 0.5))

  wrap._slider = slider
  return wrap
end

local function _makeLabeledInput(parent, label, textValue, onChanged)
  local wrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  wrap:SetHeight(52)
  wrap:SetWidth(360)
  _skinFrame(wrap, "pane")
  _hookAccentBorder(wrap)

  local lab = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lab:SetPoint("TOPLEFT", wrap, "TOPLEFT", 8, -6)
  lab:SetText(label or "")
  _applyFontSafe(lab, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(lab)
  wrap._label = lab

  local edit = CreateFrame("EditBox", nil, wrap, "InputBoxTemplate")
  edit:SetAutoFocus(false)
  edit:SetSize(120, 18)
  edit:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", -4, -6)
  edit:SetText(tostring(textValue or ""))
  edit:SetCursorPosition(0)

  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  edit:SetScript("OnEditFocusLost", function(self)
    if type(onChanged) == "function" then
      onChanged(self:GetText())
    end
  end)

  -- Optional: live update helper (caller can set wrap._onTextChanged)
  edit:SetScript("OnTextChanged", function(self)
    local p = self:GetParent()
    if p and type(p._onTextChanged) == "function" then
      p._onTextChanged(p, self:GetText())
    end
  end)


  wrap._edit = edit
  return wrap
end

local function _makeCheckbox(parent, label, checked, onChanged)

  local wrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  wrap:SetHeight(26)
  wrap:SetWidth(360)
  _skinFrame(wrap, "pane")
  _hookAccentBorder(wrap)

  local cb = CreateFrame("CheckButton", nil, wrap, "UICheckButtonTemplate")
  cb:SetPoint("LEFT", wrap, "LEFT", 6, 0)
  cb:SetSize(18, 18)
  cb:SetChecked(checked and true or false)

  local txt = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  txt:SetPoint("LEFT", cb, "RIGHT", 6, 0)
  txt:SetText(label or "")
  _applyFontSafe(txt, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(txt)

  cb:SetScript("OnClick", function()
    local v = cb:GetChecked() and true or false
    if type(onChanged) == "function" then
      onChanged(v)
    end
  end)

  wrap._cb = cb
  wrap._text = txt
  return wrap
end

local function _ensureFrame()
  if W.frame then return W.frame end


  local f = CreateFrame("Frame", "PleeBUG_MemDebugWindow", UIParent, "BackdropTemplate")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:SetSize(1120, 720)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetResizable(true)

  if f.SetResizeBounds then
    f:SetResizeBounds(1000, 620, 1800, 1200)
  else
    if f.SetMinResize then f:SetMinResize(1000, 620) end
    if f.SetMaxResize then f:SetMaxResize(1800, 1200) end
  end


  local resize = CreateFrame("Button", nil, f)
  resize:SetSize(18, 18)
  resize:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
  resize:EnableMouse(true)
  resize:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOMRIGHT")
  end)
  resize:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)

  resize.tex = resize:CreateTexture(nil, "OVERLAY")
  resize.tex:SetAllPoints()
  resize.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(self)
    if self:IsShown() then W:Refresh() end
  end)
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  if f:GetName() then
    table.insert(UISpecialFrames, f:GetName())
  end

  _skinFrame(f, "window")


  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
  title:SetText("PleeBUG Debug")
  _applyFontSafe(title, W.titleFontSize or 18, "OUTLINE")
  _colorText(title)

  local collapseAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  collapseAll:SetSize(94, 22)
  collapseAll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -6)
  collapseAll:SetText("Collapse all")
  collapseAll:SetScript("OnClick", function() W:SetAllExpanded(false) end)
  _skinButton(collapseAll)

  local expandAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  expandAll:SetSize(94, 22)
  expandAll:SetPoint("RIGHT", collapseAll, "LEFT", -6, 0)
  expandAll:SetText("Expand all")
  expandAll:SetScript("OnClick", function() W:SetAllExpanded(true) end)
  _skinButton(expandAll)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  -- Settings window (separate frame, toggled by "Settings" button)
  local sf = CreateFrame("Frame", "PleeBUG_MemDebugSettingsWindow", UIParent, "BackdropTemplate")
  sf:SetFrameStrata("FULLSCREEN_DIALOG")
  sf:SetToplevel(true)
  sf:SetSize(380, f:GetHeight() or 520)
  sf:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0)
  sf:SetClampedToScreen(true)
  sf:SetMovable(true)
  sf:EnableMouse(true)
  sf:RegisterForDrag("LeftButton")
  sf:SetScript("OnDragStart", function(self) self:StartMoving() end)
  sf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  -- Keep settings height in sync with the main window height.
  f:HookScript("OnSizeChanged", function(self)
    local sff = self and self._settingsFrame
    if not sff then
      return
    end
    local h = self.GetHeight and self:GetHeight() or nil
    if h and h > 0 then
      sff:SetHeight(h)
    end
  end)

  _skinFrame(sf, "window")

  local sTitle = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sTitle:SetPoint("TOPLEFT", sf, "TOPLEFT", 12, -10)
  sTitle:SetText("PleeBUG Settings")
  _applyFontSafe(sTitle, W.titleFontSize or 18, "OUTLINE")
  _colorText(sTitle)

  local sClose = CreateFrame("Button", nil, sf, "UIPanelCloseButton")
  sClose:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -4, -4)
  sClose:SetScript("OnClick", function() sf:Hide() end)

  sf:Hide()
  f._settingsFrame = sf

  -- If the main window closes (close button, ESC, Hide(), etc),
  -- force-close the settings window too.
  f:HookScript("OnHide", function(self)
    local sff = self and self._settingsFrame
    if sff and sff.IsShown and sff:IsShown() then
      sff:Hide()
    end
  end)


  function W:ToggleSettings()
    local ff = _ensureFrame()
    local sff = ff and ff._settingsFrame
    if not sff then return end
    if sff:IsShown() then
      sff:Hide()
    else
      sff:Show()
      self:Refresh()
    end
  end
  -- Export (copy table rows to a multiline editbox)
  local ExportFrame
  local ExportEditBox

  local function _EnsureExportFrame()
    if ExportFrame and ExportEditBox then
      return
    end

    local ef = CreateFrame("Frame", "PleeBUG_ExportWindow", UIParent, "BackdropTemplate")
    ef:SetFrameStrata("FULLSCREEN_DIALOG")
    ef:SetToplevel(true)
    ef:SetSize(820, 520)
    ef:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ef:SetClampedToScreen(true)
    ef:SetMovable(true)
    ef:EnableMouse(true)
    ef:RegisterForDrag("LeftButton")
    ef:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ef:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    if ef.SetResizeBounds then
      ef:SetResizable(true)
      ef:SetResizeBounds(520, 300, 1400, 1000)
    elseif ef.SetMinResize then
      ef:SetResizable(true)
      ef:SetMinResize(520, 300)
    end

    _skinFrame(ef, "window")

    local title = ef:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", ef, "TOPLEFT", 12, -10)
    title:SetText("PleeBUG Export (Ctrl+C)")
    _applyFontSafe(title, W.titleFontSize or 18, "OUTLINE")
    _colorText(title)

    local close = CreateFrame("Button", nil, ef, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", ef, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ef:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, ef, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", ef, "TOPLEFT", 12, -36)
    scroll:SetPoint("BOTTOMRIGHT", ef, "BOTTOMRIGHT", -30, 12)

    local edit = CreateFrame("EditBox", nil, scroll, "BackdropTemplate")
    edit:SetMultiLine(true)
    edit:SetMaxLetters(0)
    edit:EnableMouse(true)
    edit:SetAutoFocus(true)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetWidth(760)
    edit:SetScript("OnEscapePressed", function()
      ef:Hide()
    end)

    scroll:SetScrollChild(edit)

    ExportFrame = ef
    ExportEditBox = edit

    if ef:GetName() and UISpecialFrames then
      table.insert(UISpecialFrames, ef:GetName())
    end

    ef:Hide()
  end

  function W:BuildExportText()
    if not MemDebug:IsEnabled() and self._stoppedExportText then
      return self._stoppedExportText
    end
    local snapshot = self._pendingSnapshot or self.lastSnapshot or MemDebug._lastSnapshot or {}
    local flat = self:_BuildExportRows(snapshot)
    local interval = snapshot.__interval or self._pendingInterval or MemDebug:GetInterval()
    interval = tonumber(interval) or 10
    if interval <= 0 then interval = 10 end

    local cpu = MemDebug and MemDebug.CPU

    local nRows = #flat

    local lines = {}
    lines[1] = table.concat({
      "path",
      "name",
      "depth",
      "calls",
      "calls_per_sec",
      "alloc_avg_kb",
      "alloc_max_kb",
      "cpu_avg_ms",
      "cpu_peak_call_ms",
      "measurement_state",
      "measurement_kind",
      "canonical_path",
      "active_frames",
      "cpu_avg_active_frame_ms",
      "cpu_peak_frame_ms",
      "calls_avg_active_frame",
      "calls_peak_frame",
      "cpu_peak_sampled_avg_ms",
      "cpu_last_call_ms",
      "cpu_last_sampled_avg_ms",
      "cpu_scope",
      "phase_measurements",
      "cpu_total_ms",
      "alloc_total_kb",
      "dealloc_avg_kb",
      "dealloc_max_kb",
      "dealloc_total_kb",
      "allocation_calls",
      "window_seconds",
      "window_start",
      "window_end",
    }, "\t")

    for i = 1, nRows do
      local entry = flat[i]
      local node = entry and entry.node
      if node and node.path then
        local depth = entry.depth or 0
        local path = tostring(node.path or "")
        local name = tostring(node.name or "")

        local count = tonumber(node.count) or 0
        local rate = count / interval

        local memAvgKB, memMaxKB = "", ""
        local cpuTotal, allocTotal, deallocAvg, deallocMax, deallocTotal, allocationCalls = "", "", "", "", "", ""
        local cpuAvgMs, cpuMaxMs = "", ""
        local sampledPeak, lastCall, lastSample, scope, phaseText = "", "", "", "", ""
        local measurementState, measurementKind, canonicalPath = "", "", ""
        local uninstrumented = node.kind == "addon" and not next(node.children)
        if node.kind == "addon" or node.kind == "bucket" then
          local displayed = self._treeIndex and self._treeIndex[node.path]
          measurementState = _nodeState(displayed or node) or ""
        end
        local activeFrames, frameAvgMs, framePeakMs, frameAvgCalls, framePeakCalls = "", "", "", "", ""

        local isFuncLeaf = node.kind == "function"
        local isEventLeaf = node.kind == "event"
        local statKey = node.statKey

        if (isFuncLeaf or isEventLeaf) and cpu and cpu.GetStat and statKey then
          local st = cpu:GetStat(statKey)
          if st and st.n and st.n > 0 then
            local n = tonumber(st.n) or 1
            if n <= 0 then n = 1 end

            local avgMs = (tonumber(st.timeSum) or 0) / n
            local maxMs = tonumber(st.timeMax) or tonumber(st.timeLast) or 0

            count = st.n
            rate = count / interval
            cpuTotal = string.format("%.6f", st.timeSum)
            cpuAvgMs = string.format("%.6f", avgMs)
            scope = st.native and (isFuncLeaf and "native includeSubroutines=false" or "native global event counter") or "inclusive"
            if st.native then
              sampledPeak = string.format("%.6f", maxMs)
              lastSample = string.format("%.6f", st.timeLast or 0)
            else
              cpuMaxMs = string.format("%.6f", maxMs)
              lastCall = string.format("%.6f", st.timeLast or 0)
            end
            if st.phaseOrder then
              local phases = {}
              for j = 1, #st.phaseOrder do
                local phaseName = st.phaseOrder[j]
                local phase = st.phases[phaseName]
                phases[#phases + 1] = string.format("%s: calls=%d, avg_ms=%.6f, peak_ms=%.6f, alloc_avg_kb=%.3f, dealloc_avg_kb=%.3f",
                  phaseName, phase.n, phase.timeSum / phase.n, phase.timeMax,
                  phase.allocSum / phase.n / 1024, phase.deallocSum / phase.n / 1024)
              end
              phaseText = table.concat(phases, "; ")
            end

            if st.activeFrames and st.activeFrames > 0 then
              activeFrames = tostring(st.activeFrames)
              frameAvgMs = string.format("%.6f", st.timeSum / st.activeFrames)
              framePeakMs = string.format("%.6f", st.frameTimeMax)
              frameAvgCalls = string.format("%.6f", st.n / st.activeFrames)
              framePeakCalls = tostring(st.frameCallsMax)
            end

            if st.native ~= true then
              if st.allocN and st.allocN > 0 then
                local avgMem = ((tonumber(st.allocSum) or 0) / (st.allocN or n)) / 1024
                local maxMem = (tonumber(st.allocMax) or tonumber(st.allocLast) or 0) / 1024
                memAvgKB = string.format("%.3f", avgMem)
                memMaxKB = string.format("%.3f", maxMem)
                allocTotal = string.format("%.3f", st.allocSum / 1024)
                allocationCalls = tostring(st.allocN)
              end
              if st.deallocN and st.deallocN > 0 then
                deallocAvg = string.format("%.3f", st.deallocSum / st.deallocN / 1024)
                deallocMax = string.format("%.3f", st.deallocMax / 1024)
                deallocTotal = string.format("%.3f", st.deallocSum / 1024)
              end
            end

          end
        end

        if isFuncLeaf and cpu and statKey then
          if cpu.GetMeasurementState then
            measurementState = cpu:GetMeasurementState(statKey) or ""
          end
          if cpu.GetFunctionRegistration then
            local rec, registration = cpu:GetFunctionRegistration(statKey)
            measurementKind = registration and registration.kind or ""
            canonicalPath = rec and rec.canonicalPath or ""
          end
        end

        lines[#lines + 1] = table.concat({
          path,
          name,
          tostring(depth),
          uninstrumented and "" or tostring(count),
          uninstrumented and "" or string.format("%.6f", rate),
          tostring(memAvgKB),
          tostring(memMaxKB),
          tostring(cpuAvgMs),
          tostring(cpuMaxMs),
          tostring(measurementState),
          tostring(measurementKind),
          tostring(canonicalPath),
          activeFrames,
          frameAvgMs,
          framePeakMs,
          frameAvgCalls,
          framePeakCalls,
          sampledPeak,
          lastCall,
          lastSample,
          scope,
          phaseText,
          cpuTotal,
          allocTotal,
          deallocAvg,
          deallocMax,
          deallocTotal,
          allocationCalls,
          tostring(interval),
          tostring(snapshot.__windowStart or ""),
          tostring(snapshot.__windowEnd or ""),
        }, "\t")
      end
    end

    return table.concat(lines, "\n")
  end

  function W:OpenExportWindow()
    _EnsureExportFrame()
    if not (ExportFrame and ExportEditBox) then return end

    local txt = self:_FilterExportText(self:BuildExportText())
    ExportEditBox:SetText(txt)
    ExportEditBox:HighlightText()
    ExportEditBox:SetFocus()
    ExportFrame:Show()
  end

  -- Controls
  local debuggingBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  debuggingBtn:SetSize(220, 22)
  debuggingBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
  debuggingBtn:SetScript("OnClick", function()
    MemDebug:SetDebuggingEnabledAndReload(not MemDebug:IsDebuggingEnabled())
    W:Refresh()
  end)
  f._debuggingBtn = debuggingBtn

  local wrappingText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wrappingText:SetPoint("LEFT", debuggingBtn, "RIGHT", 10, 0)
  wrappingText:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  wrappingText:SetJustifyH("LEFT")
  f._wrappingText = wrappingText

  local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")

  startBtn:SetSize(90, 22)
  startBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -68)
  startBtn:SetText("Start")
  startBtn:SetScript("OnClick", function()
    MemDebug:SetEnabled(true)
    W:Refresh()
  end)



  local stopBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  stopBtn:SetSize(90, 22)
  stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
  stopBtn:SetText("Stop")
  f._startBtn, f._stopBtn = startBtn, stopBtn
  stopBtn:SetScript("OnClick", function()
    MemDebug:SetEnabled(false)
    W:Refresh()
  end)


  local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearBtn:SetSize(90, 22)
  clearBtn:SetPoint("LEFT", stopBtn, "RIGHT", 8, 0)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    MemDebug:Clear()
    W.lastSnapshot = {}
    W._buildInProgress = false
    W:Refresh()
  end)


  local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  exportBtn:SetSize(90, 22)
  exportBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
  exportBtn:SetText("Export")
  exportBtn:SetScript("OnClick", function()
    if W and W.OpenExportWindow then
      W:OpenExportWindow()
    end
  end)

  local settingsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  settingsBtn:SetSize(110, 22)
  settingsBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
  settingsBtn:SetText("Settings")
  settingsBtn:SetScript("OnClick", function()
    if W and W.ToggleSettings then
      W:ToggleSettings()
    end
  end)

  -- Built-in skin (square, 1px border, dark bg, accent hover)
  _skinButton(debuggingBtn)
  _skinButton(startBtn)
  _skinButton(stopBtn)
  _skinButton(clearBtn)
  _skinButton(exportBtn)
  _skinButton(settingsBtn)



  for _, b in ipairs({ debuggingBtn, startBtn, stopBtn, clearBtn, exportBtn, settingsBtn }) do


    if b then
      b:EnableMouse(true)
      local bg = b._bg or b._backdrop or b._back
      if bg and bg.EnableMouse then
        bg:EnableMouse(false)
      end
    end
  end



  -- Interval slider (native)
  local sf = f._settingsFrame

  local intervalSlider = _makeLabeledSlider(
    sf,
    "Window (sec)",
    5, 60, 1,
    (MemDebug.GetInterval and MemDebug:GetInterval()) or 10,
    function(val)
      if MemDebug and MemDebug.SetInterval then
        MemDebug:SetInterval(val)
      end
      W:Refresh()
    end
  )
  intervalSlider:ClearAllPoints()
  intervalSlider:SetPoint("TOPLEFT", sf, "TOPLEFT", 12, -38)
  intervalSlider:SetWidth(356)
  intervalSlider:Show()
  f._intervalSlider = intervalSlider



  -- Font size slider (native)
  local fontSlider = _makeLabeledSlider(
    sf,
    "Font Size",
    10, 22, 1,
    (MemDebug.GetFontSize and MemDebug:GetFontSize()) or (W.fontSize or 14),
    function(val)
      val = tonumber(val) or 14
      val = math.floor(val + 0.5)
      if val < 10 then val = 10 end
      if val > 22 then val = 22 end

      W.fontSize = val
      W.rowHeight = math.max(18, math.floor((val * (W.uiScale or 1)) + 0.5) + 10)

      if MemDebug and MemDebug.SetFontSize then
        MemDebug:SetFontSize(val)
      end

      W:Refresh()
    end
  )
  fontSlider:ClearAllPoints()
  fontSlider:SetPoint("TOPLEFT", intervalSlider, "BOTTOMLEFT", 0, -10)
  fontSlider:SetWidth(356)
  fontSlider:Show()
  f._fontSlider = fontSlider



  local noCallsBox = _makeCheckbox(sf, "Show rows with no calls", _showRowsWithNoCalls(), function(value)
    displaySettings.showRowsWithNoCalls = value
    f._scroll:SetVerticalScroll(0)
    W:Refresh()
  end)
  noCallsBox:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", 0, -8)
  f._noCallsBox = noCallsBox

  local allocationsBox = _makeCheckbox(sf, "Show allocation column", displaySettings.showAllocations, function(value)
    displaySettings.showAllocations = value
    W:Refresh()
  end)
  allocationsBox:SetPoint("TOPLEFT", noCallsBox, "BOTTOMLEFT", 0, -4)
  f._allocationsBox = allocationsBox

  -- Debug/profile mode controls
  local sf = f._settingsFrame or f
  local cpu = MemDebug and MemDebug.CPU

  local modeLabel = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  modeLabel:SetPoint("TOPLEFT", allocationsBox, "BOTTOMLEFT", 8, -12)
  modeLabel:SetText("Debugging: " .. MemDebug:GetDebugMode())
  _applyFontSafe(modeLabel, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(modeLabel)
  f._debugModeLabel = modeLabel

  local lightBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
  lightBtn:SetSize(172, 22)
  lightBtn:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", -8, -6)
  lightBtn:SetText("Light debug")
  lightBtn:SetScript("OnClick", function()
    if MemDebug and MemDebug.SetDebugModeAndReload then
      MemDebug:SetDebugModeAndReload("light")
    end
  end)
  _skinButton(lightBtn)
  f._lightModeBtn = lightBtn

  local fullBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
  fullBtn:SetSize(172, 22)
  fullBtn:SetPoint("LEFT", lightBtn, "RIGHT", 8, 0)
  fullBtn:SetText("Full debug")
  fullBtn:SetScript("OnClick", function()
    if MemDebug and MemDebug.SetDebugModeAndReload then
      MemDebug:SetDebugModeAndReload("full")
    end
  end)
  _skinButton(fullBtn)
  f._fullModeBtn = fullBtn

  local spText = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  spText:SetPoint("TOPLEFT", lightBtn, "BOTTOMLEFT", 8, -8)
  local spOn = cpu and cpu.IsScriptProfileEnabled and cpu:IsScriptProfileEnabled() or false
  spText:SetText("scriptProfile CVar: " .. (spOn and "ON" or "OFF"))
  _applyFontSafe(spText, math.max(12, (W.fontSize or 14)), "OUTLINE")
  _colorText(spText)
  f._scriptProfileText = spText

  local modeHelp = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  modeHelp:SetPoint("TOPLEFT", spText, "BOTTOMLEFT", 0, -6)
  modeHelp:SetWidth(360)
  modeHelp:SetJustifyH("LEFT")
  modeHelp:SetText("Choose files, then enable debugging. Enabling and disabling reload. Start and Stop record immediately while debugging is enabled.")
  _applyFontSafe(modeHelp, math.max(11, (W.fontSize or 14) - 1), nil)
  _colorText(modeHelp)
  f._modeHelpText = modeHelp

  -- Presets own these flags now. Keep the old fields nil so the UI does not expose
  -- half-overridden legacy switches that create confusing mixed states.
  f._scriptProfileEnableBtn = nil
  f._scriptProfileDisableBtn = nil
  f._cpuEnableBox = nil
  f._nativeFuncBox = nil
  f._nativeEventBox = nil
  f._cpuRefExplain = modeHelp

  -- Modules panel (auto-populated from MemDebug:Attach registrations)
  do
local panel = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    panel:SetSize(0, 0)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", f._cpuRefExplain or cpuEnableBox, "BOTTOMLEFT", 0, -12)
    panel:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -12, 12)
    f._modulesPanel = panel


    panel:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.25)
    panel:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)


    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    title:SetText("Addons and files")
    _applyFontSafe(title, math.max(12, (W.fontSize or 14)), "OUTLINE")
    _colorText(title)
    panel._title = title

    local enableAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    enableAll:SetSize(80, 18)
    enableAll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    enableAll:SetText("Enable All")
    enableAll:SetScript("OnClick", function()
      if MemDebug and MemDebug.EnableAllModules then
        MemDebug:EnableAllModules()
      end
      if W and W.Refresh then
        W:Refresh()
      end
    end)

    local disableAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    disableAll:SetSize(80, 18)
    disableAll:SetPoint("LEFT", enableAll, "RIGHT", 6, 0)
    disableAll:SetText("Disable All")
    disableAll:SetScript("OnClick", function()
      if MemDebug and MemDebug.DisableAllModules then
        MemDebug:DisableAllModules()
      end
      if W and W.Refresh then
        W:Refresh()
      end
    end)

    enableAll:SetEnabled(MemDebug:GetLoadMode() ~= "full" or not InCombatLockdown())
    disableAll:SetEnabled(MemDebug:GetLoadMode() ~= "full" or not InCombatLockdown())
    panel._enableAll = enableAll
    panel._disableAll = disableAll
    _skinButton(enableAll)
    _skinButton(disableAll)


    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", enableAll, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 0)



    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    panel._scroll = scroll
    panel._content = content
    panel._checks = panel._checks or {}
  end

  local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  status:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -102)
  status:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -102)
  status:SetJustifyH("LEFT")
  status:SetHeight(24)
  _applyFontSafe(status, 13)
  _colorText(status)
  f._statusText = status

  local native = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  native:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
  native:SetPoint("TOPRIGHT", status, "BOTTOMRIGHT", 0, -2)
  native:SetHeight(22)
  native:SetJustifyH("LEFT")
  _applyFontSafe(native, 12)
  native:SetTextColor(0.65, 0.75, 0.82)
  f._nativeText = native

  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("TOPLEFT", native, "BOTTOMLEFT", 0, -12)
  searchLabel:SetText("Search")
  _applyFontSafe(searchLabel, 12)
  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetAutoFocus(false)
  search:SetSize(300, 24)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  search:SetScript("OnTextChanged", function(self) W:SetSearch(self:GetText()) end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f._search = search
  local clearSearch = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearSearch:SetSize(60, 24)
  clearSearch:SetPoint("LEFT", search, "RIGHT", 8, 0)
  clearSearch:SetText("Clear")
  clearSearch:SetScript("OnClick", function() search:SetText(""); search:ClearFocus() end)
  _skinButton(clearSearch)
  local resort = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  resort:SetSize(80, 24)
  resort:SetPoint("TOPRIGHT", native, "BOTTOMRIGHT", 0, -8)
  resort:SetText("Resort")
  resort:SetScript("OnClick", function() W:Resort() end)
  _skinButton(resort)
  f._resort = resort
  local sortText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sortText:SetPoint("RIGHT", resort, "LEFT", -12, 0)
  _applyFontSafe(sortText, 12)
  f._sortText = sortText

  -- Profiling table
  local listHolder = CreateFrame("Frame", nil, f, "BackdropTemplate")
  listHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -204)
  listHolder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
  f._listHolder = listHolder

  listHolder:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  listHolder:SetBackdropColor(0, 0, 0, 0.18)
  listHolder:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)





  -- Keep top controls above scroll region and any shell art.
  local base = f:GetFrameLevel() or 0
  local strata = f:GetFrameStrata() or "FULLSCREEN_DIALOG"

  for _, r in ipairs({ debuggingBtn, startBtn, stopBtn, clearBtn, exportBtn, settingsBtn }) do
    if r then
      if r.SetFrameStrata then
        r:SetFrameStrata(strata)
      end
      if r.SetFrameLevel then
        r:SetFrameLevel(base + 80)
      end
    end
  end

  if intervalSlider and intervalSlider.SetFrameLevel then
    intervalSlider:SetFrameLevel(base + 30)
  end
  if fontSlider and fontSlider.SetFrameLevel then
    fontSlider:SetFrameLevel(base + 30)
  end

  if status and status.SetFrameLevel then
    status:SetFrameLevel(base + 30)
  end


-- Column header (fixed, not scrolled)
  local header = CreateFrame("Frame", nil, f._listHolder, "BackdropTemplate")
  header:SetPoint("TOPLEFT", f._listHolder, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", f._listHolder, "TOPRIGHT", -32, 0)
  header:SetHeight(W.rowHeight or 24)

  header:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  header:SetBackdropColor(0, 0, 0, 0.35)
  header:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

  header.cells = {}
  local function makeHeader(key)
    local button = CreateFrame("Button", nil, header)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetAllPoints(button)
    text:SetJustifyH(key == "name" and "LEFT" or "RIGHT")
    button.text = text
    _colorText(text)
    button:SetScript("OnClick", function() if key ~= "allocation" then W:SetSort(key) end end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if key == "allocation" then
        GameTooltip:AddLine("Average allocated KiB per measured allocation call. This is allocation activity, not retained memory.", 1, 1, 1, true)
      else
        GameTooltip:AddLine("Click to sort; click again to reverse.")
        GameTooltip:AddLine("Row order stays fixed while recording. Click Resort to update it.", 0.8, 0.8, 0.8, true)
        if key == "total" then GameTooltip:AddLine("Function measurements can overlap. Group CPU totals are deliberately left blank.", 0.8, 0.8, 0.8, true) end
        if key == "peak" then GameTooltip:AddLine("Full functions show the slowest completed call. Native counters show the highest sampled average.", 0.8, 0.8, 0.8, true) end
      end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
  end
  for _, column in ipairs(COLUMNS) do header.cells[column.key] = makeHeader(column.key) end
  header.nameButton = makeHeader("name")
  f._listHeader = header

  -- Scroll area (LIST pane)
  local scroll = CreateFrame("ScrollFrame", nil, f._listHolder, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", f._listHolder, "BOTTOMRIGHT", -32, 0)


  local content = CreateFrame("Frame", nil, scroll)

  -- IMPORTANT:
  -- If content is left at width 1, your row buttons become ~1px clickable even though text renders wider.
  -- Anchor content to the scroll frame so rows get a real width/hitbox.
  content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  content:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
  content:SetSize(1, 1) -- height is driven by Refresh; width is driven by anchors above
  scroll:SetScrollChild(content)

  local function _SyncContentWidth()
    content:SetWidth(math.max(1, scroll:GetWidth()))
  end

  -- IMPORTANT: do this immediately so row buttons get a real hitbox on first show
  _SyncContentWidth()

  -- Keep width stable if the window is resized
  scroll:SetScript("OnSizeChanged", function()
    _SyncContentWidth()
    if W._buildRoot and not W._buildInProgress then
      W:_RenderFlat()
    end
  end)

  -- Also resync on show (some layouts do not trigger OnSizeChanged the first time)
  f:HookScript("OnShow", function()
    _SyncContentWidth()
  end)


  f._scroll = scroll
  f._content = content
  local empty = listHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  empty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -18)
  empty:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -18)
  empty:SetJustifyH("LEFT")
  empty:SetWordWrap(true)
  _applyFontSafe(empty, 13)
  empty:SetTextColor(0.7, 0.7, 0.7)
  empty:Hide()
  f._emptyText = empty
  scroll:HookScript("OnVerticalScroll", function()
    if W._buildRoot and not W._buildInProgress then
      W:_RenderFlat()
    end
  end)

  W.frame = f
  f:Hide()
  return f
end


local function _refreshModulePanel(f)
  if not f or not f._modulesPanel or not MemDebug then return end

  local panel = f._modulesPanel
  local content = panel._content
  if not content then return end
  local canChangeSelection = MemDebug:GetLoadMode() ~= "full" or not InCombatLockdown()
  panel._enableAll:SetEnabled(canChangeSelection)
  panel._disableAll:SetEnabled(canChangeSelection)

  local names = (MemDebug.GetKnownModules and MemDebug:GetKnownModules()) or {}
  local grouped = {}
  local topLevel = {}

  for i = 1, #names do
    local name = names[i]
    local groupName = MemDebug.GetModuleGroup and MemDebug:GetModuleGroup(name) or nil
    if groupName then
      grouped[groupName] = grouped[groupName] or {}
      grouped[groupName][#grouped[groupName] + 1] = name
    else
      topLevel[#topLevel + 1] = { kind = "module", name = name }
    end
  end

  for groupName, members in pairs(grouped) do
    topLevel[#topLevel + 1] = {
      kind = "group",
      name = groupName,
      members = members,
    }
  end

  table.sort(topLevel, function(a, b)
    return tostring(a.name or "") < tostring(b.name or "")
  end)

  panel._groupExpanded = panel._groupExpanded or {}

  local entries = {}
  for i = 1, #topLevel do
    local entry = topLevel[i]
    entries[#entries + 1] = entry

    if entry.kind == "group" then
      local groupName = entry.name
      if panel._groupExpanded[groupName] == nil then
        panel._groupExpanded[groupName] = true
      end

      if panel._groupExpanded[groupName] then
        for j = 1, #entry.members do
          entries[#entries + 1] = {
            kind = "module",
            name = entry.members[j],
            group = groupName,
          }
        end
      end
    end
  end

  panel._rows = panel._rows or {}

  -- StaticPopup for rename
  if not StaticPopupDialogs.PLEEBUG_RENAME then
    StaticPopupDialogs.PLEEBUG_RENAME =

    {
      text = "Friendly name",
      button1 = "Save",
      button2 = "Clear",
      button3 = "Cancel",
      hasEditBox = true,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,

      OnShow = function(self)
        local data = self.data
        local mod = data and data.module
        if not mod then return end
        local cur = (MemDebug.GetModuleAlias and MemDebug:GetModuleAlias(mod)) or ""
        self.editBox:SetText(cur)
        self.editBox:HighlightText()
      end,

      OnAccept = function(self)
        local data = self.data
        local mod = data and data.module
        if not mod then return end
        local txt = self.editBox:GetText()
        if MemDebug and MemDebug.SetModuleAlias then
          MemDebug:SetModuleAlias(mod, txt)
        end
        if W and W.Refresh then
          W:Refresh()
        end
      end,

      OnAlt = function(self)
        local data = self.data
        local mod = data and data.module
        if not mod then return end
        if MemDebug and MemDebug.SetModuleAlias then
          MemDebug:SetModuleAlias(mod, nil)
        end
        if W and W.Refresh then
          W:Refresh()
        end
      end,
    }
  end

  local rowH = 18
  local y = -2

  for i = 1, #entries do
    local entry = entries[i]
    local row = panel._rows[i]
    if not row then
      row = CreateFrame("Frame", nil, content)
      row:SetHeight(rowH)

      local expand = CreateFrame("Button", nil, row)
      expand:SetSize(18, 18)
      expand:SetPoint("LEFT", row, "LEFT", 0, 0)

      local expandText = expand:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      expandText:SetAllPoints(expand)
      expandText:SetJustifyH("CENTER")
      _applyFontSafe(expandText, math.max(12, (W.fontSize or 14)), nil)
      _colorText(expandText)

      local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
      cb:SetSize(18, 18)

      local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
      _applyFontSafe(text, math.max(12, (W.fontSize or 14)), nil)
      _colorText(text)

      local gear = CreateFrame("Button", nil, row)
      gear:SetSize(18, 18)
      gear:SetPoint("RIGHT", row, "RIGHT", 0, 0)

      -- Gear icon (no emoji): Interface/HUD/UIGroupManager2x
      if gear.SetNormalAtlas then
        gear:SetNormalAtlas("GM-icon-settings", true)
      end
      if gear.SetHighlightAtlas then
        gear:SetHighlightAtlas("GM-icon-settings-hover")
      end

      if gear.SetPushedAtlas then
        gear:SetPushedAtlas("GM-icon-settings-pressed", true)
      end

      -- Slightly dim default state so hover reads better
      local nt = gear.GetNormalTexture and gear:GetNormalTexture() or nil
      if nt and nt.SetAlpha then
        nt:SetAlpha(0.9)
      end

      row._expand = expand
      row._expandText = expandText
      row._cb = cb
      row._text = text
      row._gear = gear

      expand:SetScript("OnClick", function()
        local groupName = row._groupName
        if not groupName then return end
        panel._groupExpanded[groupName] = not panel._groupExpanded[groupName]
        if W and W.Refresh then
          W:Refresh()
        end
      end)

      cb:SetScript("OnClick", function()
        if row._kind == "group" then
          local groupName = row._groupName
          local enableGroup = (row._groupEnabledCount or 0) == 0
          if groupName and MemDebug and MemDebug.SetModuleGroupEnabled then
            MemDebug:SetModuleGroupEnabled(groupName, enableGroup)
          end
        else
          local moduleName = row._moduleName
          local v = cb:GetChecked() and true or false
          if moduleName and MemDebug and MemDebug.SetModuleEnabled then
            MemDebug:SetModuleEnabled(moduleName, v)
          end
        end
        if W and W.Refresh then
          W:Refresh()
        end
      end)

      gear:SetScript("OnClick", function()
        local moduleName = row._moduleName
        if not moduleName then return end
        local dlg = StaticPopup_Show("PLEEBUG_RENAME")
        if dlg then
          dlg.data = { module = moduleName }
        end
      end)

      panel._rows[i] = row
    end

    row._kind = entry.kind
    row._moduleName = nil
    row._groupName = nil
    row._groupEnabledCount = nil

    row._cb:ClearAllPoints()
    row._cb:SetAlpha(1)

    if entry.kind == "group" then
      local groupName = entry.name
      row._groupName = groupName

      local expanded = panel._groupExpanded[groupName] == true
      row._expandText:SetText(expanded and "-" or "+")
      row._expand:Show()

      row._cb:SetPoint("LEFT", row._expand, "RIGHT", 0, 0)

      local allEnabled, enabledCount, totalCount = false, 0, 0
      if MemDebug.GetModuleGroupState then
        allEnabled, enabledCount, totalCount = MemDebug:GetModuleGroupState(groupName)
      end
      row._groupEnabledCount = enabledCount
      row._cb:SetChecked(enabledCount > 0)
      if not allEnabled and enabledCount > 0 then
        row._cb:SetAlpha(0.55)
      end

      row._text:SetText(string.format("%s (%d/%d)", MemDebug:GetAddonDisplayName(groupName), enabledCount, totalCount))
      row._gear:Hide()
    else
      local moduleName = entry.name
      row._moduleName = moduleName

      row._expand:Hide()
      row._cb:SetPoint("LEFT", row, "LEFT", entry.group and 36 or 18, 0)

      local label = moduleName
      if MemDebug and MemDebug.GetModuleDisplayName then
        label = MemDebug:GetModuleDisplayName(moduleName)
      end
      if label == moduleName and (entry.group == "PCM" or entry.group == "PRD" or entry.group == "PUIModules") then
        label = label:gsub("^PUI_", "")
      end
      row._text:SetText(label)

      local enabled = true
      if MemDebug and MemDebug.IsModuleEnabled then
        enabled = MemDebug:IsModuleEnabled(moduleName)
      end
      row._cb:SetChecked(enabled)

      row._gear:Show()
    end

    row._cb:SetEnabled(canChangeSelection)
    row._text:SetAlpha(1)
    row._text:Show()

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
    row:Show()

    y = y - rowH
  end

  for i = #entries + 1, #panel._rows do
    local row = panel._rows[i]
    if row then row:Hide() end
  end

  content:SetHeight(math.max(1, (#entries * rowH) + 6))
end


function _ensureRow(i)

  local f = W.frame
  local parent = f._content
  local row = W.rows[i]
  if row then return row end

  row = CreateFrame("Button", nil, parent)
  row:SetHeight(W.rowHeight or 24)
  row:SetPoint("LEFT", parent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  -- Background (zebra set in Refresh)
  row.BG = row:CreateTexture(nil, "BACKGROUND")
  row.BG:SetAllPoints()

  -- Hover highlight
  row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  local hl = row:GetHighlightTexture()
  if hl then
    hl:SetVertexColor(0.18, 0.18, 0.18, 0.55)
  end

  row.chevron = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.chevron:SetWidth(16)
  row.chevron:SetJustifyH("CENTER")
  _applyFontSafe(row.chevron, 14)
  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)

  local childAction = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  childAction:SetSize(130, 20)
  childAction:SetScript("OnClick", function()
    local node = row._data and row._data.node
    if node and node.kind == "addon" then
      local expanded = W.expanded[node.path] and W:AreAddonChildrenExpanded(node)
      W:SetAddonChildrenExpanded(node, not expanded)
    end
  end)
  _skinButton(childAction)
  row.childAction = childAction
  row.cells = {}
  for _, column in ipairs(COLUMNS) do
    local cell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cell:SetJustifyH("RIGHT")
    cell:SetWordWrap(false)
    row.cells[column.key] = cell
  end
  row.state = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.state:SetJustifyH("LEFT")
  row.state:SetWordWrap(false)
  row.state:SetTextColor(0.7, 0.7, 0.7)
  row.notice = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.notice:SetPoint("LEFT", row.label, "RIGHT", 0, 0)
  row.notice:SetText("!")
  row.notice:SetTextColor(1, 0.7, 0.2)

  row:SetScript("OnClick", function(self)
    local data = self._data
    if not data or not data.node then return end
    local node = data.node
    if not node.children or not next(node.children) then return end

    local path = node.path
    W.expanded[path] = not W.expanded[path]
    W:_ApplySnapshot(W._pendingSnapshot or W.lastSnapshot or {})
    W:_RenderFlat()
  end)

  row:SetScript("OnEnter", function(self)
    local entry = self._data
    if not entry then return end
    local node = entry.node
    local key = node.statKey
    local cpu = MemDebug.CPU
    local st = key and cpu:GetStat(key)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(node.name)
    GameTooltip:AddLine(node.path, 0.65, 0.75, 0.82, true)
    local state = _nodeState(node)
    if state then GameTooltip:AddLine(state, 1, 0.8, 0.4) end
    if node.kind == "function" then
      local measurement = cpu:GetMeasurementState(key)
      if measurement then GameTooltip:AddLine(measurement, 0.8, 0.8, 0.8, true) end
    elseif node.kind == "addon" or node.kind == "bucket" then
      GameTooltip:AddLine("Calls count registered activity. Nested functions can overlap; this is not complete addon CPU usage.", 0.8, 0.8, 0.8, true)
    end
    if not st or not st.n or st.n <= 0 then GameTooltip:Show(); return end
    GameTooltip:AddDoubleLine("Calls", tostring(st.n), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Calls per second", string.format("%.1f", st.n / (W._pendingInterval or MemDebug:GetInterval())), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Total measured CPU", string.format("%.3f ms", st.timeSum or 0), 1, 1, 1, 1, 1, 1)
    if st.allocN and st.allocN > 0 then
      GameTooltip:AddDoubleLine("Allocated average / maximum", string.format("%.2f / %.2f KiB", st.allocSum / st.allocN / 1024, (st.allocMax or 0) / 1024), 1, 1, 1, 1, 1, 1)
    end
    if st.native and st.selfTimeSum ~= nil then
      GameTooltip:AddDoubleLine("Self average per call", string.format("%.3f ms", st.selfTimeSum / st.n), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Inclusive average per call", string.format("%.3f ms", st.timeSum / st.n), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Peak sampled self average", string.format("%.3f ms", st.selfTimeMax or 0), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Peak sampled inclusive average", string.format("%.3f ms", st.timeMax or 0), 1, 1, 1, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine("Average per call", string.format("%.3f ms", st.timeSum / st.n), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine(st.native and "Peak sampled average" or "Slowest measured call", string.format("%.3f ms", st.timeMax or 0), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine(st.native and "Latest sampled average" or "Latest measured call", string.format("%.3f ms", st.timeLast or 0), 1, 1, 1, 1, 1, 1)
    end
    if st.activeFrames and st.activeFrames > 0 then
      GameTooltip:AddDoubleLine("Active frames", tostring(st.activeFrames), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("CPU per active frame", string.format("%.3f ms", st.timeSum / st.activeFrames), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Worst frame", string.format("%.3f ms", st.frameTimeMax), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Calls per active frame", string.format("%.1f", st.n / st.activeFrames), 1, 1, 1, 1, 1, 1)
      GameTooltip:AddDoubleLine("Most calls in one frame", tostring(st.frameCallsMax), 1, 1, 1, 1, 1, 1)
    end
    if st.phaseOrder then
      for j = 1, #st.phaseOrder do
        local name = st.phaseOrder[j]
        local phase = st.phases[name]
        GameTooltip:AddDoubleLine("Phase: " .. name, string.format("%.3f ms avg / %.3f ms peak", phase.timeSum / phase.n, phase.timeMax), 1, 1, 1, 1, 1, 1)
      end
    end
    local snap = W._pendingSnapshot or W.lastSnapshot or {}
    GameTooltip:AddDoubleLine("Measurement window", string.format("%.2f seconds", snap.__interval or MemDebug:GetInterval()), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(st.native and "Calls and CPU use the same sampled window; peaks are sample averages, not individual calls." or "Calls, CPU, allocations and phases use the same window. Frame averages exclude idle frames. Nested measurements overlap.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  row:HookScript("OnHide", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)

  W.rows[i] = row
  return row
end


function W:OnSnapshot(snapshot)
  self.lastSnapshot = snapshot or {}
  self._stoppedSnapshot = nil
  if self.frame and self.frame:IsShown() then
    self:Refresh(snapshot)
  end
end

function W:FreezeForStop()
  local now = _nowPrecise()
  local cpu = MemDebug and MemDebug.CPU
  cpu:PollNative(now)
  self._stoppedSnapshot = self._stoppedSnapshot or {}
  local snap = MemDebug:BuildRollingSnapshot(MemDebug:GetInterval(), now, self._stoppedSnapshot)

  if type(snap) == "table" then
    snap.__time = snap.__time or now
    snap.__interval = snap.__interval or ((MemDebug and MemDebug.GetInterval and MemDebug:GetInterval()) or 10)
    self.lastSnapshot = snap
    self._pendingSnapshot = snap
    self._pendingInterval = snap.__interval
    self._buildInProgress = false
    if self._buildRoot and self._treeIndex then
      self:_ApplySnapshot(snap)
    end
    if MemDebug then
      MemDebug._lastSnapshot = snap
    end
  end
end

function W:_RenderSummary()
  local f = self.frame
  local cpu = MemDebug.CPU
  local snap = self._pendingSnapshot or {}
  local debuggingEnabled = MemDebug:IsDebuggingEnabled()
  local enabled = MemDebug:IsEnabled()
  local interval = snap.__interval or MemDebug:GetInterval()
  local total = 0
  if type(snap["Events.Total"]) == "number" then total = total + snap["Events.Total"] end
  if type(snap["Funcs.Total"]) == "number" then total = total + snap["Funcs.Total"] end

  local statusWord = not debuggingEnabled and "Debugging disabled" or enabled and "Recording" or "Stopped"
  if self._buildInProgress then statusWord = statusWord .. " / building list" end
  f._statusText:SetText(string.format("%s   |   %s   |   Window %.2f s   |   %d recorded calls/events",
    statusWord, MemDebug:GetLoadMode() == "full" and "Full" or MemDebug:GetLoadMode() == "light" and "Light" or "No capture", interval, total))
  local overview = cpu:GetOverview(snap.__windowSeconds or MemDebug:GetInterval(), snap.__windowEnd)
  local memory = cpu:GetAddonMemoryKB()
  local memoryText = memory and string.format("%.0f KiB", memory) or "unavailable"
  if overview then
    f._nativeText:SetText(string.format("Native addon CPU - %s: %.2f ms total / %.3f ms per frame avg / %.3f peak   |   Addon memory: %s",
      MemDebug:GetAddonDisplayName(overview.addonName), overview.recentMs or 0,
      overview.recentAverageMs or 0, overview.recentPeakMs or 0, memoryText))
  else
    f._nativeText:SetText(debuggingEnabled and ("Native addon CPU: unavailable   |   Addon memory: " .. memoryText)
      or "Choose addons and files in Settings, then enable debugging to record.")
  end
end

function W:Refresh(snapshot)

  if self._inRefresh then return end
  self._inRefresh = true


  local f = _ensureFrame()

  -- Module discovery is owned by DropIn/Attach during source-file load.

  -- The module picker is settings-only; do not rebuild it on the stats refresh while hidden.
  if f._settingsFrame and f._settingsFrame:IsShown() then
    _refreshModulePanel(f)
  end

  f._noCallsBox._cb:SetChecked(_showRowsWithNoCalls())
  f._allocationsBox._cb:SetChecked(displaySettings.showAllocations)
  local debuggingEnabled = MemDebug:IsDebuggingEnabled()
  local enabled = MemDebug:IsEnabled()
  local canReload = not InCombatLockdown()
  f._debuggingBtn:SetText(debuggingEnabled and "Disable debugging (reload)" or "Enable debugging (reload)")
  f._debuggingBtn:SetEnabled(canReload)
  _applyFontSafe(f._wrappingText, W.fontSize or 14, nil)
  if MemDebug:GetLoadMode() == "full" then
    f._wrappingText:SetText("Wrapping: enabled (Full)")
    f._wrappingText:SetTextColor(1, 0.65, 0.2)
  elseif debuggingEnabled then
    f._wrappingText:SetText("Wrapping: disabled (Light)")
    f._wrappingText:SetTextColor(1, 0.8, 0.3)
  else
    f._wrappingText:SetText("Wrapping: disabled")
    f._wrappingText:SetTextColor(0.35, 0.9, 0.45)
  end
  f._startBtn:SetEnabled(debuggingEnabled and not enabled)
  f._stopBtn:SetEnabled(debuggingEnabled and enabled)
  f._lightModeBtn:SetEnabled(debuggingEnabled and canReload)
  f._fullModeBtn:SetEnabled(debuggingEnabled and canReload)
  f._debugModeLabel:SetText(debuggingEnabled and ("Debugging: " .. MemDebug:GetDebugMode()) or "Debugging: disabled")
  f._scriptProfileText:SetText("scriptProfile CVar: " .. (MemDebug.CPU:IsScriptProfileEnabled() and "ON" or "OFF"))
  f._modeHelpText:SetText(debuggingEnabled
    and "Start and Stop work in combat. Addon and file selections reload in Full mode and apply live in Light mode. Disable debugging and reload before normal play."
    or "Choose files, then enable debugging. Enabling and disabling reload. Start and Stop are unavailable while debugging is disabled.")



  local snap = snapshot
  local liveMode = enabled
  local cpu = MemDebug.CPU
  if enabled and not snap then
    self._liveSnapshot = self._liveSnapshot or {}
    snap = MemDebug:BuildRollingSnapshot(MemDebug:GetInterval(), nil, self._liveSnapshot)
    liveMode = true
  end

  -- When stopped, freeze the last live view captured by Stop().
  if not snap and not enabled and self._stoppedSnapshot then
    snap = self._stoppedSnapshot
  end

  -- Prefer snapshot view, but fall back to live counters so the UI is never "blank".
  if not snap then
    snap = self.lastSnapshot
    if not snap or next(snap) == nil then
      snap = MemDebug:GetLastSnapshot()
    end

    if not snap or next(snap) == nil then
      snap = MemDebug._counts or {}
      liveMode = true
    end
  end

  snap = snap or {}



  self._pendingSnapshot = snap
  self._pendingInterval = snap.__interval or (MemDebug.GetInterval and MemDebug:GetInterval()) or 10
  self._pendingEnabled = enabled
  self._pendingLiveMode = liveMode

  local registrationVersion = cpu and cpu._registrationVersion or 0
  local topologyChanged = not self._buildRoot or self._builtRegistrationVersion ~= registrationVersion
    or self._builtAddonRegistrationVersion ~= MemDebug._addonRegistrationVersion
  if topologyChanged then
    if not self._buildInProgress then
      self:_StartDeferredBuild(snap)
    end
  elseif not self._buildInProgress then
    self:_ApplySnapshot(snap)
    self:_RenderFlat()
  end


  self:_RenderSummary()
  self._inRefresh = nil
end


function W:Open()
  local f = _ensureFrame()
  f:Show()
  self:Refresh()
end

function W:Toggle()
  local f = _ensureFrame()
  if f:IsShown() then
    f:Hide()
  else
    self:Open()
  end
end
