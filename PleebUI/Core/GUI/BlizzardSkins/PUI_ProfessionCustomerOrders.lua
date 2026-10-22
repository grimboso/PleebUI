local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

local categorySurfaces = setmetatable({}, { __mode = "k" })

local function PaintCategory(row)
  if row.isSpacer then
    local surface = categorySurfaces[row]
    if surface then surface:Hide() end
    return
  end

  local surface = categorySurfaces[row]
  if not surface then
    surface = Skins.Surface(row, false, true)
    categorySurfaces[row] = surface
  end
  surface:Show()
  Skins.Hide(row.NormalTexture)
  Skins.Hide(row.Lines)
  row.SelectedTexture:SetDrawLayer("BACKGROUND", 1)
  row.SelectedTexture:SetAllPoints(row)
  row.SelectedTexture:SetBlendMode("BLEND")
  Skins.Selection(row.SelectedTexture, 0.18)
  row.HighlightTexture:SetDrawLayer("BACKGROUND", 2)
  row.HighlightTexture:SetAllPoints(row)
  row.HighlightTexture:SetBlendMode("BLEND")
  row.HighlightTexture:SetColorTexture(1, 1, 1, 0.10)
  ns.Theme.ApplyFont(row.Text, "body")
  row.Text:SetHeight(0)
  row.Text:SetDrawLayer("OVERLAY")
end

local function InstallCategory(row)
  Skins.Hook(row, "Init", PaintCategory)
  PaintCategory(row)
end

local function RefreshCustomerOrders(frame)
  Templates.TableRows(frame.BrowseOrders.RecipeList)
  Templates.TableRows(frame.MyOrdersPage.OrderList)
  Skins.ScrollRows(frame.BrowseOrders.CategoryList.ScrollBox, InstallCategory, PaintCategory)
end

Skins.Register("Blizzard_ProfessionsCustomerOrders", "ProfessionsCustomerOrdersFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Tab(frame.BrowseTab)
    Skins.Tab(frame.OrdersTab)
    Skins.Chrome(frame.MoneyFrameInset)
    Skins.Chrome(frame.MoneyFrameBorder)
    for _, region in ipairs({ frame.MoneyFrameBorder:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    local browse = frame.BrowseOrders
    Skins.Chrome(browse.CategoryList)
    local categoryScrollBox = browse.CategoryList.ScrollBox
    local categoryScrollBar = browse.CategoryList.ScrollBar
    Skins.Surface(categoryScrollBox, true, true)
    Skins.ScrollBar(categoryScrollBar)
    categoryScrollBar:ClearAllPoints()
    categoryScrollBar:SetPoint("TOPLEFT", categoryScrollBox, "TOPRIGHT", 4, 0)
    categoryScrollBar:SetPoint("BOTTOMLEFT", categoryScrollBox, "BOTTOMRIGHT", 4, 4)
    Skins.EditBox(browse.SearchBar.SearchBox)
    Skins.Button(browse.SearchBar.SearchButton, true)
    Skins.Dropdown(browse.SearchBar.FilterDropdown)
    Templates.TableList(browse.RecipeList)
    Templates.TableList(frame.MyOrdersPage.OrderList)
    RefreshCustomerOrders(frame)
  end,
  onShow = RefreshCustomerOrders,
})
