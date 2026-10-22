local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local Addon = ns.Addon
local Store = {}
ns.ChatHistoryStore = Store

function Store.Open()
  _G.PleebUIChatHistoryDB = _G.PleebUIChatHistoryDB or {}
  local saved = _G.PleebUIChatHistoryDB
  saved.char = saved.char or {}
  for character, source in pairs(Addon.db.sv.char or {}) do
    if source.chatHistoryLog then
      local target = saved.char[character]
      if not target then
        target = {}
        saved.char[character] = target
      end
      if target.chatHistoryLog == nil then
        target.chatHistoryLog = source.chatHistoryLog
        source.chatHistoryLog = nil
      end
    end
  end
  local global = Addon.db.sv.global
  if global and global.chatHistoryLog then
    saved.global = saved.global or {}
    if saved.global.chatHistoryLog == nil then
      saved.global.chatHistoryLog = global.chatHistoryLog
      global.chatHistoryLog = nil
    end
  end
  return LibStub("AceDB-3.0"):New("PleebUIChatHistoryDB", { char = {}, global = {} })
end
