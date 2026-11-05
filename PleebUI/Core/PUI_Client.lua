local _, ns = ...
local interface = select(4, GetBuildInfo())
local Client = { IsForever = interface >= 16000 and interface < 20000 }
ns.Client = Client

if Client.IsForever then
  local _, _, classID = UnitClass("player")

  function Client.GetNumSpecializations()
    return C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
  end
end
