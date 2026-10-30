local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
local Addon = ns.Addon
for _, key in ipairs({ "combatTab", "cursorTab", "groupTab" }) do Addon:UnregisterOptionsSection(key) end
local Runtime = {}
ns.CombatToolsRuntime = Runtime
local host = CreateFrame("Frame")
host:Hide()
local jobs = {}
local requests = {}
local ownerGenerations = {}

local function UpdateHost()
  if #jobs > 0 then
    host:RegisterEvent("PLAYER_LOGIN")
    host:RegisterEvent("PLAYER_ENTERING_WORLD")
    host:Show()
  else
    host:UnregisterAllEvents()
    host:Hide()
  end
end

function Runtime:Request(owner, method, argument)
  local pending = requests[owner]
  if not pending then
    pending = {}
    requests[owner] = pending
  end
  local job = pending[method]
  if not job then
    job = { owner = owner, method = method, generation = ownerGenerations[owner] }
    pending[method] = job
    jobs[#jobs + 1] = job
  end
  if type(argument) == "table" then
    if type(job.argument) ~= "table" then job.argument = {} end
    for key, value in pairs(argument) do job.argument[key] = value end
  else
    job.argument = argument
  end
  UpdateHost()
end

function Runtime:Cancel(owner)
  ownerGenerations[owner] = (ownerGenerations[owner] or 0) + 1
  requests[owner] = nil
  for index = #jobs, 1, -1 do
    if jobs[index].owner == owner then table.remove(jobs, index) end
  end
  UpdateHost()
end

local function Flush()
  host:Hide()
  local pending = jobs
  jobs = {}
  requests = {}
  for index = 1, #pending do
    local job = pending[index]
    if job.generation == ownerGenerations[job.owner]
      and (job.owner == ns.Modules.CombatQuality or job.owner:IsEnabled())
    then
      job.owner[job.method](job.owner, job.argument)
    end
  end
  UpdateHost()
end

host:SetScript("OnEvent", Flush)
host:SetScript("OnUpdate", Flush)
