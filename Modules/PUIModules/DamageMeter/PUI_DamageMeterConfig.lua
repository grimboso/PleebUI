local _, ns = ...

local DamageMeters = ns.Modules.DamageMeters
local Config = ns.DamageMeterConfig
local Breakdown = ns.DamageMeterBreakdown
local History = ns.DamageMeterHistory
local Constants = ns.DamageMeterConstants
local P = ns.DamageMeterProfiler

local _G = _G
local math_floor = _G.math.floor

local MAX_WINDOWS = Constants.MAX_WINDOWS
local BREAKDOWN_ROW_POOL_SIZE = Constants.BREAKDOWN_ROW_POOL_SIZE
local METER_TYPES = Constants.METER_TYPES
local SESSION_TYPES = Constants.SESSION_TYPES
local Clamp = ns.DamageMeterUtil.Clamp
local Round = ns.DamageMeterUtil.Round

local DEFAULT_WINDOW_POSITIONS = {
  [1] = { x = 420, y = -250 },
  [2] = { x = 420, y = -50 },
  [3] = { x = 420, y = 150 },
  [4] = { x = 444, y = -226 },
  [5] = { x = 468, y = -202 },
  [6] = { x = 492, y = -178 },
  [7] = { x = 516, y = -154 },
  [8] = { x = 540, y = -130 },
  [9] = { x = 564, y = -106 },
  [10] = { x = 588, y = -82 },
}

local DEFAULTS = {
  profile = {
    enabled = true,
    visible = true,
    windowCount = 1,
    refreshRate = 1,
    headerHeight = 30,
    barHeight = 20,
    barSpacing = 2,
    fontSize = 11,
    barAlpha = 0.82,
    showSpecIcons = true,
    history = {
      saveBossKills = true,
      bossKillsToKeep = 15,
      saveKeystones = true,
      dungeonSummariesToKeep = 10,
    },
    breakdown = {
      position = "AUTO",
      width = 360,
      height = 260,
      targetHeight = 150,
      x = 0,
      y = 0,
      showIcons = true,
      amounts = "BOTH",
      showPercent = true,
      maxSpells = 20,
      showSpellTooltips = true,
    },
    minimap = {
      hide = false,
      minimapPos = 250,
    },
    windows = {
      [1] = {
        meter = "DAMAGE_DONE",
        session = "CURRENT",
        locked = true,
        shown = true,
        width = 320,
        height = 180,
        x = 420,
        y = -250,
      },
    },
  },
  char = {
    history = {
      savedSegments = {},
      savedDungeons = {},
      nextRecordID = 0,
    },
  },
}
local function GetWindowDB(index)
  local db = DamageMeters.db.profile
  local windowDB = db.windows[index]

  if not windowDB then
    local position = DEFAULT_WINDOW_POSITIONS[index]
    windowDB = {
      meter = "DAMAGE_DONE",
      session = "CURRENT",
      locked = true,
      shown = true,
      width = 320,
      height = 180,
      x = position.x,
      y = position.y,
    }
    db.windows[index] = windowDB
  end

  return windowDB
end

local function SanitizeProfile()
  local db = DamageMeters.db.profile

  db.visible = db.visible ~= false
  db.windowCount = Clamp(math_floor(db.windowCount or 1), 0, MAX_WINDOWS)
  db.refreshRate = Clamp(db.refreshRate or 1, 0.25, 2)
  db.headerHeight = Clamp(math_floor(db.headerHeight or 30), 24, 40)
  db.barHeight = Clamp(math_floor(db.barHeight or 20), 14, 32)
  db.barSpacing = Clamp(math_floor(db.barSpacing or 2), 0, 8)
  db.fontSize = Clamp(math_floor(db.fontSize or 11), 8, 18)
  db.barAlpha = Clamp(db.barAlpha or 0.82, 0.2, 1)
  db.showSpecIcons = db.showSpecIcons ~= false
  db.history = db.history or {}
  db.history.bossKillsToKeep = Clamp(math_floor(db.history.bossKillsToKeep or 15), 0, 50)
  db.history.dungeonSummariesToKeep = Clamp(
    math_floor(db.history.dungeonSummariesToKeep or 10),
    0,
    30
  )
  db.history.saveBossKills = db.history.saveBossKills ~= false
  db.history.saveKeystones = db.history.saveKeystones ~= false
  db.breakdown = db.breakdown or {}
  if db.breakdown.position ~= "FLOATING" then
    db.breakdown.position = "AUTO"
  end
  db.breakdown.width = Clamp(math_floor(db.breakdown.width or 360), 260, 700)
  db.breakdown.height = Clamp(math_floor(db.breakdown.height or 260), 120, 600)
  db.breakdown.targetHeight = Clamp(math_floor(db.breakdown.targetHeight or 150), 90, 400)
  db.breakdown.x = Round(db.breakdown.x or 0)
  db.breakdown.y = Round(db.breakdown.y or 0)
  db.breakdown.showIcons = db.breakdown.showIcons ~= false
  if db.breakdown.amounts ~= "TOTAL" and db.breakdown.amounts ~= "RATE" and db.breakdown.amounts ~= "BOTH" then
    db.breakdown.amounts = "BOTH"
  end
  db.breakdown.showPercent = db.breakdown.showPercent ~= false
  db.breakdown.maxSpells = Clamp(math_floor(db.breakdown.maxSpells or 20), 5, BREAKDOWN_ROW_POOL_SIZE)
  db.breakdown.showSpellTooltips = db.breakdown.showSpellTooltips ~= false
  db.minimap = db.minimap or {}
  db.minimap.hide = db.minimap.hide == true
  db.minimap.minimapPos = db.minimap.minimapPos or 250

  for index = 1, db.windowCount do
    local windowDB = GetWindowDB(index)
    local defaultPosition = DEFAULT_WINDOW_POSITIONS[index]

    if not METER_TYPES[windowDB.meter] then
      windowDB.meter = "DAMAGE_DONE"
    end
    if not SESSION_TYPES[windowDB.session] then
      windowDB.session = "CURRENT"
    end
    windowDB.sessionID = nil

    windowDB.locked = windowDB.locked ~= false
    windowDB.shown = windowDB.shown ~= false
    windowDB.alwaysShowMe = windowDB.alwaysShowMe == true
    windowDB.width = Clamp(math_floor(windowDB.width or 320), 220, 700)
    windowDB.height = Clamp(math_floor(windowDB.height or 180), 90, 600)
    windowDB.x = Round(windowDB.x or defaultPosition.x)
    windowDB.y = Round(windowDB.y or defaultPosition.y)
  end
end

function DamageMeters:GetOptions()
  local refreshValues = {
    [0.25] = "0.25 seconds",
    [0.5] = "0.5 seconds",
    [1] = "1 second",
    [1.5] = "1.5 seconds",
    [2] = "2 seconds",
  }

  local breakdownPositionValues = {
    AUTO = "Automatic side",
    FLOATING = "Floating",
  }

  local breakdownAmountValues = {
    TOTAL = "Total",
    RATE = "Rate",
    BOTH = "Total and rate",
  }

  local options = {
    type = "group",
    name = "Damage Meters",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 10,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Enable damage meters",
            order = 10,
            get = function()
              return self.db.profile.enabled
            end,
            set = function(_, value)
              self.db.profile.enabled = value
              self:ApplySettings()
            end,
          },
          visible = {
            type = "toggle",
            name = "Show windows",
            order = 20,
            disabled = function()
              return self.db.profile.enabled == false
            end,
            get = function()
              return self.db.profile.visible
            end,
            set = function(_, value)
              self:SetWindowsVisible(value)
            end,
          },

          refreshRate = {
            type = "select",
            name = "Combat refresh",
            order = 30,
            values = refreshValues,
            get = function()
              return self.db.profile.refreshRate
            end,
            set = function(_, value)
              self.db.profile.refreshRate = value
              self:CompileRuntimeConfig()
              self:CancelCombatRefresh()
              self:RefreshWindows()
            end,
          },
        },
      },

      history = {
        type = "group",
        name = "Saved history",
        order = 16,
        inline = true,
        args = {
          saveBossKills = {
            type = "toggle",
            name = "Save boss kills",
            desc = "Keep completed boss kills after Blizzard no longer provides the session. Manually saved bosses are always kept.",
            order = 10,
            get = function()
              return self.db.profile.history.saveBossKills
            end,
            set = function(_, value)
              self.db.profile.history.saveBossKills = value
              History:ApplyTrackingOptions()
              self:RefreshWindows()
            end,
          },
          bossKillsToKeep = {
            type = "range",
            name = "Boss kills to keep",
            desc = "Keep the newest boss kills. Saved bosses are kept in addition to this limit.",
            order = 20,
            min = 0,
            max = 50,
            step = 1,
            disabled = function()
              return not self.db.profile.history.saveBossKills
            end,
            get = function()
              return self.db.profile.history.bossKillsToKeep
            end,
            set = function(_, value)
              self.db.profile.history.bossKillsToKeep = value
              History:ApplyTrackingOptions()
              self:RefreshWindows()
            end,
          },
          saveKeystones = {
            type = "toggle",
            name = "Save completed keystones",
            desc = "Keep completed Mythic+ Overall runs. Manually saved keystones are always kept.",
            order = 30,
            get = function()
              return self.db.profile.history.saveKeystones
            end,
            set = function(_, value)
              self.db.profile.history.saveKeystones = value
              History:ApplyTrackingOptions()
              self:RefreshWindows()
            end,
          },
          dungeonSummariesToKeep = {
            type = "range",
            name = "Keystones to keep",
            desc = "Keep this many completed Mythic+ Overall runs. Saved keystones are kept in addition to this limit.",
            order = 40,
            min = 0,
            max = 30,
            step = 1,
            disabled = function()
              return not self.db.profile.history.saveKeystones
            end,
            get = function()
              return self.db.profile.history.dungeonSummariesToKeep
            end,
            set = function(_, value)
              self.db.profile.history.dungeonSummariesToKeep = value
              History:ApplyTrackingOptions()
              self:RefreshWindows()
            end,
          },
        },
      },
      appearance = {
        type = "group",
        name = "Appearance",
        order = 20,
        inline = true,
        args = {
          headerHeight = {
            type = "range",
            name = "Header height",
            order = 10,
            min = 24,
            max = 40,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.headerHeight
            end,
            set = function(_, value)
              self.db.profile.headerHeight = value
              self:RefreshAppearance()
            end,
          },
          barHeight = {
            type = "range",
            name = "Bar height",
            order = 20,
            min = 14,
            max = 32,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.barHeight
            end,
            set = function(_, value)
              self.db.profile.barHeight = value
              self:RefreshAppearance()
            end,
          },
          barSpacing = {
            type = "range",
            name = "Bar spacing",
            order = 30,
            min = 0,
            max = 8,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.barSpacing
            end,
            set = function(_, value)
              self.db.profile.barSpacing = value
              self:RefreshAppearance()
            end,
          },
          fontSize = {
            type = "range",
            name = "Text size",
            order = 40,
            min = 8,
            max = 18,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.fontSize
            end,
            set = function(_, value)
              self.db.profile.fontSize = value
              self:RefreshAppearance()
            end,
          },
          showSpecIcons = {
            type = "toggle",
            name = "Show class/spec icons",
            order = 45,
            get = function()
              return self.db.profile.showSpecIcons
            end,
            set = function(_, value)
              self.db.profile.showSpecIcons = value
              self:CompileRuntimeConfig()
              self:RefreshAppearance()
            end,
          },
          barAlpha = {
            type = "range",
            name = "Bar opacity",
            order = 50,
            min = 0.2,
            max = 1,
            step = 0.05,
            isPercent = true,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.barAlpha
            end,
            set = function(_, value)
              self.db.profile.barAlpha = value
              self:RefreshAppearance()
            end,
          },
        },
      },
      breakdown = {
        type = "group",
        name = "Breakdown",
        order = 25,
        inline = true,
        args = {
          position = {
            type = "select",
            name = "Position",
            order = 10,
            values = breakdownPositionValues,
            get = function()
              return self.db.profile.breakdown.position
            end,
            set = function(_, value)
              self.db.profile.breakdown.position = value
              if self.breakdown then
                Breakdown.ApplyPosition(self.breakdown)
              end
            end,
          },
          width = {
            type = "range",
            name = "Width",
            order = 20,
            min = 260,
            max = 700,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.breakdown.width
            end,
            set = function(_, value)
              self.db.profile.breakdown.width = value
              self:RefreshBreakdownAppearance()
            end,
          },
          height = {
            type = "range",
            name = "Height",
            order = 30,
            min = 120,
            max = 600,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.breakdown.height
            end,
            set = function(_, value)
              self.db.profile.breakdown.height = value
              self:RefreshBreakdownAppearance()
            end,
          },
          targetHeight = {
            type = "range",
            name = "Target list height",
            order = 40,
            min = 90,
            max = 400,
            step = 1,
            arg = { puiRefreshOnRelease = true },
            get = function()
              return self.db.profile.breakdown.targetHeight
            end,
            set = function(_, value)
              self.db.profile.breakdown.targetHeight = value
              self:RefreshBreakdownAppearance()
            end,
          },
          showIcons = {
            type = "toggle",
            name = "Show spell icons",
            order = 50,
            get = function()
              return self.db.profile.breakdown.showIcons
            end,
            set = function(_, value)
              self.db.profile.breakdown.showIcons = value
              self:RefreshBreakdownAppearance()
            end,
          },
          amounts = {
            type = "select",
            name = "Amounts",
            order = 60,
            values = breakdownAmountValues,
            get = function()
              return self.db.profile.breakdown.amounts
            end,
            set = function(_, value)
              self.db.profile.breakdown.amounts = value
              self:RefreshBreakdownData()
            end,
          },
          showPercent = {
            type = "toggle",
            name = "Show percentage",
            desc = "Shown only when Blizzard exposes ordinary values outside combat.",
            order = 70,
            get = function()
              return self.db.profile.breakdown.showPercent
            end,
            set = function(_, value)
              self.db.profile.breakdown.showPercent = value
              self:RefreshBreakdownData()
            end,
          },
          maxSpells = {
            type = "range",
            name = "Maximum spells",
            order = 80,
            min = 5,
            max = BREAKDOWN_ROW_POOL_SIZE,
            step = 1,
            get = function()
              return self.db.profile.breakdown.maxSpells
            end,
            set = function(_, value)
              self.db.profile.breakdown.maxSpells = value
              self:RefreshBreakdownAppearance()
            end,
          },
          showSpellTooltips = {
            type = "toggle",
            name = "Show spell tooltips",
            order = 90,
            get = function()
              return self.db.profile.breakdown.showSpellTooltips
            end,
            set = function(_, value)
              self.db.profile.breakdown.showSpellTooltips = value
            end,
          },
        },
      },
    },
  }

  for index = 1, MAX_WINDOWS do
    local windowIndex = index
    options.args["window" .. windowIndex] = {
      type = "group",
      name = "Window " .. windowIndex,
      order = 30 + windowIndex,
      inline = true,
      hidden = function()
        return windowIndex > self.db.profile.windowCount
      end,
      args = {
        shown = {
          type = "toggle",
          name = "Show window",
          order = 10,
          get = function()
            return GetWindowDB(windowIndex).shown == true
          end,
          set = function(_, value)
            if value then
              self:ReopenWindow(windowIndex)
            else
              self:CloseWindow(windowIndex)
            end
          end,
        },
        resetPosition = {
          type = "execute",
          name = "Reset position",
          order = 20,
          func = function()
            self:ResetWindowPosition(windowIndex)
          end,
        },
        delete = {
          type = "execute",
          name = "Delete",
          order = 30,
          func = function()
            self:DeleteWindow(windowIndex)
          end,
        },
      },
    }
  end

  return options
end

GetWindowDB = P:Def("GetWindowDB", GetWindowDB)
SanitizeProfile = P:Def("SanitizeProfile", SanitizeProfile)
DamageMeters.GetOptions = P:Def("DamageMeters.GetOptions", DamageMeters.GetOptions)

Config.DEFAULTS = DEFAULTS
Config.DEFAULT_WINDOW_POSITIONS = DEFAULT_WINDOW_POSITIONS
Config.GetWindowDB = GetWindowDB
Config.SanitizeProfile = SanitizeProfile
