local _, ns = ...
local Skins = ns.BlizzardSkins
local trainerRows = setmetatable({}, { __mode = "k" })

local function RepaintTrainerRow(row)
  if not Skins.CanStyle() then return end
  ns.Theme.ApplyFont(row.name, "body")
  ns.Theme.ApplyFont(row.subText, "body")
end

local function InstallTrainerRow(row)
  if not Skins.CanStyle() then return end
  if not trainerRows[row] then
    trainerRows[row] = true
    Skins.IconButton(row, row.icon, true)
    Skins.Selection(row.selectedTex, 0.08)
    row.selectedTex:SetDrawLayer("BACKGROUND", 1)
    row.name:SetDrawLayer("OVERLAY", 2)
    row.subText:SetDrawLayer("OVERLAY", 2)
  end
  RepaintTrainerRow(row)
end

Skins.Register("Blizzard_TrainerUI", "ClassTrainerFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Chrome(frame.bottomInset)
    Skins.Hide(ClassTrainerFrameMoneyBg)
    Skins.Dropdown(frame.FilterDropdown)
    Skins.Button(ClassTrainerTrainButton, true)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.Bar(ClassTrainerStatusBar)
    Skins.Font(ClassTrainerStatusBar.rankText)
    Skins.Hide(ClassTrainerStatusBarLeft)
    Skins.Hide(ClassTrainerStatusBarRight)
    Skins.Hide(ClassTrainerStatusBarMiddle)
    InstallTrainerRow(frame.skillStepButton)
    Skins.ScrollRows(frame.ScrollBox, InstallTrainerRow, RepaintTrainerRow)
    Skins.Hook(_G, "ClassTrainerFrame_InitServiceButton", function(row)
      if trainerRows[row] then RepaintTrainerRow(row) end
    end)
  end,
  onShow = function(frame)
    InstallTrainerRow(frame.skillStepButton)
    Skins.ScrollRows(frame.ScrollBox, InstallTrainerRow, RepaintTrainerRow)
  end,
})
