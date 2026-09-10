# PleebUI Public API

PleebUI exposes `PleebUIAPI` for addons that want to use PleebUI Edit Mode movers or add configuration pages to the PleebUI options window.

The current API version is `1.1`.

## Loading PleebUI first

An addon that requires this API should declare PleebUI as a dependency:

```toc
## Dependencies: PleebUI
```

An addon that can also run without PleebUI may use an optional dependency and retain its own fallback UI:

```toc
## OptionalDeps: PleebUI
```

Only optional integrations should guard the global:

```lua
local API = _G.PleebUIAPI
if not API then
  return
end
```

Required PleebUI plugins can use `PleebUIAPI` directly because the dependency guarantees load order.

## Registering a plugin

Register once and retain the returned plugin handle:

```lua
local plugin = PleebUIAPI:RegisterPlugin("PleebDefensives", {
  name = "Pleeb Defensives",
  order = 10,
  navDescription = "Defensive and consumable reminders.",
  navIcon = "Interface\\AddOns\\PleebDefensives\\Media\\logo.tga",
})
```

Plugin keys must be stable and unique. PleebUI prefixes mover, page, and Edit Mode participant keys with the plugin key so separate addons cannot overwrite one another accidentally.

The plugin owns its frames, SavedVariables, configuration values, and runtime behavior. PleebUI owns only registration, Edit Mode presentation, and options navigation.

## API version

```lua
local major, minor = PleebUIAPI:GetVersion()
```

Breaking contract changes increment `VERSION`. Backwards-compatible additions increment `MINOR_VERSION`.

## Options pages

Plugin pages appear beneath a single addon entry in the `Plugins` navigation group. The group is hidden when no plugin has registered an options page.

An options page can use either an AceConfig table or addon-owned native frames. The plugin continues to read and write its own database.

```lua
plugin:RegisterOptionsPage("general", {
  name = "General",
  order = 10,
  pageDescription = "Configure defensive reminders.",
  getOptions = function()
    return {
      type = "group",
      name = "General",
      args = {
        enabled = {
          type = "toggle",
          name = "Enable reminders",
          order = 10,
          get = function()
            return PleebDefensivesDB.enabled
          end,
          set = function(_, value)
            PleebDefensivesDB.enabled = value
            RefreshReminders()
          end,
        },
      },
    }
  end,
})
```

Supported page fields:

- `name`: page label.
- `order`: page order beneath the plugin.
- `getOptions`: required callback returning an AceConfig group.
- `dynamicOptions`: rebuild the plugin root when changing between dynamic pages.
- `disableProviderCache`: rebuild this page whenever PleebUI requests it.
- `pageTitle`, `pageDescription`, and `pageHelp`: page-shell text.
- `meta`: additional PleebUI page metadata.
- `page`: preview and page lifecycle metadata.
- `allowPreview`: allow a supplied page preview callback.

### Native-frame pages

Small addons do not need to bundle Ace libraries. Supply `buildPage` instead of `getOptions` and create ordinary World of Warcraft frames beneath the provided host:

```lua
local page

plugin:RegisterOptionsPage("general", {
  name = "General",
  order = 10,
  buildPage = function(host, context)
    if not page then
      page = CreateFrame("Frame", nil, host)

      local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      title:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
      title:SetText("Plugin settings")
    end

    page:SetParent(host)
    page:ClearAllPoints()
    page:SetAllPoints(host)

    return page
  end,
  refreshPage = function(host, context)
    -- Refresh retained controls from the plugin database.
  end,
  onPageHide = function(host, context)
    -- Stop previews, close dropdowns, and clear input focus.
  end,
  customPageOwnsHeader = false,
})
```

`buildPage` is called whenever the page is mounted and may return its retained root frame. PleebUI reparents and shows that root beneath the page host. Reuse frames instead of rebuilding the page on every visit. `refreshPage` runs after mounting. `onPageHide` runs before the page is replaced or the PleebUI options window closes.

Set `customPageOwnsHeader` when the returned page already contains its own title and description. PleebUI then gives the native page the full content height instead of drawing a second page header.

The context contains `optionsFrame`, `shell`, `path`, `pluginKey`, and `pageKey`. These are page-lifecycle values, not plugin configuration storage.

Notify PleebUI after changing page topology or dynamically generated controls:

```lua
plugin:NotifyOptionsChanged("general")
plugin:NotifyOptionsChanged("general", { "advanced" })
```

Open a registered page or a nested group:

```lua
plugin:OpenOptions("general")
plugin:OpenOptions("general", { "advanced" })
```

Remove a page with:

```lua
plugin:UnregisterOptionsPage("general")
```

When the final page is removed, PleebUI also removes the plugin's navigation entry.

API version 1.1 supports AceConfig tables and native-frame pages. Native pages must parent all visible controls to the supplied host and must not move or resize the PleebUI options window.

## Direct movers

A direct mover places the PleebUI Edit Mode overlay on an addon-owned frame. The addon remains responsible for saving and restoring the position.

```lua
plugin:RegisterMover("reminders", reminderHolder, {
  label = "Defensive Reminders",
  optionsPage = "general",
  savePosition = function(frame)
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    PleebDefensivesDB.x = x - parentX
    PleebDefensivesDB.y = y - parentY
  end,
  resetPosition = function(frame)
    PleebDefensivesDB.x = 0
    PleebDefensivesDB.y = 0
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end,
})
```

Supported direct-mover fields:

- `label`
- `savePosition`
- `resetPosition`
- `onDragStop`
- `onDragUpdate`
- `onDrop`
- `quickSettings`
- `smartSnap`
- `overlayInsets`
- `overlayBelowFrame`
- `useOverlayDrag`
- `optionsPage` and `optionsPath`
- `openOptions` for a custom options action

Refresh or remove the mover with:

```lua
plugin:RefreshMover("reminders")
plugin:UnregisterMover("reminders")
```

## Ghost movers

Use a ghost mover when the displayed frame should not be moved directly. The ghost follows the live frame, and the callbacks apply the saved position to the live owner.

```lua
plugin:RegisterGhostMover("reminders", {
  frameName = "PleebDefensives_ReminderMover",
  label = "Defensive Reminders",
  optionsPage = "general",
  liveFrame = function()
    return reminderHolder
  end,
  getSize = function(_, liveFrame)
    return liveFrame:GetSize()
  end,
  getPoint = function(_, liveFrame)
    return liveFrame:GetPoint(1)
  end,
  shouldShow = function()
    return reminderHolder:IsShown()
  end,
  savePosition = SaveReminderPosition,
  onDragUpdate = ApplyReminderPosition,
  onDragStop = RefreshReminderPosition,
  resetPosition = ResetReminderPosition,
})
```

Ghost movers additionally support `show` and `fallbackAnchor`. `liveFrame`, `getSize`, `getPoint`, and `shouldShow` must return ordinary accessible values.

## Edit Mode participants

Most addons only need to register their frames once. Register an Edit Mode participant when the addon must create, synchronize, or release mover-specific state as `/pe` opens and closes.

```lua
plugin:RegisterEditModeParticipant("runtime", {
  order = 50,
  onChanged = function(enabled)
    if enabled then
      EnsureReminderMovers()
    else
      ReleaseReminderPreviewState()
    end
  end,
})
```

Participants run in deterministic `order`, then plugin-key order. Remove one with:

```lua
plugin:UnregisterEditModeParticipant("runtime")
```

The current state is available through:

```lua
local editing = plugin:IsEditModeActive()
```

## Removing all registrations

```lua
plugin:Unregister()
```

or:

```lua
PleebUIAPI:UnregisterPlugin("PleebDefensives")
```

This removes the plugin's Edit Mode participants, movers, ghost-mover helpers, options pages, and navigation entry. It does not delete plugin SavedVariables or PleebUI smart-snap preferences.

World of Warcraft cannot unload addon Lua during a session. Addon enable and disable changes should normally be applied with a UI reload.

## Combat and secret-value rules

Registration does not bypass World of Warcraft restrictions.

- PleebUI Edit Mode cannot be enabled in combat and closes when combat begins.
- Do not move protected or forbidden frames from insecure code during combat.
- Do not return secret booleans from `shouldShow` or secret numbers from geometry callbacks.
- Do not inspect, compare, format, coerce, cache, or branch on restricted Blizzard values.
- Only register addon-owned frames or supported ghost representations of frames your addon is allowed to position.

PleebUI does not wrap plugin callbacks in `pcall`. Callback errors remain visible with the plugin's own stack trace.
