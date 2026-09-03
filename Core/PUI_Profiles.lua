local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Theme = ns.Theme

local AceDBOptions = LibStub("AceDBOptions-3.0")
local LibDualSpec = LibStub("LibDualSpec-1.0")
local AceConfigReg = LibStub("AceConfigRegistry-3.0")

local unpack = _G.unpack
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local C_Timer = _G.C_Timer
local strtrim = _G.strtrim
local tostring = _G.tostring
local type = _G.type
local math_max = _G.math.max
local ChatFontNormal = _G.ChatFontNormal
local GameFontHighlightLarge = _G.GameFontHighlightLarge
local GameFontHighlight = _G.GameFontHighlight

local function InstallResetProfileReload(options)
  local reset = options.args.reset
  local originalFunc = reset.func
  local handler = options.handler

  reset.confirm = false
  reset.confirmText = nil
  reset.func = function(info, ...)
    local args = { ... }

    Addon:PUI_ResetAndReload(function()
      handler[originalFunc](handler, info, unpack(args))
    end)
  end
end

local function PUI_Profile_Trim(value)
  return strtrim(type(value) == "string" and value or "")
end

local function PUI_Profile_ApplyBackdrop(frame, bgKey, borderKey)
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(frame, {
    bg = colors[bgKey],
    border = colors[borderKey],
  }, Theme.GetEdgeSize())
end

local function PUI_Profile_CreateText(parent, fontObject, justify)
  local colors = Theme.GetColors()
  local text = parent:CreateFontString(nil, "OVERLAY")

  text:SetFontObject(fontObject)
  Theme.ApplyFont(text, "body")
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  text:SetJustifyH(justify)

  return text
end

local function PUI_Profile_CreateButton(parent, label, width, height)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, height)
  button:RegisterForClicks("LeftButtonUp")

  button.text = PUI_Profile_CreateText(button, GameFontHighlight, "CENTER")
  button.text:SetPoint("CENTER")
  button.text:SetText(label)

  button.Text = button.text
  button:SetFontString(button.text)

  Theme.WidgetSkins.UIButton(button)

  return button
end

local function PUI_Profile_SelectText(editBox)
  editBox:SetFocus()
  editBox:SetCursorPosition(0)
  editBox:HighlightText()

  C_Timer.After(0, function()
    if editBox:IsShown() then
      editBox:SetFocus()
      editBox:SetCursorPosition(0)
      editBox:HighlightText()
    end
  end)
end

local function PUI_Profile_EnsureLargeDialog()
  if PUIProfileTransferDialog then
    return PUIProfileTransferDialog
  end

  local frame = CreateFrame("Frame", "PUIProfileTransferDialog", UIParent, "BackdropTemplate")
  frame:SetSize(760, 430)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  PUI_Profile_ApplyBackdrop(frame, "background", "border")

  frame.title = PUI_Profile_CreateText(frame, GameFontHighlightLarge, "LEFT")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
  frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -52, -14)

  frame.close = PUI_Profile_CreateButton(frame, "X", 28, 28)
  frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  frame.close:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.description = PUI_Profile_CreateText(frame, GameFontHighlight, "LEFT")
  frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -12)
  frame.description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -50)

  frame.scrollBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.scrollBorder:SetPoint("TOPLEFT", frame.description, "BOTTOMLEFT", 0, -12)
  frame.scrollBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 58)
  PUI_Profile_ApplyBackdrop(frame.scrollBorder, "control", "border")

  frame.scroll = CreateFrame("ScrollFrame", nil, frame.scrollBorder, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", frame.scrollBorder, "TOPLEFT", 8, -8)
  frame.scroll:SetPoint("BOTTOMRIGHT", frame.scrollBorder, "BOTTOMRIGHT", -28, 8)
  Theme.WidgetSkins.Scrollbar(frame.scroll.ScrollBar)

  frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
  frame.editBox:SetMultiLine(true)
  frame.editBox:SetAutoFocus(true)
  frame.editBox:SetFontObject(ChatFontNormal)
  Theme.ApplyFont(frame.editBox, "body")
  do
    local colors = Theme.GetColors()
    frame.editBox:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  end
  frame.editBox:SetWidth(700)
  frame.editBox:SetTextInsets(4, 4, 4, 4)
  frame.editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame.editBox:SetScript("OnTextChanged", function(self)
    self:SetHeight(math_max(320, self:GetNumLines() * 16))
  end)
  frame.scroll:SetScrollChild(frame.editBox)

  frame.secondary = PUI_Profile_CreateButton(frame, "Close", 120, 32)
  frame.secondary:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
  frame.secondary:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.primary = PUI_Profile_CreateButton(frame, "OK", 180, 32)
  frame.primary:SetPoint("RIGHT", frame.secondary, "LEFT", -10, 0)

  frame:Hide()
  return frame
end

local function PUI_Profile_EnsureNameDialog()
  if PUIProfileNameDialog then
    return PUIProfileNameDialog
  end

  local frame = CreateFrame("Frame", "PUIProfileNameDialog", UIParent, "BackdropTemplate")
  frame:SetSize(430, 205)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  PUI_Profile_ApplyBackdrop(frame, "background", "border")

  frame.title = PUI_Profile_CreateText(frame, GameFontHighlightLarge, "LEFT")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
  frame.title:SetText("Name Imported Profile")

  frame.description = PUI_Profile_CreateText(frame, GameFontHighlight, "LEFT")
  frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -12)
  frame.description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -48)
  frame.description:SetText("Enter a name for the new profile.")

  frame.inputBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.inputBorder:SetPoint("TOPLEFT", frame.description, "BOTTOMLEFT", 0, -12)
  frame.inputBorder:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
  frame.inputBorder:SetHeight(30)
  PUI_Profile_ApplyBackdrop(frame.inputBorder, "control", "border")

  frame.editBox = CreateFrame("EditBox", nil, frame.inputBorder)
  frame.editBox:SetAutoFocus(true)
  frame.editBox:SetFontObject(ChatFontNormal)
  Theme.ApplyFont(frame.editBox, "body")
  do
    local colors = Theme.GetColors()
    frame.editBox:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  end
  frame.editBox:SetPoint("LEFT", frame.inputBorder, "LEFT", 8, 0)
  frame.editBox:SetPoint("RIGHT", frame.inputBorder, "RIGHT", -8, 0)
  frame.editBox:SetHeight(24)
  frame.editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame.editBox:SetScript("OnEnterPressed", function()
    frame.primary:Click()
  end)

  frame.status = PUI_Profile_CreateText(frame, GameFontHighlight, "LEFT")
  frame.status:SetPoint("TOPLEFT", frame.inputBorder, "BOTTOMLEFT", 0, -8)
  frame.status:SetPoint("TOPRIGHT", frame.inputBorder, "BOTTOMRIGHT", 0, -8)
  frame.status:SetHeight(18)
  frame.status:SetText("")

  frame.primary = PUI_Profile_CreateButton(frame, "Create Profile", 150, 30)
  frame.primary:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)

  frame.secondary = PUI_Profile_CreateButton(frame, "Cancel", 100, 30)
  frame.secondary:SetPoint("RIGHT", frame.primary, "LEFT", -10, 0)
  frame.secondary:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:Hide()
  return frame
end

function Addon:ShowTextExportDialog(title, description, exportText)
  local frame = PUI_Profile_EnsureLargeDialog()

  frame.title:SetText(title or "Export")
  frame.description:SetText(description or "Copy the string below.")
  frame.editBox:SetText(exportText or "")
  frame.editBox:SetCursorPosition(0)
  frame.primary:Hide()
  frame.secondary.text:SetText("Close")

  frame:Show()
  frame:Raise()
  PUI_Profile_SelectText(frame.editBox)
end

function Addon:ShowTextImportDialog(title, description, importFn)
  local frame = PUI_Profile_EnsureLargeDialog()
  local defaultDescription = description or "Paste an import string below."

  frame.title:SetText(title or "Import")
  frame.description:SetText(defaultDescription)
  frame.editBox:SetText("")
  frame.editBox:SetCursorPosition(0)
  frame.primary:Show()
  frame.primary.text:SetText("Import")
  frame.secondary.text:SetText("Cancel")
  frame.primary:SetScript("OnClick", function()
    local importText = PUI_Profile_Trim(frame.editBox:GetText())
    if importText == "" then
      frame.description:SetText("Import string is empty.")
      PUI_Profile_SelectText(frame.editBox)
      return
    end

    local ok, message = importFn(importText)
    if ok then
      frame:Hide()
      return
    end

    frame.description:SetText(tostring(message or "Import failed."))
    PUI_Profile_SelectText(frame.editBox)
  end)

  frame:Show()
  frame:Raise()
  PUI_Profile_SelectText(frame.editBox)
end

local function PUI_Profile_ShowImportNameDialog(importText, state)
  local frame = PUI_Profile_EnsureNameDialog()

  frame.editBox:SetText("")
  frame.editBox:SetCursorPosition(0)
  frame.status:SetText("")

  frame.primary:SetScript("OnClick", function()
    local profileName = PUI_Profile_Trim(frame.editBox:GetText())
    if profileName == "" then
      state.statusText = "Enter a profile name."
      frame.status:SetText(state.statusText)
      AceConfigReg:NotifyChange(ADDON_NAME)
      PUI_Profile_SelectText(frame.editBox)
      return
    end

    frame.status:SetText("Creating profile...")

    local ok, nameOrErr = Addon:ImportProfileString(importText, profileName, true)
    if ok then
      state.statusText = "Imported and switched to profile '" .. tostring(nameOrErr) .. "'."
      frame.status:SetText(state.statusText)
      AceConfigReg:NotifyChange(ADDON_NAME)
      frame:Hide()
      return
    end

    state.statusText = tostring(nameOrErr)
    frame.status:SetText(state.statusText)
    AceConfigReg:NotifyChange(ADDON_NAME)
  end)

  frame:Show()
  frame:Raise()
  PUI_Profile_SelectText(frame.editBox)
end

local function PUI_Profile_ShowImportDialog(state)
  Addon:ShowTextImportDialog("Import Profile", "Paste a PleebUI profile string below.", function(importText)
    PUI_Profile_ShowImportNameDialog(importText, state)
    return true
  end)
end

local function ProfilesProvider(Addon)
  local provider = {
    __puiProfileTransferState = {
      statusText = "",
    },
  }

  function provider:GetOptions()
    local db = Addon.db
    local options = provider.__puiProfileOptions
    if not options then
      options = AceDBOptions:GetOptionsTable(db)
      LibDualSpec:EnhanceOptions(options, db)
      InstallResetProfileReload(options)
      provider.__puiProfileOptions = options
    end

    local state = provider.__puiProfileTransferState

    options.name = "Profiles"
    options.order = 200

    options.args.puiProfileTransfer = {
      type = "group",
      name = "Import and export",
      order = 500,
      inline = true,
      args = {
        description = {
          type = "description",
          name = "Export or import a complete PleebUI profile.",
          order = 1,
          fontSize = "medium",
        },
        exportProfile = {
          type = "execute",
          name = "Export",
          order = 2,
          width = 0.8,
          func = function()
            local text, err = Addon:ExportCurrentProfile()
            if text then
              state.statusText = "Generated current profile export."
              Addon:ShowTextExportDialog("Export Profile", "Copy the profile string below.", text)
            else
              state.statusText = tostring(err or "Export failed.")
            end
            AceConfigReg:NotifyChange(ADDON_NAME)
          end,
        },
        importProfile = {
          type = "execute",
          name = "Import",
          order = 3,
          width = 0.8,
          func = function()
            PUI_Profile_ShowImportDialog(state)
          end,
        },
        status = {
          type = "description",
          order = 4,
          fontSize = "medium",
          name = function()
            return state.statusText or ""
          end,
        },
      },
    }

    return options
  end

  return provider
end

Addon:RegisterOptionsSection("Profiles", ProfilesProvider, 90, "Profiles", nil, {
  preview = false,
})
