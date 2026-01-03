-- CritTracker for Turtle WoW (Vanilla 1.12)
-- Version 1.2 - Soporte español + porcentaje de critico + hit rating

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
    -- Stats para hit rating (melee)
    totalMeleeSwings = 0,
    totalMeleeMisses = 0,
    sessionMeleeSwings = 0,
    sessionMeleeMisses = 0,
}

-- ============================================================
-- VARIABLES LOCALES
-- ============================================================
local playerLevel = 1
local DEBUG = false

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
    if num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local function GetDate()
    return date("%d/%m/%y")
end

local function GetCritPercent(crits, total)
    if total == 0 then return 0 end
    return (crits / total) * 100
end

local function GetHitPercent(swings, misses)
    if swings == 0 then return 100 end
    return ((swings - misses) / swings) * 100
end

local function DebugMsg(msg)
    if DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF00FF[CT Debug]|r " .. msg)
    end
end

-- ============================================================
-- WIDGET VISUAL
-- ============================================================
local Widget = CreateFrame("Button", "CritTrackerWidget", UIParent)
Widget:SetWidth(165)
Widget:SetHeight(82)
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
sessionText:SetPoint("TOPLEFT", widgetTitle, "BOTTOMLEFT", 0, -3)
sessionText:SetJustifyH("LEFT")
sessionText:SetText("Sesion: --")

-- Texto de global
local globalText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
globalText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -2)
globalText:SetJustifyH("LEFT")
globalText:SetText("Global: --")

-- Texto de nivel
local levelText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
levelText:SetPoint("TOPLEFT", globalText, "BOTTOMLEFT", 0, -2)
levelText:SetJustifyH("LEFT")
levelText:SetTextColor(0.7, 0.7, 0.7)
levelText:SetText("Nivel: --")

-- Texto de porcentaje crit
local percentText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
percentText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -2)
percentText:SetJustifyH("LEFT")
percentText:SetTextColor(1, 0.8, 0)
percentText:SetText("Crit%: --")

-- Texto de porcentaje hit
local hitText = Widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hitText:SetPoint("TOPLEFT", percentText, "BOTTOMLEFT", 0, -2)
hitText:SetJustifyH("LEFT")
hitText:SetTextColor(0.5, 0.8, 1)
hitText:SetText("Hit%: --")

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
        percentText:SetText(string.format("Crit%%: |cffFFCC00%.1f%%|r (%.1f%% total)", sessionPct, totalPct))
    else
        percentText:SetText("Crit%: --")
    end
    
    -- Porcentaje de hit (melee)
    local sessionHitPct = GetHitPercent(CritTrackerDB.sessionMeleeSwings, CritTrackerDB.sessionMeleeMisses)
    local totalHitPct = GetHitPercent(CritTrackerDB.totalMeleeSwings, CritTrackerDB.totalMeleeMisses)
    
    if CritTrackerDB.sessionMeleeSwings > 0 then
        hitText:SetText(string.format("Hit%%: |cff88CCFF%.1f%%|r (%.1f%% total)", sessionHitPct, totalHitPct))
    else
        hitText:SetText("Hit%: --")
    end
    
    UpdateLockIcon()
end

local function SavePosition()
    local centerX, centerY = Widget:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    
    if centerX and centerY and parentCenterX and parentCenterY then
        CritTrackerDB.pos.x = centerX - parentCenterX
        CritTrackerDB.pos.y = centerY - parentCenterY
        DebugMsg("Posicion guardada: " .. CritTrackerDB.pos.x .. ", " .. CritTrackerDB.pos.y)
    end
end

local function LoadPosition()
    Widget:ClearAllPoints()
    Widget:SetPoint("CENTER", UIParent, "CENTER", CritTrackerDB.pos.x or 0, CritTrackerDB.pos.y or 0)
    DebugMsg("Posicion cargada: " .. (CritTrackerDB.pos.x or 0) .. ", " .. (CritTrackerDB.pos.y or 0))
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
        -- Mostrar resumen en chat
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker Resumen ===|r")
        if CritTrackerDB.globalMax.damage > 0 then
            local spell = CritTrackerDB.globalMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("Global: |cffFFFF00" .. CritTrackerDB.globalMax.damage .. "|r con " .. spell .. " (Lvl " .. CritTrackerDB.globalMax.level .. ")")
        end
        if CritTrackerDB.sessionMax.damage > 0 then
            local spell = CritTrackerDB.sessionMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("Sesion: |cffFFFF00" .. CritTrackerDB.sessionMax.damage .. "|r con " .. spell)
        end
        
        local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
        local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Crit%% Sesion: |cffFFCC00%.1f%%|r (%d/%d)", sessionPct, CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Crit%% Total: |cffFFCC00%.1f%%|r (%d/%d)", totalPct, CritTrackerDB.totalCrits, CritTrackerDB.totalHits))
        
        local sessionHitPct = GetHitPercent(CritTrackerDB.sessionMeleeSwings, CritTrackerDB.sessionMeleeMisses)
        local totalHitPct = GetHitPercent(CritTrackerDB.totalMeleeSwings, CritTrackerDB.totalMeleeMisses)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Hit%% Sesion: |cff88CCFF%.1f%%|r (%d misses de %d)", sessionHitPct, CritTrackerDB.sessionMeleeMisses, CritTrackerDB.sessionMeleeSwings))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Hit%% Total: |cff88CCFF%.1f%%|r (%d misses de %d)", totalHitPct, CritTrackerDB.totalMeleeMisses, CritTrackerDB.totalMeleeSwings))
    end
end)

-- Tooltip
Widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(Widget, "ANCHOR_RIGHT")
    GameTooltip:AddLine("CritTracker", 1, 0.3, 0.3)
    GameTooltip:AddLine(" ")
    
    -- Global
    if CritTrackerDB.globalMax.damage > 0 then
        local spell = CritTrackerDB.globalMax.spell
        if spell == "" then spell = "Melee" end
        GameTooltip:AddDoubleLine("Record Global:", CritTrackerDB.globalMax.damage, 1, 1, 1, 1, 0.3, 0.3)
        GameTooltip:AddDoubleLine("  Habilidad:", spell, 0.7, 0.7, 0.7, 1, 1, 0.5)
        GameTooltip:AddDoubleLine("  Nivel:", CritTrackerDB.globalMax.level, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
        GameTooltip:AddDoubleLine("  Target:", CritTrackerDB.globalMax.target, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine("Sin criticos registrados aun", 0.5, 0.5, 0.5)
    end
    
    GameTooltip:AddLine(" ")
    
    -- Porcentajes de Crit
    local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
    local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
    GameTooltip:AddLine("|cffFFCC00Estadisticas de Crit:|r")
    GameTooltip:AddDoubleLine("  Sesion:", string.format("%.1f%% (%d/%d)", sessionPct, CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Total:", string.format("%.1f%% (%d/%d)", totalPct, CritTrackerDB.totalCrits, CritTrackerDB.totalHits), 0.7, 0.7, 0.7, 1, 1, 1)
    
    GameTooltip:AddLine(" ")
    
    -- Porcentajes de Hit (Melee)
    local sessionHitPct = GetHitPercent(CritTrackerDB.sessionMeleeSwings, CritTrackerDB.sessionMeleeMisses)
    local totalHitPct = GetHitPercent(CritTrackerDB.totalMeleeSwings, CritTrackerDB.totalMeleeMisses)
    GameTooltip:AddLine("|cff88CCFFEstadisticas de Hit (Melee):|r")
    GameTooltip:AddDoubleLine("  Sesion:", string.format("%.1f%% (%d miss / %d)", sessionHitPct, CritTrackerDB.sessionMeleeMisses, CritTrackerDB.sessionMeleeSwings), 0.7, 0.7, 0.7, 0.5, 0.8, 1)
    GameTooltip:AddDoubleLine("  Total:", string.format("%.1f%% (%d miss / %d)", totalHitPct, CritTrackerDB.totalMeleeMisses, CritTrackerDB.totalMeleeSwings), 0.7, 0.7, 0.7, 0.5, 0.8, 1)
    
    GameTooltip:AddLine(" ")
    
    -- Top 5 habilidades
    GameTooltip:AddLine("|cffFFFF00Top Habilidades:|r")
    local sorted = {}
    for spell, data in pairs(CritTrackerDB.bySpell) do
        table.insert(sorted, {name = spell, damage = data.damage})
    end
    table.sort(sorted, function(a, b) return a.damage > b.damage end)
    
    local shown = 0
    for i, v in ipairs(sorted) do
        if shown < 5 then
            local name = v.name
            if name == "" then name = "Melee" end
            GameTooltip:AddDoubleLine("  " .. name, v.damage, 0.7, 0.7, 0.7, 1, 1, 1)
            shown = shown + 1
        end
    end
    
    if shown == 0 then
        GameTooltip:AddLine("  Ninguna aun...", 0.5, 0.5, 0.5)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00FF00Click izq:|r Ver resumen", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("|cff00FF00Click der:|r Bloquear/Desbloquear", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("|cffFFFF00/crit|r para mas opciones", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

Widget:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================
-- REGISTRO DE HITS Y MISSES
-- ============================================================
local function RegisterHit(isCrit, isMelee)
    CritTrackerDB.totalHits = CritTrackerDB.totalHits + 1
    CritTrackerDB.sessionHits = CritTrackerDB.sessionHits + 1
    
    if isCrit then
        CritTrackerDB.totalCrits = CritTrackerDB.totalCrits + 1
        CritTrackerDB.sessionCrits = CritTrackerDB.sessionCrits + 1
    end
    
    -- Contar swings melee (hits que conectan)
    if isMelee then
        CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
        CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    end
end

local function RegisterMiss()
    -- Los misses cuentan como swing pero no como hit
    CritTrackerDB.totalMeleeSwings = CritTrackerDB.totalMeleeSwings + 1
    CritTrackerDB.sessionMeleeSwings = CritTrackerDB.sessionMeleeSwings + 1
    CritTrackerDB.totalMeleeMisses = CritTrackerDB.totalMeleeMisses + 1
    CritTrackerDB.sessionMeleeMisses = CritTrackerDB.sessionMeleeMisses + 1
    
    DebugMsg("MISS registrado! Total: " .. CritTrackerDB.sessionMeleeMisses .. "/" .. CritTrackerDB.sessionMeleeSwings)
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
    
    -- ==================
    -- DETECTAR SI ES CRITICO PRIMERO
    -- ==================
    local isCrit = false
    
    -- Buscar palabras clave de critico (cualquier variante)
    if string.find(msg, "tico") or string.find(msg, "ticas") or string.find(msg, "crit") then
        isCrit = true
        DebugMsg("Detectado como CRITICO")
    end
    
    -- ==================
    -- ESPAÑOL - CRITICOS DE SPELL
    -- ==================
    
    -- "Tu [Spell] hace un crítico a [target] por [damage]."
    _, _, spell, target, damage = string.find(msg, "Tu (.+) hace un .+ a (.+) por (%d+)")
    if damage and isCrit then
        DebugMsg("CRIT SPELL: " .. damage .. " con " .. spell)
        return tonumber(damage), spell, target, true, false
    end
    
    -- ==================
    -- ESPAÑOL - CRITICOS DE MELEE
    -- ==================
    
    -- "Críticas a [target] por [damage]." - empieza con "Cr" y tiene "a [target] por"
    if isCrit and not spell then
        _, _, target, damage = string.find(msg, "^Cr.+as a (.+) por (%d+)")
        if damage then
            DebugMsg("CRIT MELEE: " .. damage .. " a " .. target)
            return tonumber(damage), nil, target, true, true
        end
    end
    
    -- ==================
    -- ESPAÑOL - HITS NORMALES
    -- ==================
    
    -- "Golpeas a [target] por [damage]." (melee hit normal)
    _, _, target, damage = string.find(msg, "Golpeas a (.+) por (%d+)")
    if damage then
        DebugMsg("HIT MELEE: " .. damage)
        return tonumber(damage), nil, target, false, true
    end
    
    -- "Tu [Spell] golpea a [target] por [damage]." (spell hit normal)
    _, _, spell, target, damage = string.find(msg, "Tu (.+) golpea a (.+) por (%d+)")
    if damage then
        DebugMsg("HIT SPELL: " .. damage .. " con " .. spell)
        return tonumber(damage), spell, target, false, false
    end
    
    -- ==================
    -- INGLES
    -- ==================
    
    -- "You crit [target] for [damage]."
    _, _, target, damage = string.find(msg, "You crit (.+) for (%d+)")
    if damage then
        return tonumber(damage), nil, target, true, true
    end
    
    -- "Your [Spell] crits [target] for [damage]"
    _, _, spell, target, damage = string.find(msg, "Your (.+) crits (.+) for (%d+)")
    if damage then
        return tonumber(damage), spell, target, true, false
    end
    
    -- "You hit [target] for [damage]."
    _, _, target, damage = string.find(msg, "You hit (.+) for (%d+)")
    if damage then
        return tonumber(damage), nil, target, false, true
    end
    
    -- "Your [Spell] hits [target] for [damage]"
    _, _, spell, target, damage = string.find(msg, "Your (.+) hits (.+) for (%d+)")
    if damage then
        return tonumber(damage), spell, target, false, false
    end
    
    DebugMsg("No parseado")
    return nil
end

-- ============================================================
-- PARSEO DE MENSAJES DE MISS
-- ============================================================
local function ParseMissMessage(msg)
    DebugMsg("Miss msg: " .. msg)
    
    -- ==================
    -- ESPAÑOL - MISSES
    -- ==================
    
    -- "Fallas a [target]." o "Fallas [target]."
    if string.find(msg, "^Fallas") then
        DebugMsg("MISS detectado (Fallas)")
        return true
    end
    
    -- "Tu ataque falla." (variantes)
    if string.find(msg, "ataque falla") then
        DebugMsg("MISS detectado (ataque falla)")
        return true
    end
    
    -- "Erras a [target]" o similar
    if string.find(msg, "^Erras") then
        DebugMsg("MISS detectado (Erras)")
        return true
    end
    
    -- ==================
    -- INGLES - MISSES
    -- ==================
    
    -- "You miss [target]."
    if string.find(msg, "^You miss") then
        DebugMsg("MISS detectado (You miss)")
        return true
    end
    
    -- "Your attack misses"
    if string.find(msg, "attack miss") then
        DebugMsg("MISS detectado (attack miss)")
        return true
    end
    
    return false
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
        
        LoadPosition()
        UpdateWidget()
        
        if CritTrackerDB.showWidget then
            Widget:Show()
        else
            Widget:Hide()
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444CritTracker v1.2|r cargado! |cffFFFF00/crit|r para opciones")
        
    elseif event == "PLAYER_LEVEL_UP" then
        playerLevel = UnitLevel("player")
        UpdateWidget()
        
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        -- Procesar misses melee
        if DEBUG then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[CT Event]|r " .. event .. ": " .. (arg1 or "nil"))
        end
        
        if arg1 and ParseMissMessage(arg1) then
            RegisterMiss()
            UpdateWidget()
        end
        
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or 
           event == "CHAT_MSG_SPELL_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
        
        if DEBUG then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[CT Event]|r " .. event)
        end
        
        local damage, spell, target, isCrit, isMelee = ParseCombatMessage(arg1)
        
        if damage then
            RegisterHit(isCrit, isMelee)
            
            if isCrit then
                ProcessCrit(damage, spell, target)
            else
                UpdateWidget()
            end
        end
    end
end)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_CRITTRACKER1 = "/crit"
SLASH_CRITTRACKER2 = "/crittracker"

local confirmClear = false

SlashCmdList["CRITTRACKER"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "" or msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker v1.2 ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit|r - Ver este menu")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit show|r - Mostrar widget")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit hide|r - Ocultar widget")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit lock|r - Bloquear/Desbloquear")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit announce|r - Toggle anuncios")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit stats|r - Ver estadisticas")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit percent|r - Ver porcentaje de crit")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit hit|r - Ver porcentaje de hit")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit levels|r - Ver records por nivel")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit spells|r - Ver records por habilidad")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit reset|r - Resetear posicion")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit clear|r - Borrar todos los datos")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00/crit debug|r - Activar modo debug")
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
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== CritTracker Stats ===|r")
        if CritTrackerDB.globalMax.damage > 0 then
            local spell = CritTrackerDB.globalMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700Record Global:|r " .. CritTrackerDB.globalMax.damage)
            DEFAULT_CHAT_FRAME:AddMessage("  Habilidad: " .. spell)
            DEFAULT_CHAT_FRAME:AddMessage("  Nivel: " .. CritTrackerDB.globalMax.level)
            DEFAULT_CHAT_FRAME:AddMessage("  Target: " .. CritTrackerDB.globalMax.target)
            DEFAULT_CHAT_FRAME:AddMessage("  Fecha: " .. CritTrackerDB.globalMax.date)
        else
            DEFAULT_CHAT_FRAME:AddMessage("No hay criticos registrados aun.")
        end
        
        if CritTrackerDB.sessionMax.damage > 0 then
            local spell = CritTrackerDB.sessionMax.spell
            if spell == "" then spell = "Melee" end
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Sesion:|r " .. CritTrackerDB.sessionMax.damage .. " con " .. spell)
        end
        confirmClear = false
        
    elseif msg == "percent" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Porcentaje de Critico ===|r")
        local sessionPct = GetCritPercent(CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits)
        local totalPct = GetCritPercent(CritTrackerDB.totalCrits, CritTrackerDB.totalHits)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFFF00Sesion:|r %.2f%% (%d crits de %d hits)", sessionPct, CritTrackerDB.sessionCrits, CritTrackerDB.sessionHits))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %.2f%% (%d crits de %d hits)", totalPct, CritTrackerDB.totalCrits, CritTrackerDB.totalHits))
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888Compara con tu % real en la ventana de estadisticas (C)|r")
        confirmClear = false
        
    elseif msg == "hit" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF4444=== Porcentaje de Hit (Melee) ===|r")
        local sessionHitPct = GetHitPercent(CritTrackerDB.sessionMeleeSwings, CritTrackerDB.sessionMeleeMisses)
        local totalHitPct = GetHitPercent(CritTrackerDB.totalMeleeSwings, CritTrackerDB.totalMeleeMisses)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFFF00Sesion:|r %.2f%% hit (%d misses de %d swings)", sessionHitPct, CritTrackerDB.sessionMeleeMisses, CritTrackerDB.sessionMeleeSwings))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffFFD700Total:|r %.2f%% hit (%d misses de %d swings)", totalHitPct, CritTrackerDB.totalMeleeMisses, CritTrackerDB.totalMeleeSwings))
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888Nota: Solo cuenta ataques melee (autoataque)|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888El cap de hit vs mobs +3 niveles es 9%|r")
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
            CritTrackerDB.globalMax = {damage = 0, spell = "", level = 0, target = "", date = ""}
            CritTrackerDB.byLevel = {}
            CritTrackerDB.bySpell = {}
            CritTrackerDB.sessionMax = {damage = 0, spell = "", target = ""}
            CritTrackerDB.totalHits = 0
            CritTrackerDB.totalCrits = 0
            CritTrackerDB.sessionHits = 0
            CritTrackerDB.sessionCrits = 0
            CritTrackerDB.totalMeleeSwings = 0
            CritTrackerDB.totalMeleeMisses = 0
            CritTrackerDB.sessionMeleeSwings = 0
            CritTrackerDB.sessionMeleeMisses = 0
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
