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
    if not mainIcon then return nil end
    
    local mainPos = mainIcon:getPos()
    local mainX, mainY = mainPos.x, mainPos.y
    local visibilityX = mainX + VISIBILITY_ICON_OFFSET
    local visibilityY = mainY
    
    if not visibilityIcon then
        -- Criar novo ícone
        visibilityIcon = HUD.new(visibilityX, visibilityY, VISIBILITY_ICON_ID, true)
        visibilityIcon:setDraggable(false)
        visibilityIcon:setHorizontalAlignment(Enums.HorizontalAlign.Left)
        visibilityIcon:setScale(VISIBILITY_ICON_SCALE)
    else
        -- Atualizar posição existente
        visibilityIcon:setPos(visibilityX, visibilityY)
    end
    
    return visibilityIcon
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
    local visibilityIcon = manageVisibilityIcon(mainIcon, groupType)
    if visibilityIcon then
        visibilityIcon:setCallback(function()
            toggleGroupVisibility(groupType)
        end)
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


-- Função genérica para lidar com arrastar ícones
local function handleIconDrag(iconType, icon, lastPos, iconX, iconY, visibilityIcon, data)
    if not icon or not isTable(icon) then return end
    if not lastPos then
        lastPos = icon:getPos()
    end

    local currentIconPos = icon:getPos()
    if hasDragged(currentIconPos, lastPos) then
        lastPos = currentIconPos
        local index = 0
        for _, item in pairs(data) do
            setPos(item.hud.text, currentIconPos.x - 35, currentIconPos.y + 40 + (15 * index))
            index = index + 1
        end

        saveIconPosition(filename, currentIconPos, "ICON_" .. iconType)
        iconX = currentIconPos.x
        iconY = currentIconPos.y
        
        -- Reposicionar ícone de visibilidade
        manageVisibilityIcon(icon, nil, visibilityIcon)
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
    
    print("[" .. groupType:upper() .. "] Grupo de " .. config.name .. " " .. 
          (groupType == "charm" and charmGroupVisible or groupType == "tier" and tierGroupVisible or healGroupVisible) and "visível" or "oculto")
    
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

-- Função para atualizar todos os HUDs existentes
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

local function updateAllHuds()
    local dataGroups = {
        {data = charms, type = "charm", visible = charmGroupVisible},
        {data = tiers, type = "tier", visible = tierGroupVisible},
        {data = heals, type = "heal", visible = healGroupVisible}
    }
    
    for _, group in ipairs(dataGroups) do
        for name, item in pairs(group.data) do
            if item.hud.text then
                local timeElapsed = getTimeElapsedString(item.first)
                local hudText = createHudText(name, item, item.damages[#item.damages] or 0, timeElapsed, group.type)
                item.hud.text:setText(hudText)
                item.hud.text:setVisible(group.visible)
            end
        end
    end
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
    
    -- Aplicar nova configuração
    VisibleInfo.tier = VisibilityConfigs[currentVisibilityConfig].tier
    VisibleInfo.charm = VisibilityConfigs[currentVisibilityConfig].charm
    VisibleInfo.heal = VisibilityConfigs[currentVisibilityConfig].heal
    
    -- Atualizar todos os HUDs existentes
    updateAllHuds()
    
    print("[CHARMS] Configuração alterada para: " .. currentVisibilityConfig)
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

-- ================================================================
-- FUNÇÕES AUXILIARES E UTILITÁRIAS
-- ================================================================

-- Funções utilitárias básicas
local function isTable(t) return type(t) == 'table' end
local function hasDragged(currentPos, lastPos) return currentPos.x ~= lastPos.x or currentPos.y ~= lastPos.y end
local function setPos(hud, x, y) hud:setPos(x, y) end
local function getThisFilename() return debug.getinfo(1).source:gsub("Scripts/", "") end

-- Função genérica de validação
local function validateInput(value, expectedType, allowEmpty)
    if not value then return false end
    if type(value) ~= expectedType then return false end
    if not allowEmpty and (expectedType == "string" and value == "") then return false end
    return true
end

-- Sistema de debug e logging
local function checkAndPrint(class, message)
    if not print_ativo or not class or not message then return end
    if print_ativo[class] then
        print("[DEBUG:" .. class:upper() .. "] " .. tostring(message))
    end
end

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

local function createHud(x, y, text)
    local hud = HUD.new(x, y, text, true)
    hud:setColor(TEXT_COLOR.R, TEXT_COLOR.G, TEXT_COLOR.B)
    hud:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    return hud
end

-- ================================================================
-- FUNÇÕES DE GERENCIAMENTO DE COOLDOWN
-- ================================================================


-- Função genérica para atualizar variáveis de cooldown globais
local function updateGlobalCooldown(type, name, cooldownData)
    if not cooldownData then return end
    
    if cooldowns[type] and cooldowns[type][name] then
        cooldowns[type][name].lastTime = cooldownData.lastTime
    elseif type == "heal" and cooldowns.heal.default then
        cooldowns.heal.default.lastTime = cooldownData.lastTime
    end
end

-- ================================================================
-- FUNÇÕES DE CÁLCULO DE ESTATÍSTICAS
-- ================================================================

-- ================================================================
-- FUNÇÕES DE PROCESSAMENTO DE ATIVAÇÕES
-- ================================================================


-- Função genérica para criar ou atualizar HUD
local function createOrUpdateHud(data, name, iconX, iconY, foundCount, hudText, type)
    if not data[name].hud.text then
        local x = iconX - 35
        local y = iconY + 40 + (15 * foundCount)
        data[name].hud.text = createHud(x, y, hudText)
        
        -- Adicionar callback para zerar contador
        data[name].hud.text:setCallback(function()
            resetCounter(type, name)
        end)
        
        -- Aplicar visibilidade do grupo
        local groupVisibility = (type == "charm" and charmGroupVisible) or 
                               (type == "tier" and tierGroupVisible) or 
                               (type == "heal" and healGroupVisible)
        data[name].hud.text:setVisible(groupVisibility)
        
        return foundCount + 1
    else
        data[name].hud.text:setText(hudText)
        return foundCount
    end
end

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

-- Timer unificado para todos os ícones
Timer.new("handle-all-huds", function()
    handleIconDrag("CHARM", charmIcon, charmIconLastPos, ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION, charmVisibilityIcon, charms)
    handleIconDrag("TIER", tierIcon, tierIconLastPos, ICON_TIER_X_POSITION, ICON_TIER_Y_POSITION, tierVisibilityIcon, tiers)
    handleIconDrag("HEAL", healIcon, healIconLastPos, ICON_HEAL_X_POSITION, ICON_HEAL_Y_POSITION, healVisibilityIcon, heals)
end, 1000)
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
 