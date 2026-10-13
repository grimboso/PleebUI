local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins

Skins.Register("Blizzard_ProfessionsCustomerOrders", "ProfessionsCustomerOrdersFrame.Form.CurrentListings", {
  install = function(frame)
    Skins.Shell(frame)
    Templates.TableList(frame.OrderList)
  end,
  onShow = function(frame) Templates.TableRows(frame.OrderList) end,
})
