local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

local function RepaintCategory(row)
  ns.Theme.ApplyFont(row.Text, "body")
  row.Text:SetHeight(0)
end

local function InstallCategory(row)
  Skins.Hide(row.NormalTexture)
  row.SelectedTexture:SetDrawLayer("BACKGROUND", 1)
  row.SelectedTexture:SetAllPoints(row)
  Skins.Selection(row.SelectedTexture, 0.07)
  row.HighlightTexture:SetColorTexture(1, 1, 1, 0.06)
  row.HighlightTexture:SetAllPoints(row)
  RepaintCategory(row)
end

local function RefreshCustomerOrders(frame)
  Templates.TableRows(frame.BrowseOrders.RecipeList)
  Templates.TableRows(frame.MyOrdersPage.OrderList)
  Skins.ScrollRows(frame.BrowseOrders.CategoryList.ScrollBox, InstallCategory, RepaintCategory)
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
    Skins.ScrollBar(browse.CategoryList.ScrollBar)
    Skins.EditBox(browse.SearchBar.SearchBox)
    Skins.Button(browse.SearchBar.SearchButton, true)
    Skins.Dropdown(browse.SearchBar.FilterDropdown)
    Templates.TableList(browse.RecipeList)
    Templates.TableList(frame.MyOrdersPage.OrderList)
    RefreshCustomerOrders(frame)
  end,
  onShow = RefreshCustomerOrders,
})
