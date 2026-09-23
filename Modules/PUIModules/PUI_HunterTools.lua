local ADDON_NAME, ns = ...

local Addon = ns.Addon
local HunterTools = Addon:NewModule("HunterTools", "NumyAceEvent-3.0")
ns.Modules.HunterTools = HunterTools

local P = select(1, ns.Pleebug:DropIn(HunterTools, { name = "Modules.HunterTools" }))

local _G = _G
local C_Secrets = _G.C_Secrets
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local InCombatLockdown = _G.InCombatLockdown
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local UIParent = _G.UIParent
local UnitClass = _G.UnitClass
local math_floor = _G.math.floor
local tonumber = _G.tonumber
local type = _G.type

local AuraSlotDriver = ns.AuraSlotDriver
local FrameUtil = ns.FrameUtil

local EMERGENCY_SALVE_SPELL_ID = 459517
local FEIGN_DEATH_SPELL_ID = 5384

local SALVE_CANDIDATES = {
  includeDispelTypes = {
    Poison = true,
    Disease = true,
  },
}

local SALVE_TEMPLATE_NAMES = { "PUI_AuraApplicationDurationTemplate" }

local SalveAnchor
local SalveSlot
local SalveButton
local SalvePreview
local SalveDirty = false
local EmergencySalveSpellDirty = true
local EmergencySalveKnown = false

local function Clamp(value, minimum, maximum)
  value = tonumber(value) or minimum
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function NormalizeColor(color, r, g, b, a)
  if type(color) ~= "table" then
    color = {}
  end

  color.r = tonumber(color.r) or r
  color.g = tonumber(color.g) or g
  color.b = tonumber(color.b) or b
  color.a = tonumber(color.a)
  if color.a == nil then color.a = a end

  return color
end

local function NormalizeDB()
  local profile = Addon.db.profile
  profile.hunterTools = profile.hunterTools or {}

  local db = profile.hunterTools
  if db.enabled == nil then db.enabled = true end
  if db.emergencySalveEnabled == nil then db.emergencySalveEnabled = true end
  db.emergencySalveFontSize = Clamp(db.emergencySalveFontSize or 42, 16, 80)
  db.emergencySalveColor = NormalizeColor(db.emergencySalveColor, 1, 0.35, 0.10, 1)
  db.emergencySalveAnchor = db.emergencySalveAnchor or {}
  db.emergencySalveAnchor.x = tonumber(db.emergencySalveAnchor.x) or 0
  db.emergencySalveAnchor.y = tonumber(db.emergencySalveAnchor.y) or 220

  return db
end

local function IsHunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

local function RefreshEmergencySalveKnown()
  if not IsHunter() then
    EmergencySalveKnown = false
    EmergencySalveSpellDirty = false
    return
  end

  if InCombatLockdown() then
    EmergencySalveSpellDirty = true
    return
  end

  EmergencySalveKnown = C_SpellBook.IsSpellKnown(
    EMERGENCY_SALVE_SPELL_ID,
    Enum.SpellBookSpellBank.Player
  ) == true

  EmergencySalveSpellDirty = false
end

local function ApplySalveAnchor()
  if not SalveAnchor then
    return
  end

  local anchor = NormalizeDB().emergencySalveAnchor

  SalveAnchor:ClearAllPoints()
  SalveAnchor:SetPoint("CENTER", UIParent, "CENTER", anchor.x, anchor.y)
end

local function SaveSalvePosition(frame)
  local db = NormalizeDB()
  local x, y = FrameUtil.GetMoverOffsets(frame)

  db.emergencySalveAnchor.x = math_floor((x or 0) + 0.5)
  db.emergencySalveAnchor.y = math_floor((y or 0) + 0.5)
end

local function EnsureSalveAnchor()
  if SalveAnchor then
    return SalveAnchor
  end

  local frame = CreateFrame(
    "Frame",
    "PleebUI_EmergencySalveAnchor",
    UIParent
  )

  SalveAnchor = frame

  frame:SetSize(360, 72)
  frame:SetFrameStrata("LOW")
  frame:SetFrameLevel(1)
  frame:EnableMouse(false)

  ApplySalveAnchor()

  FrameUtil:RegisterMover("hunter_emergency_salve", frame, {
    label = "Emergency Salve",
    optionsString = "HunterTools",
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        local db = NormalizeDB()
        return db.enabled == true and db.emergencySalveEnabled == true
      end,
    },

    savePosition = function()
      SaveSalvePosition(frame)
    end,

    resetPosition = function()
      local db = NormalizeDB()

      db.emergencySalveAnchor.x = 0
      db.emergencySalveAnchor.y = 220

      ApplySalveAnchor()
    end,
  })

  return frame
end

local function ApplySalveVisual(frame, text, icon)
  local db = NormalizeDB()
  local size = db.emergencySalveFontSize
  local color = db.emergencySalveColor

  text:ClearAllPoints()
  text:SetPoint("CENTER", frame, "CENTER", 18, 0)
  text:SetFont(
    STANDARD_TEXT_FONT,
    ns.Theme.ResolveFontSize(size, "qualityOfLife"),
    "OUTLINE"
  )
  text:SetTextColor(color.r, color.g, color.b, color.a)

  icon:SetTexture(C_Spell.GetSpellTexture(FEIGN_DEATH_SPELL_ID))
  icon:ClearAllPoints()
  icon:SetPoint("RIGHT", text, "LEFT", -10, 0)
  icon:SetSize(size + 8, size + 8)
end

local function StyleEmergencySalveButton(initializing)
  if not SalveButton then
    return
  end

  if initializing ~= true
    and C_Secrets.ShouldAurasBeSecret() == true
  then
    SalveDirty = true
    return
  end

  if initializing == true then
    local anchor = EnsureSalveAnchor()

    SalveButton:ClearAllPoints()
    SalveButton:SetAllPoints(anchor)
    SalveButton:SetFrameStrata(anchor:GetFrameStrata())
    SalveButton:SetFrameLevel(anchor:GetFrameLevel() + 5)
    SalveButton:EnableMouse(false)

    SalveButton.PUIIcon:Hide()
    SalveButton.PUIApplicationBase:Hide()
    SalveButton.PUIApplicationBar:Hide()
    SalveButton.PUIApplicationHolder:Hide()
    SalveButton.PUIDurationBar:Hide()
    SalveButton.PUIDurationTextHolder:Hide()
    SalveButton.PUIDurationCooldown:Hide()
  end

  local text = SalveButton.__puiSalveText
  if not text then
    text = SalveButton:CreateFontString(
      nil,
      "OVERLAY",
      "GameFontHighlightLarge"
    )

    SalveButton.__puiSalveText = text
    text:SetJustifyH("CENTER")
    text:SetText("FEIGN")
  end

  local icon = SalveButton.__puiSalveIcon
  if not icon then
    icon = SalveButton:CreateTexture(nil, "ARTWORK")
    SalveButton.__puiSalveIcon = icon
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  ApplySalveVisual(SalveButton, text, icon)
end

local function EnsureSalvePreview()
  if SalvePreview then
    return SalvePreview
  end

  local anchor = EnsureSalveAnchor()
  local preview = CreateFrame("Frame", nil, anchor)
  SalvePreview = preview

  preview:SetAllPoints(anchor)
  preview:SetFrameStrata("HIGH")
  preview:SetFrameLevel(1005)
  preview:EnableMouse(false)

  local text = preview:CreateFontString(
    nil,
    "OVERLAY",
    "GameFontHighlightLarge"
  )
  preview.text = text
  text:SetJustifyH("CENTER")
  text:SetText("FEIGN")

  local icon = preview:CreateTexture(nil, "ARTWORK")
  preview.icon = icon
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  ApplySalveVisual(preview, text, icon)
  preview:Hide()
  return preview
end

local function RefreshSalvePreview(show)
  if show == true then
    local preview = EnsureSalvePreview()
    ApplySalveVisual(preview, preview.text, preview.icon)
    preview:Show()
    return
  end

  if SalvePreview then
    SalvePreview:Hide()
  end
end

local function EnsureSalveSlot()
  if SalveSlot then
    return SalveSlot
  end

  EnsureSalveAnchor()

  SalveSlot = AuraSlotDriver:CreateSlot(
    "player",
    "HARMFUL",
    {
      candidateFilters = SALVE_CANDIDATES,
      templateNames = SALVE_TEMPLATE_NAMES,

      initializeFrame = function(button)
        SalveButton = button
        StyleEmergencySalveButton(true)
      end,
    }
  )

  return SalveSlot
end

local function RefreshEmergencySalve()
  local db = NormalizeDB()

  local active = db.enabled == true
    and db.emergencySalveEnabled == true
    and IsHunter()
    and EmergencySalveKnown == true

  if C_Secrets.ShouldAurasBeSecret() == true then
    SalveDirty = true
    return
  end

  if not active then
    SalveDirty = false

    if SalveSlot then
      AuraSlotDriver:SetSlotActive(SalveSlot, false)
    end

    return
  end

  if not SalveSlot and InCombatLockdown() then
    SalveDirty = true
    return
  end

  SalveDirty = false

  local slot = EnsureSalveSlot()

  if slot.active ~= true then
    AuraSlotDriver:SetSlotCandidates(slot, SALVE_CANDIDATES)
    AuraSlotDriver:SetSlotActive(slot, true)
  end

  StyleEmergencySalveButton()
  AuraSlotDriver:RefreshUnit("player")
end

local function RefreshEventRegistration()
  HunterTools:UnregisterAllEvents()

  if not IsHunter() then
    return
  end

  local db = NormalizeDB()
  local salveActive = db.enabled == true
    and db.emergencySalveEnabled == true

  if salveActive then
    HunterTools:RegisterEvent("PLAYER_ENTERING_WORLD", "OnHunterEvent")
    HunterTools:RegisterEvent("PLAYER_TALENT_UPDATE", "OnHunterEvent")
    HunterTools:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnHunterEvent")
    HunterTools:RegisterEvent("SPELLS_CHANGED", "OnHunterEvent")
    HunterTools:RegisterEvent("TRAIT_CONFIG_UPDATED", "OnHunterEvent")
    HunterTools:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED", "OnHunterEvent")
  end

  if SalveDirty then
    HunterTools:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnHunterEvent")
  end

  if SalveDirty
    or (
      db.enabled == true
      and db.emergencySalveEnabled == true
      and EmergencySalveSpellDirty
    )
  then
    HunterTools:RegisterEvent("PLAYER_REGEN_ENABLED", "OnHunterEvent")
  end
end

function HunterTools:ApplySettings()
  NormalizeDB()
  RefreshEmergencySalveKnown()
  RefreshEmergencySalve()
  RefreshEventRegistration()

  if ns.Flags.IsEditing then
    self:OnEditModeChanged(true)
  end
end

function HunterTools:RefreshFonts()
  StyleEmergencySalveButton()

  if SalvePreview then
    ApplySalveVisual(SalvePreview, SalvePreview.text, SalvePreview.icon)
  end

  if SalveDirty then
    RefreshEventRegistration()
  end
end

function HunterTools:OnEditModeChanged(enable)
  local db = NormalizeDB()
  local showSalvePreview = enable == true
    and db.enabled == true
    and db.emergencySalveEnabled == true
    and IsHunter()

  if showSalvePreview then
    EnsureSalveAnchor()
    FrameUtil.SetMoverSuppressed("hunter_emergency_salve", false)
    RefreshSalvePreview(true)
  else
    RefreshSalvePreview(false)

    if SalveAnchor then
      FrameUtil.SetMoverSuppressed("hunter_emergency_salve", true)
    end
  end
end

function HunterTools:OnHunterEvent(event)
  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if C_Secrets.ShouldAurasBeSecret() ~= true then
      RefreshEmergencySalve()
    end

    RefreshEventRegistration()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    if EmergencySalveSpellDirty then
      RefreshEmergencySalveKnown()
    end

    RefreshEmergencySalve()
    RefreshEventRegistration()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    RefreshEmergencySalveKnown()
    RefreshEmergencySalve()
    return
  end

  if event == "PLAYER_TALENT_UPDATE"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "TRAIT_CONFIG_UPDATED"
    or event == "TRAIT_CONFIG_LIST_UPDATED"
    or event == "SPELLS_CHANGED"
  then
    RefreshEmergencySalveKnown()
    RefreshEmergencySalve()
  end
end

function HunterTools:GetOptions()
  local function MasterDisabled()
    return NormalizeDB().enabled ~= true
  end

  local function ToggleOption(name, key, order)
    return {
      type = "toggle",
      name = name,
      order = order,

      get = function()
        return NormalizeDB()[key] == true
      end,

      set = function(_, value)
        NormalizeDB()[key] = value == true
        HunterTools:ApplySettings()
      end,
    }
  end

  local function RangeOption(
    name,
    key,
    minimum,
    maximum,
    order
  )
    return {
      type = "range",
      name = name,
      order = order,
      min = minimum,
      max = maximum,
      step = 1,

      get = function()
        return NormalizeDB()[key]
      end,

      set = function(_, value)
        NormalizeDB()[key] = Clamp(
          value,
          minimum,
          maximum
        )

        HunterTools:ApplySettings()
      end,
    }
  end

  local function ColorOption(name, key, order)
    return {
      type = "color",
      name = name,
      order = order,
      hasAlpha = true,

      get = function()
        local color = NormalizeDB()[key]
        return color.r, color.g, color.b, color.a
      end,

      set = function(_, r, g, b, a)
        NormalizeDB()[key] = NormalizeColor(
          {
            r = r,
            g = g,
            b = b,
            a = a,
          },
          1,
          1,
          1,
          1
        )

        HunterTools:ApplySettings()
      end,
    }
  end

  return {
    type = "group",
    name = "Hunter Tools",

    args = {
      enabled = ToggleOption(
        "Enable Hunter Tools",
        "enabled",
        10
      ),

      emergencySalve = {
        type = "group",
        name = "Emergency Salve",
        order = 20,
        inline = true,
        disabled = MasterDisabled,

        args = {
          emergencySalveEnabled = ToggleOption(
            "Show Feign warning",
            "emergencySalveEnabled",
            10
          ),

          emergencySalveFontSize = RangeOption(
            "Warning size",
            "emergencySalveFontSize",
            16,
            80,
            20
          ),

          emergencySalveColor = ColorOption(
            "Warning color",
            "emergencySalveColor",
            30
          ),
        },
      },
    },
  }
end

function HunterTools:OnInitialize()
  NormalizeDB()
  _G.PleebUIAPI:RegisterPlugin("PleebUI_HunterTools", {
    name = "Hunter Tools",
  }):RegisterEditModeParticipant("runtime", {
    order = 30,
    onChanged = function(enable)
      self:OnEditModeChanged(enable)
    end,
  })

  Addon:RegisterOptionsSection(
    "HunterTools",
    function()
      return HunterTools
    end,
    75,
    "Hunter Tools",
    nil,
    {
      preview = false,
    }
  )
end

function HunterTools:OnEnable()
  self:ApplySettings()
end

function HunterTools:OnDisable()
  self:UnregisterAllEvents()
  RefreshSalvePreview(false)

  if SalveAnchor then
    FrameUtil.SetMoverSuppressed("hunter_emergency_salve", true)
  end

  if SalveSlot then
    AuraSlotDriver:SetSlotActive(SalveSlot, false)
  end
end

HunterTools.ApplySettings =
  P:Def("HunterTools:ApplySettings", HunterTools.ApplySettings)

HunterTools.RefreshFonts =
  P:Def("HunterTools:RefreshFonts", HunterTools.RefreshFonts)

HunterTools.OnEditModeChanged =
  P:Def("HunterTools:OnEditModeChanged", HunterTools.OnEditModeChanged)

HunterTools.OnHunterEvent =
  P:Def("HunterTools:OnHunterEvent", HunterTools.OnHunterEvent)

HunterTools.GetOptions =
  P:Def("HunterTools:GetOptions", HunterTools.GetOptions)

HunterTools.OnInitialize =
  P:Def("HunterTools:OnInitialize", HunterTools.OnInitialize)

HunterTools.OnEnable =
  P:Def("HunterTools:OnEnable", HunterTools.OnEnable)

HunterTools.OnDisable =
  P:Def("HunterTools:OnDisable", HunterTools.OnDisable)
