local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

local function RefreshOrders(page)
  Templates.RecipeRows(page.BrowseFrame.RecipeList)
  Templates.RefreshForm(page.OrderView.OrderDetails.SchematicForm)
  Templates.TableRows(page.BrowseFrame.OrderList)
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame.OrdersPage", {
  install = function(page)
    local browse = page.BrowseFrame
    Templates.RecipeList(browse.RecipeList)
    Templates.TableList(browse.OrderList)
    Skins.Button(browse.SearchButton, true)
    Skins.Arrow(browse.BackButton, "<")
    for _, tab in ipairs({ browse.PublicOrdersButton, browse.GuildOrdersButton, browse.NpcOrdersButton, browse.PersonalOrdersButton }) do Skins.Tab(tab) end
    Skins.Hide(browse.OrdersRemainingDisplay.Background)
    Templates.Fonts(browse.OrdersRemainingDisplay)
    local view = page.OrderView
    for _, button in ipairs({ view.CreateButton, view.CompleteOrderButton, view.StartRecraftButton, view.StopRecraftButton,
      view.OrderInfo.BackButton, view.OrderInfo.StartOrderButton, view.OrderInfo.DeclineOrderButton, view.OrderInfo.ReleaseOrderButton }) do Skins.Button(button, true) end
    Templates.Rank(view.RankBar)
    Templates.Fonts(view.ConcentrationDisplay)
    Skins.Chrome(view.OrderInfo)
    Templates.Fonts(view.OrderInfo)
    Skins.Hide(view.OrderInfo.NoteBox.Background.Border)
    Templates.Fonts(view.OrderInfo.NoteBox)
    Templates.Fonts(view.OrderInfo.OrderReagentsWarning)
    Skins.Hide(view.OrderInfo.NPCRewardsFrame.Background)
    Templates.Fonts(view.OrderInfo.NPCRewardsFrame)
    Templates.Item(view.OrderInfo.NPCRewardsFrame.RewardItem1)
    Templates.Item(view.OrderInfo.NPCRewardsFrame.RewardItem2)
    Skins.Chrome(view.OrderDetails)
    Templates.Schematic(view.OrderDetails.SchematicForm)
    Templates.Fonts(view.OrderDetails.FulfillmentForm)
    Templates.Note(view.OrderDetails.FulfillmentForm.NoteEditBox)
    -- Sorting, commissions, reagent ownership, glow alerts and completion stay native.
  end,
  onShow = RefreshOrders,
})
