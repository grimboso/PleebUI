local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

local function RefreshProfessions(frame)
  Templates.Tabs(frame.TabSystem)
  Templates.RecipeRows(frame.CraftingPage.RecipeList)
  Templates.RefreshForm(frame.CraftingPage.SchematicForm)
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Templates.Tabs(frame.TabSystem)
    Skins.Hook(frame, "UpdateTabs", function() Templates.Tabs(frame.TabSystem) end)
    local page = frame.CraftingPage
    for _, button in ipairs({ page.CreateButton, page.CreateAllButton, page.ViewGuildCraftersButton }) do Skins.Button(button, true) end
    Templates.Spinner(page.CreateMultipleInputBox)
    Skins.EditBox(page.MinimizedSearchBox)
    Templates.RecipeList(page.RecipeList)
    Templates.Schematic(page.SchematicForm)
    Templates.Rank(page.RankBar)
    Templates.Fonts(page.ConcentrationDisplay)
    for _, button in ipairs(page.InventorySlots) do
      Skins.Surface(button, true, true)
      Skins.Icon(button.icon)
    end
    -- Native help, profession-link, maximize/minimize and cast-bar handlers stay intact.
  end,
  onShow = RefreshProfessions,
})
