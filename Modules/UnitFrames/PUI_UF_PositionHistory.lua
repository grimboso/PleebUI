local _, ns = ...

local UF = ns.Modules.UnitFrames
local POSITION_UNITS = { "target", "focus", "boss1" }
local POSITION_FIELDS = { "point", "relativeTo", "relativePoint", "x", "y", "contextPositions" }

ns.FrameUtil.RegisterEditHistoryParticipant("unit-frame-positions", function()
  local profile = UF.db.profile
  local state = { settings = profile.positionContexts, editing = UF._positionEditContexts, units = {} }
  for _, unit in ipairs(POSITION_UNITS) do
    local position = {}
    for _, key in ipairs(POSITION_FIELDS) do position[key] = profile.units[unit][key] end
    state.units[unit] = position
  end
  return state
end, function(state)
  if InCombatLockdown() then return end
  UF.db.profile.positionContexts = state.settings
  UF._positionEditContexts = state.editing
  UF._pendingPositionGroup = nil
  for _, unit in ipairs(POSITION_UNITS) do
    local config = UF.db.profile.units[unit]
    for _, key in ipairs(POSITION_FIELDS) do config[key] = state.units[unit][key] end
  end
  UF:ApplyActivePositionHolders()
  for _, unit in ipairs(POSITION_UNITS) do UF:RefreshPositionEditing(unit) end
end)
