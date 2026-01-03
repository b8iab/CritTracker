-- CritTracker for Turtle WoW (Vanilla 1.18)
-- Version 1.3 - Hit rating completo + stats extra

-- ============================================================
-- SAVED VARIABLES Y DEFAULTS
-- ============================================================
CritTrackerDB = CritTrackerDB or {}

local defaults = {
    locked = false,
    showWidget = true,
    pos = {x = 0, y = -200},
    globalMax = {damage = 0, spell = "", level = 0, target = "", date = ""},
    byLevel = {},
    bySpell = {},
    sessionMax = {damage = 0, spell = "", target = ""},
    announceNew = true,
    -- Stats para porcentaje de crit
    totalHits = 0,
    totalCrits = 0,
    sessionHits = 0,
    sessionCrits = 0,
    -- Stats para hit rating (melee) - EXPANDIDO
    totalMeleeSwings = 0,
    totalMeleeMisses = 0,
    totalMeleeDodges = 0,
    totalMeleeParries = 0,
    totalMeleeBlocks = 0,
    sessionMeleeSwings = 0,
    sessionMeleeMisses = 0,
    sessionMeleeDodges = 0,
    sessionMeleeParries = 0,
    sessionMeleeBlocks = 0,
    -- Stats para spell hit
    totalSpellCasts = 0,
    totalSpellResists = 0,
    sessionSpellCasts = 0,
    sessionSpellResists = 0,
    -- Saltos
    totalJumps = 0,
    sessionJumps = 0,
    -- Daño total
    totalDamage = 0,
    sessionDamage = 0,
    -- Kills
    totalKills = 0,
    sessionKills = 0,
    -- Critter kills (separado)
    totalCritterKills = 0,
    sessionCritterKills = 0,
    -- Overkill
    totalOverkill = 0,
    sessionOverkill = 0,
    -- Racha de crits
    bestCritStreak = 0,
    sessionBestCritStreak = 0,
    currentCritStreak = 0,
    -- Tiempo en combate (segundos)
    totalCombatTime = 0,
    sessionCombatTime = 0,
}

-- ============================================================
-- VARIABLES LOCALES
-- ============================================================
local playerLevel = 1
local DEBUG = false
local inCombat = false
local combatStartTime = 0
local lastKillTarget = ""
local lastKillTime = 0

-- Variables para DPS de combate actual
local combatDamage = 0
local combatDuration = 0
local lastCombatEndTime = 0
local COMBAT_RESET_DELAY = 15 -- Segundos sin combate para resetear

-- ============================================================
-- FUNCIONES AUXILIARES
-- ============================================================
local function InitDB()
    for k, v in pairs(defaults) do
        if CritTrackerDB[k] == nil then
            if type(v) == "table" then
                CritTrackerDB[k] = {}
                for k2, v2 in pairs(v) do
                    CritTrackerDB[k][k2] = v2
                end
            else
                CritTrackerDB[k] = v
            end
        end
    end
end

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local function FormatTime(seconds)
    if seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds/3600), math.floor(math.mod(seconds, 3600)/60))
    elseif seconds >= 60 then
        return string.format("%dm %ds", math.floor(seconds/60), math.mod(seconds, 60))
    end
    return string.format("%ds", seconds)
end

local function GetDate()
    return date("%d/%m/%y")
end

local function GetCritPercent(crits, total)
    if total == 0 then return 0 end
    return (crits / total) * 100
end

local function GetHitPercent(swings, misses, dodges, parries, blocks)
    if swings == 0 then return 100 end
    local avoided = (misses or 0) + (dodges or 0) + (parries or 0) + (blocks or 0)
    return ((swings - avoided) / swings) * 100
end

local function GetSpellHitPercent(casts, resists)
    if casts == 0 then return 100 end
    return ((casts - resists) / casts) * 100
end

local function DebugMsg(msg)
    if DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF00FF[CT Debug]|r " .. msg)
    end
end

-- ============================================================
-- WIDGET VISUAL (EXPANDIDO)
-- ============================================================
local Widget = CreateFrame("Button", "CritTrackerWidget", UIParent)
Widget:SetWidth(175)
Widget:SetHeight(120)
Widget:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
Widget:SetMovable(true)
Widget:EnableMouse(true)
Widget:SetClampedToScreen(true)
Widget:RegisterForClicks("LeftButtonUp", "RightButtonUp")

Widget:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left = 2, right = 2, top = 2, bottom = 2}
})
Widget:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
Widget:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

-- Titulo
local widgetTitle = Widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
widgetTitle:SetPoint("TOPLEFT", Widget, "TOPLEFT", 8, -5)
widgetTitle:SetText("|cffFF4444CritTracker|r")

-- Icono de candado
local lockIcon = Widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockIcon:SetPoint("TOPRIGHT", Widget, "TOPRIGHT", -5, -5)

-- Texto de sesion
local sessionText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sessionText:SetPoint("TOPLEFT", widgetTitle, "BOTTOMLEFT", 0, -5)
sessionText:SetJustifyH("LEFT")
sessionText:SetText("Sesion: --")

-- Texto de global
local globalText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
globalText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -4)
globalText:SetJustifyH("LEFT")
globalText:SetText("Global: --")

-- Texto de nivel
local levelText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
levelText:SetPoint("TOPLEFT", globalText, "BOTTOMLEFT", 0, -4)
levelText:SetJustifyH("LEFT")
levelText:SetTextColor(0.7, 0.7, 0.7)
levelText:SetText("Nivel: --")

-- Texto de porcentaje crit
local percentText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
percentText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -4)
percentText:SetJustifyH("LEFT")
percentText:SetTextColor(1, 0.8, 0)
percentText:SetText("Crit%: --")

-- Texto de porcentaje hit
local hitText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hitText:SetPoint("TOPLEFT", percentText, "BOTTOMLEFT", 0, -4)
hitText:SetJustifyH("LEFT")
hitText:SetTextColor(0.5, 0.8, 1)
hitText:SetText("Hit%: --")

-- Texto de daño y DPS de combate
local damageText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
damageText:SetPoint("TOPLEFT", hitText, "BOTTOMLEFT", 0, -4)
damageText:SetJustifyH("LEFT")
damageText:SetTextColor(1, 0.5, 0.5)
damageText:SetText("Dmg: -- | DPS: --")

-- Texto de kills
local extraText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
extraText:SetPoint("TOPLEFT", damageText, "BOTTOMLEFT", 0, -4)
extraText:SetJustifyH("LEFT")
extraText:SetTextColor(0.7, 1, 0.7)
extraText:SetText("Kills: --")

-- ============================================================
-- FUNCIONES DE UI
-- ============================================================
local function UpdateLockIcon()
    if CritTrackerDB.locked then
        lockIcon:SetText("|cffFF0000[X]|r")
    else
        lockIcon:SetText("|cff00FF00[O]|r")
    end
end

local function UpdateWidget()
    -- Sesion
    if CritTrackerDB.sessionMax.damage > 0 then
        sessionText:SetText("Sesion: |cffFFFF00" .. FormatNumber(CritTrackerDB.sessionMax.damage) .. "|r")
    else
        sessionText:SetText("Sesion: --")
    end
    
    -- Global
    if CritTrackerDB.globalMax.damage > 0 then
        globalText:SetText("Global: |cffFF4444" .. FormatNumber(CritTrackerDB.globalMax.damage) .. "|r")
    else
        globalText:SetText("Global: --")
    end
    
    -- Nivel actual
    local lvlData = CritTrackerDB.byLevel[playerLevel]
    if lvlData and lvlData.damage > 0 then
        levelText:SetText("Lvl " .. playerLevel .. ": |cff88FF88" .. FormatNumber(lvlData.damage) .. "|r")
    else
        levelText:SetText("Lvl " .. playerLevel .. ": --")
    end
    
    -- Porcentaje de critico (sesion)
    local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
    local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
    
    if CritTrackerDB.sessionHits > 0 then
        percentText:SetText(string.format("Crit%%: |cffFFCC00%.1f%%|r (%.1f%%)", sessionPct, totalPct))
    else
        percentText:SetText("Crit%: --")
    end
    
    -- Porcentaje de hit (melee) - ACTUALIZADO
    local sessionHitPct = GetHitPercent(
        CritTrackerDB.sessionMeleeSwings, 
        CritTrackerDB.sessionMeleeMisses,
        CritTrackerDB.sessionMeleeDodges,
        CritTrackerDB.sessionMeleeParries,
        CritTrackerDB.sessionMeleeBlocks
    )
    
    if CritTrackerDB.sessionMeleeSwings > 0 then
        hitText:SetText(string.format("Hit%%: |cff88CCFF%.1f%%|r", sessionHitPct))
    else
        hitText:SetText("Hit%: --")
    end
    
    -- Daño y DPS del combate actual
    if combatDamage > 0 then
        local dps = 0
        local duration = combatDuration
        
        -- Si estamos en combate, calcular duración actual
        if inCombat and combatStartTime > 0 then
            duration = GetTime() - combatStartTime
        end
        
        if duration > 0 then
            dps = combatDamage / duration
        end
        
        damageText:SetText("Dmg: |cffFF8888" .. FormatNumber(combatDamage) .. "|r | DPS: |cffFFAA00" .. string.format("%.1f", dps) .. "|r")
    else
        damageText:SetText("Dmg: -- | DPS: --")
    end
    
    -- Kills
    local critterText = ""
    if CritTrackerDB.sessionCritterKills > 0 then
        critterText = " |cff888888(+" .. CritTrackerDB.sessionCritterKills .. " critters)|r"
    end
    extraText:SetText("Kills: |cff88FF88" .. CritTrackerDB.sessionKills .. "|r" .. critterText)
    
    UpdateLockIcon()
end

local function SavePosition()
    local centerX, centerY = Widget:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    
    if centerX and centerY and parentCenterX and parentCenterY then
        CritTrackerDB.pos.x = centerX - parentCenterX
        CritTrackerDB.pos.y = centerY - parentCenterY
    end
end

local function LoadPosition()
    Widget:ClearAllPoints()
    Widget:SetPoint("CENTER", UIParent, "CENTER", CritTrackerDB.pos.x or 0, CritTrackerDB.pos.y or 0)
end

-- ============================================================
-- DRAG Y CLICK
-- ============================================================
local isDragging = false

Widget:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" and not CritTrackerDB.locked then
        Widget:StartMoving()
        isDragging = true
    end
end)

Widget:SetScript("OnMouseUp", function()
    if isDragging then
        Widget:StopMovingOrSizing()
        isDragging = false
        SavePosition()
    end
end)

Widget:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        CritTrackerDB.locked = not CritTrackerDB.locked
        UpdateLockIcon()
        if CritTrackerDB.locked then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r |cffFF0000Bloqueado|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r |cff00FF00Desbloqueado|r - arrastra para mover")
        end
    elseif arg1 == "LeftButton" and not isDragging then
        -- Mostrar resumen rapido
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker Resumen ===|r")
        if CritTrackerDB.globalMax.damage > 0 then
            local spell = CritTrackerDB.globalMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("Global: |cffFFFF00" .. CritTrackerDB.globalMax.damage .. "|r con " .. spell)
        end
        if combatDamage > 0 then
            local dps = 0
            if combatDuration > 0 then dps = combatDamage / combatDuration end
            DEFAULT_CHAT_FRAME:AddMessage("Combate: |cffFF8888" .. FormatNumber(combatDamage) .. "|r dmg | |cffFFAA00" .. string.format("%.1f", dps) .. "|r DPS")
        end
        DEFAULT_CHAT_FRAME:AddMessage("Sesion - Dmg: |cffFF8888" .. FormatNumber(CritTrackerDB.sessionDamage) .. "|r | Kills: |cff88FF88" .. CritTrackerDB.sessionKills .. "|r")
        if CritTrackerDB.sessionBestCritStreak > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("Mejor racha de crits: |cffFFD700" .. CritTrackerDB.sessionBestCritStreak .. "|r")
        end
    end
end)

-- Tooltip EXPANDIDO
Widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(Widget, "ANCHOR_RIGHT")
    GameTooltip:AddLine("CritTracker v1.3", 1, 0.3, 0.3)
    GameTooltip:AddLine(" ")
    
    -- Global
    if CritTrackerDB.globalMax.damage > 0 then
        local spell = CritTrackerDB.globalMax.spell
        if spell == "" then spell = "Melee" end
        GameTooltip:AddDoubleLine("Record Global:", CritTrackerDB.globalMax.damage, 1, 1, 1, 1, 0.3, 0.3)
        GameTooltip:AddDoubleLine("  Habilidad:", spell, 0.7, 0.7, 0.7, 1, 1, 0.5)
        GameTooltip:AddDoubleLine("  Nivel:", CritTrackerDB.globalMax.level, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end
    
    GameTooltip:AddLine(" ")
    
    -- Crit Stats
    local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
    local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
    GameTooltip:AddLine("|cffFFCC00Crit Stats:|r")
    GameTooltip:AddDoubleLine("  Sesion:", string.format("%.1f%% (%d/%d)", sessionPct, CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Mejor racha:", CritTrackerDB.sessionBestCritStreak .. " (Total: " .. CritTrackerDB.bestCritStreak .. ")", 0.7, 0.7, 0.7, 1, 0.84, 0)
    
    GameTooltip:AddLine(" ")
    
    -- Hit Stats Melee EXPANDIDO
    GameTooltip:AddLine("|cff88CCFFHit Stats (Melee):|r")
    local sSwings = CritTrackerDB.sessionMeleeSwings
    local sMiss = CritTrackerDB.sessionMeleeMisses
    local sDodge = CritTrackerDB.sessionMeleeDodges
    local sParry = CritTrackerDB.sessionMeleeParries
    local sBlock = CritTrackerDB.sessionMeleeBlocks
    local sHitPct = GetHitPercent(sSwings, sMiss, sDodge, sParry, sBlock)
    
    GameTooltip:AddDoubleLine("  Hit%:", string.format("%.1f%% (%d swings)", sHitPct, sSwings), 0.7, 0.7, 0.7, 0.5, 0.8, 1)
    if sMiss > 0 then GameTooltip:AddDoubleLine("    Miss:", sMiss, 0.5, 0.5, 0.5, 1, 0.5, 0.5) end
    if sDodge > 0 then GameTooltip:AddDoubleLine("    Dodge:", sDodge, 0.5, 0.5, 0.5, 1, 0.8, 0.5) end
    if sParry > 0 then GameTooltip:AddDoubleLine("    Parry:", sParry, 0.5, 0.5, 0.5, 1, 0.6, 0.3) end
    if sBlock > 0 then GameTooltip:AddDoubleLine("    Block:", sBlock, 0.5, 0.5, 0.5, 0.7, 0.7, 1) end
    
    -- Spell Hit
    if CritTrackerDB.sessionSpellCasts > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffFF88FFSpell Hit:|r")
        local spellHitPct = GetSpellHitPercent(CritTrackerDB.sessionSpellCasts, CritTrackerDB.sessionSpellResists)
        GameTooltip:AddDoubleLine("  Hit%:", string.format("%.1f%% (%d resists)", spellHitPct, CritTrackerDB.sessionSpellResists), 0.7, 0.7, 0.7, 1, 0.5, 1)
    end
    
    GameTooltip:AddLine(" ")
    
    -- Damage y Kills
    GameTooltip:AddLine("|cffFF8888Damage & Combat:|r")
    if combatDamage > 0 then
        local dps = 0
        if combatDuration > 0 then dps = combatDamage / combatDuration end
        GameTooltip:AddDoubleLine("  Combate actual:", FormatNumber(combatDamage) .. " (" .. string.format("%.1f", dps) .. " DPS)", 0.7, 0.7, 0.7, 1, 0.67, 0)
    end
    GameTooltip:AddDoubleLine("  Dmg Sesion:", FormatNumber(CritTrackerDB.sessionDamage), 0.7, 0.7, 0.7, 1, 0.5, 0.5)
    GameTooltip:AddDoubleLine("  Dmg Total:", FormatNumber(CritTrackerDB.totalDamage), 0.7, 0.7, 0.7, 1, 0.5, 0.5)
    GameTooltip:AddDoubleLine("  Kills:", CritTrackerDB.sessionKills .. " (" .. CritTrackerDB.totalKills .. " total)", 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    if CritTrackerDB.sessionCritterKills > 0 then
        GameTooltip:AddDoubleLine("  Critters:", CritTrackerDB.sessionCritterKills .. " (" .. CritTrackerDB.totalCritterKills .. " total)", 0.7, 0.7, 0.7, 0.5, 0.5, 0.5)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00FF00Click izq:|r Resumen | |cff00FF00Der:|r Lock", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

Widget:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================
-- REGISTRO DE HITS, MISSES, DODGES, etc
-- ============================================================
local function RegisterHit(isCrit, isMelee, damage)
    CritTrackerDB.totalHits = CritTrackerDB.totalHits + 1
    CritTrackerDB.sessionHits = CritTrackerDB.sessionHits + 1
    
    -- Registrar daño
    if damage and damage > 0 then
        CritTrackerDB.totalDamage = CritTrackerDB.totalDamage + damage
        CritTrackerDB.sessionDamage = CritTrackerDB.sessionDamage + damage
        combatDamage = combatDamage + damage -- Daño del combate actual
    end
    
    if isCrit then
        CritTrackerDB.totalCrits = CritTrackerDB.totalCrits + 1
        CritTrackerDB.sessionCrits = CritTrackerDB.sessionCrits + 1
        
        -- Racha de crits
        CritTrackerDB.currentCritStreak = CritTrackerDB.currentCritStreak + 1
        if CritTrackerDB.currentCritStreak > CritTrackerDB.sessionBestCritStreak then
            CritTrackerDB.sessionBestCritStreak = CritTrackerDB.currentCritStreak
        end
        if CritTrackerDB.currentCritStreak > CritTrackerDB.bestCritStreak then
            CritTrackerDB.bestCritStreak = CritTrackerDB.currentCritStreak
            if CritTrackerDB.currentCritStreak >= 3 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r |cffFFD700Racha de " .. CritTrackerDB.currentCritStreak .. " crits!|r")
            end
        end
    else
        -- Romper racha
        CritTrackerDB.currentCritStreak = 0
    end
    
    -- Contar swings melee (hits que conectan)
    if isMelee then
        CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
        CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    else
        -- Spell cast exitoso
        CritTrackerDB.totalSpellCasts = CritTrackerDB.totalSpellCasts + 1
        CritTrackerDB.sessionSpellCasts = CritTrackerDB.sessionSpellCasts + 1
    end
end

local function RegisterMiss()
    CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
    CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    CritTrackerDB.totalMeleeMisses = CritTrackerDB.totalMeleeMisses + 1
    CritTrackerDB.sessionMeleeMisses = CritTrackerDB.sessionMeleeMisses + 1
    CritTrackerDB.currentCritStreak = 0
    DebugMsg("MISS registrado!")
end

local function RegisterDodge()
    CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
    CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    CritTrackerDB.totalMeleeDodges = CritTrackerDB.totalMeleeDodges + 1
    CritTrackerDB.sessionMeleeDodges = CritTrackerDB.sessionMeleeDodges + 1
    CritTrackerDB.currentCritStreak = 0
    DebugMsg("DODGE registrado!")
end

local function RegisterParry()
    CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
    CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    CritTrackerDB.totalMeleeParries = CritTrackerDB.totalMeleeParries + 1
    CritTrackerDB.sessionMeleeParries = CritTrackerDB.sessionMeleeParries + 1
    CritTrackerDB.currentCritStreak = 0
    DebugMsg("PARRY registrado!")
end

local function RegisterBlock()
    CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
    CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    CritTrackerDB.totalMeleeBlocks = CritTrackerDB.totalMeleeBlocks + 1
    CritTrackerDB.sessionMeleeBlocks = CritTrackerDB.sessionMeleeBlocks + 1
    DebugMsg("BLOCK registrado!")
end

local function RegisterSpellResist()
    CritTrackerDB.totalSpellCasts = CritTrackerDB.totalSpellCasts + 1
    CritTrackerDB.sessionSpellCasts = CritTrackerDB.sessionSpellCasts + 1
    CritTrackerDB.totalSpellResists = CritTrackerDB.totalSpellResists + 1
    CritTrackerDB.sessionSpellResists = CritTrackerDB.sessionSpellResists + 1
    CritTrackerDB.currentCritStreak = 0
    DebugMsg("RESIST registrado!")
end

local function RegisterKill(isCritter)
    if isCritter then
        CritTrackerDB.totalCritterKills = CritTrackerDB.totalCritterKills + 1
        CritTrackerDB.sessionCritterKills = CritTrackerDB.sessionCritterKills + 1
        DebugMsg("CRITTER KILL registrado!")
    else
        CritTrackerDB.totalKills = CritTrackerDB.totalKills + 1
        CritTrackerDB.sessionKills = CritTrackerDB.sessionKills + 1
        DebugMsg("KILL registrado!")
    end
end

local function RegisterOverkill(amount)
    if amount and amount > 0 then
        CritTrackerDB.totalOverkill = CritTrackerDB.totalOverkill + amount
        CritTrackerDB.sessionOverkill = CritTrackerDB.sessionOverkill + amount
        DebugMsg("OVERKILL: " .. amount)
    end
end

local function RegisterJump()
    CritTrackerDB.totalJumps = CritTrackerDB.totalJumps + 1
    CritTrackerDB.sessionJumps = CritTrackerDB.sessionJumps + 1
    DebugMsg("JUMP registrado! Total sesion: " .. CritTrackerDB.sessionJumps)
end

-- ============================================================
-- PROCESAMIENTO DE CRITICOS
-- ============================================================
local function ProcessCrit(damage, spellName, target)
    if not damage or damage <= 0 then return end
    
    local isNewGlobal = false
    local isNewLevel = false
    local isNewSpell = false
    
    -- Session max
    if damage > CritTrackerDB.sessionMax.damage then
        CritTrackerDB.sessionMax.damage = damage
        CritTrackerDB.sessionMax.spell = spellName or ""
        CritTrackerDB.sessionMax.target = target or "Unknown"
    end
    
    -- Global max
    if damage > CritTrackerDB.globalMax.damage then
        CritTrackerDB.globalMax.damage = damage
        CritTrackerDB.globalMax.spell = spellName or ""
        CritTrackerDB.globalMax.level = playerLevel
        CritTrackerDB.globalMax.target = target or "Unknown"
        CritTrackerDB.globalMax.date = GetDate()
        isNewGlobal = true
    end
    
    -- By level
    if not CritTrackerDB.byLevel[playerLevel] then
        CritTrackerDB.byLevel[playerLevel] = {damage = 0, spell = "", target = "", date = ""}
    end
    if damage > CritTrackerDB.byLevel[playerLevel].damage then
        CritTrackerDB.byLevel[playerLevel].damage = damage
        CritTrackerDB.byLevel[playerLevel].spell = spellName or ""
        CritTrackerDB.byLevel[playerLevel].target = target or "Unknown"
        CritTrackerDB.byLevel[playerLevel].date = GetDate()
        isNewLevel = true
    end
    
    -- By spell
    local spellKey = spellName or "Melee"
    if not CritTrackerDB.bySpell[spellKey] then
        CritTrackerDB.bySpell[spellKey] = {damage = 0, level = 0, target = "", date = ""}
    end
    if damage > CritTrackerDB.bySpell[spellKey].damage then
        CritTrackerDB.bySpell[spellKey].damage = damage
        CritTrackerDB.bySpell[spellKey].level = playerLevel
        CritTrackerDB.bySpell[spellKey].target = target or "Unknown"
        CritTrackerDB.bySpell[spellKey].date = GetDate()
        isNewSpell = true
    end
    
    -- Anunciar nuevos records
    if CritTrackerDB.announceNew then
        local displaySpell = spellName or "Melee"
        if isNewGlobal then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r |cffFFD700NUEVO RECORD GLOBAL!|r " .. damage .. " con " .. displaySpell .. "!")
            PlaySoundFile("Sound\\interface\\iLevelUp.wav")
        elseif isNewLevel then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r |cff00FF00Nuevo record nivel " .. playerLevel .. "!|r " .. damage .. " con " .. displaySpell)
            PlaySoundFile("Sound\\interface\\iQuestComplete.wav")
        elseif isNewSpell then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Nuevo max con |cffFFFF00" .. displaySpell .. "|r: " .. damage)
        end
    end
    
    UpdateWidget()
end

-- ============================================================
-- PARSEO DE MENSAJES DE COMBATE (ESPAÑOL + INGLES)
-- ============================================================
local function ParseCombatMessage(msg)
    local damage, spell, target
    
    DebugMsg("Mensaje: " .. msg)
    
    local isCrit = false
    if string.find(msg, "tico") or string.find(msg, "ticas") or string.find(msg, "crit") then
        isCrit = true
        DebugMsg("Detectado como CRITICO")
    end
    
    -- ESPAÑOL - CRITICOS DE SPELL
    _, _, spell, target, damage = string.find(msg, "Tu (.+) hace un .+ a (.+) por (%d+)")
    if damage and isCrit then
        return tonumber(damage), spell, target, true, false
    end
    
    -- ESPAÑOL - CRITICOS DE MELEE
    if isCrit and not spell then
        _, _, target, damage = string.find(msg, "^Cr.+as a (.+) por (%d+)")
        if damage then
            return tonumber(damage), nil, target, true, true
        end
    end
    
    -- ESPAÑOL - HITS NORMALES
    _, _, target, damage = string.find(msg, "Golpeas a (.+) por (%d+)")
    if damage then
        return tonumber(damage), nil, target, false, true
    end
    
    _, _, spell, target, damage = string.find(msg, "Tu (.+) golpea a (.+) por (%d+)")
    if damage then
        return tonumber(damage), spell, target, false, false
    end
    
    -- INGLES
    _, _, target, damage = string.find(msg, "You crit (.+) for (%d+)")
    if damage then
        return tonumber(damage), nil, target, true, true
    end
    
    _, _, spell, target, damage = string.find(msg, "Your (.+) crits (.+) for (%d+)")
    if damage then
        return tonumber(damage), spell, target, true, false
    end
    
    _, _, target, damage = string.find(msg, "You hit (.+) for (%d+)")
    if damage then
        return tonumber(damage), nil, target, false, true
    end
    
    _, _, spell, target, damage = string.find(msg, "Your (.+) hits (.+) for (%d+)")
    if damage then
        return tonumber(damage), spell, target, false, false
    end
    
    return nil
end

-- ============================================================
-- PARSEO DE MENSAJES DE MISS/DODGE/PARRY/BLOCK/RESIST
-- ============================================================
local function ParseMissMessage(msg)
    DebugMsg("MISS/EVADE parse: " .. msg)
    
    -- Verificar que sea TU ataque (no el del enemigo)
    -- Formato: "Atacas. X esquiva/para." o "Fallas a X"
    
    -- MISS - Español: "Fallas" o "Tu ataque falla"
    if string.find(msg, "^Fallas") or string.find(msg, "Tu ataque falla") then
        return "miss"
    end
    
    -- MISS - Inglés
    if string.find(msg, "^You miss") or string.find(msg, "Your attack miss") then
        return "miss"
    end
    
    -- DODGE - Español: "Atacas. X esquiva." (TU atacas, enemigo esquiva)
    if string.find(msg, "^Atacas") and string.find(msg, "esquiva") then
        return "dodge"
    end
    
    -- DODGE - Inglés
    if string.find(msg, "^You attack") and string.find(msg, "dodge") then
        return "dodge"
    end
    
    -- PARRY - Español: "Atacas. X para." (TU atacas, enemigo para)
    if string.find(msg, "^Atacas") and string.find(msg, " para%.") then
        return "parry"
    end
    
    -- PARRY - Inglés
    if string.find(msg, "^You attack") and string.find(msg, "parr") then
        return "parry"
    end
    
    -- BLOCK - Español: "Atacas. X bloquea."
    if string.find(msg, "^Atacas") and string.find(msg, "bloquea") then
        return "block"
    end
    
    -- BLOCK - Inglés
    if string.find(msg, "^You attack") and string.find(msg, "block") then
        return "block"
    end
    
    return nil
end

local function ParseSpellMissMessage(msg)
    -- Solo buscar resists completos, no hits parciales
    DebugMsg("Spell resist check: " .. msg)
    
    -- RESIST COMPLETO - Español: "X resiste completamente" o "resiste tu"
    if string.find(msg, "resiste completamente") or string.find(msg, "fully resist") then
        return "resist"
    end
    
    -- IMMUNE - Español e Inglés
    if string.find(msg, "inmune") or string.find(msg, "immune") then
        return "resist"
    end
    
    return nil
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_LEVEL_UP")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Eventos adicionales para detectar miss/dodge/parry
EventFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_MISSES")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")


-- Frame para actualizar DPS en tiempo real y resetear combate
local UpdateFrame = CreateFrame("Frame")
local updateTimer = 0
local resetCheckTimer = 0

UpdateFrame:SetScript("OnUpdate", function()
    -- Actualizar cada 0.5 segundos durante combate para mostrar DPS en tiempo real
    updateTimer = updateTimer + arg1
    if updateTimer >= 0.5 then
        updateTimer = 0
        if inCombat then
            UpdateWidget()
        end
    end
    
    -- Verificar reset cada 1 segundo
    resetCheckTimer = resetCheckTimer + arg1
    if resetCheckTimer >= 1 then
        resetCheckTimer = 0
        -- Si no estamos en combate y pasó el tiempo de reset
        if not inCombat and lastCombatEndTime > 0 and combatDamage > 0 then
            local timeSinceCombat = GetTime() - lastCombatEndTime
            if timeSinceCombat > COMBAT_RESET_DELAY then
                combatDamage = 0
                combatDuration = 0
                lastCombatEndTime = 0
                DebugMsg("Combate reseteado por inactividad")
                UpdateWidget()
            end
        end
    end
end)

EventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
        InitDB()
        playerLevel = UnitLevel("player")
        
        -- Reset session stats
        CritTrackerDB.sessionMax = {damage = 0, spell = "", target = ""}
        CritTrackerDB.sessionHits = 0
        CritTrackerDB.sessionCrits = 0
        CritTrackerDB.sessionMeleeSwings = 0
        CritTrackerDB.sessionMeleeMisses = 0
        CritTrackerDB.sessionMeleeDodges = 0
        CritTrackerDB.sessionMeleeParries = 0
        CritTrackerDB.sessionMeleeBlocks = 0
        CritTrackerDB.sessionSpellCasts = 0
        CritTrackerDB.sessionSpellResists = 0
        CritTrackerDB.sessionDamage = 0
        CritTrackerDB.sessionKills = 0
        CritTrackerDB.sessionCritterKills = 0
        CritTrackerDB.sessionOverkill = 0
        CritTrackerDB.sessionBestCritStreak = 0
        CritTrackerDB.currentCritStreak = 0
        CritTrackerDB.sessionCombatTime = 0
        
        LoadPosition()
        UpdateWidget()
        
        if CritTrackerDB.showWidget then
            Widget:Show()
        else
            Widget:Hide()
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444CritTracker v1.3|r cargado! |cffFFFF00/crit|r para opciones")
        
    elseif event == "PLAYER_LEVEL_UP" then
        playerLevel = UnitLevel("player")
        UpdateWidget()
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entramos en combate
        local currentTime = GetTime()
        
        -- Si pasó mucho tiempo desde el último combate, resetear contadores
        if lastCombatEndTime > 0 and (currentTime - lastCombatEndTime) > COMBAT_RESET_DELAY then
            combatDamage = 0
            combatDuration = 0
            DebugMsg("Combate reseteado (timeout)")
        end
        
        inCombat = true
        combatStartTime = currentTime
        DebugMsg("COMBAT START")
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Salimos de combate
        if inCombat and combatStartTime > 0 then
            local thisCombatDuration = GetTime() - combatStartTime
            combatDuration = combatDuration + thisCombatDuration
            CritTrackerDB.sessionCombatTime = CritTrackerDB.sessionCombatTime + math.floor(thisCombatDuration)
            CritTrackerDB.totalCombatTime = CritTrackerDB.totalCombatTime + math.floor(thisCombatDuration)
            DebugMsg("COMBAT END - Duration: " .. thisCombatDuration .. " | Total Dmg: " .. combatDamage .. " | DPS: " .. string.format("%.1f", combatDamage / combatDuration))
        end
        inCombat = false
        combatStartTime = 0
        lastCombatEndTime = GetTime()
        UpdateWidget()
        
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        -- Detectar kills - SOLO cuando TU matas
        DebugMsg("DEATH EVENT: " .. (arg1 or "nil"))
        
        if arg1 then
            local target = nil
            
            -- Español: "Has matado a X!" - SOLO este es cuando TU matas
            _, _, target = string.find(arg1, "Has matado a (.+)!")
            
            -- Inglés: "You have slain X!" - SOLO este es cuando TU matas
            if not target then
                _, _, target = string.find(arg1, "You have slain (.+)!")
            end
            
            -- IGNORAR "X muere." y "X dies." porque son muertes genericas
            -- (pueden ser mobs matando critters, etc)
            
            if target then
                target = string.gsub(target, "^%s+", "") -- trim inicio
                target = string.gsub(target, "%s+$", "") -- trim final
                
                -- Evitar contar doble el mismo kill
                local currentTime = GetTime()
                if target == lastKillTarget and (currentTime - lastKillTime) < 1 then
                    DebugMsg("Kill duplicado ignorado: " .. target)
                    return
                end
                
                lastKillTarget = target
                lastKillTime = currentTime
                
                DebugMsg("Kill target: [" .. target .. "]")
                
                -- Lista de critters - nombres EXACTOS solamente
                local critterExact = {
                    ["rabbit"] = true, ["squirrel"] = true, ["rat"] = true, 
                    ["mouse"] = true, ["frog"] = true, ["toad"] = true,
                    ["roach"] = true, ["cockroach"] = true, ["chicken"] = true, 
                    ["deer"] = true, ["gazelle"] = true, ["parrot"] = true, 
                    ["prairie dog"] = true, ["maggot"] = true, ["hare"] = true, 
                    ["adder"] = true, ["small frog"] = true, ["swine"] = true, 
                    ["ram"] = true, ["larva"] = true, ["skunk"] = true,
                    ["shore crab"] = true, ["snake"] = true, ["beetle"] = true, 
                    ["cow"] = true, ["bull"] = true, ["sheep"] = true, 
                    ["pig"] = true, ["cat"] = true, ["dog"] = true, 
                    ["black rat"] = true, ["crab"] = true, ["prairie chicken"] = true,
                    ["scorpid"] = true, ["armadillo"] = true,
                    -- Español
                    ["conejo"] = true, ["ardilla"] = true, ["rata"] = true, 
                    ["raton"] = true, ["rana"] = true, ["sapo"] = true,
                    ["cucaracha"] = true, ["pollo"] = true, ["gallina"] = true, 
                    ["ciervo"] = true, ["cervato"] = true, ["gacela"] = true, 
                    ["loro"] = true, ["gusano"] = true, ["liebre"] = true, 
                    ["serpiente"] = true, ["escarabajo"] = true, ["vaca"] = true, 
                    ["toro"] = true, ["oveja"] = true, ["cerdo"] = true, 
                    ["gato"] = true, ["perro"] = true, ["cangrejo"] = true, 
                    ["mofeta"] = true, ["carnero"] = true
                }
                
                local lowerTarget = string.lower(target)
                local isCritter = critterExact[lowerTarget] or false
                
                if isCritter then
                    DebugMsg("Es CRITTER!")
                else
                    DebugMsg("Es MOB normal!")
                end
                
                RegisterKill(isCritter)
                UpdateWidget()
            else
                DebugMsg("Muerte ignorada (no es tu kill)")
            end
        end
        
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        if arg1 then
            DebugMsg("SELF_MISSES event: " .. arg1)
            local result = ParseMissMessage(arg1)
            if result == "miss" then
                DebugMsg("-> MISS detectado")
                RegisterMiss()
                UpdateWidget()
            elseif result == "dodge" then
                DebugMsg("-> DODGE detectado")
                RegisterDodge()
                UpdateWidget()
            elseif result == "parry" then
                DebugMsg("-> PARRY detectado")
                RegisterParry()
                UpdateWidget()
            elseif result == "block" then
                DebugMsg("-> BLOCK detectado")
                RegisterBlock()
                UpdateWidget()
            else
                DebugMsg("-> No reconocido como miss/evade tuyo")
            end
        end
        
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" then
        -- Cuando criatura falla contra ti (TU esquivas/paras) - NO cuenta para tu hit%
        if arg1 then
            DebugMsg("CREATURE_VS_SELF_MISSES (ignorado): " .. arg1)
        end
        
    elseif event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_MISSES" then
        -- Cuando spell de criatura falla contra ti - NO cuenta para tu hit%
        if arg1 then
            DebugMsg("SPELL_CREATURE_VS_SELF_MISSES (ignorado): " .. arg1)
        end
        
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        if arg1 then
            DebugMsg("Mensaje: " .. arg1)
            
            -- Primero verificar si es resist/inmune (no contiene "por" ni "for" = no hizo daño)
            if not string.find(arg1, " por ") and not string.find(arg1, " for ") then
                local spellResult = ParseSpellMissMessage(arg1)
                if spellResult == "resist" then
                    RegisterSpellResist()
                    UpdateWidget()
                    return
                end
            end
            
            -- Si no es resist, procesar como daño normal
            local damage, spell, target, isCrit, isMelee = ParseCombatMessage(arg1)
            if damage then
                RegisterHit(isCrit, isMelee, damage)
                if isCrit then
                    ProcessCrit(damage, spell, target)
                else
                    UpdateWidget()
                end
            end
        end
        
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or 
           event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
        
        local damage, spell, target, isCrit, isMelee = ParseCombatMessage(arg1)
        if damage then
            RegisterHit(isCrit, isMelee, damage)
            if isCrit then
                ProcessCrit(damage, spell, target)
            else
                UpdateWidget()
            end
        end
    end
end)

-- ============================================================
-- SLASH COMMANDS (EXPANDIDOS)
-- ============================================================
SLASH_CRITTRACKER1 = "/crit"
SLASH_CRITTRACKER2 = "/crittracker"

local confirmClear = false

SlashCmdList["CRITTRACKER"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "" or msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker v1.3 ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit|r - Ver este menu")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit show|hide|lock|r - Widget")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit stats|r - Estadisticas completas")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit percent|r - % de crit")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit hit|r - % de hit melee")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit spellhit|r - % de spell hit")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit damage|r - Daño total")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit kills|r - Kills")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit streak|r - Rachas de crit")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit levels|spells|r - Records")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit reset|clear|r - Reset")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit reset|clear|r - Reset")
        confirmClear = false
        
    elseif msg == "debug" then
        DEBUG = not DEBUG
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Debug: " .. (DEBUG and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))
        
    elseif msg == "show" then
        Widget:Show()
        CritTrackerDB.showWidget = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Widget visible")
        
    elseif msg == "hide" then
        Widget:Hide()
        CritTrackerDB.showWidget = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Widget oculto")
        
    elseif msg == "lock" then
        CritTrackerDB.locked = not CritTrackerDB.locked
        UpdateLockIcon()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r " .. (CritTrackerDB.locked and "|cffFF0000Bloqueado|r" or "|cff00FF00Desbloqueado|r"))
        
    elseif msg == "announce" then
        CritTrackerDB.announceNew = not CritTrackerDB.announceNew
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Anuncios: " .. (CritTrackerDB.announceNew and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))
        
    elseif msg == "stats" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker Stats Completas ===|r")
        if CritTrackerDB.globalMax.damage > 0 then
            local spell = CritTrackerDB.globalMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700Record Global:|r " .. CritTrackerDB.globalMax.damage .. " con " .. spell .. " (Lvl " .. CritTrackerDB.globalMax.level .. ")")
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Sesion:|r Dmg " .. FormatNumber(CritTrackerDB.sessionDamage) .. " | Kills " .. CritTrackerDB.sessionKills)
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888Total:|r Dmg " .. FormatNumber(CritTrackerDB.totalDamage) .. " | Kills " .. CritTrackerDB.totalKills)
        DEFAULT_CHAT_FRAME:AddMessage("Combat time: " .. FormatTime(CritTrackerDB.sessionCombatTime) .. " (sesion) | " .. FormatTime(CritTrackerDB.totalCombatTime) .. " (total)")
        confirmClear = false
        
    elseif msg == "percent" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Porcentaje de Critico ===|r")
        local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
        local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFFF00Sesion:|r %.2f%% (%d/%d)", sessionPct, CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %.2f%% (%d/%d)", totalPct, CritTrackerDB.totalCrits, CritTrackerDB.totalHits))
        DEFAULT_CHAT_FRAME:AddMessage("Mejor racha: |cffFFD700" .. CritTrackerDB.bestCritStreak .. "|r crits seguidos")
        confirmClear = false
        
    elseif msg == "hit" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Porcentaje de Hit (Melee) ===|r")
        local sSwings = CritTrackerDB.sessionMeleeSwings
        local sMiss = CritTrackerDB.sessionMeleeMisses
        local sDodge = CritTrackerDB.sessionMeleeDodges
        local sParry = CritTrackerDB.sessionMeleeParries
        local sBlock = CritTrackerDB.sessionMeleeBlocks
        local sHitPct = GetHitPercent(sSwings, sMiss, sDodge, sParry, sBlock)
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFFF00Sesion:|r %.2f%% hit (%d swings)", sHitPct, sSwings))
        DEFAULT_CHAT_FRAME:AddMessage("  Miss: " .. sMiss .. " | Dodge: " .. sDodge .. " | Parry: " .. sParry .. " | Block: " .. sBlock)
        
        local tSwings = CritTrackerDB.totalMeleeSwings
        local tMiss = CritTrackerDB.totalMeleeMisses
        local tDodge = CritTrackerDB.totalMeleeDodges
        local tParry = CritTrackerDB.totalMeleeParries
        local tBlock = CritTrackerDB.totalMeleeBlocks
        local tHitPct = GetHitPercent(tSwings, tMiss, tDodge, tParry, tBlock)
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %.2f%% hit (%d swings)", tHitPct, tSwings))
        DEFAULT_CHAT_FRAME:AddMessage("  Miss: " .. tMiss .. " | Dodge: " .. tDodge .. " | Parry: " .. tParry .. " | Block: " .. tBlock)
        confirmClear = false
        
    elseif msg == "spellhit" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Porcentaje de Spell Hit ===|r")
        local sPct = GetSpellHitPercent(CritTrackerDB.sessionSpellCasts, CritTrackerDB.sessionSpellResists)
        local tPct = GetSpellHitPercent(CritTrackerDB.totalSpellCasts, CritTrackerDB.totalSpellResists)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFFF00Sesion:|r %.2f%% (%d resists de %d casts)", sPct, CritTrackerDB.sessionSpellResists, CritTrackerDB.sessionSpellCasts))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %.2f%% (%d resists de %d casts)", tPct, CritTrackerDB.totalSpellResists, CritTrackerDB.totalSpellCasts))
        confirmClear = false
        
    elseif msg == "damage" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Damage Stats ===|r")
        if combatDamage > 0 then
            local dps = 0
            if combatDuration > 0 then
                dps = combatDamage / combatDuration
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFAA00Combate actual:|r " .. FormatNumber(combatDamage) .. " dmg | " .. string.format("%.1f", dps) .. " DPS")
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Sesion:|r " .. FormatNumber(CritTrackerDB.sessionDamage) .. " dmg total")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700Total:|r " .. FormatNumber(CritTrackerDB.totalDamage) .. " dmg total")
        confirmClear = false
        
    elseif msg == "kills" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Kill Stats ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Sesion:|r " .. CritTrackerDB.sessionKills .. " kills")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700Total:|r " .. CritTrackerDB.totalKills .. " kills")
        confirmClear = false
        
    elseif msg == "streak" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Crit Streak Stats ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Sesion mejor:|r " .. CritTrackerDB.sessionBestCritStreak .. " crits seguidos")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700Record total:|r " .. CritTrackerDB.bestCritStreak .. " crits seguidos")
        DEFAULT_CHAT_FRAME:AddMessage("Racha actual: " .. CritTrackerDB.currentCritStreak)
        confirmClear = false
        
    elseif msg == "levels" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Records por Nivel ===|r")
        local hasData = false
        for lvl = 1, 60 do
            local data = CritTrackerDB.byLevel[lvl]
            if data and data.damage > 0 then
                local spell = data.spell
                if spell == "" then spell = "Melee" end
                DEFAULT_CHAT_FRAME:AddMessage("  Lvl " .. lvl .. ": |cffFFFF00" .. data.damage .. "|r (" .. spell .. ")")
                hasData = true
            end
        end
        if not hasData then
            DEFAULT_CHAT_FRAME:AddMessage("  No hay datos aun.")
        end
        confirmClear = false
        
    elseif msg == "spells" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Records por Habilidad ===|r")
        local sorted = {}
        for spell, data in pairs(CritTrackerDB.bySpell) do
            table.insert(sorted, {name = spell, damage = data.damage, level = data.level})
        end
        table.sort(sorted, function(a, b) return a.damage > b.damage end)
        
        if table.getn(sorted) > 0 then
            for i, v in ipairs(sorted) do
                local name = v.name
                if name == "" then name = "Melee" end
                DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. ": |cffFFFF00" .. v.damage .. "|r (Lvl " .. v.level .. ")")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  No hay datos aun.")
        end
        confirmClear = false
        
    elseif msg == "reset" then
        CritTrackerDB.pos = {x = 0, y = -200}
        LoadPosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Posicion reseteada")
        confirmClear = false
        
    elseif msg == "clear" then
        if confirmClear then
            -- Reset todo
            for k, v in pairs(defaults) do
                if type(v) == "table" then
                    CritTrackerDB[k] = {}
                    for k2, v2 in pairs(v) do
                        CritTrackerDB[k][k2] = v2
                    end
                else
                    CritTrackerDB[k] = v
                end
            end
            UpdateWidget()
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Todos los datos borrados!")
            confirmClear = false
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000[CritTracker]|r Seguro? Escribe |cffFFFF00/crit clear|r de nuevo para confirmar")
            confirmClear = true
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444[CritTracker]|r Comando desconocido. Usa |cffFFFF00/crit help|r")
        confirmClear = false
    end
end
