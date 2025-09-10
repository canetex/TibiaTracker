-- ================================================================
-- NEXUS SCRIPTS / Charm/Tier/Heal Proc Tracker v3.0
-- ================================================================
-- UPDATE By Mousquer
-- UPDATE v3.0 - Added Heal System - by The Crusty
-- REFACTOR by The Crusty
    --- New Icons and Colors
    --- New Visibility Configs
    --- New Debug and Logging
    --- New HUDs
    --- New Functions
    --- New Variables
    --- New Constants
    --- New Patterns
    --- New Visibility Control

-- DESCRIÇÃO:
-- Script para rastrear ativações de Charms, Tiers e Heals no Tibia
-- Exibe estatísticas em tempo real: contagem, previsão por hora,
-- dano/cura mínimo, máximo e médio, tempo decorrido

-- FUNCIONALIDADES:
-- ✅ Rastreamento de Charms (Low Blow, Savage Blow, etc.)
-- ✅ Rastreamento de Tiers (Critical, Fatal, etc.)
-- ✅ Rastreamento de Heals (Heal, Great Heal, Ultimate Heal, etc.)
-- ✅ Sistema de cooldown configurável
-- ✅ HUDs arrastáveis com posições salvas automaticamente
-- ✅ Estatísticas detalhadas de dano/cura
-- ✅ Previsão de ativações por hora
-- ✅ Validação robusta de dados
-- ✅ Tratamento de erros aprimorado
-- ✅ Callbacks para reset e alternância de visibilidade

-- REQUISITOS:
-- - ZeroBot versão 1.7.1.2 ou superior (para métricas de tier)
-- - Resolução mínima: 800x600 (com fallback automático)

-- ================================================================
-- CONFIGURAÇÕES E VARIÁVEIS GLOBAIS
-- ================================================================

-- Cor do Texto do HUD
-- https://www.google.com/search?q=rgb+color+picker
local TEXT_COLOR = {
    R = 0, 
    G = 250,
    B = 154
    } 

-- Posições dos ícones (serão ajustadas automaticamente para resoluções menores)
local ICON_CHARM_X_POSITION = 827
local ICON_CHARM_Y_POSITION = 967
local ICON_CHARM_ID = 36726

local ICON_TIER_X_POSITION = 433
local ICON_TIER_Y_POSITION = 846
local ICON_TIER_ID = 30278

local ICON_HEAL_X_POSITION = 399
local ICON_HEAL_Y_POSITION = 967
-- local ICON_HEAL_ID = 11604
local ICON_HEAL_ID = 19077

-- Ícones de visibilidade (ao lado dos ícones principais)
local VISIBILITY_ICON_ID = 19369
local VISIBILITY_ICON_SCALE = 0.4
local VISIBILITY_ICON_OFFSET = 30  -- Distância do ícone principal

-- Função geradora de configurações de visibilidade
local function createVisibilityConfig(ativacoes, previsao, danoMin, danoMed, danoMax, tempo)
    return {
        tier = { tier = true, ativacoes = ativacoes, previsao = previsao, danoMinimo = danoMin, danoMedio = danoMed, danoMaximo = danoMax, tempoDecorrido = tempo },
        charm = { charm = true, ativacoes = ativacoes, previsao = previsao, danoMinimo = danoMin, danoMedio = danoMed, danoMaximo = danoMax, tempoDecorrido = tempo },
        heal = { heal = true, ativacoes = ativacoes, previsao = previsao, curaMinima = danoMin, curaMedia = danoMed, curaMaxima = danoMax, tempoDecorrido = tempo }
    }
end

-- Configurações de visibilidade predefinidas
local VisibilityConfigs = {
    TUDO = createVisibilityConfig(true, true, true, true, true, true),
    DAMAGE = createVisibilityConfig(false, false, true, true, true, false),
    ATIVACOES = createVisibilityConfig(true, true, false, false, false, false)
}

-- Controla quais informações são exibidas no HUD quando disponiveis
local VisibleInfo = VisibilityConfigs.TUDO

-- Estado atual das configurações de visibilidade
local currentVisibilityConfig = "TUDO"

-- ================================================================
-- SISTEMA DE DEBUG E LOGGING
-- ================================================================
local print_ativo = {
    erros = true,              -- Erros do sistema
    messageCheck = false,      -- Verificação de mensagens
    messageFound = false,      -- Mensagens com Tier/Charm encontradas
    messageNotFound = false,   -- Mensagens com Tier/Charm não encontradas
    testProgram = false,       -- Testes do programa
    cooldown = false,          -- Informações de cooldown
    statistics = false         -- Estatísticas detalhadas
}

-- Configurações do sistema
local ActiveTestHud = false

-- Mensagens de teste para validação de padrões
local testMessages = {
    "You gained 35 mana. (void's call charm)",
    "You deal 150 damage. (low blow charm)",
    "You deal 200 damage. [savage blow charm]",
    "You deal 300 damage. charm 'zap'",
    "You deal 100 damage. (freeze charm)",
    "You deal 250 damage. (curse charm)",
    "You deal 180 damage. (paralyze charm)",
    "You gained 50 mana. (zap charm)",
    "You deal 1 hitpoint. (freeze charm)",
    "You deal 400 hitpoints. (freeze charm)",
    "You have been transcended.",
    "You heal yourself for 50 hitpoints",
    "You are healed for 120 hitpoints",
    "You gain 1 hitpoint",
    "You gain 200 hitpoints",
    "You gained 6 mana",
    "You gained 8 mana. (void's call charm)",
    "You recover 1 hitpoint",
    "You recover 80 hitpoints",
    "You were healed for 1 hitpoint",
    "You were healed for 17 hitpoints",
    "You were healed for 1 hitpoint. (vampiric embrace charm)",
    "You were healed for 18 hitpoints. (vampiric embrace charm)",
    "You were healed for 57 hitpoints. (vampiric embrace charm)",
    "You healed yourself for 1 hitpoint",
    "You healed yourself for 736 hitpoints",
    "You were healed by Test Player for 1 hitpoint",
    "You were healed by Test Player for 1181 hitpoints",
    "You were healed by Test Player for 1344 hitpoints",
    "You heal Test Player for 1 hitpoint",
    "You heal Test Player for 563 hitpoints",
    "A hellhunter inferniarch loses 1 hitpoints due to your attack. (active prey bonus) (perfect shoot).",
    "A hellhunter inferniarch loses 462 hitpoints due to your attack. (active prey bonus) (perfect shoot)."
}

-- DO NOT TOUCH BELOW THIS LINE // NÃO TOQUE ABAIXO DESTA LINHA --
-- ON HUD DRAG IT WILL SAVE THE NEW POSITION TO THE FILE --
-- APÓS MOVER O ÍCONE A NOVA POSIÇÃO SERÁ SALVA --


-- ================================================================
-- INICIALIZAÇÃO E CONFIGURAÇÃO AUTOMÁTICA
-- ================================================================

-- fallback para resolução menor
if Client.getGameWindowDimensions().width < ICON_CHARM_X_POSITION then ICON_CHARM_X_POSITION = 155 end
if Client.getGameWindowDimensions().width < ICON_TIER_X_POSITION then ICON_TIER_X_POSITION = 165 end
if Client.getGameWindowDimensions().width < ICON_HEAL_X_POSITION then ICON_HEAL_X_POSITION = 175 end

if Client.getGameWindowDimensions().height < ICON_CHARM_Y_POSITION then ICON_CHARM_Y_POSITION = 155 end
if Client.getGameWindowDimensions().height < ICON_TIER_Y_POSITION then ICON_TIER_Y_POSITION = 165 end
if Client.getGameWindowDimensions().height < ICON_HEAL_Y_POSITION then ICON_HEAL_Y_POSITION = 175 end

local charms = {}
local charmsFound = 0
local tiers = {}
local tiersFound = 0
local heals = {}
local healsFound = 0

-- Tabela unificada de cooldowns
local cooldowns = {
    charm = {
        ["Low Blow"] = { cooldown = 0.5, lastTime = 0 },
        ["Savage Blow"] = { cooldown = 0.5, lastTime = 0 }
    },
    tier = {
        ["Critical"] = { cooldown = 0.5, lastTime = 0 },
        ["Fatal"] = { cooldown = 0.5, lastTime = 0 }
    },
    heal = {
        ["default"] = { cooldown = 0.5, lastTime = 0 }
    }
}

local charmIcon = nil
local charmIconLastPos = nil
local tierIcon = nil
local tierIconLastPos = nil
local healIcon = nil
local healIconLastPos = nil

-- Ícones de visibilidade
local charmVisibilityIcon = nil
local tierVisibilityIcon = nil
local healVisibilityIcon = nil

-- Estados de visibilidade dos grupos
local charmGroupVisible = true
local tierGroupVisible = true
local healGroupVisible = true
local oneHourInSeconds = 3600

-- ================================================================
-- FUNÇÕES DE CALLBACK E CONTROLE
-- ================================================================

-- Função unificada para criar e atualizar ícone de visibilidade
local function manageVisibilityIcon(mainIcon, groupType, visibilityIcon)
    if not mainIcon then 
        print("[DEBUG] manageVisibilityIcon: mainIcon é nil")
        return nil 
    end
    
    local mainPos = mainIcon:getPos()
    local mainX, mainY = mainPos.x, mainPos.y
    
    -- Se a posição for 0,0, usar as posições das variáveis globais
    if mainX == 0 and mainY == 0 then
        if groupType == "charm" then
            mainX, mainY = ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION
        elseif groupType == "tier" then
            mainX, mainY = ICON_TIER_X_POSITION, ICON_TIER_Y_POSITION
        elseif groupType == "heal" then
            mainX, mainY = ICON_HEAL_X_POSITION, ICON_HEAL_Y_POSITION
        end
    end
    
    local visibilityX = mainX + VISIBILITY_ICON_OFFSET
    local visibilityY = mainY
    
    print("[DEBUG] manageVisibilityIcon: mainPos=" .. mainX .. "," .. mainY .. " visibilityPos=" .. visibilityX .. "," .. visibilityY)
    
    if not visibilityIcon then
        -- Criar novo ícone
        print("[DEBUG] Criando novo ícone de visibilidade...")
        visibilityIcon = HUD.new(visibilityX, visibilityY, VISIBILITY_ICON_ID, true)
        if visibilityIcon then
            visibilityIcon:setDraggable(false)
            visibilityIcon:setHorizontalAlignment(Enums.HorizontalAlign.Left)
            visibilityIcon:setScale(VISIBILITY_ICON_SCALE)
            print("[DEBUG] Ícone de visibilidade criado com sucesso")
        else
            print("[DEBUG] ERRO: Falha ao criar HUD.new para ícone de visibilidade")
        end
    else
        -- Atualizar posição existente
        print("[DEBUG] Atualizando posição do ícone de visibilidade existente")
        visibilityIcon:setPos(visibilityX, visibilityY)
    end
    
    return visibilityIcon
end

-- Função para atualizar todos os HUDs existentes
local function updateAllHuds()
    local dataGroups = {
        {data = charms, type = "charm", visible = charmGroupVisible},
        {data = tiers, type = "tier", visible = tierGroupVisible},
        {data = heals, type = "heal", visible = healGroupVisible}
    }
    
    print("[DEBUG] Atualizando HUDs - Configuração atual: " .. currentVisibilityConfig)
    print("[DEBUG] Configuração original TUDO.danoMinimo: " .. tostring(VisibilityConfigs.TUDO.charm.danoMinimo))
    print("[DEBUG] VisibleInfo.charm.ativacoes: " .. tostring(VisibleInfo.charm.ativacoes))
    print("[DEBUG] VisibleInfo.charm.danoMinimo: " .. tostring(VisibleInfo.charm.danoMinimo))
    print("[DEBUG] VisibleInfo.charm.danoMedio: " .. tostring(VisibleInfo.charm.danoMedio))
    print("[DEBUG] VisibleInfo.charm.danoMaximo: " .. tostring(VisibleInfo.charm.danoMaximo))
    
    for _, group in ipairs(dataGroups) do
        for name, item in pairs(group.data) do
            if item.hud.text and item.hud.text.setText and item.hud.text.setVisible then
                local timeElapsed = getTimeElapsedString(item.first)
                local hudText = createHudText(name, item, item.damages[#item.damages] or 0, timeElapsed, group.type)
                print("[DEBUG] HUD Text para " .. name .. ": " .. hudText)
                item.hud.text:setText(hudText)
                item.hud.text:setVisible(group.visible)
            end
        end
    end
end

-- Função para alternar visibilidade de um grupo
local function toggleGroupVisibility(groupType)
    local groupConfigs = {
        charm = {var = "charmGroupVisible", name = "charms"},
        tier = {var = "tierGroupVisible", name = "tiers"},
        heal = {var = "healGroupVisible", name = "heals"}
    }
    
    local config = groupConfigs[groupType]
    if not config then return end
    
    -- Alternar visibilidade
    if groupType == "charm" then
        charmGroupVisible = not charmGroupVisible
    elseif groupType == "tier" then
        tierGroupVisible = not tierGroupVisible
    elseif groupType == "heal" then
        healGroupVisible = not healGroupVisible
    end
    
    local isVisible = (groupType == "charm" and charmGroupVisible) or 
                     (groupType == "tier" and tierGroupVisible) or 
                     (groupType == "heal" and healGroupVisible)
    print("[" .. groupType:upper() .. "] Grupo de " .. config.name .. " " .. (isVisible and "visível" or "oculto"))
    
    updateAllHuds()
end

local function getTimeElapsedString(first)
    local timeDif = os.time() - first
    local minutes = math.floor(timeDif / 60)
    local seconds = timeDif % 60
    
    if minutes > 0 then
        return string.format("%dm %ds", minutes, seconds)
    else
        return string.format("%ds", seconds)
    end
end

-- Função genérica para criar texto do HUD com base nos controles de VisibleInfo
local function createHudText(name, data, damage, timeElapsed, type)
    local config = VisibleInfo[type] or VisibleInfo.charm
    local parts = {}
    
    -- Nome do item
    if config[type] then
        table.insert(parts, "[" .. name .. "]")
    end
    
    -- Ativações
    if config.ativacoes then
        table.insert(parts, "\u{1F5E1}: " .. data.count)
    end
    
    if config.previsao then
        table.insert(parts, "\u{1F553}: " .. data.inAHour)
    end
    
    -- Dano/Cura
    if damage > 0 then
        local isHeal = type == "heal"
        local damageConfig = isHeal and 
            {min = config.curaMinima, avg = config.curaMedia, max = config.curaMaxima} or
            {min = config.danoMinimo, avg = config.danoMedio, max = config.danoMaximo}
        
        if damageConfig.min then table.insert(parts, "\u{2B07}: " .. data.lowest) end
        if damageConfig.avg then table.insert(parts, "\u{1F503}: " .. string.format("%.1f", data.average)) end
        if damageConfig.max then table.insert(parts, "\u{2B06}: " .. data.higher) end
    end
    
    -- Tempo
    if config.tempoDecorrido then
        table.insert(parts, "TEMPO: " .. timeElapsed)
    end
    
    return #parts > 0 and table.concat(parts, " - ") or "[" .. name .. "]: Nenhuma informação habilitada"
end

-- Função para alternar configurações de visibilidade
local function cycleVisibilityConfig()
    local configs = {"TUDO", "DAMAGE", "ATIVACOES"}
    local currentIndex = 1
    
    -- Encontrar índice atual
    for i, config in ipairs(configs) do
        if config == currentVisibilityConfig then
            currentIndex = i
            break
        end
    end
    
    -- Próxima configuração (ciclo)
    local nextIndex = (currentIndex % #configs) + 1
    currentVisibilityConfig = configs[nextIndex]
    
    -- Aplicar nova configuração (copiar valores, não referências)
    VisibleInfo.tier = {
        tier = VisibilityConfigs[currentVisibilityConfig].tier.tier,
        ativacoes = VisibilityConfigs[currentVisibilityConfig].tier.ativacoes,
        previsao = VisibilityConfigs[currentVisibilityConfig].tier.previsao,
        danoMinimo = VisibilityConfigs[currentVisibilityConfig].tier.danoMinimo,
        danoMedio = VisibilityConfigs[currentVisibilityConfig].tier.danoMedio,
        danoMaximo = VisibilityConfigs[currentVisibilityConfig].tier.danoMaximo,
        tempoDecorrido = VisibilityConfigs[currentVisibilityConfig].tier.tempoDecorrido
    }
    VisibleInfo.charm = {
        charm = VisibilityConfigs[currentVisibilityConfig].charm.charm,
        ativacoes = VisibilityConfigs[currentVisibilityConfig].charm.ativacoes,
        previsao = VisibilityConfigs[currentVisibilityConfig].charm.previsao,
        danoMinimo = VisibilityConfigs[currentVisibilityConfig].charm.danoMinimo,
        danoMedio = VisibilityConfigs[currentVisibilityConfig].charm.danoMedio,
        danoMaximo = VisibilityConfigs[currentVisibilityConfig].charm.danoMaximo,
        tempoDecorrido = VisibilityConfigs[currentVisibilityConfig].charm.tempoDecorrido
    }
    VisibleInfo.heal = {
        heal = VisibilityConfigs[currentVisibilityConfig].heal.heal,
        ativacoes = VisibilityConfigs[currentVisibilityConfig].heal.ativacoes,
        previsao = VisibilityConfigs[currentVisibilityConfig].heal.previsao,
        curaMinima = VisibilityConfigs[currentVisibilityConfig].heal.curaMinima,
        curaMedia = VisibilityConfigs[currentVisibilityConfig].heal.curaMedia,
        curaMaxima = VisibilityConfigs[currentVisibilityConfig].heal.curaMaxima,
        tempoDecorrido = VisibilityConfigs[currentVisibilityConfig].heal.tempoDecorrido
    }
    
    -- Atualizar todos os HUDs existentes
    updateAllHuds()
    
    print("[CHARMS] Configuração alterada para: " .. currentVisibilityConfig)
end

-- Função genérica para criar ícone principal e de visibilidade
local function createMainIcon(x, y, id, groupType)
    local mainIcon = HUD.new(x, y, id, true)
    mainIcon:setDraggable(true)
    mainIcon:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    
    -- Callback para alternar configurações de visibilidade
    mainIcon:setCallback(function()
        cycleVisibilityConfig()
    end)
    
    -- Criar ícone de visibilidade
    local visibilityIcon = manageVisibilityIcon(mainIcon, groupType, nil)
    if visibilityIcon then
        print("[DEBUG] Ícone de visibilidade criado para " .. groupType)
        visibilityIcon:setCallback(function()
            toggleGroupVisibility(groupType)
        end)
    else
        print("[DEBUG] ERRO: Falha ao criar ícone de visibilidade para " .. groupType)
    end
    
    return mainIcon, visibilityIcon
end

-- Função genérica para configurar cooldown baseado no tipo
local function getCooldownData(type, name)
    if cooldowns[type] and cooldowns[type][name] then
        return {cooldown = cooldowns[type][name].cooldown, lastTime = cooldowns[type][name].lastTime}
    elseif type == "heal" and cooldowns.heal.default then
        return {cooldown = cooldowns.heal.default.cooldown, lastTime = cooldowns.heal.default.lastTime}
    end
    return nil
end

-- Sistema de debug e logging
local function checkAndPrint(class, message)
    if not print_ativo or not class or not message then return end
    if print_ativo[class] then
        print("[DEBUG:" .. class:upper() .. "] " .. tostring(message))
    end
end

-- Verifica se o cooldown expirou e atualiza para o próximo uso
-- @param cooldownData: tabela com lastTime e cooldown
-- @return: true se pode ativar, false se ainda em cooldown
local function checkAndUpdateCooldown(cooldownData)
    if not cooldownData then return true end
    
    local lastTime = cooldownData.lastTime
    local cooldown = cooldownData.cooldown
    local currentTime = os.time()
    
    -- Verificar se ainda está em cooldown
    if lastTime > 0 and currentTime < lastTime then
        checkAndPrint("cooldown", "Cooldown ativo: " .. (lastTime - currentTime) .. "s restantes")
        return false
    end
    
    -- Atualizar cooldown para o próximo uso
    cooldownData.lastTime = currentTime + cooldown
    return true
end

-- Calcula estatísticas de dano (média, maior, menor) com soma incremental
-- @param charm: objeto charm com dados de dano
-- @param lastDamage: último dano causado
-- @return: objeto charm atualizado com estatísticas
local function getAverageAndHigherDamage(charm, lastDamage)
    -- Validar entrada
    if not charm or not charm.damages or #charm.damages == 0 then
        return charm
    end
    
    if #charm.damages == 1 then
        charm.average = lastDamage
        charm.lowest = lastDamage
        charm.totalSum = lastDamage
        return charm
    end

    -- Atualizar maior e menor dano de forma mais eficiente
    if lastDamage > charm.higher then
        charm.higher = lastDamage
    end
    
    if lastDamage < charm.lowest then
        charm.lowest = lastDamage
    end

    -- Calcular média usando soma incremental (muito mais eficiente)
    charm.totalSum = (charm.totalSum or 0) + lastDamage
    local count = #charm.damages
    charm.average = math.floor((charm.totalSum / count) * 100) / 100
    
    return charm
end

-- Função para calcular previsão de ativações por hora
local function getOneHourEstimate(first, count)
    -- Validar parâmetros
    if not first or not count or count < 0 then
        return 0
    end
    
    local timeDif = os.time() - first
    if timeDif <= 0 then 
        timeDif = 1 
    end
    
    -- Para evitar divisão por zero e cálculos incorretos
    if count == 0 then
        return 0
    end
    
    -- Calcular taxa por segundo e multiplicar por 3600 segundos (1 hora)
    local ratePerSecond = count / timeDif
    local inAHour = math.floor(ratePerSecond * oneHourInSeconds)
    
    -- Log para debug
    checkAndPrint("statistics", string.format("Previsão 1h: count=%d, timeDif=%d, ratePerSecond=%.4f, inAHour=%d", 
        count, timeDif, ratePerSecond, inAHour))
    
    return inAHour
end

-- Função genérica de validação
local function validateInput(value, expectedType, allowEmpty)
    if not value then return false end
    if type(value) ~= expectedType then return false end
    if not allowEmpty and (expectedType == "string" and value == "") then return false end
    return true
end

-- Processa ativação de charm ou tier com validação e estatísticas
-- @param data: tabela de dados (charms ou tiers)
-- @param name: nome do charm/tier
-- @param damage: dano causado
-- @param cooldownData: dados de cooldown (opcional)
-- @return: true se processado com sucesso, false se em cooldown
local function processActivation(data, name, damage, cooldownData)
    -- Validar parâmetros de entrada
    if not validateInput(data, "table", true) then
        checkAndPrint("erros", "Erro: data deve ser uma tabela")
        return false
    end
    
    if not validateInput(name, "string", false) then
        checkAndPrint("erros", "Erro: name deve ser uma string não vazia")
        return false
    end
    
    if not damage or type(damage) ~= "number" or damage < 0 then
        damage = 0 -- Valor padrão para dano inválido
    end
    
    -- Verificar cooldown se especificado
    if not checkAndUpdateCooldown(cooldownData) then
        return false
    end
    
    -- Inicializar ou atualizar dados
    if not data[name] then
        data[name] = {
            count = 1,
            first = os.time(),
            inAHour = 0,
            hud = { text = nil },
            damages = { damage },
            higher = damage,
            lowest = damage,
            average = damage,
            totalSum = damage
        }
        checkAndPrint("statistics", string.format("Inicializando %s: count=1, first=%d, damage=%d", name, data[name].first, damage))
    else
        table.insert(data[name].damages, damage)
        data[name].count = data[name].count + 1
        checkAndPrint("statistics", string.format("Atualizando %s: count=%d, damage=%d", name, data[name].count, damage))
    end
    
    -- Calcular estatísticas de dano
    data[name] = getAverageAndHigherDamage(data[name], damage)
    
    -- Calcular previsão de 1 hora
    local inAHour = getOneHourEstimate(data[name].first, data[name].count)
    data[name].inAHour = inAHour
    
    -- Log de estatísticas
    checkAndPrint("statistics", string.format("%s: %d ativações, prev 1h: %d, dano: %d", 
        name, data[name].count, inAHour, damage))
    
    return true
end

-- Funções utilitárias básicas
local function isTable(t) return type(t) == 'table' end
local function hasDragged(currentPos, lastPos) return currentPos.x ~= lastPos.x or currentPos.y ~= lastPos.y end
local function setPos(hud, x, y) hud:setPos(x, y) end
local function getThisFilename() return debug.getinfo(1).source:gsub("Scripts/", "") end

-- Função genérica para atualizar variáveis de cooldown globais
local function updateGlobalCooldown(type, name, cooldownData)
    if not cooldownData then return end
    
    if cooldowns[type] and cooldowns[type][name] then
        cooldowns[type][name].lastTime = cooldownData.lastTime
    elseif type == "heal" and cooldowns.heal.default then
        cooldowns.heal.default.lastTime = cooldownData.lastTime
    end
end

local function createHud(x, y, text)
    local hud = HUD.new(x, y, text, true)
    hud:setColor(TEXT_COLOR.R, TEXT_COLOR.G, TEXT_COLOR.B)
    hud:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    return hud
end

-- Função genérica para zerar contador específico
local function resetCounter(type, name)
    local dataGroups = {charm = charms, tier = tiers, heal = heals}
    local data = dataGroups[type]
    if not data or not data[name] then return end
    
    -- Resetar dados
    data[name].count = 0
    data[name].first = os.time()
    data[name].inAHour = 0
    data[name].damages = {}
    data[name].higher = 0
    data[name].lowest = 0
    data[name].average = 0
    data[name].totalSum = 0
    
    -- Atualizar HUD
    if data[name].hud.text then
        local timeElapsed = getTimeElapsedString(data[name].first)
        local hudText = createHudText(name, data[name], 0, timeElapsed, type)
        data[name].hud.text:setText(hudText)
    end
    
    print("[" .. type:upper() .. "] Contador do " .. type .. " '" .. name .. "' zerado")
end

-- Função genérica para criar ou atualizar HUD
local function createOrUpdateHud(data, name, iconX, iconY, foundCount, hudText, type)
    if not data[name].hud.text then
        local x = iconX - 35
        local y = iconY + 40 + (15 * foundCount)
        data[name].hud.text = createHud(x, y, hudText)
        
        -- Adicionar callback para zerar contador
        if data[name].hud.text and data[name].hud.text.setCallback then
            data[name].hud.text:setCallback(function()
                resetCounter(type, name)
            end)
        end
        
        -- Aplicar visibilidade do grupo
        if data[name].hud.text and data[name].hud.text.setVisible then
            local groupVisibility = (type == "charm" and charmGroupVisible) or 
                                   (type == "tier" and tierGroupVisible) or 
                                   (type == "heal" and healGroupVisible)
            data[name].hud.text:setVisible(groupVisibility)
        end
        
        return foundCount + 1
    else
        if data[name].hud.text and data[name].hud.text.setText then
            data[name].hud.text:setText(hudText)
        end
        return foundCount
    end
end

-- Função genérica para processar grupos (charms, tiers, heals)
local function processGroup(groupType, name, damage, patterns, iconConfig, data, foundCount)
    -- Validar entrada
    if not name or type(name) ~= "string" or name == "" then
        return false, foundCount
    end
    
    -- Configurar cooldown
    local cooldownData = getCooldownData(groupType, name)
    
    -- Processar ativação
    local success = processActivation(data, name, damage, cooldownData)
    if not success then return false, foundCount end
    
    -- Atualizar variáveis de cooldown globais
    updateGlobalCooldown(groupType, name, cooldownData)
    
    -- Criar texto do HUD
    local timeElapsed = getTimeElapsedString(data[name].first)
    local hudText = createHudText(name, data[name], damage, timeElapsed, groupType)
    
    -- Criar ou atualizar HUD
    foundCount = createOrUpdateHud(data, name, iconConfig.x, iconConfig.y, foundCount, hudText, groupType)
    
    return true, foundCount
end

-- ================================================================
-- FUNÇÕES AUXILIARES E UTILITÁRIAS
-- ================================================================

local function setDebugMode(class, enabled)
    if print_ativo and print_ativo[class] ~= nil then
        print_ativo[class] = enabled
        print("[DEBUG] " .. class .. " " .. (enabled and "ATIVADO" or "DESATIVADO"))
    end
end

local function setAllDebugModes(enabled)
    for class, _ in pairs(print_ativo) do
        print_ativo[class] = enabled
    end
    print("[DEBUG] Todos os modos de debug " .. (enabled and "ATIVADOS" or "DESATIVADOS"))
end

local function openFile(path, mode)
    if not validateInput(path, "string", false) then
        checkAndPrint("erros", "Erro: caminho do arquivo inválido")
        return nil
    end
    
    local file = io.open(path, mode)
    if not file then
        checkAndPrint("erros", "Erro ao abrir arquivo: " .. tostring(path))
        return nil
    end

    return file
end

local filename = getThisFilename()


-- ================================================================
-- FUNÇÕES DE UTILITÁRIOS
-- ================================================================

-- ================================================================
-- FUNÇÕES DE GERENCIAMENTO DE COOLDOWN
-- ================================================================

-- ================================================================
-- FUNÇÕES DE CÁLCULO DE ESTATÍSTICAS
-- ================================================================

-- ================================================================
-- FUNÇÕES DE PROCESSAMENTO DE ATIVAÇÕES
-- ================================================================

-- Função para salvar posição do ícone e estados de visibilidade no arquivo
local function saveIconPosition(name, value, which)
    if not name or not value or not which then return false end
    
    local path = Engine.getScriptsDirectory() .. "/" .. name
    local file = openFile(path, "r")
    if not file then return false end
    
    local content = file:read("*all")
    file:close()
    if not content then return false end

    local X, Y = which .. "_X_POSITION = ", which .. "_Y_POSITION = "
    local currentX, currentY = content:match(X .. "(%d+)"), content:match(Y .. "(%d+)")
    if not currentX or not currentY then return false end

    local newContent = content:gsub(X .. currentX, X .. value.x):gsub(Y .. currentY, Y .. value.y)
    
    -- Salvar estados de visibilidade se for a primeira vez salvando
    if which == "ICON_CHARM" then
        newContent = newContent:gsub("local charmGroupVisible = true", "local charmGroupVisible = " .. tostring(charmGroupVisible))
        newContent = newContent:gsub("local charmGroupVisible = false", "local charmGroupVisible = " .. tostring(charmGroupVisible))
    elseif which == "ICON_TIER" then
        newContent = newContent:gsub("local tierGroupVisible = true", "local tierGroupVisible = " .. tostring(tierGroupVisible))
        newContent = newContent:gsub("local tierGroupVisible = false", "local tierGroupVisible = " .. tostring(tierGroupVisible))
    elseif which == "ICON_HEAL" then
        newContent = newContent:gsub("local healGroupVisible = true", "local healGroupVisible = " .. tostring(healGroupVisible))
        newContent = newContent:gsub("local healGroupVisible = false", "local healGroupVisible = " .. tostring(healGroupVisible))
    end
    
    -- Salvar configuração de visibilidade atual
    newContent = newContent:gsub('local currentVisibilityConfig = "[^"]*"', 'local currentVisibilityConfig = "' .. currentVisibilityConfig .. '"')
    
    file = openFile(path, "w")
    if not file then return false end

    local success = file:write(newContent)
    file:close()
    return success
end


local charmPatterns = {
    "charm '([^']+)'",           -- charm 'nome'
    "%[(.-)%s+charm%]",          -- [nome charm]
    "%(([^)]+)%s+charm%)",       -- (qualquer coisa) charm) - padrão mais flexível
    "%(([^)]*)charm%)"           -- (qualquer coisa charm) - sem espaço obrigatório
}


-- You gained 35 mana. (void's call charm)

local function findCharmsProc(text)
    -- Validar entrada
    if not validateInput(text, "string", false) then
        return false
    end
    checkAndPrint("messageCheck", "Verificando texto para charms: " .. text)
    
    local charm = nil
    for i, pattern in ipairs(charmPatterns) do
        charm = text:match(pattern)
        if charm then 
            checkAndPrint("messageFound", "Charm encontrado com padrão " .. i .. ": '" .. charm .. "'")
            break 
        end
    end
    
    if not charm then 
        checkAndPrint("messageNotFound", "Nenhum charm encontrado no texto")
        return false 
    end

    -- Extrair dano de diferentes tipos de mensagens
    local damage = tonumber(text:match("(%d+) hitpoints?") or 
                           text:match("(%d+) mana") or 
                           text:match("(%d+) damage") or 
                           text:match("deal (%d+)") or 
                           0)
    
    -- print("Dano extraído: " .. damage .. " do texto: " .. text)

    if not isTable(charmIcon) then
        charmIcon, charmVisibilityIcon = createMainIcon(ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION, ICON_CHARM_ID, "charm")
    end

    local success, newFoundCount = processGroup("charm", charm, damage, charmPatterns, 
        {x = ICON_CHARM_X_POSITION, y = ICON_CHARM_Y_POSITION}, charms, charmsFound)
    if success then charmsFound = newFoundCount end

    return true
end

-- Função unificada de teste para padrões e configurações
local function runAllTests()
    checkAndPrint("testProgram", "=== TESTE COMPLETO DO SISTEMA ===")
    
    -- Teste de padrões de charms
    checkAndPrint("testProgram", "\n--- TESTE DE PADRÕES DE CHARMS ---")
    for i, testMsg in ipairs(testMessages) do
        checkAndPrint("testProgram", "Teste " .. i .. ": " .. testMsg)
        local result = findCharmsProc(testMsg)
        checkAndPrint("testProgram", "Resultado: " .. (result and "SUCESSO" or "FALHOU"))
    end
    
    -- Teste de configurações de visibilidade
    checkAndPrint("testProgram", "\n--- TESTE DE CONFIGURAÇÕES VisibleInfo ---")
    local testData = {
        count = 5, first = os.time() - 300, inAHour = 60,
        damages = {100, 150, 200, 120, 180}, higher = 200, lowest = 100, average = 150
    }
    local testDamage, testTimeElapsed = 150, "5m 0s"
    local originalConfig = VisibleInfo.charm
    
    -- Teste múltiplas configurações
    local configs = {
        {name = "Todas habilitadas", config = {charm=true, ativacoes=true, previsao=true, danoMinimo=true, danoMedio=true, danoMaximo=true, tempoDecorrido=true}},
        {name = "Apenas ativações", config = {charm=true, ativacoes=true, previsao=true, danoMinimo=false, danoMedio=false, danoMaximo=false, tempoDecorrido=false}},
        {name = "Apenas dano", config = {charm=true, ativacoes=false, previsao=false, danoMinimo=true, danoMedio=true, danoMaximo=true, tempoDecorrido=false}},
        {name = "Nenhuma info", config = {charm=false, ativacoes=false, previsao=false, danoMinimo=false, danoMedio=false, danoMaximo=false, tempoDecorrido=false}}
    }
    
    for _, test in ipairs(configs) do
        VisibleInfo.charm = test.config
        local result = createHudText("Low Blow", testData, testDamage, testTimeElapsed, "charm")
        checkAndPrint("testProgram", test.name .. ": " .. result)
    end
    
    VisibleInfo.charm = originalConfig
    checkAndPrint("testProgram", "\n=== FIM DO TESTE COMPLETO ===")
end

local function findTiersProcs(tier, lastDamage)
    if not isTable(tierIcon) then
        tierIcon, tierVisibilityIcon = createMainIcon(ICON_TIER_X_POSITION, ICON_TIER_Y_POSITION, ICON_TIER_ID, "tier")
    end

    local success, newFoundCount = processGroup("tier", tier, lastDamage, {}, 
        {x = ICON_TIER_X_POSITION, y = ICON_TIER_Y_POSITION}, tiers, tiersFound)
    if success then tiersFound = newFoundCount end
end

-- Padrões consolidados para detectar mensagens de heal (case insensitive, 's' facultativo, texto antes/depois facultativo)
local healPatterns = {
    -- Self heal
    {pattern = ".*[Yy]ou heal?ed? yourself for (%d+) hitpoints?.*", type = "Self"},
    
    -- Player heal - To (você cura alguém)
    {pattern = ".*[Yy]ou heal ([^%s]+) for (%d+) hitpoints?.*", type = "PlayerTo"},
    
    -- Player heal - From (você recebe cura)
    {pattern = ".*[Yy]ou were healed by ([^%s]+) for (%d+) hitpoints?.*", type = "PlayerFrom"},
    
    -- Imbuiments heal
    {pattern = ".*[Yy]ou were healed for (%d+) hitpoints?.*", type = "Imbuiments"},
    {pattern = ".*[Yy]ou gain?ed? (%d+) (hitpoints?|mana).*", type = "Imbuiments"},
    {pattern = ".*[Yy]ou recover (%d+) hitpoints?.*", type = "Imbuiments"},
    
    -- Charm heal
    {pattern = ".*[Yy]ou were healed for (%d+) hitpoints?%. %(([^)]+) charm%).*", type = "Charm"},
    {pattern = ".*[Yy]ou gained (%d+) (mana|hitpoints?)%. %(([^)]+) charm%).*", type = "Charm"}
}

local function findHealsProc(text)
    -- Validar entrada
    if not validateInput(text, "string", false) then
        return false
    end
    checkAndPrint("messageCheck", "Verificando texto para heals: " .. text)
    
    local healAmount = nil
    local healType = nil
    local playerName = nil
    local charmName = nil
    
    -- Verificar padrões de heal
    for _, patternData in ipairs(healPatterns) do
        local pattern, type = patternData.pattern, patternData.type
        local matches = {text:match(pattern)}
        
        if #matches > 0 then
            local isSelfOrImbu = type == "Self" or type == "Imbuiments"
            local isPlayer = type == "PlayerFrom" or type == "PlayerTo"
            local isCharm = type == "Charm"
            
            if isSelfOrImbu then
                healAmount = tonumber(matches[1])
                healType = type .. " Heal"
            elseif isPlayer then
                healAmount, playerName = tonumber(matches[2]), matches[1]
                healType = type .. " Heal"
            elseif isCharm then
                healAmount = tonumber(matches[1])
                charmName = #matches == 2 and matches[2] or matches[3]
                healType = "Charm Heal"
            end
            break
        end
    end
    
    if not healAmount then 
        checkAndPrint("messageNotFound", "Nenhum heal encontrado no texto")
        return false 
    end

    -- Determinar nome do heal baseado no tipo
    local healName = nil
    if healType == "Self Heal" then
        healName = "Self"
    elseif healType == "Imbuiments Heal" then
        -- Verificar se é mana ou hitpoints baseado no texto
        if text:find("mana") then
            healName = "Void Leech"
        else
            healName = "Vampirism"
        end
    elseif healType == "PlayerFrom Heal" then
        healName = "From_" .. playerName
    elseif healType == "PlayerTo Heal" then
        healName = "To_" .. playerName
    elseif healType == "Charm Heal" then
        healName = "Charm_" .. charmName
    end

    if not isTable(healIcon) then
        healIcon, healVisibilityIcon = createMainIcon(ICON_HEAL_X_POSITION, ICON_HEAL_Y_POSITION, ICON_HEAL_ID, "heal")
    end

    local success, newFoundCount = processGroup("heal", healName, healAmount, healPatterns, 
        {x = ICON_HEAL_X_POSITION, y = ICON_HEAL_Y_POSITION}, heals, healsFound)
    if success then healsFound = newFoundCount end

    -- Se for um charm de cura, também processar no sistema de charms
    if healType == "Charm Heal" then
        -- Configurar cooldown para charm
        local charmCooldownData = getCooldownData("charm", charmName)
        
        -- Processar ativação no sistema de charms
        local charmSuccess = processActivation(charms, charmName, healAmount, charmCooldownData)
        if charmSuccess then
            -- Atualizar variáveis de cooldown globais para charm
            updateGlobalCooldown("charm", charmName, charmCooldownData)

            -- Criar texto do HUD para charm
            local charmTimeElapsed = getTimeElapsedString(charms[charmName].first)
            local charmHudText = createHudText(charmName, charms[charmName], healAmount, charmTimeElapsed, "charm")
            
            -- Criar ou atualizar HUD do charm
            charmsFound = createOrUpdateHud(charms, charmName, ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION, charmsFound, charmHudText, "charm")
        end
    end

    return true
end

-- Função genérica para detectar tiers
local function detectTiers(text, lastDamage)
    local tierDetections = {
        {pattern = "critical attack", name = "Critical", requiresMyAttack = true},
        {pattern = "Ruse", name = "Ruse", requiresMyAttack = false},
        {pattern = "You dodged", name = "Dodge", requiresMyAttack = false},
        {pattern = "You dodge", name = "Dodge", requiresMyAttack = false},
        {pattern = "Momentum", name = "Momentum", requiresMyAttack = false},
        {pattern = "Transcendance", name = "Transcendence", requiresMyAttack = false},
        {pattern = "Transcendence", name = "Transcendence", requiresMyAttack = false},
        {pattern = "transcendenced", name = "Transcendence", requiresMyAttack = false},
        {pattern = "transcended", name = "Transcendence", requiresMyAttack = false},
        {pattern = "Onslaught", name = "Fatal", requiresMyAttack = true},
        {pattern = "Perfect Shot", name = "Perfect Shot", requiresMyAttack = true},
        {pattern = "active prey bonus", name = "Active Prey", requiresMyAttack = true},
        {pattern = "Runic Mastery", name = "Runic Mastery", requiresMyAttack = true},
        {pattern = "damage reflection", name = "Reflection", requiresMyAttack = true},
        {pattern = "Amplified", name = "Amplify", requiresMyAttack = false}
    }
    
    local myAttack = text:find("your")
    
    for _, detection in ipairs(tierDetections) do
        if text:find(detection.pattern) and (not detection.requiresMyAttack or myAttack) then
            findTiersProcs(detection.name, lastDamage)
            return true
        end
    end
    
    return false
end

Game.registerEvent(Game.Events.TEXT_MESSAGE, function(data)
    -- Processar charms e heals primeiro
    if findCharmsProc(data.text) or findHealsProc(data.text) then return end

    -- Verificar versão do bot para tiers
    if getBotVersion() < 1712 then
        Client.showMessage("Please update your zerobot version to 1.7.1.2 to get tiers metrics \nPor favor, atualize sua versao do zerobot para 1.7.1.2 para obter as metricas de tier")
        return
    end

    -- Detectar tiers
    local lastDamage = tonumber(data.text:match("(%d+) hitpoints?.*") or 0)
    detectTiers(data.text, lastDamage)
end)

-- Sistema de eventos para drag (muito mais eficiente que timer)
local saveTimer = nil
local SAVE_DELAY = 2000  -- 2 segundos de delay para salvar
local lastSavedPositions = {
    charm = { x = ICON_CHARM_X_POSITION, y = ICON_CHARM_Y_POSITION },
    tier = { x = ICON_TIER_X_POSITION, y = ICON_TIER_Y_POSITION },
    heal = { x = ICON_HEAL_X_POSITION, y = ICON_HEAL_Y_POSITION }
}

-- Função para salvar posições com delay (só se a posição mudou)
local function scheduleSave(iconType, currentPos)
    if saveTimer then
        saveTimer:stop()
    end
    
    saveTimer = Timer.new("delayed-save", function()
        -- Só salva se a posição realmente mudou
        local lastPos = lastSavedPositions[iconType:lower()]
        if currentPos.x ~= lastPos.x or currentPos.y ~= lastPos.y then
            local mainFilename = "Charms2.0.lua"
            saveIconPosition(mainFilename, currentPos, "ICON_" .. iconType)
            lastSavedPositions[iconType:lower()] = { x = currentPos.x, y = currentPos.y }
            
            -- Atualizar variáveis globais de posição
            if iconType == "CHARM" then
                ICON_CHARM_X_POSITION = currentPos.x
                ICON_CHARM_Y_POSITION = currentPos.y
            elseif iconType == "TIER" then
                ICON_TIER_X_POSITION = currentPos.x
                ICON_TIER_Y_POSITION = currentPos.y
            elseif iconType == "HEAL" then
                ICON_HEAL_X_POSITION = currentPos.x
                ICON_HEAL_Y_POSITION = currentPos.y
            end
            
            print("[DEBUG] Posição do ícone " .. iconType .. " salva: " .. currentPos.x .. ", " .. currentPos.y)
        end
        
        saveTimer = nil
    end, SAVE_DELAY, false)
    
    saveTimer:start()
end

-- Função para reposicionar HUDs quando ícone é arrastado
local function repositionHUDs(iconType, currentPos, data, visibilityIcon)
    print("[DEBUG] " .. iconType .. " - Detectado arrasto! Reposicionando HUDs...")
    local index = 0
    for name, item in pairs(data) do
        if item.hud.text and item.hud.text.setPos then
            local newX = currentPos.x - 35
            local newY = currentPos.y + 40 + (15 * index)
            print("[DEBUG] " .. iconType .. " - Reposicionando HUD " .. name .. " para: " .. newX .. ", " .. newY)
            setPos(item.hud.text, newX, newY)
            
            -- Garantir que o HUD permaneça visível após reposicionamento
            if item.hud.text.setVisible then
                local groupVisible = (iconType == "CHARM" and charmGroupVisible) or 
                                   (iconType == "TIER" and tierGroupVisible) or 
                                   (iconType == "HEAL" and healGroupVisible)
                item.hud.text:setVisible(groupVisible)
                print("[DEBUG] " .. iconType .. " - HUD " .. name .. " visibilidade: " .. tostring(groupVisible))
            end
        end
        index = index + 1
    end
    
    -- Reposicionar ícone de visibilidade
    if visibilityIcon then
        manageVisibilityIcon(iconType == "CHARM" and charmIcon or iconType == "TIER" and tierIcon or healIcon, nil, visibilityIcon)
    end
end

-- Sistema de eventos para drag
Game.registerEvent(Game.Events.HUD_DRAG, function(hudId, x, y)
    local iconType = nil
    local data = nil
    local visibilityIcon = nil
    
    -- Identificar qual ícone foi arrastado
    if charmIcon and hudId == charmIcon:getId() then
        iconType = "CHARM"
        data = charms
        visibilityIcon = charmVisibilityIcon
    elseif tierIcon and hudId == tierIcon:getId() then
        iconType = "TIER"
        data = tiers
        visibilityIcon = tierVisibilityIcon
    elseif healIcon and hudId == healIcon:getId() then
        iconType = "HEAL"
        data = heals
        visibilityIcon = healVisibilityIcon
    end
    
    if iconType and data then
        local currentPos = {x = x, y = y}
        print("[DEBUG] " .. iconType .. " - Posição atual: " .. currentPos.x .. ", " .. currentPos.y)
        
        -- Reposicionar HUDs imediatamente
        repositionHUDs(iconType, currentPos, data, visibilityIcon)
        
        -- Agendar salvamento com delay
        scheduleSave(iconType, currentPos)
    end
end)
-- Nexus scripts / Charm/Tier/Heal Proc Tracker --


function getBotVersion()
    local s = Engine.getBotVersion() or ""
    local numbers = {}
    for number in s:gmatch("%d+") do
        table.insert(numbers, tonumber(number))
    end

    return tonumber(table.concat(numbers, "")) or 0
end


-- HUD para teste de padrões
local testHUD = nil

if ActiveTestHud then
    testHUD = HUD.new(50, 50, "Test Charm Patterns", true)
    testHUD:setColor(255, 255, 0)
    testHUD:setFontSize(12)
    testHUD:setCallback(function() 
        runAllTests()
    end)
end
 