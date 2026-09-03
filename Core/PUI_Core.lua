local ADDON_NAME, ns = ...

_G.C_AddOns.LoadAddOn("Blizzard_AuraContainer")

ns.Name = ADDON_NAME
ns.LSM = LibStub("LibSharedMedia-3.0")
ns.Modules = {}

ns.Registry = {
  Modules = {},
  Options = {},
  Movers = {},
  Widgets = {},
  EditModeParticipants = {},
  TestModeParticipants = {},
  TestModeControls = {},
}

ns.Flags = {
  IsEditing = false,
  FirstRunPending = true,
  OptionsReady = false,
}

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")
local LibDualSpec = LibStub("LibDualSpec-1.0")
ns.Pleebug = LibStub("LibPleebug-1")

ns.Pixel = {
  Round = function(value)
    return ns.FrameScale:Scale(value)
  end,
}

local Addon = AceAddon:NewAddon(ADDON_NAME, "NumyAceEvent-3.0")
ns.Addon = Addon

function Addon:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ADDON_NAME .. "|r: " .. tostring(message))
end

function Addon:PUI_ResetAndReload(resetFn)
  if InCombatLockdown() then
    self:Print("Cannot reset while in combat.")
    return false
  end

  self:PUI_ConfirmResetAndReload({
    title = "Reset Profile",
    text = "Reset the current profile to defaults?\n\nThis will reload the UI.",
    yesText = "Reset + Reload",
    resetFn = resetFn,
  })

  return true
end

function Addon:Slash_PUI(input)
  local command = (input:match("^%s*(%S+)") or ""):lower()

  if command == "" then
    self:OpenOptions()
    return
  end

  if command == "test" then
    if InCombatLockdown() then
      self:Print("Cannot toggle test mode while in combat.")
      return
    end

    self:SetEditMode(not self:IsEditMode())
    return
  end

  if command == "install" or command == "setup" then
    self:ShowInstallWizard(true)
    return
  end

  self:OpenOptions()
end

SLASH_PCM1 = "/cd"
function SlashCmdList.PCM()
  if not InCombatLockdown() then
    CooldownViewerSettings:TogglePanel()
  end
end

SLASH_PUI1 = "/pui"
function SlashCmdList.PUI(message)
  Addon:Slash_PUI(message)
end

SLASH_PUI_TEST1 = "/test"
SLASH_PUI_TEST2 = "/puitest"
function SlashCmdList.PUI_TEST()
  Addon:Slash_PUI("test")
end

SLASH_PLEEBUI_EDIT1 = "/pe"
function SlashCmdList.PLEEBUI_EDIT()
  Addon:SetEditMode(not Addon:IsEditMode())
end

SLASH_PLEEBUI_DEBUG1 = "/puidbg"
function SlashCmdList.PLEEBUI_DEBUG()
  Addon:Slash_PUIDBG()
end

SLASH_PUI_KEYBIND1 = "/kb"
function SlashCmdList.PUI_KEYBIND()
  LibStub("LibKeyBound-1.0"):Toggle()
end

local DB_DEFAULTS = {
  profile = {
    debug          = false,

    blizzardFonts = {},
    pui = {
      schemaVersion = 6,

      media = {
        iconTextGlobalFont  = "FiraSans Heavy",
        iconTextGlobalFlags = "OUTLINE",
        fontSizeOffset      = 0,
        fontSizeScopes = {
          general         = true,
          options         = true,
          unitFrames      = true,
          actionBars      = true,
          cooldownManager = true,
          resourceDisplay = true,
          playerBuffs     = true,
          minimap         = true,
          qualityOfLife   = true,
        },
      },

      options = {
        puiOptionsFontSize = 14,
        optionsScale       = 1.0,

        skin = {
          widgetRowBackgrounds = true,
        },
      },


      -- Blizzard status tracking bars (XP / Rep / etc) mover anchor
      trackingBars = {
        point    = "BOTTOM",
        relPoint = "BOTTOM",
        x        = 0,
        y        = 160,
        scale    = 1.0,
      },
    },
  },


  char = {
    onboarding = {
      schemaVersion = 0,
      installComplete = false,
      installVersion = 0,
    },
  },

  global = {
    reloadCount = 0,
    installed   = false,
    schemaVersion = 6,
    whatsNew = {
      disabled = false,
      lastSeenRelease = "1.0",
    },
    onboarding = {
      schemaVersion = 0,
      installComplete = false,
      installVersion = 0,
    },
    pui = {
      options = {
        useCustomUIScale = true,
        UIScale = 0.533333333333333,
      },
    },
  },
}




-- Character profile helpers

local function PUI_GetCharKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetNormalizedRealmName() or GetRealmName() or "Unknown"
  return name .. "-" .. realm
end

local function PUI_EnsureProfileExists(db, profileName)
  if type(db.profiles[profileName]) ~= "table" then
    db.profiles[profileName] = {}
  end
end

function Addon:EnsureAndApplyCharacterProfile()
  local db = self.db
  local profileName = db.char.characterProfileName

  if type(profileName) ~= "string" or profileName == "" or profileName == "Default" then
    profileName = PUI_GetCharKey()
    db.char.useCharacterProfiles = true
    db.char.characterProfileName = profileName
    self.__puiCreatedCharacterProfile = true
  end

  PUI_EnsureProfileExists(db, profileName)

  if not db:IsDualSpecEnabled() and db:GetCurrentProfile() ~= profileName then
    db:SetProfile(profileName)
  end
end

function Addon:GetInstallerExistingProfiles()
  local db = self.db
  local values = {}
  local order = {}
  local currentProfile = db:GetCurrentProfile()
  local profiles = db:GetProfiles({})
  table.sort(profiles)

  for i = 1, #profiles do
    local profileName = profiles[i]
    if profileName ~= "Default" and profileName ~= currentProfile then
      values[profileName] = profileName
      order[#order + 1] = profileName
    end
  end

  return values, order
end

function Addon:ActivateExistingProfile(profileName)
  local db = self.db

  if InCombatLockdown() then
    return false, "Profiles cannot be changed during combat."
  end

  if type(profileName) ~= "string" or profileName == "" then
    return false, "Select an existing profile."
  end

  if profileName == "Default" then
    return false, "The Default profile cannot be selected from the installer."
  end

  if profileName == db:GetCurrentProfile() then
    return false, "That profile is already active."
  end

  local profiles = db:GetProfiles({})
  local exists = false

  for i = 1, #profiles do
    if profiles[i] == profileName then
      exists = true
      break
    end
  end

  if not exists then
    return false, "The selected profile no longer exists."
  end

  db.char.useCharacterProfiles = true
  db.char.characterProfileName = profileName
  db:SetProfile(profileName)

  return true
end

function Addon:OnProfileChanged(event, db, newProfile)
  local root = db or self.db

  if newProfile == "Default" and not root:IsDualSpecEnabled() and not root.__puiRedirectingDefaultProfile then
    local profileName = PUI_GetCharKey()

    root.__puiRedirectingDefaultProfile = true
    root.char = root.char or {}
    root.char.useCharacterProfiles = true
    root.char.characterProfileName = profileName
    PUI_EnsureProfileExists(root, profileName)
    root:SetProfile(profileName)
    root.__puiRedirectingDefaultProfile = nil
    return
  end

  if not root:IsDualSpecEnabled() then
    root.char = root.char or {}
    root.char.useCharacterProfiles = true

    if type(newProfile) == "string" and newProfile ~= "" then
      root.char.characterProfileName = newProfile
    else
      root.char.characterProfileName = root:GetCurrentProfile()
    end
  end

  self:EnsureSchema()
  self:StaggeredUpdateAll({ profile = true, profileChanged = true, movers = true, layout = true, options = true, theme = true, fonts = true })
end

function Addon:OnProfileCopied(event, db, sourceProfile)
  self:EnsureSchema()
  self:StaggeredUpdateAll({ profile = true, profileCopied = true, movers = true, layout = true, options = true, theme = true, fonts = true })
end

function Addon:OnProfileReset(event, db)
  self:EnsureSchema()
  self:StaggeredUpdateAll({ profile = true, profileReset = true, movers = true, layout = true, options = true, theme = true, fonts = true })
end

function Addon:OnNewProfile(event, db)
  self:EnsureSchema()
  self:StaggeredUpdateAll({ profile = true, profileNew = true, movers = true, layout = true, options = true, theme = true, fonts = true })
end

local function _PUI_InstallCopyProfileConfirm(db)
  if db.__puiCopyProfileConfirmInstalled then
    return
  end

  db.__puiCopyProfileConfirmInstalled = true
  db.__puiOriginalCopyProfile = db.__puiOriginalCopyProfile or db.CopyProfile

  db.CopyProfile = function(dbObj, profileName, skipConfirm, ...)
    if skipConfirm then
      return dbObj.__puiOriginalCopyProfile(dbObj, profileName, ...)
    end

    if type(profileName) ~= "string" or profileName == "" then
      return dbObj.__puiOriginalCopyProfile(dbObj, profileName, ...)
    end

    if dbObj:GetCurrentProfile() == profileName then
      return
    end

    Addon:PUI_ConfirmAction({
      title = "Copy Profile",
      text = "This will overwrite the settings",
      yesText = ACCEPT,
      noText = CANCEL,
      onYes = function()
        dbObj:CopyProfile(profileName, true)
      end,
    })
  end
end


local PUI_SCHEMA_VERSION = 6

local function _PUI_EnsureTable(parent, key)
  if not parent then return nil end
  local v = parent[key]
  if type(v) ~= "table" then
    v = {}
    parent[key] = v
  end
  return v
end

function Addon:EnsureSchema()
  if not self.db then return end

  local g = self.db.global or {}
  self.db.global = g

  local current = tonumber(g.schemaVersion) or 0
  if current > PUI_SCHEMA_VERSION then
    -- Future DB from newer build: do not downgrade.
    return
  end

  local p = self.db.profile
  if not p then return end

  -- Ensure required root tables exist.
  _PUI_EnsureTable(p, "blizzardFonts")

  local pui = _PUI_EnsureTable(p, "pui")
  local profileSchemaVersion = tonumber(rawget(pui, "schemaVersion")) or 0

  local puiMedia = _PUI_EnsureTable(pui, "media")
  local puiOptions = _PUI_EnsureTable(pui, "options")
  local puiSkin = _PUI_EnsureTable(puiOptions, "skin")
  pui.layouts = nil
  local globalPUI = _PUI_EnsureTable(g, "pui")
  local globalOptions = _PUI_EnsureTable(globalPUI, "options")

  if puiMedia.iconTextGlobalFont == nil or puiMedia.iconTextGlobalFont == "" then
    puiMedia.iconTextGlobalFont = p.iconTextGlobalFont or "FiraSans Heavy"
  end
  if puiMedia.iconTextGlobalFlags == nil or puiMedia.iconTextGlobalFlags == "" then
    puiMedia.iconTextGlobalFlags = p.iconTextGlobalFlags or "OUTLINE"
  end

  puiMedia.fontSizeOffset = tonumber(puiMedia.fontSizeOffset) or 0
  if puiMedia.fontSizeOffset < -5 then puiMedia.fontSizeOffset = -5 end
  if puiMedia.fontSizeOffset > 10 then puiMedia.fontSizeOffset = 10 end

  local fontSizeScopes = _PUI_EnsureTable(puiMedia, "fontSizeScopes")
  if fontSizeScopes.general == nil then fontSizeScopes.general = true end
  if fontSizeScopes.options == nil then fontSizeScopes.options = true end
  if fontSizeScopes.unitFrames == nil then fontSizeScopes.unitFrames = true end
  if fontSizeScopes.actionBars == nil then fontSizeScopes.actionBars = true end
  if fontSizeScopes.cooldownManager == nil then fontSizeScopes.cooldownManager = true end
  if fontSizeScopes.resourceDisplay == nil then fontSizeScopes.resourceDisplay = true end
  fontSizeScopes.chat = nil
  if fontSizeScopes.playerBuffs == nil then fontSizeScopes.playerBuffs = true end
  if fontSizeScopes.minimap == nil then fontSizeScopes.minimap = true end
  if fontSizeScopes.qualityOfLife == nil then fontSizeScopes.qualityOfLife = true end

  puiMedia.globalFontSizeOffset = nil

  puiOptions.uiTheme = "modern"

  if profileSchemaVersion < 3 then
    if puiSkin.backgroundColor == nil then
      puiSkin.backgroundColor = puiSkin.uiShellColor
    end
    if puiSkin.accentColor == nil then
      puiSkin.accentColor = puiSkin.uiAccentColor
    end
    if puiSkin.borderColor == nil then
      puiSkin.borderColor = puiSkin.controlBorderColor
    end

    puiSkin.uiShellColor = nil
    puiSkin.uiGroupColor = nil
    puiSkin.uiChild1Color = nil
    puiSkin.uiChild2Color = nil
    puiSkin.uiAccentColor = nil
    puiSkin.controlBorderColor = nil
    puiSkin.controlHoverColor = nil
  end

  if puiOptions.puiOptionsFontSize == nil then
    puiOptions.puiOptionsFontSize = tonumber(p.puiOptionsFontSize) or 14
  end
  if puiOptions.optionsScale == nil or tonumber(puiOptions.optionsScale) == nil or tonumber(puiOptions.optionsScale) <= 0 then
    puiOptions.optionsScale = tonumber(p.optionsScale) or 1.0
  end
  local storedProfileUseCustomUIScale = rawget(puiOptions, "useCustomUIScale")
  local storedProfileUIScale = rawget(puiOptions, "UIScale")
  local storedGlobalUseCustomUIScale = rawget(globalOptions, "useCustomUIScale")
  local storedGlobalUIScale = rawget(globalOptions, "UIScale")

  if type(storedGlobalUseCustomUIScale) ~= "boolean" then
    globalOptions.useCustomUIScale = type(storedProfileUseCustomUIScale) == "boolean" and storedProfileUseCustomUIScale or true
  end
  if type(storedGlobalUIScale) ~= "number" or storedGlobalUIScale <= 0 then
    if type(storedProfileUIScale) == "number" and storedProfileUIScale > 0 and storedProfileUIScale ~= 0.533333333333333 then
      globalOptions.UIScale = storedProfileUIScale
    else
      globalOptions.UIScale = 0.533333333333333
    end
  end

  puiOptions.useCustomUIScale = nil
  puiOptions.UIScale = nil

  -- PCM roots (Core owns schema + defaults)
  local cm = _PUI_EnsureTable(p, "cooldownManager")
  if cm.enabled == nil then cm.enabled = true end

  if profileSchemaVersion < 6 then
    cm.customIconGroups = nil

    local function ClearCustomTrackerButtonGroups(root)
      if type(root) ~= "table" then
        return
      end
      for _, tracker in pairs(root) do
        if type(tracker) == "table" and type(tracker.icon) == "table" then
          tracker.icon.group = nil
        end
      end
    end

    ClearCustomTrackerButtonGroups(cm.spellBars)
    ClearCustomTrackerButtonGroups(cm.cooldownStackBars)
    ClearCustomTrackerButtonGroups(cm.stackBars)
  end

  -- Required subtables used by runtime + options
  local cmStyle = _PUI_EnsureTable(cm, "style")
  local cmBuffBarStyle = _PUI_EnsureTable(cmStyle, "buffBar")
  local cmBorders = _PUI_EnsureTable(cm, "borders")
  local cmEffects = _PUI_EnsureTable(cm, "effects")
  _PUI_EnsureTable(cm, "flags")
  _PUI_EnsureTable(cm, "viewerSwipes")
  _PUI_EnsureTable(cm, "iconSettings")
  _PUI_EnsureTable(cm, "count")

  -- Borders structure + defaults
  local bModule  = _PUI_EnsureTable(cmBorders, "module")
  local bViewer  = _PUI_EnsureTable(cmBorders, "viewer")
  local bIcon    = _PUI_EnsureTable(cmBorders, "icon")
  local bBuffBar = _PUI_EnsureTable(cmBorders, "buffBar")

  if cmBorders.enabled == nil then cmBorders.enabled = true end
  if bModule.enabled == nil then bModule.enabled = true end
  if bViewer.enabled == nil then bViewer.enabled = true end
  if bIcon.enabled == nil then bIcon.enabled = true end
  if bBuffBar.enabled == nil then bBuffBar.enabled = true end

  -- Style defaults (so Options never has to seed)
  if cmStyle.bgColor == nil then cmStyle.bgColor = { 0, 0, 0, 0.65 } end
  if cmStyle.headerTextColor == nil then cmStyle.headerTextColor = { 1, 1, 1, 1 } end
  if cmStyle.moduleTitleColor == nil then cmStyle.moduleTitleColor = { 1, 1, 1, 1 } end
  if cmStyle.viewerTitleColor == nil then cmStyle.viewerTitleColor = { 1, 1, 1, 1 } end
  if cmStyle.iconBgColor == nil then cmStyle.iconBgColor = { 0, 0, 0, 0.35 } end
  if cmStyle.buffBarBgColor == nil then cmStyle.buffBarBgColor = { 0, 0, 0, 0.5 } end
  if cmStyle.buffBarUseClassColor == nil then cmStyle.buffBarUseClassColor = true end
  if cmStyle.buffBarTextColor == nil then cmStyle.buffBarTextColor = { 1, 1, 1, 1 } end

  -- Effects defaults
  if cmEffects.hideEssential == nil then cmEffects.hideEssential = false end
  if cmEffects.hideUtility == nil then cmEffects.hideUtility = false end

  -- PCM Buffs root + minimal structure used by Options/runtimes
  local pb = _PUI_EnsureTable(p, "pcmBuffs")
  local pbStyle = _PUI_EnsureTable(pb, "style")
  local pbBorders = _PUI_EnsureTable(pb, "borders")

  _PUI_EnsureTable(pbStyle, "viewerSizes")
  _PUI_EnsureTable(pbStyle, "viewerSpacing")
  local pbViewerGrowth = _PUI_EnsureTable(pbStyle, "viewerGrowth")

  if pbStyle.iconSize == nil then pbStyle.iconSize = 36 end
  if pbStyle.iconSpacing == nil then pbStyle.iconSpacing = 1 end
  if pbViewerGrowth.BuffIconCooldownViewer == nil then pbViewerGrowth.BuffIconCooldownViewer = "CENTER" end

  if profileSchemaVersion < 4 then
    cm.editMode = nil
    cmBuffBarStyle.hideWhenInactive = nil
    pbStyle.hideWhenInactive = nil

    local editMode = p.EditMode
    local oldPositions = editMode and editMode.viewerPositions
    if type(oldPositions) == "table" then
      local oldPosition = oldPositions.BuffIconCooldownViewer
      if type(oldPosition) == "table" then
        local pbAnchor = _PUI_EnsureTable(pb, "anchor")
        if pbAnchor.BuffIconCooldownViewer == nil then
          pbAnchor.BuffIconCooldownViewer = oldPosition
        end
      end

      editMode.viewerPositions = nil
    end
  end
  pui.schemaVersion = PUI_SCHEMA_VERSION

  local pbIcon = _PUI_EnsureTable(pbBorders, "icon")
  _PUI_EnsureTable(pbIcon, "viewers")

  -- PCM Toggles (Core owns defaults)
  local t = _PUI_EnsureTable(p, "pcmToggles")
  if t.essentials == nil then t.essentials = true end
  if t.utility     == nil then t.utility     = true end
  if t.buffIcons   == nil then t.buffIcons   = true end
  if t.buffBars    == nil then t.buffBars    = true end
  if t.customProcs == nil then t.customProcs = true end

  -- Custom Cooldowns: preserve data, never delete; ensure containers exist
  local cc = _PUI_EnsureTable(p, "customCooldowns")
  _PUI_EnsureTable(cc, "trackers")


  g.schemaVersion = PUI_SCHEMA_VERSION
end

function Addon:GetMediaDB()
  return self.db.profile.pui.media
end

function Addon:GetOptionsDB()
  return self.db.profile.pui.options
end

function Addon:GetGlobalOptionsDB()
  return self.db.global.pui.options
end

local PUI_PROFILE_EXPORT_PREFIX = "PUI-PROFILE:"
local PUI_PROFILE_FORMAT = "PleebUIProfile"
local PUI_PROFILE_FORMAT_VERSION = 1

local function _PUI_CloneProfileData(value, seen)
  local valueType = type(value)
  if valueType == "nil" then
    return nil
  end
  if valueType ~= "table" then
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
      return value
    end
    return nil
  end

  seen = seen or {}
  if seen[value] then
    return seen[value]
  end

  local out = {}
  seen[value] = out

  for key, child in pairs(value) do
    local clonedKey = _PUI_CloneProfileData(key, seen)
    local clonedValue = _PUI_CloneProfileData(child, seen)
    if clonedKey ~= nil and clonedValue ~= nil then
      out[clonedKey] = clonedValue
    end
  end

  return out
end

ns.CloneProfileData = _PUI_CloneProfileData

local function _PUI_TrimProfileName(value)
  value = type(value) == "string" and value or ""
  return strtrim(value)
end

local function _PUI_GetSafeProfileName(db, requestedName, fallbackName)
  local profiles = db.profiles
  local baseName = _PUI_TrimProfileName(requestedName)

  if baseName == "" then
    baseName = _PUI_TrimProfileName(fallbackName)
  end
  if baseName == "" then
    baseName = "Imported Profile"
  end

  if type(profiles[baseName]) ~= "table" then
    return baseName
  end

  local index = 2
  local candidate = baseName .. " " .. tostring(index)
  while type(profiles[candidate]) == "table" do
    index = index + 1
    candidate = baseName .. " " .. tostring(index)
  end

  return candidate
end

local function _PUI_GetCurrentProfileName(db)
  local name = db:GetCurrentProfile()
  if type(name) == "string" and name ~= "" then
    return name
  end

  return "Profile"
end

local function _PUI_GetRootProfileExportData(db)
  local data = _PUI_CloneProfileData(db.profile)
  if type(data) ~= "table" then
    data = {}
  end

  if type(data.pui) == "table" then
    data.pui.layouts = nil
  end

  return data
end

local function _PUI_GetNamespaceProfileExportData(db, profileName)
  local out = {}

  local rawNamespaces = db.sv.namespaces
  if type(rawNamespaces) == "table" then
    for namespaceName, namespaceStore in pairs(rawNamespaces) do
      local namespaceProfiles = type(namespaceStore) == "table" and namespaceStore.profiles or nil
      local namespaceProfile = type(namespaceProfiles) == "table" and namespaceProfiles[profileName] or nil
      if type(namespaceProfile) == "table" then
        out[namespaceName] = _PUI_CloneProfileData(namespaceProfile)
      end
    end
  end

  local liveNamespaces = db.namespaces
  if type(liveNamespaces) == "table" then
    for namespaceName, namespaceDB in pairs(liveNamespaces) do
      if out[namespaceName] == nil and type(namespaceDB) == "table" and type(namespaceDB.profile) == "table" then
        out[namespaceName] = _PUI_CloneProfileData(namespaceDB.profile)
      end
    end
  end

  return out
end

local function _PUI_SetNamespaceProfileImportData(db, profileName, namespaceData)
  if type(namespaceData) ~= "table" then
    return
  end

  db.sv = db.sv or {}
  db.sv.namespaces = db.sv.namespaces or {}

  for namespaceName, data in pairs(namespaceData) do
    if type(namespaceName) == "string" and type(data) == "table" then
      db.sv.namespaces[namespaceName] = db.sv.namespaces[namespaceName] or {}
      db.sv.namespaces[namespaceName].profiles = db.sv.namespaces[namespaceName].profiles or {}
      db.sv.namespaces[namespaceName].profiles[profileName] = _PUI_CloneProfileData(data)
    end
  end
end

function Addon:ExportCurrentProfile()
  local db = self.db

  local profileName = _PUI_GetCurrentProfileName(db)
  local payload = {
    format = PUI_PROFILE_FORMAT,
    formatVersion = PUI_PROFILE_FORMAT_VERSION,
    addon = ADDON_NAME,
    profileName = profileName,
    exportedAt = date("!%Y-%m-%dT%H:%M:%SZ"),
    data = {
      profile = _PUI_GetRootProfileExportData(db),
      namespaces = _PUI_GetNamespaceProfileExportData(db, profileName),
    },
  }

  local serialized = AceSerializer:Serialize(payload)
  local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
  local encoded = compressed and LibDeflate:EncodeForPrint(compressed) or nil
  if not encoded or encoded == "" then
    return nil, "Failed to encode profile."
  end

  return PUI_PROFILE_EXPORT_PREFIX .. encoded
end

function Addon:ImportProfileString(text, targetProfileName, applyNow)
  text = type(text) == "string" and text or ""
  text = text:gsub("%s+", "")
  if text == "" then
    return false, "Import string is empty."
  end
  if text:sub(1, #PUI_PROFILE_EXPORT_PREFIX) == PUI_PROFILE_EXPORT_PREFIX then
    text = text:sub(#PUI_PROFILE_EXPORT_PREFIX + 1)
  end

  local decoded = LibDeflate:DecodeForPrint(text)
  if not decoded then
    return false, "Failed to decode profile string."
  end

  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then
    return false, "Failed to decompress profile string."
  end

  local ok, payload = AceSerializer:Deserialize(decompressed)
  if not ok or type(payload) ~= "table" then
    return false, "Failed to deserialize profile."
  end
  if payload.format ~= PUI_PROFILE_FORMAT or type(payload.data) ~= "table" then
    return false, "Imported payload is not a PleebUI profile."
  end

  local db = self.db
  local profiles = db.profiles

  local importedRoot = payload.data.profile or payload.data.root or payload.data
  if type(importedRoot) ~= "table" then
    return false, "Imported profile data is invalid."
  end

  local profileName = _PUI_GetSafeProfileName(db, targetProfileName, payload.profileName)
  local importedProfile = _PUI_CloneProfileData(importedRoot)
  if type(importedProfile.pui) == "table" then
    importedProfile.pui.layouts = nil
  end

  profiles[profileName] = importedProfile
  _PUI_SetNamespaceProfileImportData(db, profileName, payload.data.namespaces)

  if applyNow then
    db:SetProfile(profileName)
  else
    self:EnsureSchema()
    self:RequestUpdate("Options", { options = true })
  end

  return true, profileName
end



function Addon:OnInitialize()
  self.db = AceDB:New("PleebUIDB", DB_DEFAULTS, "Default")
  ns.DB = self.db

  ns.Flags.OptionsDebug = self.db.profile.debug == true
  ns.Flags.__puiBlizzardEditModeActive = ns.Flags.__puiBlizzardEditModeActive or false

  function Addon:IsBlizzardEditModeActive()
    if ns.Flags.__puiBlizzardEditModeActive then
      return true
    end

    local em = _G.EditModeManagerFrame
    if em then
      return em:IsEditModeActive() and true or false
    end

    return false
  end

  if not ns.Flags.__puiBlizzardEditModeCallbacksInstalled then
    ns.Flags.__puiBlizzardEditModeCallbacksInstalled = true

    local function _PUI_OnBlizzardEditModeEnter()
      ns.Flags.__puiBlizzardEditModeActive = true
      if Addon:IsEditMode() then
        Addon:SetEditMode(false)
      end
    end

    local function _PUI_OnBlizzardEditModeExit()
      ns.Flags.__puiBlizzardEditModeActive = false
    end

    EventRegistry:RegisterCallback("EditMode.Enter", _PUI_OnBlizzardEditModeEnter)
    EventRegistry:RegisterCallback("EditMode.Exit", _PUI_OnBlizzardEditModeExit)
  end

  self:EnsureSchema()
  ns.Theme.SeedBlizzardFontsDB(self.db.profile)

  LibDualSpec:EnhanceDatabase(self.db, ADDON_NAME)
  _PUI_InstallCopyProfileConfirm(self.db)

  self:EnsureAndApplyCharacterProfile()
  self:EnsureSchema()

  self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
  self.db.RegisterCallback(self, "OnProfileCopied",  "OnProfileCopied")
  self.db.RegisterCallback(self, "OnProfileReset",   "OnProfileReset")
  self.db.RegisterCallback(self, "OnNewProfile",     "OnNewProfile")

  ns.AceHooks.Install()

  local odb = self.db.profile.pui.options
  local os = tonumber(odb.optionsScale)
  if not os or os <= 0 then
    odb.optionsScale = 1.0
  end

  local previousReloadCount = tonumber(self.db.global.reloadCount) or 0
  local onboarding = self.db.global.onboarding

  if (tonumber(onboarding.schemaVersion) or 0) < 1 then
    onboarding.installComplete = self.db.global.installed == true or previousReloadCount > 0
    onboarding.installVersion = onboarding.installComplete and 1 or 0
    onboarding.schemaVersion = 1
    self.db.global.installed = onboarding.installComplete
  end

  local characterOnboarding = self.db.char.onboarding
  if (tonumber(characterOnboarding.schemaVersion) or 0) < 1 then
    if self.__puiCreatedCharacterProfile then
      characterOnboarding.installComplete = false
      characterOnboarding.installVersion = 0
    else
      characterOnboarding.installComplete = onboarding.installComplete == true
      characterOnboarding.installVersion = characterOnboarding.installComplete and 1 or 0
    end

    characterOnboarding.schemaVersion = 1
  end

  ns.Flags.FirstRunPending = characterOnboarding.installComplete ~= true

  self.db.global.reloadCount = previousReloadCount + 1
  self:Print("PleebUI loaded. Reload count: " .. self.db.global.reloadCount)
  self:Print("Settings: /pui")
  self:Print("Edit Mode: /pe")
  self._db_ref      = self.db
  self._profile_ref = self.db.profile

  ns.Modules.Quality:ApplyAll()

  ns.MinimapData.Initialize()
end

function Addon:RefreshIconFonts()
  local media = self.db.profile.pui.media

  ns.Theme.RefreshFontSizeOffsetCache()

  local fontKey = media.iconTextGlobalFont
  if fontKey and fontKey ~= "" then
    ns.Theme.SetIconTextGlobalFont(fontKey)
  end

  local flags = media.iconTextGlobalFlags
  if flags and flags ~= "" then
    ns.Theme.SetIconTextGlobalFlags(flags)
  end

  ns.Theme.RefreshAppliedFonts()

  ns.Modules.UnitFrames:RefreshIconFonts()
  ns.Modules.PartyFrames:RefreshText()
  ns.Modules.RaidFrames:RefreshText()
  ns.Modules.CastBar:RefreshFromProfile()
  ns.Modules.PRD:RefreshIconFonts()
  ns.Modules.ActionBar:RefreshIconFonts()
  ns.Modules.CooldownManager:RefreshIconFonts()
  ns.Registry.ChatLinks:RefreshFonts()
  ns.Modules.PlayerBuffs:RefreshFonts()
  ns.Modules.HunterTools:RefreshFonts()
  ns.Registry.Minimap:RefreshFonts()
  ns.Modules.Quality:RefreshFonts()
end

Addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
  Addon:RefreshIconFonts()
end)


local UI_Hider = _G.PleebUI_Hider
if not UI_Hider then
  UI_Hider = CreateFrame("Frame", "PleebUI_Hider", nil, "SecureFrameTemplate")
  UI_Hider:Hide()
  UI_Hider:SetAlpha(0)
end

-- Expose on the namespace so all modules can reuse it.
ns.UIHider = UI_Hider

-- Generic helper: move arbitrary regions/frames to the hider and clear visuals.
function ns.HideToHider(...)
  local h = ns.UIHider

  for i = 1, select("#", ...) do
    local region = select(i, ...)
    if region then
      local forbidden = (region.IsForbidden and region:IsForbidden()) and true or false
      if not forbidden then
        local protected = (region.IsProtected and region:IsProtected()) and true or false
        local inCombat = InCombatLockdown() and true or false

        -- If protected (or in combat), DO NOT reparent or Hide().
        -- Those are common taint triggers for UIParent-managed frames.
        if protected or inCombat then
          if region.SetAlpha then region:SetAlpha(0) end
          if region.EnableMouse then region:EnableMouse(false) end
          if region.EnableMouseWheel then region:EnableMouseWheel(false) end
          if region.SetMouseMotionEnabled then region:SetMouseMotionEnabled(false) end
          if region.SetMouseClickEnabled then region:SetMouseClickEnabled(false) end
        else
          region:SetParent(h)
          region:SetAlpha(0)
          region:Hide()

          local objType = region.GetObjectType and region:GetObjectType()
          if objType == "Texture" or objType == "MaskTexture" then
            region:SetTexture(nil)
          elseif objType == "StatusBar" then
            region:SetStatusBarTexture("")
          elseif objType == "FontString" then
            region:SetText("")
          end
        end
      end
    end
  end
end

Addon._puiUpdateBus = Addon._puiUpdateBus or {
  targets = {},
  scheduled = false,
  deferredSoft = {},
}

local PUI_PROFILE_UPDATE_TARGETS = {
  "ActionBar",
  "PartyFrames",
  "RaidFrames",
  "Dragonriding",
  "Minimap",
  "ChatLinks",
  "UnitFrames",
  "CastBar",
  "CooldownManager",
  "PlayerBuffs",
  "HunterTools",
  "PRD",
  "CharacterSheet",
  "Options",
}

local PUI_SOFT_UPDATE_TARGETS = {
  "UnitFrames",
  "CastBar",
  "CooldownManager",
  "PRD",
}

local PUI_THEME_UPDATE_TARGETS = {
  "ChatLinks",
  "CooldownManager",
  "PlayerBuffs",
  "PRD",
  "DamageMeters",
  "CharacterSheet",
  "Bags",
  "TestMode",
}

local function _PUI_UB_MergeFlags(dst, flags)
  if type(flags) == "string" then
    dst[flags] = true
    return
  end
  if type(flags) ~= "table" then return end

  for k, v in pairs(flags) do
    if type(k) == "number" then
      if type(v) == "string" then
        dst[v] = true
      end
    else
      if v then dst[k] = true end
    end
  end
end

local function _PUI_UB_ApplySoftTarget(target, flags)
  ns.Modules[target]:SoftRebuild(flags)
end

local function _PUI_UB_RequestSoftTarget(ub, target, flags)
  if InCombatLockdown() then
    local deferred = ub.deferredSoft[target]
    if not deferred then
      deferred = {}
      ub.deferredSoft[target] = deferred
    end

    _PUI_UB_MergeFlags(deferred, flags)
    return
  end

  _PUI_UB_ApplySoftTarget(target, flags)
end

local function _PUI_ST_Push(queue, name)
  queue[#queue + 1] = name
end

function Addon:RequestProfileUpdates(flags)
  for index = 1, #PUI_PROFILE_UPDATE_TARGETS do
    self:RequestUpdate(PUI_PROFILE_UPDATE_TARGETS[index], flags)
  end
end

function Addon:RequestThemeUpdates()
  for index = 1, #PUI_THEME_UPDATE_TARGETS do
    self:RequestUpdate(PUI_THEME_UPDATE_TARGETS[index], { theme = true })
  end
end

function Addon:_RunStaggeredUpdateStep(step, flags)
  flags = flags or {}

  if step == "ApplyScale" then
    self.FrameScale:ApplyUIScaleFromProfile()
  elseif step == "ApplyQuality" then
    ns.Modules.Quality:ApplyAll()
  elseif step == "RequestProfileUpdates" then
    self:RequestProfileUpdates(flags)
  elseif step == "RefreshFonts" and flags.fonts == true then
    self:RefreshIconFonts()
  end
end

function Addon:_RunNextStaggeredUpdate()
  local st = self._puiStaggeredUpdate
  if not st or st.running ~= true then
    return
  end

  local step = table.remove(st.queue, 1)
  if not step then
    local nextFlags = st.nextFlags
    st.running = false
    st.flags = nil
    st.nextFlags = nil
    st.queue = {}

    if nextFlags and next(nextFlags) then
      self:StaggeredUpdateAll(nextFlags)
    end

    return
  end

  self:_RunStaggeredUpdateStep(step, st.flags or {})
  C_Timer.After(0.02, function()
    Addon:_RunNextStaggeredUpdate()
  end)
end

function Addon:StaggeredUpdateAll(flags)
  local st = self._puiStaggeredUpdate
  if not st then
    self._puiStaggeredUpdate = { queue = {}, running = false, flags = nil, nextFlags = nil }
    st = self._puiStaggeredUpdate
  end

  if st.running == true then
    st.nextFlags = st.nextFlags or {}
    _PUI_UB_MergeFlags(st.nextFlags, flags)
    return
  end

  st.queue = {}
  st.flags = {}
  st.nextFlags = nil
  st.running = true

  _PUI_UB_MergeFlags(st.flags, flags)

  _PUI_ST_Push(st.queue, "ApplyScale")
  _PUI_ST_Push(st.queue, "ApplyQuality")
  _PUI_ST_Push(st.queue, "RequestProfileUpdates")
  _PUI_ST_Push(st.queue, "RefreshFonts")

  self:_RunNextStaggeredUpdate()
end

function Addon:RequestUpdate(target, flags)
  local ub = self._puiUpdateBus
  local targetFlags = ub.targets[target]
  if not targetFlags then
    targetFlags = {}
    ub.targets[target] = targetFlags
  end

  _PUI_UB_MergeFlags(targetFlags, flags)

  if ub.scheduled then return end
  ub.scheduled = true

  C_Timer.After(0, function()
    Addon:_FlushUpdateBus()
  end)
end

function Addon:_FlushUpdateBus()
  local ub = self._puiUpdateBus
  if not ub then return end

  local targets = ub.targets
  ub.targets = {}
  ub.scheduled = false

  local actionBar = ns.Modules.ActionBar
  local flags = targets.ActionBar
  if flags then
    actionBar:HandleProfileChanged(flags)
  end

  local partyFrames = ns.Modules.PartyFrames
  flags = targets.PartyFrames
  if flags then
    partyFrames:Refresh()
  end

  local raidFrames = ns.Modules.RaidFrames
  flags = targets.RaidFrames
  if flags then
    raidFrames:Refresh()
  end

  local dragonriding = ns.Modules.Dragonriding
  flags = targets.Dragonriding
  if flags then
    dragonriding:Refresh()
  end

  local minimap = ns.Registry.Minimap
  flags = targets.Minimap
  if flags then
    minimap:RefreshFromOptions(flags)
  end

  local chatLinks = ns.Registry.ChatLinks
  flags = targets.ChatLinks
  if flags then
    if flags.theme == true then
      chatLinks:RefreshTheme()
    else
      chatLinks:OnProfileChanged(flags)
    end
  end

  local unitFrames = ns.Modules.UnitFrames
  flags = targets.UnitFrames
  if flags then
    unitFrames:ApplySettings(flags)

    if flags.profile ~= true and (flags.layout == true or flags.movers == true) then
      _PUI_UB_RequestSoftTarget(ub, "UnitFrames", flags)
    end
  end

  flags = targets.CastBar
  if flags
    and (flags.profile == true or flags.layout == true or flags.movers == true)
  then
    _PUI_UB_RequestSoftTarget(ub, "CastBar", flags)
  end

  local cooldownManager = ns.Modules.CooldownManager
  flags = targets.CooldownManager
  if flags then
    cooldownManager:ApplySettings(flags)

    if flags.profile == true or flags.layout == true or flags.movers == true then
      _PUI_UB_RequestSoftTarget(ub, "CooldownManager", flags)
    end
  end

  local playerBuffs = ns.Modules.PlayerBuffs
  flags = targets.PlayerBuffs
  if flags then
    playerBuffs:ApplySettings(flags)
  end

  local hunterTools = ns.Modules.HunterTools
  flags = targets.HunterTools
  if flags then
    hunterTools:ApplySettings(flags)
  end

  local prd = ns.Modules.PRD
  flags = targets.PRD
  if flags then
    prd:ApplySettings(flags)

    if flags.profile == true or flags.layout == true or flags.movers == true then
      _PUI_UB_RequestSoftTarget(ub, "PRD", flags)
    end
  end

  local damageMeters = ns.Modules.DamageMeters
  flags = targets.DamageMeters
  if flags then
    damageMeters:RefreshTheme()
  end

  local characterSheet = ns.Registry.CharacterSheet
  flags = targets.CharacterSheet
  if flags then
    characterSheet:RefreshTheme()
  end

  local bags = ns.Registry.Bags
  flags = targets.Bags
  if flags then
    bags:RefreshTheme()
  end

  local testMode = ns.TestMode
  flags = targets.TestMode
  if flags then
    testMode:RefreshTheme()
  end

  flags = targets.Options
  if flags and flags.options == true then
    self:RefreshOpenOptions()
  end
end

Addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
  Addon.FrameScale:ApplyPendingUIScale()

  local optionsWindow = Addon._OptionsWindow
  if not (optionsWindow and optionsWindow:IsShown()) then
    ns.Modules.CooldownManager:FlushPendingEditModeChanges()
  end

  local ub = Addon._puiUpdateBus
  local deferredSoft = ub and ub.deferredSoft
  if not deferredSoft or not next(deferredSoft) then
    return
  end

  ub.deferredSoft = {}

  for index = 1, #PUI_SOFT_UPDATE_TARGETS do
    local target = PUI_SOFT_UPDATE_TARGETS[index]
    local flags = deferredSoft[target]
    if flags then
      _PUI_UB_ApplySoftTarget(target, flags)
    end
  end
end)


local PUI_OPTIONS_SECTION_UX = {
  GeneralOptions = {
    label = "UI Scale",
    order = 10,
    meta = {
      navDescription = "Resolution presets and custom scale.",
      pageTitle = "UI Scale",
      pageDescription = "Set the UI scale used by PleebUI.",
      pageHelp = "Choose a preset or adjust the scale manually.",
    },
  },
  UITheme = {
    label = "UI Theme",
    order = 15,
    meta = {
      navDescription = "Colors, fonts, and options layout.",
      pageTitle = "UI Theme",
      pageDescription = "Set PleebUI colors, fonts, and options layout.",
      pageHelp = "These settings apply throughout PleebUI.",
    },
  },
  unitframes = {
    label = "Unit Frames",
    order = 20,
    meta = {
      navDescription = "Player, target, party, raid, auras, text, and layout.",
      pageTitle = "Unit Frames",
      pageDescription = "Configure the frames that show unit health, power, casts, auras, roles, and status indicators.",
      pageHelp = "Use Overview first, then tune Player, Target, Party, and Raid separately.",
    },
  },
  PLAYER_BUFFS = {
    label = "Player Buffs",
    order = 25,
    meta = {
      navDescription = "Player buff and debuff appearance.",
      pageTitle = "Player Buffs",
      pageDescription = "Configure player buffs and debuffs.",
      pageHelp = "Set icon size, text, borders, and position.",
    },
  },
  PRD = {
    label = "Resource Display",
    order = 30,
    meta = {
      navDescription = "Personal health, power, class resources, and text.",
      pageTitle = "Personal Resource Display",
      pageDescription = "Configure your personal resource display, including health, primary power, secondary power, and class-specific resources.",
      pageHelp = "Set the layout first, then refine text, colors, and class-specific resource behavior.",
    },
  },
  ACTIONBARS = {
    label = "Action Bars",
    order = 40,
    meta = {
      navDescription = "Bar layout, buttons, text, and visibility.",
      pageTitle = "Action Bars",
      pageDescription = "Set action bar layout, appearance, text, and visibility.",
      pageHelp = "Set shared defaults in Overview, then override individual bars as needed.",
    },
  },
  CooldownManager = {
    label = "Cooldown Manager",
    order = 50,
    meta = {
      navDescription = "Cooldown icons, buff icons, buff bars, and custom bars.",
      pageTitle = "Cooldown Manager",
      pageDescription = "Style Cooldown Manager viewers and create custom bars.",
      pageHelp = "Choose a viewer or custom bar from the tabs above.",
    },
  },
  Chat = {
    label = "Chat",
    order = 60,
    meta = {
      navDescription = "Chat appearance, formatting, fade, and history.",
      pageTitle = "Chat",
      pageDescription = "Set chat appearance, formatting, fade, and behavior.",
      pageHelp = "PleebUI Chat is disabled when another supported chat addon owns the frame.",
    },
  },
  Minimap = {
    label = "Minimap",
    order = 70,
    meta = {
      navDescription = "Minimap appearance, buttons, clock, and data.",
      pageTitle = "Minimap",
      pageDescription = "Set minimap appearance, buttons, clock, and data.",
      pageHelp = "Button collection and the top panel can be configured separately.",
    },
  },
  Dragonriding = {
    label = "Skyriding",
    order = 75,
    meta = {
      navDescription = "Vigor, speed, second wind, and alerts.",
      pageTitle = "Skyriding",
      pageDescription = "Set the skyriding display and alerts.",
      pageHelp = "The display appears while skyriding.",
    },
  },

  Quality = {
    label = "Quality of Life",
    order = 90,
    meta = {
      navDescription = "Automation, loot, dialogs, and helpers.",
      pageTitle = "Quality of Life",
      pageDescription = "Set up automation and small gameplay helpers.",
      pageHelp = "Automation can be disabled separately for each activity.",
    },
  },
  Profiles = {
    label = "Profiles",
    order = 100,
    meta = {
      navDescription = "Switch, copy, reset, import, and export.",
      pageTitle = "Profiles",
      pageDescription = "Manage profiles for different characters or setups.",
      pageHelp = "Switching profiles updates every PleebUI module.",
    },
  },
}

local function PUI_CopyOptionsMeta(src)
  local out = {}
  if type(src) ~= "table" then
    return out
  end

  for key, value in pairs(src) do
    if type(value) == "table" then
      out[key] = PUI_CopyOptionsMeta(value)
    else
      out[key] = value
    end
  end

  return out
end

local function PUI_MergeOptionsMeta(base, override)
  local out = PUI_CopyOptionsMeta(base)

  if type(override) == "table" then
    for key, value in pairs(override) do
      if type(value) == "table" then
        out[key] = PUI_CopyOptionsMeta(value)
      else
        out[key] = value
      end
    end
  end

  return out
end

function Addon:RegisterOptionsSection(key, factory, order, label, parentKey, meta)
  local ux = PUI_OPTIONS_SECTION_UX[key]
  local finalMeta = PUI_MergeOptionsMeta(meta, ux and ux.meta)

  ns.Registry.Options[key] = {
    key       = key,
    name      = (ux and ux.label) or label or key,
    label     = (ux and ux.label) or label or key,
    order     = (ux and ux.order) or order or 50,
    factory   = factory,

    -- Optional: parent category key (for nav indentation)
    parentKey = parentKey,
    meta      = finalMeta,
  }
end

