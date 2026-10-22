local _, childNamespace = ...
local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
ns.oUF = childNamespace.oUF

local Runtime = {}
ns.UFRuntime = Runtime
local host = CreateFrame("Frame")
host:Hide()
local starts = {}
local jobs = {}
local requests = {}
local moduleOrder = { "UnitFrames", "PartyFrames", "RaidFrames", "CastBar" }

local function UpdateHost()
  if next(starts) or #jobs > 0 then
    host:RegisterEvent("PLAYER_LOGIN")
    host:RegisterEvent("PLAYER_ENTERING_WORLD")
    host:Show()
  else
    host:UnregisterAllEvents()
    host:Hide()
  end
end

function Runtime:ScheduleStart(owner)
  starts[owner] = true
  UpdateHost()
end

function Runtime:Request(owner, method, argument)
  local pending = requests[owner]
  if not pending then
    pending = {}
    requests[owner] = pending
  end
  local job = pending[method]
  if not job then
    job = { owner = owner, method = method }
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
  starts[owner] = nil
  requests[owner] = nil
  for index = #jobs, 1, -1 do
    if jobs[index].owner == owner then table.remove(jobs, index) end
  end
  UpdateHost()
end

local function Flush()
  host:Hide()
  for index = 1, #moduleOrder do
    local owner = ns.Modules[moduleOrder[index]]
    if owner and starts[owner] then
      starts[owner] = nil
      if owner:IsEnabled() then owner:StartRuntime() end
    end
  end
  local pending = jobs
  jobs = {}
  requests = {}
  for index = 1, #pending do
    local job = pending[index]
    if job.owner:IsEnabled() then
      job.owner[job.method](job.owner, job.argument)
    end
  end
  UpdateHost()
end

host:SetScript("OnEvent", Flush)
host:SetScript("OnUpdate", Flush)
