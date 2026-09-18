-- File: PUI_ActionBars_Config.lua

local ADDON_NAME, ns = ...

local Addon  = ns.Addon
local Core = ns.ActionBarsCore
local OptionsUtil = ns.OptionsUtil
local InCombatLockdown = InCombatLockdown
local UnitHasVehicleUI = UnitHasVehicleUI

local ActionBarsConfigDebug = {}
local P = select(1, ns.Pleebug:DropIn(ActionBarsConfigDebug))

local FLYOUT_DIRECTION_VALUES = {
  UP = "Up",
  DOWN = "Down",
  LEFT = "Left",
  RIGHT = "Right",
}

local TOOLTIP_MODE_VALUES = {
  enabled = "Always",
  nocombat = "Out of combat",
  disabled = "Never",
}

local function _GetBarConfig(db, key)
  db.bars      = db.bars or {}
  db.overrides = db.overrides or {}

  db.bars[key]      = db.bars[key]      or {}
  db.overrides[key] = db.overrides[key] or {}
  db.overrides[key].skin = db.overrides[key].skin or {}

  return db.bars[key], db.overrides[key]
end

local function ActionBarsOptionsProvider(Addon)
  local provider = {}

  local function _AB_GetProfile()
    local db = Core:GetDB()
    db.skin = db.skin or {}
    db.bars = db.bars or {}
    db.overrides = db.overrides or {}
    db.ui = db.ui or {}
    return db
  end

  local function _AB_MakeOutlineValues()
    local STANDARD_OUTLINE_KEY = ns.Theme.STANDARD_OUTLINE_KEY
    return OptionsUtil.BuildOutlineValues(true, "Use global outline", STANDARD_OUTLINE_KEY), STANDARD_OUTLINE_KEY
  end

  local MarkDirtyFromOptions
  local MarkBarDirtyFromOptions

  local function _AB_MakeFontGroup(name, skinTable, baseSkin, prefix, orderBase, disabledFn, barKey)
    local ThemeObj = ns.Theme
    local outlineValues, STANDARD_OUTLINE_KEY = _AB_MakeOutlineValues()
    local fontValues = OptionsUtil.BuildFontValues()

    local faceKey      = prefix .. "FontFace"
    local useGlobalKey = prefix .. "UseGlobalFont"
    local sizeKey      = prefix .. "FontSize"
    local outlineKey   = prefix .. "FontOutline"
    local colorKey     = prefix .. "FontColor"

    baseSkin = baseSkin or skinTable or {}

    local function MarkFontDirty()
      if barKey then
        MarkBarDirtyFromOptions(barKey, { fonts = true })
      else
        MarkDirtyFromOptions({ fonts = true })
      end
    end

    MarkFontDirty = P:Def("MarkFontDirty", MarkFontDirty)

    return {
      type = "group",
      name = name,
      inline = true,
      order = orderBase,
      disabled = disabledFn,
      args = {
        useGlobalFont = {
          type = "toggle",
          name = "Use global font",
          order = 10,
          get = function()
            local flag = skinTable[useGlobalKey]
            if flag ~= nil then
              return flag == true
            end
            local v = skinTable[faceKey]
            return not (type(v) == "string" and v ~= "")
          end,
          set = function(_, v)
            skinTable[useGlobalKey] = v and true or false
            MarkFontDirty()
          end,
        },
        fontFace = {
          type = "select",
          dialogControl = "LSM30_Font",
          name = "Font",
          values = fontValues,
          order = 11,
          disabled = function()
            local flag = skinTable[useGlobalKey]
            if flag ~= nil then
              return flag == true
            end
            local v = skinTable[faceKey]
            return not (type(v) == "string" and v ~= "")
          end,
          get = function()
            local v = skinTable[faceKey]
            return OptionsUtil.ResolveFontKey(v, skinTable[useGlobalKey])
          end,
          set = function(_, v)
            skinTable[faceKey] = v
            skinTable[useGlobalKey] = false
            MarkFontDirty()
          end,
        },
        fontSize = {
          type = "range",
          name = "Font size",
          min = 8,
          max = 24,
          step = 1,
          order = 20,
          get = function()
            return skinTable[sizeKey] or baseSkin[sizeKey] or baseSkin.fontSize or 12
          end,
          set = function(_, v)
            skinTable[sizeKey] = v
            MarkFontDirty()
          end,
        },
        fontOutline = {
          type = "select",
          name = "Font outline",
          values = outlineValues,
          order = 30,
          get = function()
            local cur = ThemeObj.NormalizeOutlineFlags(skinTable[outlineKey])
            if cur == nil then
              return STANDARD_OUTLINE_KEY
            end
            return cur
          end,
          set = function(_, key)
            if key == STANDARD_OUTLINE_KEY then
              skinTable[outlineKey] = nil
            else
              skinTable[outlineKey] = ThemeObj.NormalizeOutlineFlags(key)
            end
            MarkFontDirty()
          end,
        },
        fontColor = {
          type = "color",
          name = "Font color",
          hasAlpha = true,
          order = 40,
          get = function()
            local c = skinTable[colorKey] or baseSkin[colorKey] or baseSkin.fontColor or { 1, 1, 1, 1 }
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
          end,
          set = function(_, r, g, b, a)
            skinTable[colorKey] = { r, g, b, a or 1 }
            MarkFontDirty()
          end,
        },
      },
    }
  end

  MarkDirtyFromOptions = function(flags)
    flags = type(flags) == "table" and flags or { full = true }
    Addon:ApplyOptionsChange("ActionBars", flags)
  end

  MarkBarDirtyFromOptions = function(barKey, flags)
    MarkDirtyFromOptions({
      bars = {
        [barKey] = flags,
      },
    })
  end

  _AB_GetProfile = P:Def("_AB_GetProfile", _AB_GetProfile)
  _AB_MakeOutlineValues = P:Def("_AB_MakeOutlineValues", _AB_MakeOutlineValues)
  _AB_MakeFontGroup = P:Def("_AB_MakeFontGroup", _AB_MakeFontGroup)
  MarkDirtyFromOptions = P:Def("MarkDirtyFromOptions", MarkDirtyFromOptions)
  MarkBarDirtyFromOptions = P:Def("MarkBarDirtyFromOptions", MarkBarDirtyFromOptions)

  function provider:GetOptions()
    local db = _AB_GetProfile()
    local skin = db.skin


    local tabs = {
      general = {
        type = "group",
        name = "General",
        order = 10,
        childGroups = "tree",
        args = {
          behavior = {
            type = "group",
            name = "Behavior",
            order = 10,
            args = {
              globalBehavior = {
                type = "group",
                name = "Button behavior",
                inline = true,
                order = 10,
                args = {
                  lockActionBars = {
                    type = "toggle",
                    name = "Lock action bars",
                    order = 10,
                    get = function() return db.lockActionBars ~= false end,
                    set = function(_, v) db.lockActionBars = v and true or false; MarkDirtyFromOptions({ cvars = true }) end,
                  },
                  castOnKeyDown = {
                    type = "toggle",
                    name = "Cast on key down",
                    order = 20,
                    get = function() return db.castOnKeyDown ~= false end,
                    set = function(_, v) db.castOnKeyDown = v and true or false; MarkDirtyFromOptions({ cvars = true }) end,
                  },
                  hideUnusedButtons = {
                    type = "toggle",
                    name = "Hide unused action buttons",
                    desc = "Makes empty action-button slots invisible without changing bar layout.",
                    order = 30,
                    get = function() return db.alwaysShowGrid == false end,
                    set = function(_, v) db.alwaysShowGrid = v ~= true; MarkDirtyFromOptions({ cvars = true }) end,
                  },
                  cooldownNumbers = {
                    type = "toggle",
                    name = "Global cooldown numbers",
                    order = 40,
                    get = function() return db.countdownForCooldowns ~= false end,
                    set = function(_, v)
                      db.countdownForCooldowns = v and true or false
                      db.skin = db.skin or {}
                      db.skin.showCooldownText = v and true or false
                      MarkDirtyFromOptions({ cvars = true, fonts = true })
                    end,
                  },
                  tooltipMode = {
                    type = "select",
                    name = "Action button tooltips",
                    values = TOOLTIP_MODE_VALUES,
                    order = 50,
                    get = function() return db.tooltipMode or "enabled" end,
                    set = function(_, value)
                      db.tooltipMode = value
                      MarkDirtyFromOptions({ tooltips = true })
                    end,
                  },
                  useBlizzardVehicleUI = {
                    type = "toggle",
                    name = "Use Blizzard Vehicle UI",
                    desc = "Use Blizzard's vehicle and override bar instead of showing those actions on the primary PleebUI bar. This cannot be changed during combat or while a vehicle UI is active.",
                    order = 60,
                    disabled = function()
                      return InCombatLockdown() or UnitHasVehicleUI("player")
                    end,
                    get = function()
                      return db.useBlizzardVehicleUI == true
                    end,
                    set = function(_, value)
                      if InCombatLockdown() or UnitHasVehicleUI("player") then
                        return
                      end
                      db.useBlizzardVehicleUI = value and true or false
                      MarkDirtyFromOptions({ full = true })
                    end,
                  },
                },
              },
            },
          },
          size = {
            type = "group",
            name = "Bars",
            order = 20,
            args = {
              activateBars = {
                type = "group",
                name = "Enabled bars",
                inline = true,
                order = 20,
                arg = {
                  puiWidgetColumns = 8,
                },
                args = (function()
                  local args = {}

                  local function BuildBarToggle(index)
                    local barKey = tostring(index)

                    return {
                      type = "toggle",
                      name = "Bar " .. barKey,
                      order = index * 10,
                      disabled = index == 1,
                      get = function()
                        local barCfg = _GetBarConfig(db, barKey)
                        if index == 1 then
                          barCfg.enabled = true
                          return true
                        end
                        return barCfg.enabled ~= false
                      end,
                      set = function(_, enabled)
                        if index == 1 then
                          return
                        end

                        local barCfg = _GetBarConfig(db, barKey)
                        barCfg.enabled = enabled == true
                        MarkBarDirtyFromOptions(barKey, { visibility = true })
                      end,
                    }
                  end

                  BuildBarToggle = P:Def("BuildBarToggle", BuildBarToggle)

                  for index = 1, 12 do
                    args["bar" .. index] = BuildBarToggle(index)
                  end

                  return args
                end)(),
              },
              layout = {
                type = "group",
                name = "Layout",
                inline = true,
                order = 30,
                args = {
                  iconSize = {
                    type = "range",
                    name = "Button size",
                    min = 16, max = 64, step = 1,
                    order = 10,
                    get = function() return skin.iconSize or 30 end,
                    set = function(_, v) skin.iconSize = v; MarkDirtyFromOptions({ layout = true }) end,
                  },
                  iconSpacing = {
                    type = "range",
                    name = "Button spacing",
                    min = 0, max = 16, step = 1,
                    order = 20,
                    get = function() return skin.iconSpacing or 4 end,
                    set = function(_, v) skin.iconSpacing = v; MarkDirtyFromOptions({ layout = true }) end,
                  },
                  iconsPerRow = {
                    type = "range",
                    name = "Buttons per row",
                    min = 1, max = 12, step = 1,
                    order = 30,
                    get = function() return skin.iconsPerRow or 12 end,
                    set = function(_, v) skin.iconsPerRow = v; MarkDirtyFromOptions({ layout = true }) end,
                  },
                  iconsPerBar = {
                    type = "range",
                    name = "Buttons per bar",
                    min = 1, max = 12, step = 1,
                    order = 40,
                    get = function()
                      local v = tonumber(skin.iconsPerBar) or 12
                      if v < 1 then v = 1 end
                      if v > 12 then v = 12 end
                      return v
                    end,
                    set = function(_, v)
                      local val = tonumber(v) or 12
                      if val < 1 then val = 1 end
                      if val > 12 then val = 12 end
                      skin.iconsPerBar = val
                      MarkDirtyFromOptions({ layout = true })
                    end,
                  },
                },
              },
            },
          },
          appearance = {
            type = "group",
            name = "Appearance",
            order = 30,
            args = {
              buttonAppearance = {
                type = "group",
                name = "Button appearance",
                inline = true,
                order = 10,
                args = {
                  borderSize = {
                    type = "range",
                    name = "Icon border size",
                    min = 0, max = 4, step = 1,
                    order = 50,
                    get = function() return skin.borderSize or 1 end,
                    set = function(_, v) skin.borderSize = v; MarkDirtyFromOptions({ skin = true }) end,
                  },
                  borderColor = {
                    type = "color",
                    name = "Border color",
                    hasAlpha = true,
                    order = 60,
                    get = function()
                      local c = skin.borderColor or { 0, 0, 0, 1 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
                    end,
                    set = function(_, r, g, b, a)
                      skin.borderColor = { r, g, b, a or 1 }
                      MarkDirtyFromOptions({ skin = true })
                    end,
                  },
                },
              },
              barBackdrop = {
                type = "group",
                name = "Bar backdrop",
                inline = true,
                order = 20,
                args = {
                  frameBgColor = {
                    type = "color",
                    name = "Backdrop color",
                    hasAlpha = true,
                    order = 70,
                    get = function()
                      local c = skin.frameBgColor or { 0, 0, 0, 0.7 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
                    end,
                    set = function(_, r, g, b, a)
                      skin.frameBgColor = { r, g, b, a or 1 }
                      MarkDirtyFromOptions({ skin = true })
                    end,
                  },
                  showBarBackground = {
                    type = "toggle",
                    name = "Show backdrop",
                    order = 80,
                    get = function() return skin.showBarBackground ~= false end,
                    set = function(_, v) skin.showBarBackground = v and true or false; MarkDirtyFromOptions({ skin = true }) end,
                  },
                  frameBorderSize = {
                    type = "range",
                    name = "Backdrop border size",
                    min = 0, max = 4, step = 1,
                    order = 90,
                    get = function() return skin.frameBorderSize or 2 end,
                    set = function(_, v) skin.frameBorderSize = v; MarkDirtyFromOptions({ skin = true }) end,
                  },
                  frameBorderColor = {
                    type = "color",
                    name = "Backdrop border color",
                    hasAlpha = true,
                    order = 100,
                    get = function()
                      local c = skin.frameBorderColor or { 0, 0, 0, 0.7 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
                    end,
                    set = function(_, r, g, b, a)
                      skin.frameBorderColor = { r, g, b, a or 1 }
                      MarkDirtyFromOptions({ skin = true })
                    end,
                  },
                },
              },
            },
          },
          visibility = {
            type = "group",
            name = "Visibility",
            order = 40,
            args = {
              visibilityGroup = {
                type = "group",
                name = "Shared visibility",
                inline = true,
                order = 10,
                args = {
                  alpha = {
                    type = "range",
                    name = "Alpha",
                    desc = "How visible the bars are normally.",
                    min = 0, max = 100, step = 5,
                    order = 10,
                    get = function()
                      local a = tonumber(skin.alpha) or 1.0
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      return math.floor(a * 100 + 0.5)
                    end,
                    set = function(_, v)
                      local a = (tonumber(v) or 100) / 100
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      skin.alpha = a
                      MarkDirtyFromOptions({ alpha = true })
                    end,
                  },
                  fadeOutEnabled = {
                    type = "toggle",
                    name = "Fade out",
                    desc = "Fade the bars until you move the mouse over them.",
                    order = 20,
                    get = function() return skin.fadeOutEnabled and true or false end,
                    set = function(_, v) skin.fadeOutEnabled = v and true or false; MarkDirtyFromOptions({ alpha = true }) end,
                  },
                  fadeOutAlpha = {
                    type = "range",
                    name = "Fade-out alpha",
                    desc = "How visible the bars are while faded.",
                    min = 0, max = 100, step = 5,
                    order = 30,
                    disabled = function() return skin.fadeOutEnabled ~= true end,
                    get = function()
                      local a = tonumber(skin.fadeOutAlpha) or 0
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      return math.floor(a * 100 + 0.5)
                    end,
                    set = function(_, v)
                      local a = (tonumber(v) or 100) / 100
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      skin.fadeOutAlpha = a
                      MarkDirtyFromOptions({ alpha = true })
                    end,
                  },
                  fadeOutDuration = {
                    type = "range",
                    name = "Fade-out time",
                    desc = "How long the fade-out takes.",
                    min = 0, max = 10, step = 0.5,
                    order = 40,
                    disabled = function() return skin.fadeOutEnabled ~= true end,
                    get = function() return tonumber(skin.fadeOutDuration) or 0 end,
                    set = function(_, v) skin.fadeOutDuration = tonumber(v) or 0; MarkDirtyFromOptions({ alpha = true }) end,
                  },
                  spellUIForceAlpha = {
                    type = "toggle",
                    name = "Keep visible in Spellbook and talents",
                    desc = "Show the bars at full alpha while the Spellbook or talents are open.",
                    order = 50,
                    get = function() return db.spellUIForceAlpha and true or false end,
                    set = function(_, v) db.spellUIForceAlpha = v and true or false; MarkDirtyFromOptions({ alpha = true }) end,
                  },
                },
              },
            },
          },
          fonts = {
            type = "group",
            name = "Text",
            order = 50,
            args = {
              showHotkeyText = {
                type = "toggle",
                name = "Show keybinds",
                order = 5,
                get = function() return skin.showHotkeyText ~= false end,
                set = function(_, value)
                  skin.showHotkeyText = value and true or false
                  MarkDirtyFromOptions({ fonts = true })
                end,
              },
              hotkey = _AB_MakeFontGroup("Keybind text", skin, skin, "hotkey", 10),
              macro = _AB_MakeFontGroup("Macro text", skin, skin, "macro", 20),
              charge = _AB_MakeFontGroup("Charge and count", skin, skin, "charge", 30),
              cooldown = _AB_MakeFontGroup("Cooldown count", skin, skin, "cooldown", 40),
            },
          },
        },
      },
    }

    for i = 1, 12 do
      local barKey = tostring(i)
      local barDB, override = _GetBarConfig(db, barKey)
      barDB.visibility = barDB.visibility or {}
      override.skin = override.skin or {}
      local visibility = barDB.visibility
      local s = override.skin
      local base = db.skin or {}

      local function MarkBarDirty(flags)
        MarkBarDirtyFromOptions(barKey, flags)
      end

      MarkBarDirty = P:Def("MarkBarDirty", MarkBarDirty)

      tabs[barKey] = {
        type = "group",
        name = barKey,
        order = 10 + i,
        childGroups = "tree",
        args = {
          general = {
            type = "group",
            name = "General",
            order = 10,
            args = {
              group = {
                type = "group",
                name = "Bar settings",
                inline = true,
                order = 10,
                args = {
                  useCustom = {
                    type = "toggle",
                    name = "Use custom settings",
                    order = 10,
                    get = function() return override.useCustom == true end,
                    set = function(_, v) override.useCustom = v and true or false; MarkBarDirty({ full = true }) end,
                  },
                  showCooldownText = {
                    type = "toggle",
                    name = "Show cooldown text",
                    order = 20,
                    disabled = function() return override.useCustom ~= true end,
                    get = function()
                      local v = s.showCooldownText
                      if v == nil then v = base.showCooldownText ~= false end
                      return v and true or false
                    end,
                    set = function(_, v) s.showCooldownText = v and true or false; MarkBarDirty({ fonts = true }) end,
                  },
                  showHotkeyText = {
                    type = "toggle",
                    name = "Show keybinds",
                    order = 25,
                    disabled = function() return override.useCustom ~= true end,
                    get = function()
                      local v = s.showHotkeyText
                      if v == nil then v = base.showHotkeyText ~= false end
                      return v and true or false
                    end,
                    set = function(_, v) s.showHotkeyText = v and true or false; MarkBarDirty({ fonts = true }) end,
                  },
                  showMacroText = {
                    type = "toggle",
                    name = "Show macro name",
                    order = 30,
                    disabled = function() return override.useCustom ~= true end,
                    get = function()
                      local v = s.showMacroText
                      if v == nil then v = base.showMacroText ~= false end
                      return v and true or false
                    end,
                    set = function(_, v) s.showMacroText = v and true or false; MarkBarDirty({ fonts = true }) end,
                  },
                  showChargeText = {
                    type = "toggle",
                    name = "Show counts",
                    order = 40,
                    disabled = function() return override.useCustom ~= true end,
                    get = function()
                      local v = s.showChargeText
                      if v == nil then v = base.showChargeText ~= false end
                      return v and true or false
                    end,
                    set = function(_, v) s.showChargeText = v and true or false; MarkBarDirty({ fonts = true }) end,
                  },
                  flyoutDirection = {
                    type = "select",
                    name = "Flyout direction",
                    values = FLYOUT_DIRECTION_VALUES,
                    order = 50,
                    get = function() return barDB.flyoutDirection or "UP" end,
                    set = function(_, value)
                      barDB.flyoutDirection = value
                      MarkBarDirty({ flyouts = true })
                    end,
                  },
                  buttonOffset = {
                    type = "range",
                    name = "Button offset",
                    desc = "Shift the action slots shown by this bar. An offset of 0 starts with slot 1; an offset of 6 starts with slot 7.",
                    min = 0, max = 11, step = 1,
                    order = 60,
                    get = function() return tonumber(barDB.buttonOffset) or 0 end,
                    set = function(_, value)
                      barDB.buttonOffset = tonumber(value) or 0
                      MarkBarDirty({ actions = true })
                    end,
                  },
                },
              },
            },
          },
          size = {
            type = "group",
            name = "Layout and appearance",
            order = 20,
            args = {
              layout = {
                type = "group",
                name = "Layout",
                inline = true,
                order = 10,
                disabled = function() return override.useCustom ~= true end,
                args = {
                  iconSize = {
                    type = "range",
                    name = "Button size",
                    min = 16, max = 64, step = 1,
                    order = 10,
                    get = function() return s.iconSize ~= nil and s.iconSize or (base.iconSize or 30) end,
                    set = function(_, v) s.iconSize = v; MarkBarDirty({ layout = true }) end,
                  },
                  iconSpacing = {
                    type = "range",
                    name = "Button spacing",
                    min = 0, max = 16, step = 1,
                    order = 20,
                    get = function() return s.iconSpacing ~= nil and s.iconSpacing or (base.iconSpacing or 4) end,
                    set = function(_, v) s.iconSpacing = v; MarkBarDirty({ layout = true }) end,
                  },
                  iconsPerRow = {
                    type = "range",
                    name = "Buttons per row",
                    min = 1, max = 12, step = 1,
                    order = 30,
                    get = function() return s.iconsPerRow ~= nil and s.iconsPerRow or (base.iconsPerRow or 12) end,
                    set = function(_, v) s.iconsPerRow = v; MarkBarDirty({ layout = true }) end,
                  },
                  iconsPerBar = {
                    type = "range",
                    name = "Buttons per bar",
                    min = 1, max = 12, step = 1,
                    order = 40,
                    get = function()
                      local baseIconsPerBar = tonumber(base.iconsPerBar) or 12
                      if baseIconsPerBar < 1 then baseIconsPerBar = 1 end
                      if baseIconsPerBar > 12 then baseIconsPerBar = 12 end
                      local v = tonumber(s.iconsPerBar)
                      if v == nil then v = baseIconsPerBar end
                      if v < 1 then v = 1 end
                      if v > 12 then v = 12 end
                      return v
                    end,
                    set = function(_, v)
                      local val = tonumber(v) or 12
                      if val < 1 then val = 1 end
                      if val > 12 then val = 12 end
                      s.iconsPerBar = val
                      MarkBarDirty({ layout = true })
                    end,
                  },
                },
              },
              buttonAppearance = {
                type = "group",
                name = "Button appearance",
                inline = true,
                order = 20,
                disabled = function() return override.useCustom ~= true end,
                args = {
                  borderSize = {
                    type = "range",
                    name = "Icon border size",
                    min = 0, max = 4, step = 1,
                    order = 50,
                    get = function() return s.borderSize ~= nil and s.borderSize or (base.borderSize or 1) end,
                    set = function(_, v) s.borderSize = v; MarkBarDirty({ skin = true }) end,
                  },
                  borderColor = {
                    type = "color",
                    name = "Border color",
                    hasAlpha = true,
                    order = 60,
                    get = function()
                      local c = s.borderColor or base.borderColor or { 0, 0, 0, 1 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
                    end,
                    set = function(_, r, g, b, a) s.borderColor = { r, g, b, a or 1 }; MarkBarDirty({ skin = true }) end,
                  },
                },
              },
              barBackdrop = {
                type = "group",
                name = "Bar backdrop",
                inline = true,
                order = 30,
                disabled = function() return override.useCustom ~= true end,
                args = {
                  frameBgColor = {
                    type = "color",
                    name = "Backdrop color",
                    hasAlpha = true,
                    order = 70,
                    get = function()
                      local c = s.frameBgColor or base.frameBgColor or { 0, 0, 0, 0.7 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
                    end,
                    set = function(_, r, g, b, a) s.frameBgColor = { r, g, b, a or 1 }; MarkBarDirty({ skin = true }) end,
                  },
                  frameBorderSize = {
                    type = "range",
                    name = "Backdrop border size",
                    min = 0, max = 4, step = 1,
                    order = 80,
                    get = function() return s.frameBorderSize ~= nil and s.frameBorderSize or (base.frameBorderSize or 2) end,
                    set = function(_, v) s.frameBorderSize = v; MarkBarDirty({ skin = true }) end,
                  },
                  frameBorderColor = {
                    type = "color",
                    name = "Backdrop border color",
                    hasAlpha = true,
                    order = 90,
                    get = function()
                      local c = s.frameBorderColor or base.frameBorderColor or { 0, 0, 0, 0.7 }
                      return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
                    end,
                    set = function(_, r, g, b, a) s.frameBorderColor = { r, g, b, a or 1 }; MarkBarDirty({ skin = true }) end,
                  },
                },
              },
            },
          },
          visibility = {
            type = "group",
            name = "Visibility",
            order = 30,
            args = {
              conditions = {
                type = "group",
                name = "Show and hide conditions",
                inline = true,
                order = 10,
                args = {
                  alwaysHidden = {
                    type = "toggle",
                    name = "Always hide",
                    desc = "Keep this bar hidden while its keybinds remain active.",
                    order = 10,
                    get = function() return visibility.alwaysHidden == true end,
                    set = function(_, value)
                      visibility.alwaysHidden = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideInCombat = {
                    type = "toggle",
                    name = "Hide in combat",
                    order = 20,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideInCombat == true end,
                    set = function(_, value)
                      visibility.hideInCombat = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideOutOfCombat = {
                    type = "toggle",
                    name = "Hide out of combat",
                    order = 30,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideOutOfCombat == true end,
                    set = function(_, value)
                      visibility.hideOutOfCombat = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithPet = {
                    type = "toggle",
                    name = "Hide with pet",
                    order = 40,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideWithPet == true end,
                    set = function(_, value)
                      visibility.hideWithPet = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithoutPet = {
                    type = "toggle",
                    name = "Hide without pet",
                    order = 50,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideWithoutPet == true end,
                    set = function(_, value)
                      visibility.hideWithoutPet = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithVehicle = {
                    type = "toggle",
                    name = "Hide with vehicle",
                    order = 60,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideWithVehicle == true end,
                    set = function(_, value)
                      visibility.hideWithVehicle = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithVehicleUI = {
                    type = "toggle",
                    name = "Hide with vehicle UI",
                    order = 70,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideWithVehicleUI == true end,
                    set = function(_, value)
                      visibility.hideWithVehicleUI = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithOverride = {
                    type = "toggle",
                    name = "Hide with override bar",
                    order = 80,
                    disabled = function() return visibility.alwaysHidden == true end,
                    get = function() return visibility.hideWithOverride == true end,
                    set = function(_, value)
                      visibility.hideWithOverride = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                  hideWithPossess = {
                    type = "toggle",
                    name = "Hide while possessing",
                    desc = barKey == "1"
                      and "The primary bar always switches to possess and temporary shapeshift actions."
                      or nil,
                    order = 90,
                    disabled = function()
                      return barKey == "1" or visibility.alwaysHidden == true
                    end,
                    get = function()
                      return barKey ~= "1" and visibility.hideWithPossess == true
                    end,
                    set = function(_, value)
                      visibility.hideWithPossess = value and true or false
                      MarkBarDirty({ visibilityDriver = true })
                    end,
                  },
                },
              },
              group = {
                type = "group",
                name = "Alpha and fade",
                inline = true,
                order = 20,
                disabled = function() return override.useCustom ~= true end,
                args = {
                  alpha = {
                    type = "range",
                    name = "Alpha",
                    desc = "How visible this bar is normally.",
                    min = 0, max = 100, step = 5,
                    order = 10,
                    get = function()
                      local a = s.alpha
                      if a == nil then a = base.alpha or 1.0 end
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      return math.floor((a or 1) * 100 + 0.5)
                    end,
                    set = function(_, v)
                      local a = (tonumber(v) or 100) / 100
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      s.alpha = a
                      MarkBarDirty({ alpha = true })
                    end,
                  },
                  fadeOutEnabled = {
                    type = "toggle",
                    name = "Fade out",
                    desc = "Fade this bar until you move the mouse over it.",
                    order = 20,
                    get = function()
                      local enabled = s.fadeOutEnabled
                      if enabled == nil then enabled = base.fadeOutEnabled == true end
                      return enabled == true
                    end,
                    set = function(_, v) s.fadeOutEnabled = v and true or false; MarkBarDirty({ alpha = true }) end,
                  },
                  fadeOutAlpha = {
                    type = "range",
                    name = "Fade-out alpha",
                    desc = "How visible this bar is while faded.",
                    min = 0, max = 100, step = 5,
                    order = 30,
                    disabled = function()
                      if override.useCustom ~= true then return true end
                      local enabled = s.fadeOutEnabled
                      if enabled == nil then enabled = base.fadeOutEnabled == true end
                      return enabled ~= true
                    end,
                    get = function()
                      local a = s.fadeOutAlpha
                      if a == nil then a = base.fadeOutAlpha or 0 end
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      return math.floor((a or 1) * 100 + 0.5)
                    end,
                    set = function(_, v)
                      local a = (tonumber(v) or 100) / 100
                      if a < 0 then a = 0 end
                      if a > 1 then a = 1 end
                      s.fadeOutAlpha = a
                      MarkBarDirty({ alpha = true })
                    end,
                  },
                  fadeOutDuration = {
                    type = "range",
                    name = "Fade-out time",
                    desc = "How long the fade-out takes.",
                    min = 0, max = 10, step = 0.5,
                    order = 40,
                    disabled = function()
                      if override.useCustom ~= true then return true end
                      local enabled = s.fadeOutEnabled
                      if enabled == nil then enabled = base.fadeOutEnabled == true end
                      return enabled ~= true
                    end,
                    get = function()
                      local fade = s.fadeOutDuration
                      if fade == nil then fade = base.fadeOutDuration or 0 end
                      if fade < 0 then fade = 0 end
                      if fade > 10 then fade = 10 end
                      return fade
                    end,
                    set = function(_, v) s.fadeOutDuration = tonumber(v) or 0; MarkBarDirty({ alpha = true }) end,
                  },
                },
              },
            },
          },
          fonts = {
            type = "group",
            name = "Text",
            order = 40,
            args = {
              hotkey = _AB_MakeFontGroup("Keybind text", s, base, "hotkey", 10, function() return override.useCustom ~= true end, barKey),
              macro = _AB_MakeFontGroup("Macro text", s, base, "macro", 20, function() return override.useCustom ~= true end, barKey),
              charge = _AB_MakeFontGroup("Charge and count", s, base, "charge", 30, function() return override.useCustom ~= true end, barKey),
              cooldown = _AB_MakeFontGroup("Cooldown count", s, base, "cooldown", 40, function() return override.useCustom ~= true end, barKey),
            },
          },
        },
      }
    end

    tabs.special = {
      type = "group",
      name = "Special bars",
      order = 99,
      childGroups = "tree",
      args = {
        pet = {
          type = "group",
          name = "Pet bar",
          order = 10,
          args = {},
        },
        stance = {
          type = "group",
          name = "Stance bar",
          order = 20,
          args = {},
        },
      },
    }

    local function AddSpecialArgs(node, specialKey, defaultSize)
      local barConfig, override = _GetBarConfig(db, specialKey)
      override.skin = override.skin or {}
      local s = override.skin
      local base = db.skin or {}

      local function MarkSpecialDirty(flags)
        MarkBarDirtyFromOptions(specialKey, flags)
      end

      MarkSpecialDirty = P:Def("MarkSpecialDirty", MarkSpecialDirty)

      node.args.general = {
        type = "group",
        name = "General",
        inline = true,
        order = 10,
        args = {
          useCustom = {
            type = "toggle",
            name = "Use custom settings",
            order = 10,
            get = function() return override.useCustom == true end,
            set = function(_, v) override.useCustom = v and true or false; MarkSpecialDirty({ full = true }) end,
          },
          buttonCount = {
            type = "range",
            name = "Buttons",
            desc = "Number of pet actions shown.",
            min = 1,
            max = 10,
            step = 1,
            order = 20,
            hidden = specialKey ~= "pet",
            get = function()
              return tonumber(barConfig.buttonCount) or 10
            end,
            set = function(_, value)
              local count = math.floor(tonumber(value) or 10)
              if count < 1 then count = 1 end
              if count > 10 then count = 10 end
              barConfig.buttonCount = count
              MarkSpecialDirty({ full = true })
            end,
          },
          showCooldowns = {
            type = "toggle",
            name = "Show cooldown swipes",
            order = 30,
            hidden = specialKey ~= "pet",
            get = function()
              return barConfig.showCooldowns ~= false
            end,
            set = function(_, value)
              barConfig.showCooldowns = value and true or false
              MarkSpecialDirty({ full = true })
            end,
          },
        },
      }

      node.args.layout = {
        type = "group",
        name = "Layout",
        inline = true,
        order = 20,
        disabled = function() return override.useCustom ~= true end,
        args = {
          iconSize = {
            type = "range",
            name = "Button size",
            min = 8, max = 64, step = 1,
            order = 10,
            get = function() return s.iconSize ~= nil and s.iconSize or defaultSize end,
            set = function(_, v) s.iconSize = v; MarkSpecialDirty({ layout = true }) end,
          },
          iconSpacing = {
            type = "range",
            name = "Button spacing",
            min = 0, max = 16, step = 1,
            order = 20,
            get = function() return s.iconSpacing ~= nil and s.iconSpacing or (base.iconSpacing or 4) end,
            set = function(_, v) s.iconSpacing = v; MarkSpecialDirty({ layout = true }) end,
          },
          iconsPerRow = {
            type = "range",
            name = "Buttons per row",
            min = 1, max = 10, step = 1,
            order = 30,
            hidden = specialKey ~= "pet",
            get = function()
              local value = tonumber(s.iconsPerRow)
              if value == nil then value = tonumber(base.iconsPerRow) or 10 end
              if value < 1 then value = 1 end
              if value > 10 then value = 10 end
              return value
            end,
            set = function(_, v) s.iconsPerRow = v; MarkSpecialDirty({ layout = true }) end,
          },
        },
      }

      node.args.buttonAppearance = {
        type = "group",
        name = "Button appearance",
        inline = true,
        order = 30,
        disabled = function() return override.useCustom ~= true end,
        args = {
          borderSize = {
            type = "range",
            name = "Icon border size",
            min = 0, max = 4, step = 1,
            order = 10,
            get = function() return s.borderSize ~= nil and s.borderSize or (base.borderSize or 1) end,
            set = function(_, v) s.borderSize = v; MarkSpecialDirty({ skin = true }) end,
          },
          borderColor = {
            type = "color",
            name = "Border color",
            hasAlpha = true,
            order = 20,
            get = function()
              local c = s.borderColor or base.borderColor or { 0, 0, 0, 1 }
              return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
            end,
            set = function(_, r, g, b, a)
              s.borderColor = { r, g, b, a or 1 }
              MarkSpecialDirty({ skin = true })
            end,
          },
        },
      }

      node.args.barBackdrop = {
        type = "group",
        name = "Bar backdrop",
        inline = true,
        order = 40,
        disabled = function() return override.useCustom ~= true end,
        args = {
          showBarBackground = {
            type = "toggle",
            name = "Show backdrop",
            order = 10,
            get = function()
              local value = s.showBarBackground
              if value == nil then value = base.showBarBackground ~= false end
              return value ~= false
            end,
            set = function(_, value)
              s.showBarBackground = value and true or false
              MarkSpecialDirty({ skin = true })
            end,
          },
          frameBgColor = {
            type = "color",
            name = "Backdrop color",
            hasAlpha = true,
            order = 20,
            get = function()
              local c = s.frameBgColor or base.frameBgColor or { 0, 0, 0, 0.7 }
              return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
            end,
            set = function(_, r, g, b, a)
              s.frameBgColor = { r, g, b, a or 1 }
              MarkSpecialDirty({ skin = true })
            end,
          },
          frameBorderSize = {
            type = "range",
            name = "Backdrop border size",
            min = 0, max = 4, step = 1,
            order = 30,
            get = function() return s.frameBorderSize ~= nil and s.frameBorderSize or (base.frameBorderSize or 2) end,
            set = function(_, v) s.frameBorderSize = v; MarkSpecialDirty({ skin = true }) end,
          },
          frameBorderColor = {
            type = "color",
            name = "Backdrop border color",
            hasAlpha = true,
            order = 40,
            get = function()
              local c = s.frameBorderColor or base.frameBorderColor or { 0, 0, 0, 0.7 }
              return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.7
            end,
            set = function(_, r, g, b, a)
              s.frameBorderColor = { r, g, b, a or 1 }
              MarkSpecialDirty({ skin = true })
            end,
          },
        },
      }

      node.args.visibility = {
        type = "group",
        name = "Visibility",
        inline = true,
        order = 50,
        disabled = function() return override.useCustom ~= true end,
        args = {
          alpha = {
            type = "range",
            name = "Alpha",
            desc = "How visible this bar is normally.",
            min = 0, max = 100, step = 5,
            order = 10,
            get = function()
              local value = s.alpha
              if value == nil then value = base.alpha or 1 end
              if value < 0 then value = 0 end
              if value > 1 then value = 1 end
              return math.floor(value * 100 + 0.5)
            end,
            set = function(_, value)
              local alpha = (tonumber(value) or 100) / 100
              if alpha < 0 then alpha = 0 end
              if alpha > 1 then alpha = 1 end
              s.alpha = alpha
              MarkSpecialDirty({ alpha = true })
            end,
          },
          fadeOutEnabled = {
            type = "toggle",
            name = "Fade out",
            desc = "Fade this bar until you move the mouse over it.",
            order = 20,
            get = function()
              local enabled = s.fadeOutEnabled
              if enabled == nil then enabled = base.fadeOutEnabled == true end
              return enabled == true
            end,
            set = function(_, value)
              s.fadeOutEnabled = value and true or false
              MarkSpecialDirty({ alpha = true })
            end,
          },
          fadeOutAlpha = {
            type = "range",
            name = "Fade-out alpha",
            desc = "How visible this bar is while faded.",
            min = 0, max = 100, step = 5,
            order = 30,
            disabled = function()
              if override.useCustom ~= true then return true end
              local enabled = s.fadeOutEnabled
              if enabled == nil then enabled = base.fadeOutEnabled == true end
              return enabled ~= true
            end,
            get = function()
              local value = s.fadeOutAlpha
              if value == nil then value = base.fadeOutAlpha or 0 end
              if value < 0 then value = 0 end
              if value > 1 then value = 1 end
              return math.floor(value * 100 + 0.5)
            end,
            set = function(_, value)
              local alpha = (tonumber(value) or 0) / 100
              if alpha < 0 then alpha = 0 end
              if alpha > 1 then alpha = 1 end
              s.fadeOutAlpha = alpha
              MarkSpecialDirty({ alpha = true })
            end,
          },
          fadeOutDuration = {
            type = "range",
            name = "Fade-out time",
            desc = "How long the fade-out takes.",
            min = 0, max = 10, step = 0.5,
            order = 40,
            disabled = function()
              if override.useCustom ~= true then return true end
              local enabled = s.fadeOutEnabled
              if enabled == nil then enabled = base.fadeOutEnabled == true end
              return enabled ~= true
            end,
            get = function()
              local value = s.fadeOutDuration
              if value == nil then value = base.fadeOutDuration or 0 end
              if value < 0 then value = 0 end
              if value > 10 then value = 10 end
              return value
            end,
            set = function(_, value)
              s.fadeOutDuration = tonumber(value) or 0
              MarkSpecialDirty({ alpha = true })
            end,
          },
        },
      }
    end

    AddSpecialArgs = P:Def("AddSpecialArgs", AddSpecialArgs)

    AddSpecialArgs(tabs.special.args.pet, "pet", 17)
    AddSpecialArgs(tabs.special.args.stance, "stance", 23)

    return {
      type = "group",
      name = "Action bars",
      childGroups = "tab",
      args = tabs,
    }
  end

  provider.GetOptions = P:Def("provider:GetOptions", provider.GetOptions)

  return provider
end

_GetBarConfig = P:Def("_GetBarConfig", _GetBarConfig)
ActionBarsOptionsProvider = P:Def("ActionBarsOptionsProvider", ActionBarsOptionsProvider)

Addon:RegisterOptionsSection("ACTIONBARS", ActionBarsOptionsProvider, 30, "Action bars", nil, {
  preview = false,
})
