-- Modules/Player_Nameplates.lua
-- EnhanceTBC - Player nameplate (personal frame) and swing timers

local ADDON_NAME, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.PlayerNameplates = mod

local player_nameplate
local driver
local hooks = false

local player_class = select(2, UnitClass("player"))

local MELEE_CLASSES = {
  WARRIOR = true,
  PALADIN = { 2, 3 },
  DRUID = { 2 },
  ROGUE = true,
  SHAMAN = { 2 },
  HUNTER = true,
}

local MELEE_RESET_SPELLS = {
  ["Heroic Strike"] = true,
  ["Cleave"] = true,
  ["Repentance"] = true,
  ["War Stomp"] = true,
}

local PALADIN_SEALS = {
  ["Seal of Blood"] = true,
  ["Seal of Command"] = true,
  ["Seal of Vengeance"] = true,
  ["Seal of Corruption"] = true,
  ["Seal of Wisdom"] = true,
  ["Seal of the Crusader"] = true,
  ["Seal of Righteousness"] = true,
  ["Seal of Justice"] = true,
  ["Seal of Light"] = true,
}

local RANGED_CLASSES = {
  HUNTER = true,
  WARLOCK = true,
  MAGE = true,
  PRIEST = true,
}

local HUNTER_SPELLS = {
  ["Auto Shot"] = true,
  ["Feign Death"] = true,
  ["Trueshot Aura"] = true,
  ["Multi-Shot"] = true,
  ["Aimed Shot"] = true,
  ["Steady Shot"] = true,
  ["Raptor Strike"] = true,
}

local ABSORB_BUFFS = {
  ["Power Word: Shield"] = { spell_id = 17 },
  ["Ice Barrier"] = { spell_id = 11426 },
  ["Sacrifice"] = { spell_id = 7812 },
  ["Mana Shield"] = { spell_id = 1463 },
}

local function GetDB()
  ETBC.db.profile.player_nameplates = ETBC.db.profile.player_nameplates or {}
  local db = ETBC.db.profile.player_nameplates

  if db.enabled == nil then db.enabled = true end
  if db.player_nameplate_frame == nil then db.player_nameplate_frame = true end
  if db.player_nameplate_scale == nil then db.player_nameplate_scale = 0.9 end
  if db.player_nameplate_alpha == nil then db.player_nameplate_alpha = 1 end
  if db.player_nameplate_width == nil then db.player_nameplate_width = 128 end
  if db.player_nameplate_height == nil then db.player_nameplate_height = 22 end
  if db.player_nameplate_pos_y == nil then db.player_nameplate_pos_y = -105 end
  if db.player_nameplate_show == nil then db.player_nameplate_show = false end
  if db.player_nameplate_health == nil then db.player_nameplate_health = false end
  if db.player_nameplate_text == nil then db.player_nameplate_text = true end

  if db.player_alt_manabar == nil then db.player_alt_manabar = true end

  if db.player_melee_swing_timer == nil then db.player_melee_swing_timer = false end
  if db.player_melee_swing_timer_show_offhand == nil then db.player_melee_swing_timer_show_offhand = false end
  if db.player_melee_swing_timer_only_in_combat == nil then db.player_melee_swing_timer_only_in_combat = false end
  if db.player_melee_swing_timer_hide_out_of_combat == nil then db.player_melee_swing_timer_hide_out_of_combat = false end
  if db.player_melee_swing_timer_width == nil then db.player_melee_swing_timer_width = 230 end
  if db.player_melee_swing_timer_height == nil then db.player_melee_swing_timer_height = 9 end
  if db.player_melee_swing_timer_alpha == nil then db.player_melee_swing_timer_alpha = 1 end
  if db.player_melee_swing_timer_color == nil then db.player_melee_swing_timer_color = { r = 1, g = 1, b = 1, a = 1 } end
  if db.player_melee_swing_timer_seperate == nil then db.player_melee_swing_timer_seperate = false end
  if db.player_melee_swing_timer_scale == nil then db.player_melee_swing_timer_scale = 1 end
  if db.player_melee_swing_timer_pos_y == nil then db.player_melee_swing_timer_pos_y = -150 end
  if db.player_melee_swing_timer_icon == nil then db.player_melee_swing_timer_icon = true end
  if db.player_melee_swing_timer_text == nil then db.player_melee_swing_timer_text = true end

  if db.player_ranged_cast_timer == nil then db.player_ranged_cast_timer = false end
  if db.player_ranged_cast_timer_width == nil then db.player_ranged_cast_timer_width = 230 end
  if db.player_ranged_cast_timer_height == nil then db.player_ranged_cast_timer_height = 9 end
  if db.player_ranged_cast_timer_alpha == nil then db.player_ranged_cast_timer_alpha = 1 end
  if db.player_ranged_cast_timer_color == nil then db.player_ranged_cast_timer_color = { r = 1, g = 1, b = 1, a = 1 } end
  if db.player_ranged_cast_timer_seperate == nil then db.player_ranged_cast_timer_seperate = false end
  if db.player_ranged_cast_timer_scale == nil then db.player_ranged_cast_timer_scale = 1 end
  if db.player_ranged_cast_timer_pos_y == nil then db.player_ranged_cast_timer_pos_y = -140 end
  if db.player_ranged_cast_timer_text == nil then db.player_ranged_cast_timer_text = true end
  if db.player_auto_shot_timer == nil then db.player_auto_shot_timer = true end

  return db
end

local function ApplyFont(fs, size)
  if not fs or not fs.SetFont then return end
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(fs, nil, size)
  else
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 10, "OUTLINE")
  end
end

local function ApplyBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function ApplyBackdropAlt(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0, 0, 0, 0.65)
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function GetStatusbarTexture()
  if ETBC.Theme and ETBC.Theme.FetchStatusbar then
    return ETBC.Theme:FetchStatusbar()
  end
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, tex = pcall(ETBC.LSM.Fetch, ETBC.LSM, "statusbar", "Blizzard")
    if ok and tex then return tex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetColorValue(color)
  if type(color) == "table" then
    local r = color.r or color[1] or 1
    local g = color.g or color[2] or 1
    local b = color.b or color[3] or 1
    return r, g, b
  end
  return 1, 1, 1
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_PlayerNameplateDriver", UIParent)
  driver:Hide()
end

local function ShowPlayerNameplate()
  local db = GetDB()
  if not player_nameplate or not db.player_nameplate_frame then return end

  player_nameplate.fade:SetToAlpha(db.player_nameplate_alpha or 1)
  player_nameplate.fade:SetFromAlpha(player_nameplate:GetAlpha())
  player_nameplate.fade_direction = 1
  player_nameplate.animation:Play()
end

local function HidePlayerNameplate()
  local db = GetDB()
  if not player_nameplate or db.player_nameplate_show then return end

  C_Timer.After(2.5, function()
    if not player_nameplate then return end

    local health = player_nameplate.healthbar:GetValue()
    local _, health_max = player_nameplate.healthbar:GetMinMaxValues()

    if health and health_max and health_max > 0 then
      local player_health = math.ceil((health / health_max) * 100)
      local in_combat = not not UnitAffectingCombat("player")
      if (player_health <= 0 or player_health >= 100 or UnitIsDeadOrGhost("player"))
        and not in_combat and not db.player_nameplate_show then
        player_nameplate.fade:SetToAlpha(0)
        player_nameplate.fade:SetFromAlpha(player_nameplate:GetAlpha())
        player_nameplate.fade_direction = 0
        player_nameplate.animation:Play()
      end
    end
  end)
end

local function UpdatePlayerNameplateHealth()
  if not player_nameplate then return end
  local health = player_nameplate.healthbar:GetValue()
  local _, health_max = player_nameplate.healthbar:GetMinMaxValues()

  if health and health_max and health_max > 0 then
    local player_health = math.ceil((health / health_max) * 100)
    player_nameplate.healthbar.text:SetText(player_health .. "%")

    if player_nameplate.healthbar.absorb and player_nameplate.healthbar.absorb:IsShown() then
      local x = player_nameplate.healthbar:GetWidth() * (health / health_max)
      if x + player_nameplate.healthbar.absorb:GetWidth() > player_nameplate.healthbar:GetWidth() then
        x = player_nameplate.healthbar:GetWidth() - player_nameplate.healthbar.absorb:GetWidth()
        player_nameplate.healthbar.absorb.over_absorb_texture:Show()
      else
        player_nameplate.healthbar.absorb.over_absorb_texture:Hide()
      end
      player_nameplate.healthbar.absorb:SetPoint("LEFT", player_nameplate.healthbar, x, 0)
    end

    if PlayerFrameHealthBar and PlayerFrameHealthBar.MyHealPredictionBar
      and PlayerFrameHealthBar.MyHealPredictionBar:IsShown() then
      SetPlayerFillMask()
    elseif PlayerFrameHealthBar and PlayerFrameHealthBar.OtherHealPredictionBar
      and PlayerFrameHealthBar.OtherHealPredictionBar:IsShown() then
      SetPlayerOtherFillMask()
    end

    if player_health >= 100 or player_health <= 0 or UnitIsDeadOrGhost("player") then
      local db = GetDB()
      if not db.player_nameplate_show then
        HidePlayerNameplate()
      else
        ShowPlayerNameplate()
      end
    else
      ShowPlayerNameplate()
    end
  else
    player_nameplate.healthbar.text:SetText("")
  end
end

local function UpdatePlayerNameplatePower()
  if not player_nameplate then return end
  local power = player_nameplate.manabar:GetValue()
  local _, power_max = player_nameplate.manabar:GetMinMaxValues()

  if power and power_max and power_max > 0 then
    local player_power = math.floor((power / power_max) * 100 + 0.5)
    local power_type = UnitPowerType("player")

    if power_type and power_type == 0 then
      player_nameplate.manabar.text:SetText(player_power .. "%")
    else
      player_nameplate.manabar.text:SetText(player_power .. " ")
    end
  else
    player_nameplate.manabar.text:SetText("")
  end
end

local function SetPlayerFillMask()
  if not player_nameplate or not PlayerFrameHealthBar or not PlayerFrameHealthBar.MyHealPredictionBar
    or not PlayerFrameHealthBar.MyHealPredictionBar.FillMask then
    return
  end

  local health = player_nameplate.healthbar:GetValue()
  local _, health_max = player_nameplate.healthbar:GetMinMaxValues()
  if health and health_max and health_max > 0 then
    local health_p = health / health_max
    local heal_p = PlayerFrameHealthBar.MyHealPredictionBar.FillMask:GetWidth() / PlayerFrameHealthBar:GetWidth()
    local width = player_nameplate.healthbar:GetWidth()
    local size = (heal_p + health_p > 1) and ((1 - health_p) * width) or (heal_p * width)
    player_nameplate.healthbar.heal:SetSize(size, player_nameplate.healthbar:GetHeight())
    player_nameplate.healthbar.heal:ClearAllPoints()
    player_nameplate.healthbar.heal:SetPoint("LEFT", player_nameplate.healthbar, width * health_p, 0)
  end
end

local function SetPlayerOtherFillMask()
  if not player_nameplate or not PlayerFrameHealthBar or not PlayerFrameHealthBar.OtherHealPredictionBar
    or not PlayerFrameHealthBar.OtherHealPredictionBar.FillMask then
    return
  end

  local health = player_nameplate.healthbar:GetValue()
  local _, health_max = player_nameplate.healthbar:GetMinMaxValues()
  if health and health_max and health_max > 0 then
    local health_p = health / health_max
    local heal_p = PlayerFrameHealthBar.OtherHealPredictionBar.FillMask:GetWidth() / PlayerFrameHealthBar:GetWidth()
    local width = player_nameplate.healthbar:GetWidth()
    local size = (heal_p + health_p > 1) and ((1 - health_p) * width) or (heal_p * width)
    player_nameplate.healthbar.other_heal:SetSize(size, player_nameplate.healthbar:GetHeight())
    player_nameplate.healthbar.other_heal:ClearAllPoints()
    player_nameplate.healthbar.other_heal:SetPoint("LEFT", player_nameplate.healthbar, width * health_p, 0)
  end
end

local function SetPlayerNameplateAbsorb()
  if not player_nameplate or not player_nameplate.healthbar or not player_nameplate.healthbar.absorb then return end
  if UnitExists("player") and not UnitIsDead("player") then
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, absorb_spell_id = UnitAura("player", i, "HELPFUL")
      if name then
        local absorb_buff = ABSORB_BUFFS[name]
        if absorb_buff and absorb_buff.track_spell_id and absorb_spell_id
          and not absorb_buff.track_spell_id[absorb_spell_id] then
          absorb_buff = nil
        end

        if absorb_buff then
          local unit_health = UnitHealth("player")
          local unit_health_max = UnitHealthMax("player")
          if unit_health and unit_health_max and unit_health_max > 0 then
            local x = player_nameplate.healthbar:GetWidth() * (unit_health / unit_health_max)
            if x + player_nameplate.healthbar.absorb:GetWidth() > player_nameplate.healthbar:GetWidth() then
              x = player_nameplate.healthbar:GetWidth() - player_nameplate.healthbar.absorb:GetWidth()
              player_nameplate.healthbar.absorb.over_absorb_texture:Show()
            else
              player_nameplate.healthbar.absorb.over_absorb_texture:Hide()
            end
            player_nameplate.healthbar.absorb:SetPoint("LEFT", player_nameplate.healthbar, x, 0)
            player_nameplate.healthbar.absorb:Show()
          end
          return
        end
      else
        player_nameplate.healthbar.absorb:Hide()
        break
      end
    end
  else
    player_nameplate.healthbar.absorb:Hide()
  end
end

local function IsInCombat()
  return not not UnitAffectingCombat("player")
end

local function StartSwingTimer(timer, swing_time)
  if not timer or not swing_time or swing_time <= 0 then return end
  timer.swing_time = swing_time
  timer.current_timer = swing_time
  timer:SetMinMaxValues(0, swing_time)
  timer:SetValue(0)
  timer.spark:SetAlpha(1)
  timer.spark:SetPoint("LEFT", -7, 0)
  if timer.text then timer.text:SetText(string.format("%.1fs", swing_time)) end
end

local function RefreshSwingTimer(timer, swing_time)
  if not timer or not swing_time or swing_time <= 0 or swing_time == timer.swing_time then return end
  local time_elapsed = timer.swing_time - timer.current_timer
  timer.current_timer = swing_time - time_elapsed

  if timer.current_timer > 0 then
    timer.swing_time = swing_time
    timer:SetMinMaxValues(0, swing_time)
    timer:SetValue(time_elapsed)
    timer.spark:SetAlpha(1)
    timer.spark:SetPoint("LEFT", (time_elapsed / timer.swing_time) * timer:GetWidth() - 7, 0)
    if timer.text then timer.text:SetText(string.format("%.1fs", timer.current_timer)) end
  else
    timer:SetValue(timer.swing_time)
    timer.spark:SetPoint("LEFT", timer:GetWidth() - 7, 0)
    timer.spark:SetAlpha(0)
    timer.swing_time = -1
    timer.current_timer = -1
    if timer.text then timer.text:SetText("0.0s") end
  end
end

local function UpdateSwingTimer(timer, elapsed)
  if not timer or timer.current_timer < 0 then return end
  timer.current_timer = timer.current_timer - elapsed

  if timer.current_timer > 0 then
    local time_elapsed = timer.swing_time - timer.current_timer
    timer:SetValue(time_elapsed)
    timer.spark:SetPoint("LEFT", (time_elapsed / timer.swing_time) * timer:GetWidth() - 7, 0)
    if timer.text then timer.text:SetText(string.format("%.1fs", timer.current_timer)) end
  else
    timer:SetValue(timer.swing_time)
    timer.spark:SetPoint("LEFT", timer:GetWidth() - 7, 0)
    timer.spark:SetAlpha(0)
    timer.swing_time = -1
    timer.current_timer = -1
    if timer.text then timer.text:SetText("0.0s") end
  end
end

local function StartMeleeSwingTimer(is_offhand)
  if not player_nameplate or not player_nameplate.melee_swing_timer then return end
  local timer = is_offhand and player_nameplate.offhand_swing_timer or player_nameplate.melee_swing_timer
  if not timer or not timer:IsShown() then return end

  local main_speed, off_speed = UnitAttackSpeed("player")
  local attack_speed = is_offhand and off_speed or main_speed
  if attack_speed and attack_speed > 0 then
    StartSwingTimer(timer, attack_speed)

    if not is_offhand and timer.twist_timer then
      timer.twist_timer:SetWidth(attack_speed > timer.twist_time and
        math.floor(timer.twist_time / attack_speed * timer:GetWidth()) or timer:GetWidth())
    end
  end
end

local function RefreshMeleeSwingTimer()
  if not player_nameplate or not player_nameplate.melee_swing_timer then return end
  local main_timer = player_nameplate.melee_swing_timer
  local offhand_timer = player_nameplate.offhand_swing_timer
  local main_speed, off_speed = UnitAttackSpeed("player")

  if main_timer:IsShown() and main_speed and main_speed > 0 and main_speed ~= main_timer.swing_time then
    RefreshSwingTimer(main_timer, main_speed)
    if main_timer.twist_timer then
      main_timer.twist_timer:SetWidth(main_speed > main_timer.twist_time and
        math.floor(main_timer.twist_time / main_speed * main_timer:GetWidth()) or main_timer:GetWidth())
    end
  end

  if offhand_timer and offhand_timer:IsShown() and off_speed and off_speed > 0
    and off_speed ~= offhand_timer.swing_time then
    RefreshSwingTimer(offhand_timer, off_speed)
  end
end

local function UpdateMeleeSwingTimer(elapsed)
  if not player_nameplate or not player_nameplate.melee_swing_timer then return end
  UpdateSwingTimer(player_nameplate.melee_swing_timer, elapsed)
end

local function UpdateOffhandSwingTimer(elapsed)
  if not player_nameplate or not player_nameplate.offhand_swing_timer then return end
  UpdateSwingTimer(player_nameplate.offhand_swing_timer, elapsed)
end

local function StartRangedCastTimer()
  if not player_nameplate or not player_nameplate.ranged_cast_timer then return end
  local timer = player_nameplate.ranged_cast_timer
  if not timer:IsShown() then return end

  local cast_speed = UnitRangedDamage("player")
  if cast_speed and cast_speed > 0 then
    timer.cast_time = cast_speed
    timer.current_timer = cast_speed

    timer.clipping_timer:SetWidth(cast_speed > timer.clipping_time and
      math.floor(timer.clipping_time / cast_speed * timer:GetWidth()) or timer:GetWidth())

    timer:SetMinMaxValues(0, cast_speed)
    timer:SetValue(0)
    timer.spark:SetAlpha(1)
    timer.spark:SetPoint("LEFT", -7, 0)
    timer.text:SetText(string.format("%.1fs", cast_speed))
  end
end

local function RefreshRangedCastTimer()
  if not player_nameplate or not player_nameplate.ranged_cast_timer then return end
  local timer = player_nameplate.ranged_cast_timer
  if not timer:IsShown() then return end

  local cast_speed = UnitRangedDamage("player")
  if cast_speed and cast_speed > 0 and cast_speed ~= timer.cast_time then
    local time_elapsed = timer.cast_time - timer.current_timer
    timer.current_timer = cast_speed - time_elapsed

    if timer.current_timer > 0 then
      timer.cast_time = cast_speed
      timer.clipping_timer:SetWidth(cast_speed > timer.clipping_time and
        math.floor(timer.clipping_time / cast_speed * timer:GetWidth()) or timer:GetWidth())
      timer:SetMinMaxValues(0, cast_speed)
      timer:SetValue(time_elapsed)
      timer.spark:SetAlpha(1)
      timer.spark:SetPoint("LEFT", (time_elapsed / timer.cast_time) * timer:GetWidth() - 7, 0)
      timer.text:SetText(string.format("%.1fs", timer.current_timer))
    else
      timer:SetValue(timer.cast_time)
      timer.spark:SetPoint("LEFT", timer:GetWidth() - 7, 0)
      timer.spark:SetAlpha(0)
      timer.cast_time = -1
      timer.current_timer = -1
      timer.text:SetText("0.0s")
    end
  end
end

local function UpdateRangedCastTimer(elapsed)
  if not player_nameplate or not player_nameplate.ranged_cast_timer then return end
  local timer = player_nameplate.ranged_cast_timer
  if timer.current_timer < 0 then return end
  timer.current_timer = timer.current_timer - elapsed

  if timer.current_timer > 0 then
    local time_elapsed = timer.cast_time - timer.current_timer
    timer:SetValue(time_elapsed)
    timer.spark:SetPoint("LEFT", (time_elapsed / timer.cast_time) * timer:GetWidth() - 7, 0)
    timer.text:SetText(string.format("%.1fs", timer.current_timer))
  else
    timer:SetValue(timer.cast_time)
    timer.spark:SetPoint("LEFT", timer:GetWidth() - 7, 0)
    timer.spark:SetAlpha(0)
    timer.cast_time = -1
    timer.current_timer = -1
    timer.text:SetText("0.0s")
  end
end

local function StartAutoShotTimer()
  if not player_nameplate or not player_nameplate.auto_shot_timer then return end
  local timer = player_nameplate.auto_shot_timer
  local db = GetDB()
  if not timer:IsShown() or not db.player_auto_shot_timer then return end

  local cast_speed = 0.5
  timer:SetAlpha(1)
  timer.cast_time = cast_speed
  timer.current_timer = cast_speed
  timer:SetMinMaxValues(0, cast_speed)
  timer:SetValue(0)
  timer.spark:SetAlpha(1)
  timer.spark:SetPoint("LEFT", -7, 0)
end

local function UpdateAutoShotTimer(elapsed)
  if not player_nameplate or not player_nameplate.auto_shot_timer then return end
  local timer = player_nameplate.auto_shot_timer
  if timer.current_timer < 0 then return end
  timer.current_timer = timer.current_timer - elapsed

  if timer.current_timer > 0 then
    local time_elapsed = timer.cast_time - timer.current_timer
    timer:SetValue(time_elapsed)
    timer.spark:SetPoint("LEFT", (time_elapsed / timer.cast_time) * timer:GetWidth() - 7, 0)
  else
    timer:SetAlpha(0)
    timer:SetValue(timer.cast_time)
    timer.spark:SetPoint("LEFT", timer:GetWidth() - 7, 0)
    timer.spark:SetAlpha(0)
    timer.cast_time = -1
    timer.current_timer = -1
  end
end

local function UpdateMeleeTimerVisibility()
  if not player_nameplate or not player_nameplate.melee_swing_timer then return end
  local db = GetDB()
  local in_combat = IsInCombat()
  local spec_allowed = player_nameplate.melee_swing_timer.spec_allowed
  local show_melee = db.player_melee_swing_timer and MELEE_CLASSES[player_class]
    and (spec_allowed == nil or spec_allowed)

  if db.player_melee_swing_timer_only_in_combat and not in_combat then
    show_melee = false
  end
  if db.player_melee_swing_timer_hide_out_of_combat and not in_combat then
    show_melee = false
  end

  local melee_timer = player_nameplate.melee_swing_timer
  if show_melee then
    melee_timer:SetAlpha(0)
    melee_timer:Show()
  else
    melee_timer:SetAlpha(db.player_melee_swing_timer_alpha or 1)
    melee_timer:Hide()
  end

  local offhand_timer = player_nameplate.offhand_swing_timer
  if offhand_timer then
    local off_speed = select(2, UnitAttackSpeed("player"))
    local show_offhand = show_melee and db.player_melee_swing_timer_show_offhand
      and off_speed and off_speed > 0
    if show_offhand then
      offhand_timer:SetAlpha(0)
      offhand_timer:Show()
    else
      offhand_timer:SetAlpha(db.player_melee_swing_timer_alpha or 1)
      offhand_timer:Hide()
    end
  end
end

local function HookPlayerFrames()
  if hooks then return end
  hooks = true

  if PlayerFrameHealthBar then
    hooksecurefunc(PlayerFrameHealthBar, "SetValue", function(_, value)
      if player_nameplate then
        player_nameplate.healthbar:SetValue(value)
        UpdatePlayerNameplateHealth()
      end
    end)

    hooksecurefunc(PlayerFrameHealthBar, "SetMinMaxValues", function(_, min, max)
      if player_nameplate then
        player_nameplate.healthbar:SetMinMaxValues(min, max)
        UpdatePlayerNameplateHealth()
      end
    end)

    hooksecurefunc(PlayerFrameHealthBar, "SetStatusBarColor", function(_, r, g, b)
      if player_nameplate then
        player_nameplate.healthbar:SetStatusBarColor(r, g, b)
      end
    end)

    if PlayerFrameHealthBar.MyHealPredictionBar then
      hooksecurefunc(PlayerFrameHealthBar.MyHealPredictionBar, "Show", function()
        if player_nameplate and player_nameplate.healthbar.heal then
          player_nameplate.healthbar.heal:Show()
          SetPlayerFillMask()
        end
      end)

      hooksecurefunc(PlayerFrameHealthBar.MyHealPredictionBar, "Hide", function()
        if player_nameplate and player_nameplate.healthbar.heal then
          player_nameplate.healthbar.heal:Hide()
        end
      end)

      if PlayerFrameHealthBar.MyHealPredictionBar.FillMask then
        hooksecurefunc(PlayerFrameHealthBar.MyHealPredictionBar.FillMask, "SetSize", function()
          SetPlayerFillMask()
        end)
      end
    end

    if PlayerFrameHealthBar.OtherHealPredictionBar then
      hooksecurefunc(PlayerFrameHealthBar.OtherHealPredictionBar, "Show", function()
        if player_nameplate and player_nameplate.healthbar.other_heal then
          player_nameplate.healthbar.other_heal:Show()
          SetPlayerOtherFillMask()
        end
      end)

      hooksecurefunc(PlayerFrameHealthBar.OtherHealPredictionBar, "Hide", function()
        if player_nameplate and player_nameplate.healthbar.other_heal then
          player_nameplate.healthbar.other_heal:Hide()
        end
      end)

      if PlayerFrameHealthBar.OtherHealPredictionBar.FillMask then
        hooksecurefunc(PlayerFrameHealthBar.OtherHealPredictionBar.FillMask, "SetSize", function()
          SetPlayerOtherFillMask()
        end)
      end
    end
  end

  if PlayerFrameManaBar then
    hooksecurefunc(PlayerFrameManaBar, "SetValue", function(_, value)
      if player_nameplate then
        player_nameplate.manabar:SetValue(value)
        UpdatePlayerNameplatePower()
      end
    end)

    hooksecurefunc(PlayerFrameManaBar, "SetMinMaxValues", function(_, min, max)
      if player_nameplate then
        player_nameplate.manabar:SetMinMaxValues(min, max)
        UpdatePlayerNameplatePower()
      end
    end)

    hooksecurefunc(PlayerFrameManaBar, "SetStatusBarColor", function(_, r, g, b)
      if player_nameplate then
        player_nameplate.manabar:SetStatusBarColor(r, g, b)
      end
    end)
  end

  if PlayerFrame and PlayerFrame.alt_manabar then
    hooksecurefunc(PlayerFrame.alt_manabar, "SetAlpha", function(_, alpha)
      if player_nameplate and player_nameplate.alt_manabar then
        player_nameplate.alt_manabar:SetAlpha(alpha)
      end
    end)

    hooksecurefunc(PlayerFrame.alt_manabar, "SetStatusBarColor", function(_, r, g, b)
      if player_nameplate and player_nameplate.alt_manabar then
        player_nameplate.alt_manabar:SetStatusBarColor(r, g, b)
      end
    end)

    hooksecurefunc(PlayerFrame.alt_manabar, "SetValue", function(_, value)
      if player_nameplate and player_nameplate.alt_manabar then
        player_nameplate.alt_manabar:SetValue(value)
      end
    end)

    hooksecurefunc(PlayerFrame.alt_manabar, "SetMinMaxValues", function(_, min, max)
      if player_nameplate and player_nameplate.alt_manabar then
        player_nameplate.alt_manabar:SetMinMaxValues(min, max)
      end
    end)
  end
end

local function EnsurePlayerNameplate()
  if player_nameplate then return end
  local texture = GetStatusbarTexture()

  player_nameplate = CreateFrame("Frame", "EnhanceTBC_PlayerNameplate", UIParent)
  player_nameplate:SetFrameStrata("MEDIUM")
  player_nameplate:SetAlpha(0)

  player_nameplate.animation = player_nameplate:CreateAnimationGroup()
  player_nameplate.fade_direction = 1
  player_nameplate.fade = player_nameplate.animation:CreateAnimation("Alpha")
  player_nameplate.fade:SetDuration(0.15)

  player_nameplate.animation:SetScript("OnFinished", function()
    local live_db = GetDB()
    if player_nameplate.fade_direction > 0 then
      player_nameplate:SetAlpha(live_db.player_nameplate_alpha or 1)
    else
      player_nameplate:SetAlpha(0)
    end
  end)

  player_nameplate.healthbar = CreateFrame("StatusBar", nil, player_nameplate)
  player_nameplate.healthbar:SetPoint("BOTTOMLEFT", player_nameplate, "LEFT", 0, 0)
  player_nameplate.healthbar:SetPoint("TOPRIGHT", 0, 0)
  player_nameplate.healthbar:SetStatusBarTexture(texture)
  player_nameplate.healthbar:SetMinMaxValues(0, UnitHealthMax("player") or 1)

  player_nameplate.healthbar.text = player_nameplate.healthbar:CreateFontString(nil, "OVERLAY")
  player_nameplate.healthbar.text:SetAllPoints(true)
  player_nameplate.healthbar.text:SetJustifyH("CENTER")
  player_nameplate.healthbar.text:SetJustifyV("MIDDLE")
  ApplyFont(player_nameplate.healthbar.text, 11)

  player_nameplate.healthbar.backdrop = CreateFrame("Frame", nil, player_nameplate.healthbar, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ApplyBackdropAlt(player_nameplate.healthbar.backdrop)

  player_nameplate.healthbar.heal = CreateFrame("Frame", nil, player_nameplate)
  player_nameplate.healthbar.heal:Hide()
  player_nameplate.healthbar.heal.texture = player_nameplate.healthbar.heal:CreateTexture(nil, "OVERLAY")
  player_nameplate.healthbar.heal.texture:SetAllPoints(true)
  player_nameplate.healthbar.heal.texture:SetTexture(texture)
  player_nameplate.healthbar.heal.texture:SetVertexColor(0, 0.75, 0.65)

  player_nameplate.healthbar.other_heal = CreateFrame("Frame", nil, player_nameplate)
  player_nameplate.healthbar.other_heal:Hide()
  player_nameplate.healthbar.other_heal.texture = player_nameplate.healthbar.other_heal:CreateTexture(nil, "OVERLAY")
  player_nameplate.healthbar.other_heal.texture:SetAllPoints(true)
  player_nameplate.healthbar.other_heal.texture:SetTexture(texture)
  player_nameplate.healthbar.other_heal.texture:SetVertexColor(0, 0.75, 0.65)

  player_nameplate.healthbar.absorb = CreateFrame("Frame", nil, player_nameplate)
  player_nameplate.healthbar.absorb:SetSize(16, player_nameplate.healthbar:GetHeight())
  player_nameplate.healthbar.absorb:Hide()

  player_nameplate.healthbar.absorb.shield_texture = player_nameplate.healthbar.absorb:CreateTexture(nil, "OVERLAY")
  player_nameplate.healthbar.absorb.shield_texture:SetAllPoints(true)
  player_nameplate.healthbar.absorb.shield_texture:SetTexture(798064)

  player_nameplate.healthbar.absorb.over_absorb_texture = player_nameplate.healthbar.absorb:CreateTexture(nil, "OVERLAY")
  player_nameplate.healthbar.absorb.over_absorb_texture:SetSize(12, player_nameplate.healthbar.absorb:GetHeight())
  player_nameplate.healthbar.absorb.over_absorb_texture:SetPoint("RIGHT", player_nameplate.healthbar, 6, 0)
  player_nameplate.healthbar.absorb.over_absorb_texture:SetTexture(798066)
  player_nameplate.healthbar.absorb.over_absorb_texture:SetBlendMode("ADD")

  player_nameplate.manabar = CreateFrame("StatusBar", nil, player_nameplate)
  player_nameplate.manabar:SetPoint("BOTTOMLEFT", 0, -1)
  player_nameplate.manabar:SetPoint("TOPRIGHT", player_nameplate, "RIGHT", 0, -1)
  player_nameplate.manabar:SetStatusBarTexture(texture)
  player_nameplate.manabar:SetMinMaxValues(0, UnitPowerMax("player") or 1)

  player_nameplate.manabar.text = player_nameplate.manabar:CreateFontString(nil, "OVERLAY")
  player_nameplate.manabar.text:SetAllPoints(true)
  player_nameplate.manabar.text:SetJustifyH("CENTER")
  player_nameplate.manabar.text:SetJustifyV("MIDDLE")
  ApplyFont(player_nameplate.manabar.text, 11)

  player_nameplate.manabar.backdrop = CreateFrame("Frame", nil, player_nameplate.manabar, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ApplyBackdropAlt(player_nameplate.manabar.backdrop)

  player_nameplate.alt_manabar = CreateFrame("StatusBar", nil, player_nameplate)
  player_nameplate.alt_manabar:SetHeight(7)
  player_nameplate.alt_manabar:SetPoint("TOPLEFT", player_nameplate.manabar, "BOTTOMLEFT", 0, -1)
  player_nameplate.alt_manabar:SetPoint("TOPRIGHT", player_nameplate.manabar, "BOTTOMRIGHT", 0, -1)
  player_nameplate.alt_manabar:SetStatusBarTexture(texture)
  player_nameplate.alt_manabar:SetMinMaxValues(0, UnitPowerMax("player") or 1)
  player_nameplate.alt_manabar:SetAlpha(0)

  player_nameplate.alt_manabar.backdrop = CreateFrame("Frame", nil, player_nameplate.alt_manabar, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ApplyBackdropAlt(player_nameplate.alt_manabar.backdrop)

  player_nameplate.melee_swing_timer = CreateFrame("StatusBar", nil, UIParent)
  player_nameplate.melee_swing_timer:SetStatusBarTexture(texture)

  player_nameplate.melee_swing_timer.backdrop = CreateFrame("Frame", nil, player_nameplate.melee_swing_timer, BackdropTemplateMixin and "BackdropTemplate" or nil)
  player_nameplate.melee_swing_timer.backdrop:SetAllPoints(true)
  player_nameplate.melee_swing_timer.backdrop:SetFrameStrata("LOW")
  player_nameplate.melee_swing_timer.backdrop:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  })
  player_nameplate.melee_swing_timer.backdrop:SetBackdropColor(0, 0, 0, 0.65)

  player_nameplate.melee_swing_timer.spark = player_nameplate.melee_swing_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.melee_swing_timer.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  player_nameplate.melee_swing_timer.spark:SetBlendMode("ADD")
  player_nameplate.melee_swing_timer.spark:SetAlpha(0)

  player_nameplate.melee_swing_timer.twist_timer = CreateFrame("Frame", nil, player_nameplate.melee_swing_timer)
  player_nameplate.melee_swing_timer.twist_timer:SetPoint("RIGHT", 0, 0)
  player_nameplate.melee_swing_timer.twist_timer:SetFrameStrata("LOW")

  player_nameplate.melee_swing_timer.twist_timer.texture = player_nameplate.melee_swing_timer.twist_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.melee_swing_timer.twist_timer.texture:SetAllPoints(true)
  player_nameplate.melee_swing_timer.twist_timer.texture:SetTexture(texture)
  player_nameplate.melee_swing_timer.twist_timer.texture:SetVertexColor(0.8, 0, 0)

  player_nameplate.melee_swing_timer.text = player_nameplate.melee_swing_timer:CreateFontString(nil, "OVERLAY")
  player_nameplate.melee_swing_timer.text:SetPoint("BOTTOMLEFT", 4, 0)
  player_nameplate.melee_swing_timer.text:SetPoint("TOPRIGHT", 54, 0)
  player_nameplate.melee_swing_timer.text:SetJustifyH("LEFT")
  player_nameplate.melee_swing_timer.text:SetJustifyV("MIDDLE")
  ApplyFont(player_nameplate.melee_swing_timer.text, 10)
  player_nameplate.melee_swing_timer.text:SetText("0.0s")

  player_nameplate.melee_swing_timer.ability_icon = CreateFrame("Frame", nil, player_nameplate.melee_swing_timer)
  player_nameplate.melee_swing_timer.ability_icon:SetSize(21, 21)
  player_nameplate.melee_swing_timer.ability_icon:SetPoint("RIGHT", player_nameplate.melee_swing_timer, "LEFT", -6, 0)
  player_nameplate.melee_swing_timer.ability_icon:Hide()

  player_nameplate.melee_swing_timer.ability_icon.guid = nil
  player_nameplate.melee_swing_timer.ability_icon.current_spell = nil
  player_nameplate.melee_swing_timer.ability_icon.texture = player_nameplate.melee_swing_timer.ability_icon:CreateTexture(nil, "OVERLAY")
  player_nameplate.melee_swing_timer.ability_icon.texture:SetAllPoints(true)
  player_nameplate.melee_swing_timer.ability_icon.texture:SetTexCoord(0.07, 0.94, 0.07, 0.94)

  player_nameplate.melee_swing_timer.ability_icon.backdrop = CreateFrame("Frame", nil, player_nameplate.melee_swing_timer.ability_icon, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ApplyBackdrop(player_nameplate.melee_swing_timer.ability_icon.backdrop)

  player_nameplate.melee_swing_timer.swing_time = -1
  player_nameplate.melee_swing_timer.current_timer = -1
  player_nameplate.melee_swing_timer.twist_time = 0
  player_nameplate.melee_swing_timer.main_hand_id = nil
  player_nameplate.melee_swing_timer.spec_allowed = true

  player_nameplate.offhand_swing_timer = CreateFrame("StatusBar", nil, UIParent)
  player_nameplate.offhand_swing_timer:SetStatusBarTexture(texture)

  player_nameplate.offhand_swing_timer.backdrop = CreateFrame(
    "Frame",
    nil,
    player_nameplate.offhand_swing_timer,
    BackdropTemplateMixin and "BackdropTemplate" or nil
  )
  player_nameplate.offhand_swing_timer.backdrop:SetAllPoints(true)
  player_nameplate.offhand_swing_timer.backdrop:SetFrameStrata("LOW")
  player_nameplate.offhand_swing_timer.backdrop:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  })
  player_nameplate.offhand_swing_timer.backdrop:SetBackdropColor(0, 0, 0, 0.65)

  player_nameplate.offhand_swing_timer.spark = player_nameplate.offhand_swing_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.offhand_swing_timer.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  player_nameplate.offhand_swing_timer.spark:SetBlendMode("ADD")
  player_nameplate.offhand_swing_timer.spark:SetAlpha(0)

  player_nameplate.offhand_swing_timer.text = player_nameplate.offhand_swing_timer:CreateFontString(nil, "OVERLAY")
  player_nameplate.offhand_swing_timer.text:SetPoint("BOTTOMLEFT", 4, 0)
  player_nameplate.offhand_swing_timer.text:SetPoint("TOPRIGHT", 54, 0)
  player_nameplate.offhand_swing_timer.text:SetJustifyH("LEFT")
  player_nameplate.offhand_swing_timer.text:SetJustifyV("MIDDLE")
  ApplyFont(player_nameplate.offhand_swing_timer.text, 10)
  player_nameplate.offhand_swing_timer.text:SetText("0.0s")

  player_nameplate.offhand_swing_timer.swing_time = -1
  player_nameplate.offhand_swing_timer.current_timer = -1
  player_nameplate.offhand_swing_timer.offhand_id = nil

  player_nameplate.ranged_cast_timer = CreateFrame("StatusBar", nil, UIParent)
  player_nameplate.ranged_cast_timer:SetStatusBarTexture(texture)

  player_nameplate.ranged_cast_timer.backdrop = CreateFrame("Frame", nil, player_nameplate.ranged_cast_timer, BackdropTemplateMixin and "BackdropTemplate" or nil)
  player_nameplate.ranged_cast_timer.backdrop:SetAllPoints(true)
  player_nameplate.ranged_cast_timer.backdrop:SetFrameStrata("LOW")
  player_nameplate.ranged_cast_timer.backdrop:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  })
  player_nameplate.ranged_cast_timer.backdrop:SetBackdropColor(0, 0, 0, 0.65)

  player_nameplate.ranged_cast_timer.spark = player_nameplate.ranged_cast_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.ranged_cast_timer.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  player_nameplate.ranged_cast_timer.spark:SetBlendMode("ADD")
  player_nameplate.ranged_cast_timer.spark:SetAlpha(0)

  player_nameplate.ranged_cast_timer.clipping_timer = CreateFrame("Frame", nil, player_nameplate.ranged_cast_timer)
  player_nameplate.ranged_cast_timer.clipping_timer:SetPoint("RIGHT", 0, 0)
  player_nameplate.ranged_cast_timer.clipping_timer:SetFrameStrata("LOW")

  player_nameplate.ranged_cast_timer.clipping_timer.texture = player_nameplate.ranged_cast_timer.clipping_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.ranged_cast_timer.clipping_timer.texture:SetAllPoints(true)
  player_nameplate.ranged_cast_timer.clipping_timer.texture:SetTexture(texture)
  player_nameplate.ranged_cast_timer.clipping_timer.texture:SetVertexColor(0.8, 0, 0)

  player_nameplate.ranged_cast_timer.text = player_nameplate.ranged_cast_timer:CreateFontString(nil, "OVERLAY")
  player_nameplate.ranged_cast_timer.text:SetPoint("BOTTOMLEFT", 4, 0)
  player_nameplate.ranged_cast_timer.text:SetPoint("TOPRIGHT", 54, 0)
  player_nameplate.ranged_cast_timer.text:SetJustifyH("LEFT")
  player_nameplate.ranged_cast_timer.text:SetJustifyV("MIDDLE")
  ApplyFont(player_nameplate.ranged_cast_timer.text, 10)
  player_nameplate.ranged_cast_timer.text:SetText("0.0s")

  player_nameplate.ranged_cast_timer.cast_time = -1
  player_nameplate.ranged_cast_timer.current_timer = -1
  player_nameplate.ranged_cast_timer.clipping_time = 0
  player_nameplate.ranged_cast_timer.ranged_id = nil

  player_nameplate.auto_shot_timer = CreateFrame("StatusBar", nil, player_nameplate.ranged_cast_timer)
  player_nameplate.auto_shot_timer:SetPoint("TOPLEFT", player_nameplate.ranged_cast_timer, "BOTTOMLEFT", 0, -3)
  player_nameplate.auto_shot_timer:SetPoint("BOTTOMRIGHT", player_nameplate.ranged_cast_timer, "BOTTOMRIGHT", 0, -7)
  player_nameplate.auto_shot_timer:SetAlpha(0)
  player_nameplate.auto_shot_timer:SetStatusBarTexture(texture)

  player_nameplate.auto_shot_timer.backdrop = CreateFrame("Frame", nil, player_nameplate.auto_shot_timer, BackdropTemplateMixin and "BackdropTemplate" or nil)
  player_nameplate.auto_shot_timer.backdrop:SetAllPoints(true)
  player_nameplate.auto_shot_timer.backdrop:SetFrameStrata("LOW")
  player_nameplate.auto_shot_timer.backdrop:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  })
  player_nameplate.auto_shot_timer.backdrop:SetBackdropColor(0, 0, 0, 0.65)

  player_nameplate.auto_shot_timer.spark = player_nameplate.auto_shot_timer:CreateTexture(nil, "OVERLAY")
  player_nameplate.auto_shot_timer.spark:SetSize(14, 9)
  player_nameplate.auto_shot_timer.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  player_nameplate.auto_shot_timer.spark:SetBlendMode("ADD")
  player_nameplate.auto_shot_timer.spark:SetAlpha(0)

  player_nameplate.auto_shot_timer.cast_time = -1
  player_nameplate.auto_shot_timer.current_timer = -1

  HookPlayerFrames()
end

local function ApplySettings()
  local db = GetDB()

  if not db.enabled then
    if player_nameplate then
      player_nameplate:Hide()
    end
    return
  end

  EnsurePlayerNameplate()
  player_class = select(2, UnitClass("player")) or player_class

  player_nameplate:SetScale(db.player_nameplate_scale or 0.9)
  player_nameplate:SetSize(db.player_nameplate_width or 128, db.player_nameplate_height or 22)
  player_nameplate:ClearAllPoints()
  player_nameplate:SetPoint("CENTER", UIParent, "CENTER", 0, db.player_nameplate_pos_y or -105)

  player_nameplate.healthbar.absorb:SetSize(16, player_nameplate.healthbar:GetHeight())
  player_nameplate.healthbar.absorb.over_absorb_texture:SetSize(12, player_nameplate.healthbar.absorb:GetHeight())

  if db.player_nameplate_health then
    player_nameplate.healthbar:Hide()
  else
    player_nameplate.healthbar:Show()
  end

  if db.player_nameplate_text then
    player_nameplate.healthbar.text:Show()
    player_nameplate.manabar.text:Show()
  else
    player_nameplate.healthbar.text:Hide()
    player_nameplate.manabar.text:Hide()
  end

  if player_class ~= "DRUID" or not db.player_alt_manabar then
    player_nameplate.alt_manabar:Hide()
  else
    player_nameplate.alt_manabar:Show()
  end

  if db.player_nameplate_frame then
    player_nameplate:Show()
  else
    player_nameplate:Hide()
  end

  local texture = GetStatusbarTexture()
  player_nameplate.healthbar:SetStatusBarTexture(texture)
  player_nameplate.healthbar.heal.texture:SetTexture(texture)
  player_nameplate.healthbar.other_heal.texture:SetTexture(texture)
  player_nameplate.manabar:SetStatusBarTexture(texture)
  player_nameplate.alt_manabar:SetStatusBarTexture(texture)

  local melee_timer = player_nameplate.melee_swing_timer
  melee_timer:SetParent(db.player_melee_swing_timer_seperate and UIParent or player_nameplate)
  melee_timer:SetScale(db.player_melee_swing_timer_scale or 1)
  melee_timer:SetSize(db.player_melee_swing_timer_width or 230, db.player_melee_swing_timer_height or 9)
  melee_timer:ClearAllPoints()
  melee_timer:SetPoint("CENTER", UIParent, "CENTER", 0, db.player_melee_swing_timer_pos_y or -150)
  melee_timer:SetStatusBarTexture(texture)

  local mr, mg, mb = GetColorValue(db.player_melee_swing_timer_color)
  melee_timer:SetStatusBarColor(mr, mg, mb)

  melee_timer.spark:SetSize(14, (db.player_melee_swing_timer_height or 9) * 2)
  melee_timer.twist_timer:SetSize(0, db.player_melee_swing_timer_height or 9)
  melee_timer.text:SetText("0.0s")

  if db.player_melee_swing_timer_text then
    melee_timer.text:Show()
  else
    melee_timer.text:Hide()
  end

  if db.player_melee_swing_timer_icon then
    melee_timer.ability_icon:Show()
  else
    melee_timer.ability_icon:Hide()
  end

  local offhand_timer = player_nameplate.offhand_swing_timer
  offhand_timer:SetParent(db.player_melee_swing_timer_seperate and UIParent or player_nameplate)
  offhand_timer:SetScale(db.player_melee_swing_timer_scale or 1)
  offhand_timer:SetSize(db.player_melee_swing_timer_width or 230, db.player_melee_swing_timer_height or 9)
  offhand_timer:ClearAllPoints()
  offhand_timer:SetPoint("TOPLEFT", melee_timer, "BOTTOMLEFT", 0, -3)
  offhand_timer:SetPoint("TOPRIGHT", melee_timer, "BOTTOMRIGHT", 0, -3)
  offhand_timer:SetStatusBarTexture(texture)
  offhand_timer:SetStatusBarColor(mr, mg, mb)
  offhand_timer.spark:SetSize(14, (db.player_melee_swing_timer_height or 9) * 2)
  offhand_timer.text:SetText("0.0s")

  if db.player_melee_swing_timer_text then
    offhand_timer.text:Show()
  else
    offhand_timer.text:Hide()
  end

  local ranged_timer = player_nameplate.ranged_cast_timer
  ranged_timer:SetParent(db.player_ranged_cast_timer_seperate and UIParent or player_nameplate)
  ranged_timer:SetScale(db.player_ranged_cast_timer_scale or 1)
  ranged_timer:SetSize(db.player_ranged_cast_timer_width or 230, db.player_ranged_cast_timer_height or 9)
  ranged_timer:ClearAllPoints()
  ranged_timer:SetPoint("CENTER", UIParent, "CENTER", 0, db.player_ranged_cast_timer_pos_y or -140)
  ranged_timer:SetStatusBarTexture(texture)

  local rr, rg, rb = GetColorValue(db.player_ranged_cast_timer_color)
  ranged_timer:SetStatusBarColor(rr, rg, rb)

  ranged_timer.spark:SetSize(14, (db.player_ranged_cast_timer_height or 9) * 2)
  ranged_timer.clipping_timer:SetSize(0, db.player_ranged_cast_timer_height or 9)
  ranged_timer.text:SetText("0.0s")

  if db.player_ranged_cast_timer_text then
    ranged_timer.text:Show()
  else
    ranged_timer.text:Hide()
  end

  if db.player_ranged_cast_timer then
    ranged_timer:SetAlpha(0)
    ranged_timer:Show()
  else
    ranged_timer:SetAlpha(db.player_ranged_cast_timer_alpha or 1)
    ranged_timer:Hide()
  end

  if ranged_timer:IsShown() then
    ranged_timer:SetScript("OnUpdate", function(_, elapsed)
      UpdateRangedCastTimer(elapsed)
    end)
  else
    ranged_timer:SetScript("OnUpdate", nil)
  end

  player_nameplate.auto_shot_timer:SetStatusBarTexture(texture)
  player_nameplate.auto_shot_timer:SetStatusBarColor(rr, rg, rb)

  if player_class == "HUNTER" and db.player_auto_shot_timer then
    player_nameplate.auto_shot_timer:Show()
    player_nameplate.auto_shot_timer:SetScript("OnUpdate", function(_, elapsed)
      UpdateAutoShotTimer(elapsed)
    end)
  else
    player_nameplate.auto_shot_timer:SetAlpha(0)
    player_nameplate.auto_shot_timer:Hide()
    player_nameplate.auto_shot_timer:SetScript("OnUpdate", nil)
  end

  if not MELEE_CLASSES[player_class] then
    melee_timer:Hide()
    offhand_timer:Hide()
  elseif player_class == "PALADIN" then
    melee_timer.twist_time = 0.4
  end

  UpdateMeleeTimerVisibility()

  if melee_timer:IsShown() then
    melee_timer:SetScript("OnUpdate", function(_, elapsed)
      UpdateMeleeSwingTimer(elapsed)
    end)
  else
    melee_timer:SetScript("OnUpdate", nil)
  end

  if offhand_timer:IsShown() then
    offhand_timer:SetScript("OnUpdate", function(_, elapsed)
      UpdateOffhandSwingTimer(elapsed)
    end)
  else
    offhand_timer:SetScript("OnUpdate", nil)
  end

  if not RANGED_CLASSES[player_class] then
    ranged_timer:Hide()
  elseif player_class == "HUNTER" then
    ranged_timer.clipping_time = 0.5
  end

  UpdatePlayerNameplateHealth()
  UpdatePlayerNameplatePower()
  SetPlayerNameplateAbsorb()
end

local function RegisterEvents()
  EnsureDriver()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("UNIT_AURA")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("UNIT_ATTACK_SPEED")
  driver:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("PLAYER_TALENT_UPDATE")
  driver:RegisterEvent("PLAYER_DEAD")
  driver:RegisterEvent("UNIT_SPELLCAST_SENT")
  driver:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  driver:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

  driver:SetScript("OnEvent", function(_, event, unit, target_guid, cast_spell_id, spell_id)
    if not player_nameplate then return end

    if event == "PLAYER_ENTERING_WORLD" then
      UpdatePlayerNameplateHealth()
      UpdatePlayerNameplatePower()
      SetPlayerNameplateAbsorb()

      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() then
        if not player_nameplate.melee_swing_timer.main_hand_id then
          player_nameplate.melee_swing_timer.main_hand_id = GetInventoryItemID("player", 16)
        end
      end

      if player_nameplate.offhand_swing_timer and player_nameplate.offhand_swing_timer:IsShown() then
        if not player_nameplate.offhand_swing_timer.offhand_id then
          player_nameplate.offhand_swing_timer.offhand_id = GetInventoryItemID("player", 17)
        end
      end

      if player_nameplate.ranged_cast_timer and player_nameplate.ranged_cast_timer:IsShown() then
        if not player_nameplate.ranged_cast_timer.ranged_id then
          player_nameplate.ranged_cast_timer.ranged_id = GetInventoryItemID("player", 18)
        end
      end
    elseif event == "UNIT_AURA" then
      if unit == "player" then
        SetPlayerNameplateAbsorb()
      end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
      HidePlayerNameplate()
      UpdateMeleeTimerVisibility()
    elseif event == "PLAYER_REGEN_DISABLED" then
      ShowPlayerNameplate()
      UpdateMeleeTimerVisibility()
    elseif event == "UNIT_ATTACK_SPEED" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() then
        if player_nameplate.melee_swing_timer.swing_time > 0 then RefreshMeleeSwingTimer() end
      end

      if player_nameplate.ranged_cast_timer and player_nameplate.ranged_cast_timer:IsShown() then
        if player_nameplate.ranged_cast_timer.cast_time > 0 then RefreshRangedCastTimer() end
      end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() then
        local main_hand_id = GetInventoryItemID("player", 16) or 0
        if player_nameplate.melee_swing_timer.main_hand_id ~= main_hand_id then
          player_nameplate.melee_swing_timer.main_hand_id = main_hand_id
          StartMeleeSwingTimer()
        end
      end

      if player_nameplate.offhand_swing_timer and player_nameplate.offhand_swing_timer:IsShown() then
        local offhand_id = GetInventoryItemID("player", 17) or 0
        if player_nameplate.offhand_swing_timer.offhand_id ~= offhand_id then
          player_nameplate.offhand_swing_timer.offhand_id = offhand_id
          StartMeleeSwingTimer(true)
        end
      end

      UpdateMeleeTimerVisibility()

      if player_nameplate.ranged_cast_timer and player_nameplate.ranged_cast_timer:IsShown() then
        local ranged_id = GetInventoryItemID("player", 18) or 0
        if player_nameplate.ranged_cast_timer.ranged_id ~= ranged_id then
          player_nameplate.ranged_cast_timer.ranged_id = ranged_id
          StartRangedCastTimer()
        end
      end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_TALENT_UPDATE" then
      if type(MELEE_CLASSES[player_class]) == "table" and UnitLevel("player") >= 10 then
        local spec_tab
        local spec_tab_talent_points = 0
        for i = 1, GetNumTalentTabs() do
          local n = 0
          for j = 1, GetNumTalents(i) do
            n = n + select(5, GetTalentInfo(i, j))
          end
          if not spec_tab or n > spec_tab_talent_points then
            spec_tab = i
            spec_tab_talent_points = n
          end
        end

        local spec = false
        for i = 1, #MELEE_CLASSES[player_class] do
          if spec_tab == MELEE_CLASSES[player_class][i] then
            spec = true
            break
          end
        end

        if not spec then
          player_nameplate.melee_swing_timer.spec_allowed = false
          player_nameplate.melee_swing_timer:Hide()
        else
          player_nameplate.melee_swing_timer.spec_allowed = true
          player_nameplate.melee_swing_timer:Show()
        end
        UpdateMeleeTimerVisibility()
      end
    elseif event == "UNIT_SPELLCAST_SENT" and unit == "player" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() and spell_id then
        local name, _, icon = GetSpellInfo(spell_id)
        if name == "Heroic Strike" or name == "Cleave" then
          if GetDB().player_melee_swing_timer_icon then
            player_nameplate.melee_swing_timer.ability_icon.guid = target_guid
            player_nameplate.melee_swing_timer.ability_icon.texture:SetTexture(icon)
            player_nameplate.melee_swing_timer.ability_icon:Show()
          end
        end
      end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() and cast_spell_id then
        local name = GetSpellInfo(cast_spell_id)
        if name == "War Stomp" then
          StartMeleeSwingTimer()
        end
      end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() and IsMounted() then
        StartMeleeSwingTimer()
      end
    elseif event == "PLAYER_TARGET_CHANGED" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown()
        and player_nameplate.melee_swing_timer.ability_icon.guid then
        player_nameplate.melee_swing_timer.ability_icon.guid = nil
        player_nameplate.melee_swing_timer.ability_icon:Hide()
      end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      if player_nameplate.melee_swing_timer and player_nameplate.melee_swing_timer:IsShown() then
        local _, combat_event, _, _, source_name, _, _, _, dest_name, _, _, spell_id = CombatLogGetCurrentEventInfo()
        if combat_event == "SWING_DAMAGE" and source_name == UnitName("player") then
          local _, _, _, _, _, _, _, _, _, is_offhand = select(12, CombatLogGetCurrentEventInfo())
          if is_offhand then
            StartMeleeSwingTimer(true)
          else
            StartMeleeSwingTimer()
            StartRangedCastTimer()
          end
        elseif combat_event == "SWING_MISSED" then
          local miss_type, is_offhand = select(12, CombatLogGetCurrentEventInfo())
          if source_name == UnitName("player") and is_offhand then
            StartMeleeSwingTimer(true)
          elseif not is_offhand then
            if source_name == UnitName("player") then
              StartMeleeSwingTimer()
              StartRangedCastTimer()
            elseif dest_name == UnitName("player") and miss_type == "PARRY" then
              local parry_timer = player_nameplate.melee_swing_timer.current_timer
                - (player_nameplate.melee_swing_timer.swing_time * 0.4)
              if parry_timer <= player_nameplate.melee_swing_timer.swing_time * 0.2 then
                StartMeleeSwingTimer()
                StartRangedCastTimer()
              else
                player_nameplate.melee_swing_timer.current_timer = parry_timer
              end
            end
          end
        elseif combat_event == "SPELL_CAST_SUCCESS" and source_name == UnitName("player") and spell_id then
          local name, _, icon, cast_time = GetSpellInfo(spell_id)
          if not HUNTER_SPELLS[name] then
            if (cast_time and cast_time > 0) or MELEE_RESET_SPELLS[name] then
              player_nameplate.melee_swing_timer.ability_icon.guid = nil
              player_nameplate.melee_swing_timer.ability_icon:Hide()
              StartMeleeSwingTimer()
              StartRangedCastTimer()
            elseif PALADIN_SEALS[name] and GetDB().player_melee_swing_timer_icon then
              player_nameplate.melee_swing_timer.ability_icon.current_spell = name
              player_nameplate.melee_swing_timer.ability_icon.texture:SetTexture(icon)
              player_nameplate.melee_swing_timer.ability_icon:Show()
            end
          else
            if name == "Raptor Strike" then
              StartMeleeSwingTimer()
              StartRangedCastTimer()
            end
          end
        elseif combat_event == "SPELL_AURA_REMOVED" and source_name == UnitName("player") and spell_id then
          local name = GetSpellInfo(spell_id)
          if PALADIN_SEALS[name] and player_nameplate.melee_swing_timer.ability_icon.current_spell then
            if player_nameplate.melee_swing_timer.ability_icon.current_spell == name then
              player_nameplate.melee_swing_timer.ability_icon.current_spell = nil
              player_nameplate.melee_swing_timer.ability_icon:Hide()
            end
          end
        end
      end

      if player_nameplate.ranged_cast_timer and player_nameplate.ranged_cast_timer:IsShown() then
        local _, combat_event, _, _, source_name, _, _, _, _, _, _, spell_id = CombatLogGetCurrentEventInfo()
        if combat_event == "SPELL_CAST_SUCCESS" and source_name == UnitName("player") and spell_id then
          local name, _, _, cast_time = GetSpellInfo(spell_id)
          if HUNTER_SPELLS[name] then
            if name == "Auto Shot" then
              StartRangedCastTimer()
              StartMeleeSwingTimer()
            end
          else
            if name == "Shoot" or (cast_time and cast_time > 0) then
              StartRangedCastTimer()
            end
          end
        elseif combat_event == "SPELL_CAST_START" and source_name == UnitName("player") and spell_id then
          local name = GetSpellInfo(spell_id)
          if HUNTER_SPELLS[name] then
            if name == "Auto Shot" then
              StartAutoShotTimer()
            end
          end
        end
      end
    end
  end)
end

local function UnregisterEvents()
  if not driver then return end
  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)
end

function mod:UpdateTextures()
  if not player_nameplate then return end
  local texture = GetStatusbarTexture()
  player_nameplate.healthbar:SetStatusBarTexture(texture)
  player_nameplate.healthbar.heal.texture:SetTexture(texture)
  player_nameplate.healthbar.other_heal.texture:SetTexture(texture)
  player_nameplate.manabar:SetStatusBarTexture(texture)
  player_nameplate.alt_manabar:SetStatusBarTexture(texture)
  player_nameplate.melee_swing_timer:SetStatusBarTexture(texture)
  player_nameplate.melee_swing_timer.twist_timer.texture:SetTexture(texture)
  player_nameplate.offhand_swing_timer:SetStatusBarTexture(texture)
  player_nameplate.ranged_cast_timer:SetStatusBarTexture(texture)
  player_nameplate.ranged_cast_timer.clipping_timer.texture:SetTexture(texture)
  player_nameplate.auto_shot_timer:SetStatusBarTexture(texture)
end

function mod:Apply()
  if not ETBC.db or not ETBC.db.profile or not ETBC.db.profile.general or not ETBC.db.profile.general.enabled then
    UnregisterEvents()
    if player_nameplate then player_nameplate:Hide() end
    return
  end

  local db = GetDB()
  if not db.enabled then
    UnregisterEvents()
    if player_nameplate then player_nameplate:Hide() end
    return
  end

  EnsurePlayerNameplate()
  ApplySettings()
  RegisterEvents()
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("player_nameplates", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("ui", function()
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled then
      mod:UpdateTextures()
    end
  end)
end
