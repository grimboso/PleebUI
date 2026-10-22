local addonName = ...
local pleebug = LibStub("LibPleebug-1")
pleebug:RegisterAddon(addonName, "Chat", {
  PUI_Chat = "Chat",
  PUI_ChatArchive = "Chat Archive",
  PUI_ChatTabs = "Chat Tabs",
  PUI_ChatFocus = "Chat Focus",
  PUI_ChatWindows = "Chat Windows",
  PUI_ChatHistory = "Chat History",
  PUI_ChatHistoryDB = "Chat History Database",
}, 9)
