local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins
local tabs = setmetatable({}, { __mode = "k" })

local function RefreshSpecTabs(page)
  for tab in page.tabsPool:EnumerateActive() do
    if not tabs[tab] then
      tabs[tab] = true
      Skins.Tab(tab)
    end
  end
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame.SpecPage", {
  install = function(page)
    for _, button in ipairs({ page.ApplyButton, page.UnlockTabButton, page.ViewTreeButton,
      page.ViewPreviewButton, page.BackToFullTreeButton, page.BackToPreviewButton,
      page.DetailedView.UnlockPathButton, page.DetailedView.SpendPointsButton }) do Skins.Button(button, true) end
    for _, region in ipairs({ page.PanelFooter:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Skins.Hide(page.TopDivider)
    Skins.Hide(page.VerticalDivider)
    Templates.Fonts(page.TreeView)
    Templates.Fonts(page.DetailedView)
    Templates.Fonts(page.DetailedView.UnspentPoints)
    Templates.Fonts(page.TreePreview)
    RefreshSpecTabs(page)
    Skins.Hook(page, "UpdateTabs", RefreshSpecTabs)
    -- Tree paths, dials, unlock states and knowledge animations remain native.
  end,
  onShow = RefreshSpecTabs,
})
