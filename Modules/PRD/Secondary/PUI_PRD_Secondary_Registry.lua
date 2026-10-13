local ADDON_NAME, ns = ...

local M = ns.Modules.PRD
local AuraWidget = ns.AuraWidget
local Secondary = {}
ns.PRDSecondary = Secondary

Secondary.Adapters = {}

local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Registry" })
local function Noop()
end

local function IsDefaultStructureReady(owner)
  return owner.secondaryBar ~= nil
    or owner.secondaryStatusBar ~= nil
    or owner.secondarySegments and #owner.secondarySegments > 0
end

function Secondary:RegisterAdapter(key, adapter)
  adapter.key = key
  adapter.Deactivate = adapter.Deactivate or Noop
  adapter.Suspend = adapter.Suspend or Noop
  adapter.RefreshText = adapter.RefreshText or Noop
  adapter.IsStructureReady = adapter.IsStructureReady or IsDefaultStructureReady
  self.Adapters[key] = adapter
  return adapter
end

local COMBO_POINTS = {
  adapter = "POWER",
  resourceKey = "COMBO_POINTS",
  powerType = Enum.PowerType.ComboPoints,
  token = "COMBO_POINTS",
  texture = "PUI: Combo Points",
  maxFromPowerType = Enum.PowerType.ComboPoints,
  minRealMax = 2,
}

local ALTERNATE_MANA = {
  adapter = "POWER_SECRET",
  isAlternatePower = true,
  resourceKey = "ALTERNATE_MANA",
  powerType = Enum.PowerType.Mana,
  token = "MANA",
  texture = "PUI: Mana",
  colorToken = "MANA",
  max = 1,
  forceContinuous = true,
}

local RESOURCE_NAMES = {
  SOUL_SHARDS = "Soul Shards",
  HOLY_POWER = "Holy Power",
  STAGGER = "Stagger",
  CHI = "Chi",
  COMBO_POINTS = "Combo Points",
  SOUL_FRAGMENTS_VENGEANCE = "Soul Fragments (Vengeance)",
  SOUL_FRAGMENTS_DEVOURER = "Soul Fragments (Devourer)",
  ALTERNATE_MANA = "Alternate Mana",
  ARCANE_CHARGES = "Arcane Charges",
  ARCANE_SALVO = "Arcane Salvo",
  ICICLES = "Icicles",
  FREEZING = "Freezing",
  TIP_OF_THE_SPEAR = "Tip of the Spear",
  SHINING_LIGHT = "Shining Light",
  MAELSTROM_WEAPON = "Maelstrom Weapon",
  ESSENCE = "Essence",
  RUNES = "Runes",
  BONE_SHIELD = "Bone Shield",
  FINGERS_OF_FROST = "Fingers of Frost",
  HAILSTORM = "Hailstorm",
  OVERFLOWING_MAELSTROM = "Overflowing Maelstrom",
  SHEILUNS_GIFT = "Sheilun's Gift",
  LIGHTWEAVER = "Lightweaver",
  SWEEPING_STRIKES = "Sweeping Strikes",
  IRONFUR = "Ironfur",
  WHIRLWIND_STACKS = "Whirlwind stacks",
  IGNORE_PAIN = "Ignore Pain",
}

local NUMERIC_CUE_RESOURCES = {
  SOUL_SHARDS = true,
  HOLY_POWER = true,
  CHI = true,
  COMBO_POINTS = true,
  ARCANE_CHARGES = true,
  ESSENCE = true,
  RUNES = true,
}

local STACK_COLOR_SHIFT_DISABLED_RESOURCES = {
  SHINING_LIGHT = true,
  SHEILUNS_GIFT = true,
  SWEEPING_STRIKES = true,
}

local APPLICATION_COUNTDOWN_MAX_BY_RESOURCE = {
  SHINING_LIGHT = 3,
}

local DEFINITIONS = {
  WARLOCK = {
    adapter = "POWER",
    resourceKey = "SOUL_SHARDS",
    powerType = Enum.PowerType.SoulShards,
    token = "SOUL_SHARDS",
    texture = "Pleebar",
    maxFromPowerType = Enum.PowerType.SoulShards,
    minRealMax = 2,
    preciseResourceCountBySpec = {
      [267] = true,
    },
    currentDivisorBySpec = {
      [267] = 10,
    },
    displayFloor = true,
  },

  PALADIN = {
    resources = {
      {
        adapter = "POWER",
        resourceKey = "HOLY_POWER",
        powerType = Enum.PowerType.HolyPower,
        token = "HOLY_POWER",
        texture = "Pleebar",
        maxFromPowerType = Enum.PowerType.HolyPower,
        minRealMax = 2,
      },
      {
        adapter = "AURA_STACKS",
        resourceKey = "SHINING_LIGHT",
        token = "SHINING_LIGHT",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 1.00, 0.82, 0.20, 1.00 },
        max = 2,
        auraSpellIDs = {
          182104,
        },
        forceContinuous = true,
        specIDs = {
          [66] = true,
        },
      },
    },
  },

  MONK = {
    bySpec = {
      [268] = {
        adapter = "STAGGER",
        resourceKey = "STAGGER",
        token = "STAGGER",
        texture = "Pleebar",
        max = 1,
      },
      [269] = {
        adapter = "POWER",
        resourceKey = "CHI",
        powerType = Enum.PowerType.Chi,
        token = "CHI",
        texture = "PUI: Chi",
        maxFromPowerType = Enum.PowerType.Chi,
        minRealMax = 2,
      },
      [270] = {
        adapter = "SPELL_COUNT",
        resourceKey = "SHEILUNS_GIFT",
        token = "SHEILUNS_GIFT",
        texture = "Pleebar",
        defaultColor = { 0.30, 0.85, 0.65, 1.00 },
        max = 10,
        maxAuraSpellID = 399497,
        castCountSpellID = 399491,
        cooldownCountSpellIDs = { 399491 },
        countDisplayName = "Sheilun's Gift display",
        countDisplayDescription = "Show cloud count on the Sheilun's Gift icon, the PRD bar, both, or neither.",
        forceContinuous = true,
      },
    },
  },

  ROGUE = COMBO_POINTS,

  DEMONHUNTER = {
    bySpec = {
      [581] = {
        adapter = "SPELL_COUNT",
        resourceKey = "SOUL_FRAGMENTS_VENGEANCE",
        token = "SOUL_FRAGMENTS_VENGEANCE",
        texture = "Pleebar",
        colorToken = "FURY",
        max = 6,
        castCountSpellID = 228477,
        cooldownCountSpellIDs = { 228477, 247454 },
        countDisplayName = "Soul Fragment display",
        countDisplayDescription = "Track Soul Fragments on the Soul Cleave and Spirit Bomb icons, the PRD bar, both, or neither.",
        forceContinuous = true,
      },
      [1480] = {
        adapter = "AURA_STACKS",
        resourceKey = "SOUL_FRAGMENTS_DEVOURER",
        token = "SOUL_FRAGMENTS",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        colorToken = "FURY",
        max = 50,
        knownMaxSpellID = 1247534,
        maxWhenKnown = 35,
        maxWhenUnknown = 50,
        auraSpellIDs = {
          1225789,
          1227702,
        },
        forceContinuous = true,
      },
    },
  },

  DRUID = {
    byForm = {
      [0] = {
        bySpec = {
          [102] = ALTERNATE_MANA,
        },
      },
      [DRUID_BEAR_FORM] = {
        bySpec = {
          [104] = {
            adapter = "AURA_STACKS",
            resourceKey = "IRONFUR",
            configurableMaximum = true,
            token = "IRONFUR",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            defaultColor = { 0.70, 0.55, 0.30, 1 },
            max = 10,
            auraSpellIDs = { 192081 },
            forceContinuous = true,
            defaultEnabled = false,
          },
        },
      },
      [DRUID_CAT_FORM] = COMBO_POINTS,
      [DRUID_MOONKIN_FORM_1] = ALTERNATE_MANA,
      [DRUID_MOONKIN_FORM_2] = ALTERNATE_MANA,
    },
  },

  MAGE = {
    bySpec = {
      [62] = {
        resources = {
          {
            adapter = "POWER",
            resourceKey = "ARCANE_CHARGES",
            powerType = Enum.PowerType.ArcaneCharges,
            token = "ARCANE_CHARGES",
            texture = "PUI: Arcane Power",
            maxFromPowerType = Enum.PowerType.ArcaneCharges,
            minRealMax = 2,
          },
          {
            adapter = "AURA_STACKS",
            resourceKey = "ARCANE_SALVO",
            token = "ARCANE_SALVO",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            colorToken = "MANA",
            max = 20,
            knownMaxSpellID = 1260616,
            maxWhenKnown = 25,
            maxWhenUnknown = 20,
            auraSpellIDs = {
              1242974,
            },
            castCountSpellID = 44425,
            cooldownCountSpellIDs = { 44425 },
            countDisplayName = "Arcane Salvo display",
            countDisplayDescription = "Show Arcane Salvo stacks on the Arcane Barrage icon, the PRD bar, both, or neither.",
            forceContinuous = true,
          },
        },
      },
      [64] = {
        resources = {
          {
            adapter = "AURA_STACKS",
            resourceKey = "ICICLES",
            token = "ICICLES",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            colorToken = "MANA",
            max = 5,
            maxAuraSpellID = 205473,
            auraSpellIDs = {
              205473,
            },
          },
          {
            adapter = "AURA_STACKS",
            resourceKey = "FREEZING",
            token = "FREEZING",
            unit = "target",
            filter = "HARMFUL|PLAYER",
            texture = "Pleebar",
            defaultColor = { 0.35, 0.75, 1.00, 1.00 },
            max = 20,
            maxAuraSpellID = 1221389,
            auraSpellIDs = {
              1221389,
            },
          },
          {
            adapter = "AURA_STACKS",
            resourceKey = "FINGERS_OF_FROST",
            token = "FINGERS_OF_FROST",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            defaultColor = { 0.45, 0.80, 1.00, 1.00 },
            max = 2,
            maxAuraSpellID = 44544,
            auraSpellIDs = { 44544 },
            castCountSpellID = 30455,
            cooldownCountSpellIDs = { 30455 },
            countDisplayName = "Fingers of Frost display",
            countDisplayDescription = "Show Fingers of Frost charges on the Ice Lance icon, the PRD bar, both, or neither.",
            forceContinuous = true,
          },
        },
      },
    },
  },

  HUNTER = {
    bySpec = {
      [255] = {
        adapter = "AURA_STACKS",
        resourceKey = "TIP_OF_THE_SPEAR",
        token = "TIP_OF_THE_SPEAR",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 0.4235, 0.7373, 0.1569, 1.00 },
        max = 3,
        maxAuraSpellID = 260286,
        auraSpellIDs = {
          260286,
        },
      },
    },
  },

  PRIEST = {
    bySpec = {
      [257] = {
        adapter = "AURA_STACKS",
        resourceKey = "LIGHTWEAVER",
        token = "LIGHTWEAVER",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 1.00, 0.90, 0.55, 1.00 },
        max = 4,
        maxAuraSpellID = 390993,
        auraSpellIDs = { 390993 },
        castCountSpellID = 596,
        cooldownCountSpellIDs = { 596 },
        countDisplayName = "Lightweaver display",
        countDisplayDescription = "Show Lightweaver charges on the Prayer of Healing icon, the PRD bar, both, or neither.",
        forceContinuous = true,
      },
      [258] = ALTERNATE_MANA,
    },
  },

  SHAMAN = {
    bySpec = {
      [262] = ALTERNATE_MANA,
      [263] = {
        resources = {
          {
            adapter = "AURA_STACKS",
            resourceKey = "MAELSTROM_WEAPON",
            token = "MAELSTROM_WEAPON",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            colorToken = "MAELSTROM",
            max = 10,
            maxAuraSpellID = 344179,
            auraSpellIDs = { 344179 },
          },
          {
            adapter = "AURA_STACKS",
            resourceKey = "HAILSTORM",
            token = "HAILSTORM",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            defaultColor = { 0.45, 0.80, 1.00, 1.00 },
            max = 5,
            maxAuraSpellID = 334196,
            auraSpellIDs = { 334196 },
            castCountSpellID = 196840,
            cooldownCountSpellIDs = { 196840 },
            countDisplayName = "Hailstorm display",
            countDisplayDescription = "Show Hailstorm stacks on the Frost Shock icon, the PRD bar, both, or neither.",
            forceContinuous = true,
          },
          {
            adapter = "AURA_STACKS",
            resourceKey = "OVERFLOWING_MAELSTROM",
            token = "OVERFLOWING_MAELSTROM",
            unit = "player",
            filter = "HELPFUL|PLAYER",
            texture = "Pleebar",
            defaultColor = { 0.30, 0.85, 0.65, 1.00 },
            max = 20,
            maxAuraSpellID = 410681,
            auraSpellIDs = { 410681 },
            castCountSpellID = 8004,
            cooldownCountSpellIDs = { 8004, 1064 },
            countDisplayName = "Overflowing Maelstrom display",
            countDisplayDescription = "Show Overflowing Maelstrom stacks on the Healing Surge and Chain Heal icons, the PRD bar, both, or neither.",
            forceContinuous = true,
          },
        },
      },
    },
  },

  EVOKER = {
    adapter = "ESSENCE",
    resourceKey = "ESSENCE",
    powerType = Enum.PowerType.Essence,
    token = "ESSENCE",
    texture = "Pleebar",
    defaultColor = { 100 / 255, 173 / 255, 206 / 255, 1.00 },
    maxFromPowerType = Enum.PowerType.Essence,
    minRealMax = 2,
  },

  WARRIOR = {
    resources = {
      {
        legacySpecID = 71,
        adapter = "SPELL_COUNT",
        resourceKey = "SWEEPING_STRIKES",
        token = "SWEEPING_STRIKES",
        texture = "Pleebar",
        defaultColor = { 0.78, 0.61, 0.43, 1.00 },
        max = 12,
        knownMaxSpellID = 1261049,
        maxWhenKnown = 18,
        maxWhenUnknown = 12,
        castCountSpellID = 260708,
        cooldownCountSpellIDs = { 260708 },
        countDisplayName = "Sweeping Strikes display",
        countDisplayDescription = "Show remaining Sweeping Strikes uses on its icon, the PRD bar, both, or neither.",
        forceContinuous = true,
      },
      {
        legacySpecID = 72,
        adapter = "AURA_STACKS",
        resourceKey = "WHIRLWIND_STACKS",
        token = "WHIRLWIND_STACKS",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 0.78, 0.61, 0.43, 1 },
        max = 4,
        auraSpellIDs = { 85739 },
        forceContinuous = true,
        defaultEnabled = false,
      },
      {
        legacySpecID = 73,
        adapter = "AURA_STACKS",
        resourceKey = "IGNORE_PAIN",
        token = "IGNORE_PAIN",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 0.85, 0.65, 0.20, 1 },
        max = 100,
        auraSpellIDs = { 190456 },
        forceContinuous = true,
        defaultEnabled = false,
      },
    },
  },

  DEATHKNIGHT = {
    resources = {
      {
        adapter = "RUNES",
        resourceKey = "RUNES",
        powerType = Enum.PowerType.RunicPower,
        token = "RUNIC_POWER",
        defaultColor = { 1, 0, 0, 1 },
        defaultColorBySpec = {
          [251] = { 0, 0.5, 1, 1 },
          [252] = { 0, 1, 0, 1 },
        },
        texture = "PUI: Runes Blood",
        textureBySpec = {
          [251] = "PUI: Runes Frost",
          [252] = "PUI: Runes Unholy",
        },
        max = 6,
      },
      {
        adapter = "AURA_STACKS",
        resourceKey = "BONE_SHIELD",
        token = "BONE_SHIELD",
        unit = "player",
        filter = "HELPFUL|PLAYER",
        texture = "Pleebar",
        defaultColor = { 0.85, 0.82, 0.70, 1.00 },
        max = 10,
        maxAuraSpellID = 195181,
        auraSpellIDs = { 195181 },
        castCountSpellID = 195182,
        cooldownCountSpellIDs = { 195182, 195292 },
        countDisplayName = "Bone Shield display",
        countDisplayDescription = "Track Bone Shield stacks on the Marrowrend and Death's Caress icons, the PRD bar, both, or neither.",
        forceContinuous = true,
        specIDs = { [250] = true },
      },
    },
  },
}

Secondary.Definitions = DEFINITIONS

local RESOURCE_DEFINITIONS_BY_CLASS = {}

local function IndexResourceDefinitions(entry, indexed)
  if entry.adapter then
    indexed[entry.resourceKey] = entry
    return
  end

  for _, branch in ipairs({ "resources", "bySpec", "byForm" }) do
    for _, definition in pairs(entry[branch] or {}) do
      IndexResourceDefinitions(definition, indexed)
    end
  end
end

for classToken, entry in pairs(DEFINITIONS) do
  local indexed = {}
  IndexResourceDefinitions(entry, indexed)
  RESOURCE_DEFINITIONS_BY_CLASS[classToken] = indexed
end

local function DefinitionContainsAlternatePower(entry)
  if type(entry) ~= "table" then
    return false
  end

  if entry.isAlternatePower == true then
    return true
  end

  if type(entry.resources) == "table" then
    for _, definition in ipairs(entry.resources) do
      if DefinitionContainsAlternatePower(definition) then
        return true
      end
    end
  end

  if type(entry.bySpec) == "table" then
    for _, definition in pairs(entry.bySpec) do
      if DefinitionContainsAlternatePower(definition) then
        return true
      end
    end
  end

  if type(entry.byForm) == "table" then
    for _, definition in pairs(entry.byForm) do
      if DefinitionContainsAlternatePower(definition) then
        return true
      end
    end
  end

  return false
end

local PLAYER_CLASS = select(2, UnitClass("player"))
Secondary.PlayerClassHasAlternatePower = DefinitionContainsAlternatePower(DEFINITIONS[PLAYER_CLASS])

function Secondary:GetResourceDefinition(resourceKey)
  return RESOURCE_DEFINITIONS_BY_CLASS[PLAYER_CLASS][resourceKey]
end

local function GetPlayerSpecID()
  local specIndex = C_SpecializationInfo.GetSpecialization()
  if not specIndex then
    return nil
  end
  return C_SpecializationInfo.GetSpecializationInfo(specIndex)
end

Secondary.Specializations = {}
local SPECIALIZATIONS_BY_CLASS = {}
for classID = 1, GetNumClasses() do
  local classInfo = C_CreatureInfo.GetClassInfo(classID)
  if classInfo then
    local specs = {}
    SPECIALIZATIONS_BY_CLASS[classInfo.classFile] = specs
    for index = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
      local specID, name = GetSpecializationInfoForClassID(classID, index)
      local spec = { id = specID, name = name, classToken = classInfo.classFile }
      specs[#specs + 1] = spec
      Secondary.Specializations[#Secondary.Specializations + 1] = spec
    end
  end
end

local IsDefinitionEnabled

local function GetResolvedDefinitionCandidates()
  local entry = DEFINITIONS[PLAYER_CLASS]
  if not entry then
    return nil, nil
  end

  local specID = GetPlayerSpecID()
  if not specID then return nil, nil end
  local formID = GetShapeshiftFormID() or nil
  local resolvedEntry = entry

  if PLAYER_CLASS == "DRUID" and type(entry.byForm) == "table" then
    resolvedEntry = entry.byForm[formID or 0]
  elseif type(entry.bySpec) == "table" then
    resolvedEntry = entry.bySpec[specID]
  end

  if type(resolvedEntry) == "table" and type(resolvedEntry.bySpec) == "table" then
    resolvedEntry = resolvedEntry.bySpec[specID]
  end

  if type(resolvedEntry) ~= "table" then
    return nil, specID
  end

  if type(resolvedEntry.resources) == "table" then
    return resolvedEntry.resources, specID
  end

  return { resolvedEntry }, specID
end

function Secondary:GetCooldownCountResourceKey(entry)
  if entry.settingsFamily ~= "cooldown" or not entry.identitySpellIDs then
    return nil
  end

  local candidates, specID = GetResolvedDefinitionCandidates()
  if not candidates then return nil end
  for index = 1, #candidates do
    local definition = candidates[index]
    local spellIDs = definition.cooldownCountSpellIDs
    if spellIDs and (not definition.specIDs or definition.specIDs[specID] == true) then
      for spellIndex = 1, #spellIDs do
        for identityIndex = 1, #entry.identitySpellIDs do
          if entry.identitySpellIDs[identityIndex] == spellIDs[spellIndex] then
            return definition.resourceKey, definition.castCountSpellID, definition
          end
        end
      end
    end
  end
end

function Secondary:GetResourceDisplayMode(resourceKey)
  local icons = ns.PCMIconSettings:GetResourceCountEnabled(resourceKey)
  local bar = M:IsSecondaryResourceEnabled(resourceKey)
  if icons then return bar and "BOTH" or "ICONS" end
  return bar and "BAR" or "NONE"
end

function Secondary:SetResourceDisplayMode(resourceKey, mode)
  ns.PCMIconSettings:SetResourceCountEnabled(resourceKey, mode == "ICONS" or mode == "BOTH")
  M:SetSecondaryResourceEnabled(resourceKey, mode == "BAR" or mode == "BOTH")
end

local RESOURCE_OPTIONS_BY_CLASS = {
  WARLOCK = {
    { key = "SOUL_SHARDS", name = "Soul Shards", category = "CLASS_RESOURCE" },
  },
  PALADIN = {
    { key = "HOLY_POWER", name = "Holy Power", category = "CLASS_RESOURCE" },
    { key = "SHINING_LIGHT", name = "Shining Light", category = "TRACKED_EFFECT", specIDs = { [66] = true } },
  },
  MONK = {
    { key = "STAGGER", name = "Stagger", category = "CLASS_RESOURCE", specIDs = { [268] = true } },
    { key = "CHI", name = "Chi", category = "CLASS_RESOURCE", specIDs = { [269] = true } },
    { key = "SHEILUNS_GIFT", name = "Sheilun's Gift", category = "TRACKED_EFFECT", specIDs = { [270] = true } },
  },
  ROGUE = {
    { key = "COMBO_POINTS", name = "Combo Points", category = "CLASS_RESOURCE" },
  },
  DEMONHUNTER = {
    { key = "SOUL_FRAGMENTS_VENGEANCE", name = "Soul Fragments (Vengeance)", category = "CLASS_RESOURCE", specIDs = { [581] = true } },
    { key = "SOUL_FRAGMENTS_DEVOURER", name = "Soul Fragments (Devourer)", category = "TRACKED_EFFECT", specIDs = { [1480] = true } },
  },
  DRUID = {
    { key = "COMBO_POINTS", name = "Combo Points", category = "CLASS_RESOURCE" },
    { key = "IRONFUR", name = "Ironfur", category = "TRACKED_EFFECT", specIDs = { [104] = true } },
  },
  MAGE = {
    { key = "ARCANE_CHARGES", name = "Arcane Charges", category = "CLASS_RESOURCE", specIDs = { [62] = true } },
    { key = "ARCANE_SALVO", name = "Arcane Salvo", category = "TRACKED_EFFECT", specIDs = { [62] = true } },
    { key = "ICICLES", name = "Icicles", category = "TRACKED_EFFECT", specIDs = { [64] = true } },
    { key = "FREEZING", name = "Freezing", category = "TRACKED_EFFECT", specIDs = { [64] = true } },
    { key = "FINGERS_OF_FROST", name = "Fingers of Frost", category = "TRACKED_EFFECT", specIDs = { [64] = true } },
  },
  HUNTER = {
    { key = "TIP_OF_THE_SPEAR", name = "Tip of the Spear", category = "TRACKED_EFFECT", specIDs = { [255] = true } },
  },
  PRIEST = {
    { key = "LIGHTWEAVER", name = "Lightweaver", category = "TRACKED_EFFECT", specIDs = { [257] = true } },
  },
  SHAMAN = {
    { key = "MAELSTROM_WEAPON", name = "Maelstrom Weapon", category = "TRACKED_EFFECT", specIDs = { [263] = true } },
    { key = "HAILSTORM", name = "Hailstorm", category = "TRACKED_EFFECT", specIDs = { [263] = true } },
    { key = "OVERFLOWING_MAELSTROM", name = "Overflowing Maelstrom", category = "TRACKED_EFFECT", specIDs = { [263] = true } },
  },
  EVOKER = {
    { key = "ESSENCE", name = "Essence", category = "CLASS_RESOURCE" },
  },
  WARRIOR = {
    { key = "SWEEPING_STRIKES", name = "Sweeping Strikes", category = "TRACKED_EFFECT" },
    { key = "WHIRLWIND_STACKS", name = "Whirlwind stacks", category = "TRACKED_EFFECT" },
    { key = "IGNORE_PAIN", name = "Ignore Pain", category = "TRACKED_EFFECT" },
  },
  DEATHKNIGHT = {
    { key = "RUNES", name = "Runes", category = "CLASS_RESOURCE" },
    { key = "BONE_SHIELD", name = "Bone Shield", category = "TRACKED_EFFECT", specIDs = { [250] = true } },
  },
}

local RESOURCE_OPTIONS_BY_SPEC = {}
local NO_RESOURCE_OPTIONS = {}
for classToken, specs in pairs(SPECIALIZATIONS_BY_CLASS) do
  local bySpec = {}
  RESOURCE_OPTIONS_BY_SPEC[classToken] = bySpec
  for _, spec in ipairs(specs) do
    local options = {}
    bySpec[spec.id] = options
    for _, resource in ipairs(RESOURCE_OPTIONS_BY_CLASS[classToken] or NO_RESOURCE_OPTIONS) do
      if not resource.specIDs or resource.specIDs[spec.id] then
        options[#options + 1] = {
          key = resource.key, name = resource.name, category = resource.category, specID = spec.id,
        }
      end
    end
  end
end

function Secondary:GetResourceOptionsForClass(classToken, specID)
  return RESOURCE_OPTIONS_BY_SPEC[classToken][specID or GetPlayerSpecID()] or NO_RESOURCE_OPTIONS
end

IsDefinitionEnabled = function(definition, profile)
  if type(definition) ~= "table" then
    return false
  end

  if definition.isAlternatePower == true then
    return profile.primary.hideAlternateMana ~= true
  end

  return profile.secondary.resourceSettings[PLAYER_CLASS][GetPlayerSpecID()][definition.resourceKey].enabled ~= false
end

local function ResolveMaximum(definition, deferSecretAuraMaximum)
  local resolvedMax = tonumber(definition.max) or 0

  if definition.configurableMaximum then
    resolvedMax = M.db.profile.secondary.resourceSettings[PLAYER_CLASS][GetPlayerSpecID()][definition.resourceKey].behavior.stackCeiling
  elseif definition.knownMaxSpellID then
    if C_SpellBook.IsSpellKnown(definition.knownMaxSpellID) then
      resolvedMax = tonumber(definition.maxWhenKnown) or resolvedMax
    else
      resolvedMax = tonumber(definition.maxWhenUnknown) or resolvedMax
    end
  elseif definition.maxAuraSpellID then
    local auraMaximum = C_Spell.GetSpellMaxCumulativeAuraApplications(definition.maxAuraSpellID)
    if issecretvalue(auraMaximum) then
      if deferSecretAuraMaximum then
        return nil
      end
    elseif auraMaximum > 0 then
      resolvedMax = auraMaximum
    end
  elseif definition.maxFromPowerType ~= nil then
    resolvedMax = UnitPowerMax("player", definition.maxFromPowerType) or 0
  end

  resolvedMax = tonumber(resolvedMax) or 0
  if resolvedMax < 0 then
    resolvedMax = 0
  end

  return resolvedMax
end

function Secondary:GetResourceSettings(profile, resourceKey, classToken, specID, resourceIndex)
  local secondary = profile.secondary
  secondary.resourceSettings = secondary.resourceSettings or {}
  classToken = classToken or PLAYER_CLASS
  specID = specID or GetPlayerSpecID()
  if not specID then return nil end
  local classSettings = secondary.resourceSettings[classToken]
  if not classSettings then
    classSettings = {}
    secondary.resourceSettings[classToken] = classSettings
  end

  local specSettings = classSettings[specID]
  if not specSettings then
    specSettings = {}
    classSettings[specID] = specSettings
  end
  local settings = specSettings[resourceKey]
  if not settings then
    settings = {}
    specSettings[resourceKey] = settings
  end

  if settings.enabled == nil then
    local definition = RESOURCE_DEFINITIONS_BY_CLASS[classToken][resourceKey]
    settings.enabled = definition.defaultEnabled ~= false
      and (not definition.legacySpecID or definition.legacySpecID == specID)
  end
  if settings.visibilityMode == nil then settings.visibilityMode = "ALWAYS" end

  settings.behavior = settings.behavior or {}
  local behavior = settings.behavior
  if behavior.darkenPartial == nil then behavior.darkenPartial = false end
  if resourceKey == "COMBO_POINTS" and classToken == "ROGUE" then
    if behavior.colorChargedPoints == nil then behavior.colorChargedPoints = false end
    if behavior.chargedColor == nil then behavior.chargedColor = { 0.44, 0.77, 1, 1 } end
  elseif resourceKey == "MAELSTROM_WEAPON" then
    if behavior.fiveBarStyle == nil then behavior.fiveBarStyle = false end
    if behavior.overflowColor == nil then behavior.overflowColor = { 1, 0.6, 0.2, 1 } end
  elseif resourceKey == "IRONFUR" then
    if behavior.fillMode == nil then behavior.fillMode = "DURATION" end
    behavior.stackCeiling = math.max(1, math.min(50, tonumber(behavior.stackCeiling) or 10))
  end

  if resourceKey == "RUNES" then
    behavior.rechargeAnimation = nil
    if behavior.simpleRunes == nil then behavior.simpleRunes = false end
    if behavior.customRechargeColor == nil then behavior.customRechargeColor = false end
    if behavior.rechargeColor == nil then behavior.rechargeColor = { 0.5, 0.5, 0.5, 1 } end
    if behavior.showRechargeTime == nil then behavior.showRechargeTime = true end
    if behavior.showQueuedRuneTime == nil then behavior.showQueuedRuneTime = false end
    if behavior.showReadyGlow == nil then behavior.showReadyGlow = true end
    if behavior.completionAnimation == nil then behavior.completionAnimation = "FADE" end
  elseif resourceKey == "ESSENCE" then
    if behavior.showRechargeTime == nil then behavior.showRechargeTime = true end
    if behavior.showReadyGlow == nil then behavior.showReadyGlow = true end
    if behavior.completionAnimation == nil then behavior.completionAnimation = "FADE" end
    if behavior.rechargeDirection == nil then behavior.rechargeDirection = "LTR" end
  elseif resourceKey == "STAGGER" then
    if behavior.useSeverityColors == nil then behavior.useSeverityColors = true end
    if behavior.showSeverityLabel == nil then behavior.showSeverityLabel = false end
    if behavior.yellowThreshold == nil then behavior.yellowThreshold = 30 end
    if behavior.redThreshold == nil then behavior.redThreshold = 60 end
    behavior.fillCeiling = math.max(1, math.min(500, tonumber(behavior.fillCeiling) or 100))
  end

  if resourceKey == "RUNES" or resourceKey == "ESSENCE" then
    if behavior.completionAnimation ~= "FADE" and behavior.completionAnimation ~= "PULSE" then
      behavior.completionAnimation = "FADE"
    end
  end

  if (resourceKey == "RUNES" or resourceKey == "ESSENCE")
    and behavior.rechargeDirection ~= "LTR"
    and behavior.rechargeDirection ~= "RTL"
    and behavior.rechargeDirection ~= "TTB"
    and behavior.rechargeDirection ~= "BTT"
  then
    behavior.rechargeDirection = "LTR"
  end

  if resourceKey == "STAGGER" then
    behavior.yellowThreshold = math.max(0, math.min(99, tonumber(behavior.yellowThreshold) or 30))
    behavior.redThreshold = math.max(1, math.min(100, tonumber(behavior.redThreshold) or 60))
    if behavior.redThreshold < behavior.yellowThreshold then
      behavior.redThreshold = behavior.yellowThreshold
    end
  end

  if settings.detached == nil then settings.detached = secondary.detached == true end
  settings.useSharedAppearance = nil
  if settings.height == nil then settings.height = secondary.height or profile.appearance.height or 15 end
  if settings.width == nil then settings.width = secondary.width or profile.size.width or 240 end
  if settings.perSegment == nil then settings.perSegment = secondary.perSegment == true end
  if settings.texture == nil then settings.texture = secondary.texture or profile.appearance.texture or "Pleebar" end
  if settings.useCustomColor == nil then settings.useCustomColor = secondary.useCustomColor == true end
  if settings.useBlizzardPowerColor == nil then settings.useBlizzardPowerColor = secondary.useBlizzardPowerColor ~= false end
  if settings.useClassColor == nil then settings.useClassColor = secondary.useClassColor == true end
  if settings.customColor == nil then
    local color = secondary.customColor or { 1, 1, 1, 1 }
    settings.customColor = { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
  end

  settings.style = settings.style or {}
  local secondaryStyle = secondary.style or profile.appearance.style
  if settings.style.borderSize == nil then settings.style.borderSize = secondaryStyle.borderSize or 1 end
  if settings.style.borderColor == nil then
    local color = secondaryStyle.borderColor or { 0.20, 0.20, 0.24, 1 }
    settings.style.borderColor = { color[1] or 0.20, color[2] or 0.20, color[3] or 0.24, color[4] or 1 }
  end
  if settings.style.bgColor == nil then
    local color = secondaryStyle.bgColor or { 0, 0, 0, 0.65 }
    settings.style.bgColor = { color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0.65 }
  end

  settings.text = settings.text or {}
  local secondaryText = profile.text.secondary
  if settings.text.mode == nil then
    settings.text.mode = resourceKey == "IGNORE_PAIN" and "PCT" or secondaryText.mode or "CUR"
  end
  if settings.text.showNumber == nil then settings.text.showNumber = secondaryText.showNumber ~= false end
  if settings.text.size == nil then settings.text.size = secondaryText.size or profile.appearance.text.size or 14 end
  if settings.text.flags == nil then settings.text.flags = secondaryText.flags or profile.appearance.text.flags or "" end
  if settings.text.font == nil then settings.text.font = secondaryText.font or profile.appearance.text.font end
  if settings.text.useGlobalFont == nil then settings.text.useGlobalFont = secondaryText.useGlobalFont ~= false end

  settings.anchor = settings.anchor or {}
  if settings.anchor.point == nil then settings.anchor.point = "CENTER" end
  if settings.anchor.x == nil then settings.anchor.x = secondary.anchor and secondary.anchor.x or 0 end
  if settings.anchor.y == nil then
    local sharedY = secondary.anchor and secondary.anchor.y or -230
    local index = math.max(1, tonumber(resourceIndex) or 1)
    settings.anchor.y = sharedY
      - ((index - 1) * ((settings.height or 15) + (secondary.gap or 2)))
  end

  if settings.inactiveAlpha == nil then settings.inactiveAlpha = secondary.inactiveAlpha or 0.15 end
  if settings.showDividers == nil then
    settings.showDividers = resourceKey ~= "IGNORE_PAIN" and secondary.showDividers ~= false
  end
  if settings.stackTickValues == nil then settings.stackTickValues = "ALL" end
  if settings.dividerSize == nil then settings.dividerSize = secondary.dividerSize or 1 end
  if settings.dividerColor == nil then
    local color = secondary.dividerColor or { 0.20, 0.20, 0.24, 1 }
    settings.dividerColor = { color[1] or 0.20, color[2] or 0.20, color[3] or 0.24, color[4] or 1 }
  end
  if settings.showSpellIcon == nil then settings.showSpellIcon = false end
  if settings.iconGap == nil then settings.iconGap = 2 end
  if APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[resourceKey]
    and settings.showApplicationsRemaining == nil
  then
    settings.showApplicationsRemaining = false
  end
  if STACK_COLOR_SHIFT_DISABLED_RESOURCES[resourceKey] then
    settings.stackColorThresholds = nil
  end

  settings.cues = settings.cues or {}
  local cues = settings.cues
  if cues.desaturateMode == nil then cues.desaturateMode = "NONE" end
  if cues.desaturateThreshold == nil then cues.desaturateThreshold = 0 end
  if cues.glowMode == nil then cues.glowMode = "NONE" end
  if cues.glowThreshold == nil then cues.glowThreshold = 0 end
  if cues.glowType == nil then cues.glowType = "PIXEL" end
  if cues.glowColor == nil then cues.glowColor = { 1, 0.82, 0, 1 } end
  if cues.buffGlowSpellID == nil then
    if resourceKey == "SHINING_LIGHT" then
      cues.buffGlowSpellID = 327510
    elseif resourceKey == "ARCANE_SALVO" then
      cues.buffGlowSpellID = 1223797
    elseif resourceKey == "FREEZING" then
      cues.buffGlowSpellID = 1247730
    else
      cues.buffGlowSpellID = 0
    end
  end
  if cues.buffGlowEnabled == nil then
    cues.buffGlowEnabled = (tonumber(cues.buffGlowSpellID) or 0) > 0
  end
  cues.buffGlowType = nil
  if cues.buffGlowColor == nil then cues.buffGlowColor = { 0.25, 0.75, 1, 1 } end

  return settings
end

local function CopyMissingResourceSettings(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" then
      if target[key] == nil then target[key] = {} end
      if type(target[key]) == "table" then
        CopyMissingResourceSettings(target[key], value)
      end
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

function Secondary:NormalizeProfile(profile)
  local secondary = profile.secondary
  local migrating = secondary.__puiSpecResourcesMigrated ~= true
  local allSettings = secondary.resourceSettings or {}
  secondary.resourceSettings = allSettings
  for classToken, definitions in pairs(RESOURCE_DEFINITIONS_BY_CLASS) do
    local classSettings = allSettings[classToken] or {}
    allSettings[classToken] = classSettings
    for _, spec in ipairs(SPECIALIZATIONS_BY_CLASS[classToken]) do
      local specSettings = classSettings[spec.id] or {}
      classSettings[spec.id] = specSettings
      for resourceKey, definition in pairs(definitions) do
        local settings = specSettings[resourceKey] or {}
        specSettings[resourceKey] = settings
        if migrating then
          local hadEnabled = settings.enabled ~= nil
          if classSettings[resourceKey] then
            CopyMissingResourceSettings(settings, classSettings[resourceKey])
          end
          if allSettings[resourceKey] then
            CopyMissingResourceSettings(settings, allSettings[resourceKey])
          end
          if not hadEnabled then
            if definition.isAlternatePower ~= true and secondary.enabled == false then
              settings.enabled = false
            elseif definition.legacySpecID and definition.legacySpecID ~= spec.id then
              settings.enabled = false
            elseif settings.enabled == nil and secondary.resourceEnabled then
              settings.enabled = secondary.resourceEnabled[resourceKey]
            end
          end
          if settings.visibilityMode == nil then
            settings.visibilityMode = secondary.visibilityMode
          end
        end
        self:GetResourceSettings(profile, resourceKey, classToken, spec.id)
      end
    end
    if migrating then
      for resourceKey in pairs(definitions) do classSettings[resourceKey] = nil end
    end
  end

  if migrating then
    -- Copy every class/spec before retiring shared settings from existing profiles.
    for _, definitions in pairs(RESOURCE_DEFINITIONS_BY_CLASS) do
      for resourceKey in pairs(definitions) do
        allSettings[resourceKey] = nil
        if secondary.resourceEnabled then secondary.resourceEnabled[resourceKey] = nil end
      end
    end
    if secondary.resourceEnabled and not next(secondary.resourceEnabled) then
      secondary.resourceEnabled = nil
    end
    secondary.enabled = nil
    secondary.visibilityMode = nil
    secondary.__puiClassResourcesMigrated = nil
    secondary.__puiSpecResourcesMigrated = true
  end
end

function Secondary:ResourceSupportsNumericCues(resourceKey)
  return NUMERIC_CUE_RESOURCES[resourceKey] == true
end

function Secondary:ResourceSupportsStackColorShifts(resourceKey)
  return STACK_COLOR_SHIFT_DISABLED_RESOURCES[resourceKey] ~= true
end

function Secondary:GetApplicationCountdownMax(resourceKey)
  return APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[resourceKey]
end

local function BuildResourceConfigStateKey(config)
  local anchor = config.anchor
  local style = config.style
  local text = config.text
  local font = config.font
  local cues = config.cues
  local behavior = config.behavior
  local customColor = config.customColor
  local defaultColor = config.defaultColor
  local borderColor = style.borderColor
  local backgroundColor = style.bgColor
  local dividerColor = config.dividerColor
  local glowColor = cues.glowColor
  local buffGlowColor = cues.buffGlowColor

  return table.concat({
    config.resourceKey,
    config.specID,
    config.detached and 1 or 0,
    config.height, config.width,
    anchor.point, anchor.x, anchor.y,
    config.perSegment and 1 or 0,
    config.showApplicationsRemaining and 1 or 0,
    config.applicationCountdownMax or 0,
    config.texture or "",
    config.useCustomColor and 1 or 0,
    config.useBlizzardPowerColor and 1 or 0,
    config.useClassColor and 1 or 0,
    customColor[1], customColor[2], customColor[3], customColor[4],
    defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4],
    style.borderSize,
    borderColor[1], borderColor[2], borderColor[3], borderColor[4],
    backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4],
    text.mode, text.showNumber and 1 or 0,
    font.font or "", font.size or 14, font.flags or "", font.useGlobalFont and 1 or 0,
    config.inactiveAlpha, config.showDividers and 1 or 0, config.stackTickValues or "", config.dividerSize,
    dividerColor[1], dividerColor[2], dividerColor[3], dividerColor[4],
    config.showSpellIcon and 1 or 0, config.iconGap,
    cues.desaturateMode, cues.desaturateThreshold,
    cues.glowMode, cues.glowThreshold, cues.glowType,
    glowColor[1], glowColor[2], glowColor[3], glowColor[4],
    cues.buffGlowSpellID,
    buffGlowColor[1], buffGlowColor[2], buffGlowColor[3], buffGlowColor[4],
    behavior.showRechargeTime and 1 or 0,
    behavior.showQueuedRuneTime and 1 or 0,
    behavior.showReadyGlow and 1 or 0,
    behavior.completionAnimation or "",
    behavior.rechargeDirection or "",
    behavior.useSeverityColors and 1 or 0,
    behavior.showSeverityLabel and 1 or 0,
    behavior.yellowThreshold or "",
    behavior.redThreshold or "",
    behavior.fillCeiling,
    behavior.fillMode,
    behavior.simpleRunes and 1 or 0,
    behavior.customRechargeColor and 1 or 0,
    behavior.rechargeColor[1], behavior.rechargeColor[2], behavior.rechargeColor[3], behavior.rechargeColor[4],
    behavior.darkenPartial and 1 or 0,
    behavior.colorChargedPoints and 1 or 0,
    behavior.chargedColor[1], behavior.chargedColor[2], behavior.chargedColor[3], behavior.chargedColor[4],
    behavior.fiveBarStyle and 1 or 0,
    behavior.overflowColor[1], behavior.overflowColor[2], behavior.overflowColor[3], behavior.overflowColor[4],
  }, "|")
end

local function BuildResourceConfigStructureKey(config)
  return table.concat({
    config.resourceKey,
    config.specID,
    config.perSegment and 1 or 0,
    config.behavior.fiveBarStyle and 1 or 0,
  }, "|")
end

local function CopyColor(color, r, g, b, a)
  color = color or {}
  return {
    tonumber(color[1] or color.r) or r,
    tonumber(color[2] or color.g) or g,
    tonumber(color[3] or color.b) or b,
    tonumber(color[4] or color.a) or a,
  }
end

local function ResolveResourceConfig(profile, definition, specID)
  if not definition then
    return nil
  end

  local revision = M._puiRuntimeConfigRevision or 0
  local cacheKey = definition.resourceKey
  local cached = M._puiResourceConfigCache[cacheKey]
  if cached
    and cached.profile == profile
    and cached.definition == definition
    and cached.specID == specID
    and cached.revision == revision
  then
    return cached.config
  end

  local shared = profile.secondary
  local settings = shared.resourceSettings[PLAYER_CLASS][specID][definition.resourceKey]
  local appearance = settings
  local text = settings.text
  local font = settings.text
  local colorSource = settings

  local sourceStyle = appearance.style
  local sourceBehavior = settings.behavior
  local sourceCues = settings.cues
  local sourceAnchor = settings.anchor
  local customColor = CopyColor(
    colorSource.customColor or definition.defaultColor,
    1, 1, 1, 1
  )
  local stackColorThresholds
  if definition.adapter == "AURA_STACKS"
    and Secondary:ResourceSupportsStackColorShifts(definition.resourceKey)
  then
    local thresholds = AuraWidget.EnsureStackColorThresholds(settings)
    if thresholds and #thresholds > 0 then
      stackColorThresholds = {}
      for index = 1, #thresholds do
        local threshold = thresholds[index]
        stackColorThresholds[index] = {
          enabled = threshold.enabled == true,
          value = threshold.value,
          colorMode = threshold.colorMode,
          color = CopyColor(threshold.color, 1, 0.82, 0, 1),
        }
      end
    end
  end
  local dividerColor = CopyColor(
    settings.dividerColor or shared.dividerColor,
    0.20, 0.20, 0.24, 1
  )

  local config = {
    resourceKey = definition.resourceKey,
    specID = specID,
    visibilityMode = settings.visibilityMode,
    resourceName = RESOURCE_NAMES[definition.resourceKey] or definition.resourceKey,
    thresholdGlowKey = "PUI_PRD_THRESHOLD_" .. definition.resourceKey,
    detached = settings.detached == true,
    height = tonumber(appearance.height) or 15,
    width = tonumber(settings.width) or shared.width or profile.size.width or 240,
    anchor = {
      point = sourceAnchor.point,
      x = sourceAnchor.x,
      y = sourceAnchor.y,
    },
    perSegment = settings.perSegment == true,
    showApplicationsRemaining = settings.showApplicationsRemaining == true
      and APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[definition.resourceKey] ~= nil,
    applicationCountdownMax = tonumber(
      APPLICATION_COUNTDOWN_MAX_BY_RESOURCE[definition.resourceKey]
    ) or 0,
    texture = appearance.texture,
    useCustomColor = colorSource.useCustomColor == true,
    useBlizzardPowerColor = colorSource.useBlizzardPowerColor ~= false,
    useClassColor = colorSource.useClassColor == true,
    customColor = customColor,
    stackColorThresholds = stackColorThresholds,
    style = {
      borderSize = tonumber(sourceStyle.borderSize) or 1,
      borderColor = CopyColor(sourceStyle.borderColor, 0.20, 0.20, 0.24, 1),
      bgColor = CopyColor(sourceStyle.bgColor, 0, 0, 0, 0.65),
    },
    text = {
      mode = text.mode or "CUR",
      showNumber = text.showNumber ~= false,
    },
    font = {
      font = font.font,
      size = tonumber(font.size) or 14,
      flags = font.flags or "",
      useGlobalFont = font.useGlobalFont == true,
    },
    inactiveAlpha = tonumber(settings.inactiveAlpha) or shared.inactiveAlpha or 0.15,
    showDividers = settings.showDividers ~= false,
    stackTickValues = settings.stackTickValues or "ALL",
    dividerSize = tonumber(settings.dividerSize) or shared.dividerSize or 1,
    dividerColor = dividerColor,
    showSpellIcon = settings.showSpellIcon == true and definition.auraSpellIDs ~= nil,
    iconGap = tonumber(settings.iconGap) or 2,
    iconSpellID = definition.auraSpellIDs and definition.auraSpellIDs[1] or nil,
    behavior = {
      showRechargeTime = sourceBehavior.showRechargeTime ~= false,
      showQueuedRuneTime = sourceBehavior.showQueuedRuneTime == true,
      showReadyGlow = sourceBehavior.showReadyGlow ~= false,
      completionAnimation = sourceBehavior.completionAnimation or "FADE",
      rechargeDirection = sourceBehavior.rechargeDirection or "LTR",
      useSeverityColors = sourceBehavior.useSeverityColors ~= false,
      showSeverityLabel = sourceBehavior.showSeverityLabel == true,
      yellowThreshold = tonumber(sourceBehavior.yellowThreshold) or 30,
      redThreshold = tonumber(sourceBehavior.redThreshold) or 60,
      fillCeiling = tonumber(sourceBehavior.fillCeiling) or 100,
      fillMode = sourceBehavior.fillMode or "STACKS",
      simpleRunes = sourceBehavior.simpleRunes == true,
      customRechargeColor = sourceBehavior.customRechargeColor == true,
      rechargeColor = CopyColor(sourceBehavior.rechargeColor, 0.5, 0.5, 0.5, 1),
      darkenPartial = sourceBehavior.darkenPartial == true,
      colorChargedPoints = PLAYER_CLASS == "ROGUE" and sourceBehavior.colorChargedPoints == true,
      chargedColor = CopyColor(sourceBehavior.chargedColor, 0.44, 0.77, 1, 1),
      fiveBarStyle = definition.resourceKey == "MAELSTROM_WEAPON" and sourceBehavior.fiveBarStyle == true,
      overflowColor = CopyColor(sourceBehavior.overflowColor, 1, 0.6, 0.2, 1),
    },
    cues = {
      desaturateMode = sourceCues.desaturateMode or "NONE",
      desaturateThreshold = tonumber(sourceCues.desaturateThreshold) or 0,
      glowMode = sourceCues.glowMode or "NONE",
      glowThreshold = tonumber(sourceCues.glowThreshold) or 0,
      glowType = sourceCues.glowType or "PIXEL",
      glowColor = CopyColor(sourceCues.glowColor, 1, 0.82, 0, 1),
      buffGlowSpellID = sourceCues.buffGlowEnabled == true and (tonumber(sourceCues.buffGlowSpellID) or 0) or 0,
      buffGlowColor = CopyColor(sourceCues.buffGlowColor, 0.25, 0.75, 1, 1),
    },
    supportsNumericCues = NUMERIC_CUE_RESOURCES[definition.resourceKey] == true,
    defaultColor = CopyColor(
      definition.defaultColorBySpec and definition.defaultColorBySpec[specID] or definition.defaultColor,
      1, 1, 1, 1
    ),
  }

  config.stateKey = BuildResourceConfigStateKey(config)
  config.structureKey = BuildResourceConfigStructureKey(config)
  M._puiResourceConfigCache[cacheKey] = {
    profile = profile,
    definition = definition,
    specID = specID,
    revision = revision,
    config = config,
  }
  return config
end

local function ResolveDefinitions()
  local candidates, specID = GetResolvedDefinitionCandidates()
  if not candidates then
    return nil, specID
  end

  local profile = M.db.profile
  local resources = {}

  for index = 1, #candidates do
    local definition = candidates[index]
    local appliesToSpec = type(definition.specIDs) ~= "table"
      or definition.specIDs[specID] == true

    if appliesToSpec and IsDefinitionEnabled(definition, profile) then
      local resolvedMax = ResolveMaximum(definition)
      local minimum = tonumber(definition.minRealMax) or 0

      if minimum <= 0 or resolvedMax >= minimum then
        local resolvedTexture = definition.textureBySpec
          and (definition.textureBySpec[specID] or definition.texture)
          or definition.texture

        local precisePower = definition.preciseResourceCount == true
        if definition.preciseResourceCountBySpec then
          precisePower = definition.preciseResourceCountBySpec[specID] == true
        end

        local currentDivisor = definition.currentDivisor or 1
        if definition.currentDivisorBySpec then
          currentDivisor = definition.currentDivisorBySpec[specID] or currentDivisor
        end

        resources[#resources + 1] = {
          definition = definition,
          adapter = Secondary.Adapters[definition.adapter],
          maximum = resolvedMax,
          texture = resolvedTexture,
          precisePower = precisePower == true,
          currentDivisor = currentDivisor,
          config = ResolveResourceConfig(profile, definition, specID),
        }
      end
    end
  end

  if #resources == 0 then
    return nil, specID
  end

  return resources, specID
end

local function IsResourceVisibilityAllowed(resource)
  if resource.definition.isAlternatePower == true then
    return true
  end

  local mode = resource.config.visibilityMode
  if mode == "COMBAT" then
    return UnitAffectingCombat("player") == true
  elseif mode == "TARGET" then
    return UnitExists("target") == true
  elseif mode == "COMBAT_OR_TARGET" then
    return UnitAffectingCombat("player") == true or UnitExists("target") == true
  end
  return true
end

function M:GetSecondaryDefinition()
  local profile = self.db.profile
  local revision = self._puiRuntimeConfigRevision or 0
  local configReady = self._puiSecondaryDefinitionReady == true
    and self._puiSecondaryDefinitionDirty ~= true
    and self._puiSecondaryDefinitionProfile == profile
    and self._puiSecondaryDefinitionRevision == revision
  if configReady and self._puiSecondaryVisibilityDirty ~= true then
    return self.secondaryDef
  end

  local resources, specID
  if configReady then
    resources, specID = self.secondaryResources, self.secondarySpecID
  else
    -- Spec events can reach the new profile before its deferred settings refresh.
    if profile.secondary.__puiSpecResourcesMigrated ~= true then
      Secondary:NormalizeProfile(profile)
    end
    resources, specID = ResolveDefinitions()
    resources = resources or {}
  end

  local hasVisibleResources = false
  for index = 1, #resources do
    local resource = resources[index]
    resource.visible = IsResourceVisibilityAllowed(resource)
    hasVisibleResources = hasVisibleResources or resource.visible
  end
  self._puiSecondaryHasVisibleResources = hasVisibleResources
  local primary = resources[1]
  local definition = primary and primary.definition or nil

  self.secondaryResources = resources
  self.secondaryResourceByKey = {}
  self.secondaryAdapters = {}

  local seenAdapters = {}
  for index = 1, #self.secondaryResources do
    local resource = self.secondaryResources[index]
    local resourceKey = resource.definition.resourceKey
    local adapter = resource.adapter

    resource.index = index
    self.secondaryResourceByKey[resourceKey] = resource

    if resource.visible and adapter and seenAdapters[adapter] ~= true then
      seenAdapters[adapter] = true
      self.secondaryAdapters[#self.secondaryAdapters + 1] = adapter
    end
  end

  self.secondaryDef = definition
  self.secondarySpecID = specID
  self.secondaryResolvedMax = primary and primary.maximum or 0
  self.secondaryTexture = primary and primary.texture or nil
  self.secondaryPowerPrecise = primary and primary.precisePower == true or false
  self.secondaryCurrentDivisor = primary and primary.currentDivisor or 1
  self.secondaryDisplayFloor = definition and definition.displayFloor == true or false
  self.secondaryAdapter = primary and primary.adapter or nil
  self.secondaryResourceConfig = primary and primary.config or nil
  self._puiSecColorDirty = true

  if self.secondary then
    self:AssignSecondaryResourceFrames()
  end

  self._puiSecondaryDefinitionProfile = profile
  self._puiSecondaryDefinitionRevision = revision
  self._puiSecondaryDefinitionDirty = nil
  self._puiSecondaryVisibilityDirty = nil
  self._puiSecondaryDefinitionReady = true

  return definition
end

function M:ResolveSecondaryType()
  local definition = self:GetSecondaryDefinition()
  if not definition then
    return nil, nil, 0
  end

  return definition.powerType, definition.token, self.secondaryResolvedMax
end

Secondary.RegisterAdapter = P:Def("RegisterAdapter", Secondary.RegisterAdapter)
Secondary.GetResourceDefinition = P:Def("GetResourceDefinition", Secondary.GetResourceDefinition)
Secondary.GetCooldownCountResourceKey = P:Def("GetCooldownCountResourceKey", Secondary.GetCooldownCountResourceKey)
Secondary.GetResourceDisplayMode = P:Def("GetResourceDisplayMode", Secondary.GetResourceDisplayMode)
Secondary.SetResourceDisplayMode = P:Def("SetResourceDisplayMode", Secondary.SetResourceDisplayMode)
Secondary.GetResourceOptionsForClass = P:Def("GetResourceOptionsForClass", Secondary.GetResourceOptionsForClass)
Secondary.GetResourceSettings = P:Def("GetResourceSettings", Secondary.GetResourceSettings)
Secondary.NormalizeProfile = P:Def("NormalizeProfile", Secondary.NormalizeProfile)
Secondary.ResourceSupportsNumericCues = P:Def("ResourceSupportsNumericCues", Secondary.ResourceSupportsNumericCues)
Secondary.ResourceSupportsStackColorShifts = P:Def(
  "ResourceSupportsStackColorShifts",
  Secondary.ResourceSupportsStackColorShifts
)
Secondary.GetApplicationCountdownMax = P:Def("GetApplicationCountdownMax", Secondary.GetApplicationCountdownMax)
GetPlayerSpecID = P:Def("GetPlayerSpecialization", GetPlayerSpecID)
Secondary.GetPlayerSpecialization = GetPlayerSpecID
GetResolvedDefinitionCandidates = P:Def(
  "GetResolvedDefinitionCandidates",
  GetResolvedDefinitionCandidates
)
IsDefinitionEnabled = P:Def("IsDefinitionEnabled", IsDefinitionEnabled)
ResolveMaximum = P:Def("ResolveMaximum", ResolveMaximum)
Secondary.ResolveMaximum = ResolveMaximum
CopyMissingResourceSettings = P:Def("CopyMissingResourceSettings", CopyMissingResourceSettings)
IsResourceVisibilityAllowed = P:Def("IsResourceVisibilityAllowed", IsResourceVisibilityAllowed)
BuildResourceConfigStateKey = P:Def("BuildResourceConfigStateKey", BuildResourceConfigStateKey)
BuildResourceConfigStructureKey = P:Def(
  "BuildResourceConfigStructureKey",
  BuildResourceConfigStructureKey
)
CopyColor = P:Def("CopyColor", CopyColor)
ResolveResourceConfig = P:Def("ResolveResourceConfig", ResolveResourceConfig)
ResolveDefinitions = P:Def("ResolveDefinitions", ResolveDefinitions)
M.GetSecondaryDefinition = P:Def("GetSecondaryDefinition", M.GetSecondaryDefinition)
M.ResolveSecondaryType = P:Def("ResolveSecondaryType", M.ResolveSecondaryType)
