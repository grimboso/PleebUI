local _, ns = ...

local Secondary = {}
ns.ResourceSettings = Secondary

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
  local icons = ns.ResourceCounts:GetEnabled(resourceKey)
  local profile = ns.Addon.PRDDB.profile
  if profile.secondary.__puiSpecResourcesMigrated ~= true then self:NormalizeProfile(profile) end
  local bar = self:GetResourceSettings(profile, resourceKey).enabled ~= false
  if icons then return bar and "BOTH" or "ICONS" end
  return bar and "BAR" or "NONE"
end

function Secondary:SetResourceDisplayMode(resourceKey, mode)
  ns.ResourceCounts:SetEnabled(resourceKey, mode == "ICONS" or mode == "BOTH")
  local module = ns.Modules.PRD
  if module then
    module:SetSecondaryResourceEnabled(resourceKey, mode == "BAR" or mode == "BOTH")
  else
    local profile = ns.Addon.PRDDB.profile
    if profile.secondary.__puiSpecResourcesMigrated ~= true then self:NormalizeProfile(profile) end
    self:GetResourceSettings(profile, resourceKey).enabled = mode == "BAR" or mode == "BOTH"
  end
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

Secondary.GetPlayerSpecialization = GetPlayerSpecID
Secondary.GetResolvedDefinitionCandidates = GetResolvedDefinitionCandidates
Secondary.ResourceNames = RESOURCE_NAMES
Secondary.NumericCueResources = NUMERIC_CUE_RESOURCES
Secondary.ApplicationCountdownMaxByResource = APPLICATION_COUNTDOWN_MAX_BY_RESOURCE
