local _, ns = ...
local Skins, Theme = ns.BlizzardSkins, ns.Theme

local function RefreshHeader(row)
  if not Skins.CanStyle() then return end
  local collapsed = row:IsCollapsed()
  if issecretvalue(collapsed) then return end
  Theme.ApplyExpandCollapseTexture(row.Right, not collapsed)
  Theme.ApplyExpandCollapseTexture(row.HighlightRight, not collapsed)
end

local function RefreshHeaderText(row)
  if not Skins.CanStyle() then return end
  local color = Theme.GetColors().text
  row.Name:SetTextColor(color[1], color[2], color[3], color[4])
end

local function RefreshToggle(toggle)
  if not Skins.CanStyle() then return end
  local collapsed = toggle:GetHeader():IsCollapsed()
  if not issecretvalue(collapsed) then Theme.ApplyExpandCollapseButton(toggle, not collapsed) end
end

local function InstallRow(row)
  local surface = Skins.Surface(row, true)
  surface:SetFrameLevel(math.max(0, row:GetFrameLevel() - 2))
  if row.Right then
    for _, key in ipairs({ "Left", "Middle", "HighlightLeft", "HighlightMiddle" }) do Skins.Hide(row[key]) end
    Skins.Font(row.Name, "nav")
    Skins.Hook(row, "UpdateCollapsedState", RefreshHeader)
    Skins.Hook(row, "CheckHighlightTitle", RefreshHeaderText)
    RefreshHeader(row)
  elseif row.ToggleCollapseButton then
    Skins.Font(row.Text)
    Skins.Hook(row.ToggleCollapseButton, "RefreshIcon", RefreshToggle)
    RefreshToggle(row.ToggleCollapseButton)
  else
    -- Native quantity colors distinguish empty currencies; never inspect amounts for styling.
    Theme.ApplyFont(row.Content.Name, "body")
    Theme.ApplyFont(row.Content.Count, "body")
    local icon = row.Content.CurrencyIcon
    Skins.Icon(icon)
    local border = CreateFrame("Frame", nil, row.Content)
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    border:SetFrameLevel(math.max(0, row.Content:GetFrameLevel() - 1))
    Skins.Surface(border, true)
  end
  -- Watched-currency checkmarks, account icons and selection opacity stay native.
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
end

Skins.Register("Blizzard_TokenUI", "TokenFrame", {
  install = function(frame)
    Skins.Dropdown(frame.filterDropdown)
    Skins.ScrollBar(frame.ScrollBar)
  end,
  onShow = RefreshRows,
  manageControls = false,
})
