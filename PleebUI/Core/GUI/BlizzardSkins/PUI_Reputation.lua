local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme
local bars = setmetatable({}, { __mode = "k" })

local function PaintBar(bar)
  local color = Theme.GetColors().accent
  bar:SetStatusBarColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, color[4])
end

local function RefreshBarTheme()
  for bar in pairs(bars) do
    bar:SetStatusBarTexture(Theme.GetBarTexture())
    PaintBar(bar)
  end
end

local function RefreshHeader(row)
  local collapsed = row:IsCollapsed()
  if issecretvalue(collapsed) then return end
  Theme.ApplyExpandCollapseTexture(row.Right, not collapsed)
  Theme.ApplyExpandCollapseTexture(row.HighlightRight, not collapsed)
end

local function RefreshToggle(toggle)
  local collapsed = toggle:GetHeader():IsCollapsed()
  if not issecretvalue(collapsed) then Theme.ApplyExpandCollapseButton(toggle, not collapsed) end
end

local function InstallRow(row)
  local surface = Skins.Surface(row, true)
  -- Native selection/at-war artwork sits one level below the row.
  surface:SetFrameLevel(math.max(0, row:GetFrameLevel() - 2))
  if row.Right then
    for _, key in ipairs({ "Left", "Middle", "HighlightLeft", "HighlightMiddle" }) do Skins.Hide(row[key]) end
    Skins.Font(row.Name, "nav")
    Skins.Hook(row, "Initialize", RefreshHeader)
    RefreshHeader(row)
    return
  end

  Skins.Font(row.Content.Name)
  local bar = row.Content.ReputationBar
  Skins.Hide(bar.LeftTexture)
  Skins.Hide(bar.RightTexture)
  bar.Background:SetColorTexture(0, 0, 0, 0.6)
  Skins.Bar(bar)
  Skins.Font(bar.BarText, "tiny")
  bars[bar] = true
  Skins.Hook(bar, "UpdateBarColor", PaintBar)
  PaintBar(bar)
  if row.ToggleCollapseButton then
    Skins.Hook(row.ToggleCollapseButton, "RefreshIcon", RefreshToggle)
    RefreshToggle(row.ToggleCollapseButton)
  end
  -- Account-wide, bonus, paragon reward and at-war indicators remain native.
end

local function RefreshRow(row)
  if row.Right then
    RefreshHeader(row)
  elseif row.ToggleCollapseButton then
    RefreshToggle(row.ToggleCollapseButton)
  end
end

local function RefreshRows(frame)
  Skins.ScrollRows(frame.ScrollBox, InstallRow, RefreshRow)
  RefreshBarTheme()
end

Skins.Register("Blizzard_UIPanels_Game", "ReputationFrame", {
  install = function(frame)
    Skins.Dropdown(frame.filterDropdown)
    Skins.ScrollBar(frame.ScrollBar)
  end,
  onShow = RefreshRows,
  onTheme = RefreshBarTheme,
  manageControls = false,
})
