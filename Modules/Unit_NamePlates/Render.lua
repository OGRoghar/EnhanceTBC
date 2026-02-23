-- Modules/Unit_NamePlates/Render.lua
-- EnhanceTBC - Unit nameplate render/styling helpers (internal)

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local H = mod.Internal.Render or {}
mod.Internal.Render = H

local shared = mod.Internal.Shared
local GetDB = shared.GetDB
local SafeUnitIsUnit = shared.SafeUnitIsUnit
local IsFriendlyNameplate = shared.IsFriendlyNameplate
local Trim = shared.Trim
local GetUnitAuraByIndex = shared.GetUnitAuraByIndex
local FindAuraByName = shared.FindAuraByName
local GetTotemColorByName = shared.GetTotemColorByName
local GetFormattedDebuff = shared.GetFormattedDebuff
local GetFormattedPlayerDebuff = shared.GetFormattedPlayerDebuff
local GetFormattedAbsorbBuff = shared.GetFormattedAbsorbBuff
local FindTrackedAbsorbAura = shared.FindTrackedAbsorbAura
local FindPriorityTrackedDebuffAura = shared.FindPriorityTrackedDebuffAura

local function SetNameplateHealthBarText(statusbar, unit)
  if not statusbar or not statusbar.unit_health_text then return end

  local unit_health = UnitHealth(unit)
  local unit_health_max = UnitHealthMax(unit)

  if unit_health and unit_health_max and unit_health_max > 0 then
    if statusbar.unit_health_text:IsShown() then
      statusbar.unit_health_text.text_left:SetText(math.ceil(unit_health / unit_health_max * 100) .. "%")

      if unit_health < 1000 then
        statusbar.unit_health_text.text_right:SetText(unit_health)
      elseif unit_health < 1000000 then
        statusbar.unit_health_text.text_right:SetText(string.format("%.1fK", (unit_health / 1000)))
      elseif unit_health < 1000000000 then
        statusbar.unit_health_text.text_right:SetText(string.format("%.1fM", (unit_health / 1000000)))
      end
    else
      statusbar.unit_health_text.text_left:SetText("")
      statusbar.unit_health_text.text_right:SetText("")
    end

    if statusbar.absorb and statusbar.absorb:IsShown() then
      local x = statusbar:GetWidth() * (unit_health / unit_health_max)

      if x + statusbar.absorb:GetWidth() > statusbar:GetWidth() then
        x = statusbar:GetWidth() - statusbar.absorb:GetWidth()
        statusbar.absorb.over_absorb_texture:Show()
      else
        statusbar.absorb.over_absorb_texture:Hide()
      end

      statusbar.absorb:SetPoint("LEFT", statusbar, x, 0)
    end
  end
end

local function SetNameplateHealthBarColor(nameplate, statusbar, unit)
  local db = GetDB()
  if not UnitExists(unit) or not statusbar or not statusbar.unit_health_text then return end

  if UnitIsPlayer(unit) then
    if not UnitIsConnected(unit) then
      statusbar:SetStatusBarColor(0.75, 0.75, 0.75)
      return
    end

    if not UnitIsPVP(unit) and not IsFriendlyNameplate(nameplate, unit) then
      statusbar:SetStatusBarColor(1, 0.9, 0.1)
      return
    end

    if db.friendly_nameplate_default_color and IsFriendlyNameplate(nameplate, unit) then
      statusbar:SetStatusBarColor(0, 0.1, 0.9)
      return
    end

    if db.class_colored_nameplates then
      local _, unit_class = UnitClass(unit)
      if not unit_class then return end
      local unit_class_color = RAID_CLASS_COLORS[unit_class]
      if unit_class_color then
        statusbar:SetStatusBarColor(unit_class_color:GetRGB())
      end
    else
      local unit_reaction = UnitReaction(unit, "player")
      if unit_reaction then
        if unit_reaction >= 1 and unit_reaction <= 3 then
          statusbar:SetStatusBarColor(0.9, 0, 0.1)
        elseif unit_reaction == 4 then
          statusbar:SetStatusBarColor(1, 0.9, 0.1)
        else
          statusbar:SetStatusBarColor(0, 0.85, 0.2)
        end
      end
    end
  else
    if db.nameplate_unit_target_color then
      if not IsFriendlyNameplate(nameplate, unit) then
        if SafeUnitIsUnit(unit .. "target", "player") then
          statusbar:SetStatusBarColor(0, 0.1, 0.9)
          return
        end
      else
        if nameplate and nameplate.nameplate_events then
          nameplate.nameplate_events:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
        end
      end
    end

    if db.totem_nameplate_colors then
      local unit_name = UnitName(unit)
      if unit_name then
        local totem_ranks = { "I", "II", "III", "IV", "V", "VI", "VII" }
        for _, v in ipairs(totem_ranks) do
          unit_name = string.gsub(unit_name, v, "")
        end
        unit_name = Trim(unit_name)

        local color = GetTotemColorByName(unit_name)
        if color then
          statusbar:SetStatusBarColor(color:GetRGB())
          return
        end
      end
    end

    if not UnitIsFriend(unit, "player") and UnitIsTapDenied(unit) then
      statusbar:SetStatusBarColor(0.75, 0.75, 0.75)
      return
    end

    local unit_reaction = UnitReaction(unit, "player")
    if unit_reaction then
      if unit_reaction >= 1 and unit_reaction <= 3 then
        statusbar:SetStatusBarColor(0.9, 0, 0.1)
      elseif unit_reaction == 4 then
        statusbar:SetStatusBarColor(1, 0.9, 0.1)
      else
        statusbar:SetStatusBarColor(0, 0.85, 0.2)
      end
    end
  end
end

local function SetNameplateAbsorb(nameplate, unit)
  local db = GetDB()
  if unit and UnitExists(unit) and not UnitIsDead(unit)
    and nameplate and nameplate.UnitFrame then
    local nameplate_health_bar = nameplate.UnitFrame.healthBar
    if not nameplate_health_bar or not nameplate_health_bar.absorb then return end

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      nameplate_health_bar.absorb:Hide()
      return
    end

    if db.useSpellIDAuraLookup then
      local absorb_buff, auraData = FindTrackedAbsorbAura(unit)
      if absorb_buff and auraData then
        local unit_health = UnitHealth(unit)
        local unit_health_max = UnitHealthMax(unit)

        if unit_health and unit_health_max and unit_health_max > 0 then
          local x = nameplate_health_bar:GetWidth() * (unit_health / unit_health_max)
          if x + nameplate_health_bar.absorb:GetWidth() > nameplate_health_bar:GetWidth() then
            x = nameplate_health_bar:GetWidth() - nameplate_health_bar.absorb:GetWidth()
            nameplate_health_bar.absorb.over_absorb_texture:Show()
          else
            nameplate_health_bar.absorb.over_absorb_texture:Hide()
          end

          nameplate_health_bar.absorb:SetPoint("LEFT", nameplate_health_bar, x, 0)
          nameplate_health_bar.absorb:Show()
          return
        end
      end
    end

    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, absorb_spell_id = GetUnitAuraByIndex(unit, i, "HELPFUL")
      if name then
        local absorb_buff = GetFormattedAbsorbBuff(name)

        if absorb_buff and absorb_buff.track_spell_id and absorb_spell_id
          and not absorb_buff.track_spell_id[absorb_spell_id] then
          absorb_buff = nil
        end

        if absorb_buff then
          local unit_health = UnitHealth(unit)
          local unit_health_max = UnitHealthMax(unit)

          if unit_health and unit_health_max and unit_health_max > 0 then
            local x = nameplate_health_bar:GetWidth() * (unit_health / unit_health_max)

            if x + nameplate_health_bar.absorb:GetWidth() > nameplate_health_bar:GetWidth() then
              x = nameplate_health_bar:GetWidth() - nameplate_health_bar.absorb:GetWidth()
              nameplate_health_bar.absorb.over_absorb_texture:Show()
            else
              nameplate_health_bar.absorb.over_absorb_texture:Hide()
            end

            nameplate_health_bar.absorb:SetPoint("LEFT", nameplate_health_bar, x, 0)
            nameplate_health_bar.absorb:Show()
          end

          return
        end
      else
        break
      end
    end

    nameplate_health_bar.absorb:Hide()
  end
end

local function SetNameplateCastBar(nameplate, castbar)
  if nameplate and castbar then
    castbar.Icon:Show()
    castbar.Text:Show()
    castbar.Border:Hide()
  end
end

local function SetNameplateSize(nameplate, statusbar, unit)
  local db = GetDB()
  if not UnitExists(unit) or not nameplate.modified then return end

  if not SafeUnitIsUnit("player", unit) then
    if not IsFriendlyNameplate(nameplate, unit) then
      nameplate.UnitFrame.healthBarWrapper:SetSize(
        db.enemy_nameplate_width or 109,
        db.enemy_nameplate_height or 12.5
      )
      nameplate.UnitFrame.castBarWrapper:SetSize(
        db.enemy_nameplate_castbar_width or 109,
        db.enemy_nameplate_castbar_height or 12.5
      )

      if statusbar.unit_health_text then
        if db.enemy_nameplate_health_text then statusbar.unit_health_text:Show() end

        nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth() - 20)
        nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(1)
        nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(1)

        SetNameplateHealthBarText(statusbar, unit)
      end
    else
      nameplate.UnitFrame.healthBarWrapper:SetSize(
        db.friendly_nameplate_width or 42,
        db.friendly_nameplate_height or 12.5
      )
      nameplate.UnitFrame.castBarWrapper:SetSize(
        db.friendly_nameplate_castbar_width or 42,
        db.friendly_nameplate_castbar_height or 12.5
      )

      if statusbar.unit_health_text then
        statusbar.unit_health_text:Hide()

        if nameplate.UnitFrame.healthBarWrapper:GetWidth() >= 70 then
          nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth() - 20)
          nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(1)
          nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(1)
        else
          nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth())
          nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(0)
          nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(0)
        end
      end
    end
  end

  nameplate.UnitFrame.healthBar:ClearAllPoints()
  nameplate.UnitFrame.healthBar:SetPoint(
    "BOTTOMLEFT", nameplate.UnitFrame.healthBarWrapper, "BOTTOMLEFT", 0, 0
  )
  nameplate.UnitFrame.healthBar:SetPoint("TOPRIGHT", nameplate.UnitFrame.healthBarWrapper, "TOPRIGHT", 0, 0)

  nameplate.UnitFrame.castBar:ClearAllPoints()
  nameplate.UnitFrame.castBar:SetPoint(
    "BOTTOMLEFT",
    nameplate.UnitFrame.castBarWrapper,
    "BOTTOMLEFT",
    nameplate.UnitFrame.castBarWrapper:GetHeight() + 0.5,
    0
  )
  nameplate.UnitFrame.castBar:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBarWrapper, "TOPRIGHT", 0, 0)

  nameplate.UnitFrame.castBar.Icon:ClearAllPoints()
  nameplate.UnitFrame.castBar.Icon:SetPoint("BOTTOMLEFT", nameplate.UnitFrame.castBarWrapper, "BOTTOMLEFT", 0, 0)
  nameplate.UnitFrame.castBar.Icon:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBar, "TOPLEFT", -0.5, 0)

  nameplate.UnitFrame.castBar.icon_backdrop:ClearAllPoints()
  nameplate.UnitFrame.castBar.icon_backdrop:SetPoint("BOTTOMLEFT", nameplate.UnitFrame.castBar.Icon, -1, -1)
  nameplate.UnitFrame.castBar.icon_backdrop:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBar.Icon, 1, 1)

  nameplate.UnitFrame.castBar.Spark:SetSize(15, nameplate.UnitFrame.castBar:GetHeight() * 1.6)

  nameplate.UnitFrame.healthBar.absorb:SetSize(16, nameplate.UnitFrame.healthBar:GetHeight())
  nameplate.UnitFrame.healthBar.absorb.over_absorb_texture:SetSize(12, nameplate.UnitFrame.healthBar.absorb:GetHeight())
end

local function SetNameplatePlayerDebuffs(nameplate, unit)
  local db = GetDB()
  if unit and nameplate.UnitFrame then
    local nameplate_player_debuffs = nameplate.UnitFrame.healthBar.player_debuffs
    if not nameplate_player_debuffs then return end
    local player_debuff_frames = { nameplate_player_debuffs:GetChildren() }

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      for _, player_debuff in ipairs(player_debuff_frames) do
        player_debuff.current_debuff = nil
        player_debuff.cooldown_started = -1
        player_debuff.cooldown_duration = -1
        player_debuff.aura_count = -1

        player_debuff.aura_count_text:SetText("")

        player_debuff:Hide()
        player_debuff.cooldown:Hide()
      end

      return
    end

    for _, player_debuff in ipairs(player_debuff_frames) do
      if player_debuff.current_debuff and player_debuff.current_debuff.name and
        (not FindAuraByName(player_debuff.current_debuff.name, unit, "HARMFUL") or
        (player_debuff.cooldown_duration - (GetTime() - player_debuff.cooldown_started)) < 0) then
        player_debuff.current_debuff = nil
        player_debuff.cooldown_started = -1
        player_debuff.cooldown_duration = -1
        player_debuff.aura_count = -1

        player_debuff.aura_count_text:SetText("")

        player_debuff:Hide()
        player_debuff.cooldown:Hide()
      end
    end

    if not db.enemy_nameplate_player_debuffs then return end

    for i = 1, 40 do
      local name, icon, debuff_aura_count, _, debuff_duration,
        debuff_expiration_time, unit_caster, _, _, debuff_spell_id = GetUnitAuraByIndex(unit, i, "HARMFUL")
      if not debuff_duration then debuff_duration = 0 end

      if name then
        local player_debuff = GetFormattedPlayerDebuff(name)

        if player_debuff and player_debuff.track_spell_id and debuff_spell_id
          and not player_debuff.track_spell_id[debuff_spell_id] then
          player_debuff = nil
        end

        if player_debuff and unit_caster and debuff_expiration_time and (
          SafeUnitIsUnit(unit_caster, "player")
          or SafeUnitIsUnit(unit_caster, "pet")
          or player_debuff.totem_debuff
        ) then
          local debuff_frame = nil

          for _, player_debuff_frame in ipairs(player_debuff_frames) do
            if player_debuff_frame.current_debuff then
              if player_debuff.name == player_debuff_frame.current_debuff.name then
                debuff_frame = player_debuff_frame
                break
              end
            end
          end

          if not debuff_frame then
            for _, player_debuff_frame in ipairs(player_debuff_frames) do
              if not player_debuff_frame.current_debuff then
                debuff_frame = player_debuff_frame
                break
              end
            end
          end

          if not debuff_frame then
            for _, player_debuff_frame in ipairs(player_debuff_frames) do
              if player_debuff_frame.current_debuff then
                if (debuff_expiration_time - GetTime())
                  > (player_debuff_frame.cooldown_duration - (GetTime() - player_debuff_frame.cooldown_started)) then
                  debuff_frame = player_debuff_frame
                  break
                end
              end
            end
          end

          if debuff_frame then
            if debuff_frame.current_debuff and player_debuff.name == debuff_frame.current_debuff.name then
              if debuff_aura_count and debuff_aura_count > 1 then
                if debuff_aura_count ~= debuff_frame.aura_count then
                  debuff_frame.aura_count = debuff_aura_count
                  debuff_frame.aura_count_text:SetText(debuff_aura_count)
                end
              else
                debuff_frame.aura_count = -1
                debuff_frame.aura_count_text:SetText("")
              end

              if (debuff_expiration_time - GetTime())
                > (debuff_frame.cooldown_duration - (GetTime() - debuff_frame.cooldown_started)) then
                debuff_frame.cooldown_started = GetTime()
                  - (debuff_duration - (debuff_expiration_time - GetTime()))
                debuff_frame.cooldown_duration = debuff_duration
                debuff_frame.cooldown:SetCooldown(debuff_frame.cooldown_started, debuff_frame.cooldown_duration)
              end
            else
              debuff_frame.current_debuff = player_debuff
              debuff_frame.cooldown_started = GetTime()
                - (debuff_duration - (debuff_expiration_time - GetTime()))
              debuff_frame.cooldown_duration = debuff_duration
              debuff_frame:Show()

              if icon ~= player_debuff.texture then
                debuff_frame.texture:SetTexture(icon)
              else
                debuff_frame.texture:SetTexture(player_debuff.texture)
              end

              if debuff_aura_count and debuff_aura_count > 1 then
                debuff_frame.aura_count = debuff_aura_count
                debuff_frame.aura_count_text:SetText(debuff_aura_count)
              else
                debuff_frame.aura_count = -1
                debuff_frame.aura_count_text:SetText("")
              end

              debuff_frame.cooldown:SetCooldown(debuff_frame.cooldown_started, debuff_frame.cooldown_duration)
              debuff_frame.cooldown:Show()
            end
          end
        elseif player_debuff and unit_caster
          and not SafeUnitIsUnit(unit_caster, "player")
          and not SafeUnitIsUnit(unit_caster, "pet") then
          for _, player_debuff_frame in ipairs(player_debuff_frames) do
            if player_debuff_frame.current_debuff then
              if player_debuff.single_debuff and player_debuff.name == player_debuff_frame.current_debuff.name then
                player_debuff_frame.current_debuff = nil
                player_debuff_frame.cooldown_started = -1
                player_debuff_frame.cooldown_duration = -1
                player_debuff_frame.aura_count = -1

                player_debuff_frame.aura_count_text:SetText("")

                player_debuff_frame:Hide()
                player_debuff_frame.cooldown:Hide()

                break
              end
            end
          end
        end
      else
        break
      end
    end

    local x = 0
    for _, player_debuff in ipairs(player_debuff_frames) do
      if player_debuff.current_debuff then
        player_debuff:SetPoint("BOTTOMLEFT", x, 0)
        x = x + player_debuff:GetWidth() + (db.enemy_nameplate_player_debuffs_padding or 4)
      end
    end
  end
end

local function SetNameplateUnitDebuff(nameplate, unit)
  local db = GetDB()
  if unit and nameplate.UnitFrame then
    local nameplate_debuff = nameplate.UnitFrame.healthBar.unit_debuff
    if not nameplate_debuff then return end

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      if nameplate.nameplate_events then
        nameplate.nameplate_events:UnregisterEvent("UNIT_AURA")
      end

      nameplate_debuff.current_debuff = nil
      nameplate_debuff.cooldown_started = -1
      nameplate_debuff.cooldown_duration = -1
      nameplate_debuff.filter = nil

      nameplate_debuff:Hide()
      nameplate_debuff.cooldown:Hide()

      return
    end

    if nameplate_debuff.current_debuff and nameplate_debuff.current_debuff.name
      and not nameplate_debuff.current_debuff.interrupt and
      (not FindAuraByName(nameplate_debuff.current_debuff.name, unit, nameplate_debuff.filter) or
      (nameplate_debuff.cooldown_duration - (GetTime() - nameplate_debuff.cooldown_started)) < 0) then
      nameplate_debuff.current_debuff = nil
      nameplate_debuff.cooldown_started = -1
      nameplate_debuff.cooldown_duration = -1
      nameplate_debuff.filter = nil

      nameplate_debuff:Hide()
      nameplate_debuff.cooldown:Hide()
    end

    if not db.enemy_nameplate_debuff then return end

    if db.useSpellIDAuraLookup then
      local trackedDebuff, auraData = FindPriorityTrackedDebuffAura(unit)
      if trackedDebuff and auraData then
        local debuff_duration = tonumber(auraData.duration) or 0
        local debuff_expiration_time = tonumber(auraData.expirationTime) or 0
        local icon = auraData.icon
        local now = GetTime()
        local cooldownStarted = now
        if debuff_expiration_time > 0 then
          cooldownStarted = now - (debuff_duration - (debuff_expiration_time - now))
        end

        nameplate_debuff.current_debuff = trackedDebuff
        nameplate_debuff.cooldown_started = cooldownStarted
        nameplate_debuff.cooldown_duration = debuff_duration
        nameplate_debuff.filter = auraData.isHarmful and "HARMFUL" or "HELPFUL"
        nameplate_debuff:Show()

        if icon ~= trackedDebuff.texture then
          nameplate_debuff.texture:SetTexture(icon)
        else
          nameplate_debuff.texture:SetTexture(trackedDebuff.texture)
        end

        nameplate_debuff.cooldown:SetCooldown(
          nameplate_debuff.cooldown_started,
          nameplate_debuff.cooldown_duration
        )
        nameplate_debuff.cooldown:Show()
        return
      end
    end

    for _, aura_type in pairs({ "HELPFUL", "HARMFUL" }) do
      for i = 1, 40 do
        local name, icon, _, _, debuff_duration, debuff_expiration_time,
          _, _, _, debuff_spell_id = GetUnitAuraByIndex(unit, i, aura_type)
        if not debuff_duration then debuff_duration = 0 end

        if name then
          local debuff = GetFormattedDebuff(name)

          if debuff and debuff.track_spell_id and debuff_spell_id
            and not debuff.track_spell_id[debuff_spell_id] then
            debuff = nil
          end

          if debuff and debuff_expiration_time then
            local show_debuff = false

            if nameplate_debuff.current_debuff then
              if debuff.priority > nameplate_debuff.current_debuff.priority
                or (debuff.priority == nameplate_debuff.current_debuff.priority
                and (debuff_expiration_time - GetTime())
                > (nameplate_debuff.cooldown_duration - (GetTime() - nameplate_debuff.cooldown_started))) then
                show_debuff = true
              end
            else
              show_debuff = true
            end

            if show_debuff then
              nameplate_debuff.current_debuff = debuff
              nameplate_debuff.cooldown_started = GetTime()
                - (debuff_duration - (debuff_expiration_time - GetTime()))
              nameplate_debuff.cooldown_duration = debuff_duration
              nameplate_debuff.filter = aura_type
              nameplate_debuff:Show()

              if icon ~= debuff.texture then
                nameplate_debuff.texture:SetTexture(icon)
              else
                nameplate_debuff.texture:SetTexture(debuff.texture)
              end

              nameplate_debuff.cooldown:SetCooldown(
                nameplate_debuff.cooldown_started,
                nameplate_debuff.cooldown_duration
              )
              nameplate_debuff.cooldown:Show()
            end
          end
        else
          break
        end
      end
    end
  end
end

H.SetNameplateHealthBarText = SetNameplateHealthBarText
H.SetNameplateHealthBarColor = SetNameplateHealthBarColor
H.SetNameplateAbsorb = SetNameplateAbsorb
H.SetNameplateCastBar = SetNameplateCastBar
H.SetNameplateSize = SetNameplateSize
H.SetNameplatePlayerDebuffs = SetNameplatePlayerDebuffs
H.SetNameplateUnitDebuff = SetNameplateUnitDebuff
