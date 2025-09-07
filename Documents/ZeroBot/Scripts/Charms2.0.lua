-- ================================================================
-- NEXUS SCRIPTS / Charm/Tier Proc Tracker v2.0
-- ================================================================
-- UPDATE By Mousquer
-- UPDATE by TheCrusty

-- DESCRIÇÃO:
-- Script para rastrear ativações de Charms e Tiers no Tibia
-- Exibe estatísticas em tempo real: contagem, previsão por hora,
-- dano mínimo, máximo e médio, tempo decorrido

-- FUNCIONALIDADES:
-- ✅ Rastreamento de Charms (Low Blow, Savage Blow, etc.)
-- ✅ Rastreamento de Tiers (Critical, Fatal, etc.)
-- ✅ Sistema de cooldown configurável
-- ✅ HUDs arrastáveis com posições salvas automaticamente
-- ✅ Estatísticas detalhadas de dano
-- ✅ Previsão de ativações por hora
-- ✅ Validação robusta de dados
-- ✅ Tratamento de erros aprimorado

-- REQUISITOS:
-- - ZeroBot versão 1.7.1.2 ou superior (para métricas de tier)
-- - Resolução mínima: 800x600 (com fallback automático)

-- ================================================================
-- CONFIGURAÇÕES E VARIÁVEIS GLOBAIS
-- ================================================================

-- Posições dos ícones (serão ajustadas automaticamente para resoluções menores)
local ICON_CHARM_X_POSITION = 1025
local ICON_CHARM_Y_POSITION = 915
local ICON_CHARM_ID = 36726

local ICON_TIER_X_POSITION = 478
local ICON_TIER_Y_POSITION = 955
local ICON_TIER_ID = 30278

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
    "You deal 400 hitpoints. (freeze charm)"
}
 -- Controla quais informações são exibidas no HUD quando disponiveis
local VisibleInfo = {
    tier = {
        tier = true,
        ativacoes = true,
        previsao = true,
        danoMinimo = true,
        danoMedio = true,
        danoMaximo = true,
        tempoDecorrido = false,
    },
    charm = {
        charm = true,
        ativacoes = true,
        previsao = true,
        danoMinimo = true,
        danoMedio = true,
        danoMaximo = true,
        tempoDecorrido = false,
    }
}

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

-- DO NOT TOUCH BELOW THIS LINE // NÃO TOQUE ABAIXO DESTA LINHA --
-- ON HUD DRAG IT WILL SAVE THE NEW POSITION TO THE FILE --
-- APÓS MOVER O ÍCONE A NOVA POSIÇÃO SERÁ SALVA --


-- ================================================================
-- INICIALIZAÇÃO E CONFIGURAÇÃO AUTOMÁTICA
-- ================================================================

-- fallback para resolução menor
if Client.getGameWindowDimensions().width < ICON_CHARM_X_POSITION then ICON_CHARM_X_POSITION = 155 end
if Client.getGameWindowDimensions().width < ICON_TIER_X_POSITION then ICON_TIER_X_POSITION = 165 end

if Client.getGameWindowDimensions().height < ICON_CHARM_Y_POSITION then ICON_CHARM_Y_POSITION = 155 end
if Client.getGameWindowDimensions().height < ICON_TIER_Y_POSITION then ICON_TIER_Y_POSITION = 165 end

local charms = {}
local charmsFound = 0
local lowblowCooldown = 0.5
local savageblowCooldown = 0.5
local lastLowblow = 0
local lastSavageblow = 0

local tiers = {}
local tiersFound = 0
local criticalCooldown = 0.5
local lastCritical = 0
local onslaughtCooldown = 0.5
local lastOnslaught = 0

local charmIcon = nil
local charmIconLastPos = nil
local tierIcon = nil
local tierIconLastPos = nil
local oneHourInSeconds = 3600

-- ================================================================
-- FUNÇÕES AUXILIARES
-- ================================================================

-- Função para controle de debug e logging
-- @param class: classe de debug (erros, messageCheck, etc.)
-- @param message: mensagem a ser exibida
local function checkAndPrint(class, message)
    if not print_ativo or not class or not message then
        return
    end
    
    if print_ativo[class] then
        print("[DEBUG:" .. class:upper() .. "] " .. tostring(message))
    end
end

-- Função para controlar o sistema de debug
-- @param class: classe de debug a controlar
-- @param enabled: true para ativar, false para desativar
local function setDebugMode(class, enabled)
    if print_ativo and print_ativo[class] ~= nil then
        print_ativo[class] = enabled
        print("[DEBUG] " .. class .. " " .. (enabled and "ATIVADO" or "DESATIVADO"))
    end
end

-- Função para ativar/desativar todos os debugs
-- @param enabled: true para ativar tudo, false para desativar tudo
local function setAllDebugModes(enabled)
    for class, _ in pairs(print_ativo) do
        print_ativo[class] = enabled
    end
    print("[DEBUG] Todos os modos de debug " .. (enabled and "ATIVADOS" or "DESATIVADOS"))
end


local function isTable(t)
    return type(t) == 'table'
end

local function hasDragged(currentPos, lastPos)
    return currentPos.x ~= lastPos.x or currentPos.y ~= lastPos.y
end

local function setPos(hud, x, y)
    hud:setPos(x, y)
end

local function getThisFilename()
    local filename = debug.getinfo(1).source:gsub("Scripts/", "")
    return filename
end

local filename = getThisFilename()

local function openFile(path, mode)
    if not path or type(path) ~= "string" then
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

-- ================================================================
-- FUNÇÕES DE UTILITÁRIOS
-- ================================================================

local function createHud(x, y, text)
    local hud = HUD.new(x, y, text, true)
    hud:setColor(0, 250, 154)
    hud:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    return hud
end

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

-- ================================================================
-- FUNÇÕES DE GERENCIAMENTO DE COOLDOWN
-- ================================================================

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

-- Função genérica para configurar cooldown baseado no tipo
local function getCooldownData(type, name)
    if type == "charm" then
        if name == "Low Blow" then
            return { lastTime = lastLowblow, cooldown = lowblowCooldown }
        elseif name == "Savage Blow" then
            return { lastTime = lastSavageblow, cooldown = savageblowCooldown }
        end
    elseif type == "tier" then
        if name == "Critical" then
            return { lastTime = lastCritical, cooldown = criticalCooldown }
        elseif name == "Fatal" then
            return { lastTime = lastOnslaught, cooldown = onslaughtCooldown }
        end
    end
    return nil
end

-- Função genérica para atualizar variáveis de cooldown globais
local function updateGlobalCooldown(type, name, cooldownData)
    if not cooldownData then return end
    
    if type == "charm" then
        if name == "Low Blow" then
            lastLowblow = cooldownData.lastTime
        elseif name == "Savage Blow" then
            lastSavageblow = cooldownData.lastTime
        end
    elseif type == "tier" then
        if name == "Critical" then
            lastCritical = cooldownData.lastTime
        elseif name == "Fatal" then
            lastOnslaught = cooldownData.lastTime
        end
    end
end

-- ================================================================
-- FUNÇÕES DE CÁLCULO DE ESTATÍSTICAS
-- ================================================================

-- Calcula estatísticas de dano (média, maior, menor)
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
        return charm
    end

    -- Atualizar maior e menor dano de forma mais eficiente
    if lastDamage > charm.higher then
        charm.higher = lastDamage
    end
    
    if lastDamage < charm.lowest then
        charm.lowest = lastDamage
    end

    -- Calcular média de forma mais eficiente
    local sum = 0
    local count = #charm.damages
    for i = 1, count do
        sum = sum + charm.damages[i]
    end

    -- Usar math.floor para melhor performance que string.format
    charm.average = math.floor((sum / count) * 100) / 100
    return charm
end

-- ================================================================
-- FUNÇÕES DE PROCESSAMENTO DE ATIVAÇÕES
-- ================================================================

-- Processa ativação de charm ou tier com validação e estatísticas
-- @param data: tabela de dados (charms ou tiers)
-- @param name: nome do charm/tier
-- @param damage: dano causado
-- @param cooldownData: dados de cooldown (opcional)
-- @return: true se processado com sucesso, false se em cooldown
local function processActivation(data, name, damage, cooldownData)
    -- Validar parâmetros de entrada
    if not data or type(data) ~= "table" then
        checkAndPrint("erros", "Erro: data deve ser uma tabela")
        return false
    end
    
    if not name or type(name) ~= "string" or name == "" then
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
            average = damage
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

-- Função genérica para criar texto do HUD com base nos controles de VisibleInfo
local function createHudText(name, data, damage, timeElapsed, type)
    local inAHour = data.inAHour
    local activationParts = {}
    local damageParts = {}
    local timeParts = {}
    
    -- Determinar qual configuração usar (tier ou charm)
    local config = VisibleInfo[type] or VisibleInfo.charm
    
    -- Nome do item (sempre exibido se habilitado)
    local namePart = ""
    if config[type] then
        namePart = "[" .. name .. "]"
    end
    
    -- Bloco de ativações
    if config.ativacoes then
        table.insert(activationParts, "ATIVAÇÕES: " .. data.count)
    end
    
    if config.previsao then
        table.insert(activationParts, "PREV 1H: " .. inAHour)
    end
    
    -- Bloco de dano (apenas se há dano e estão habilitadas)
    if damage > 0 then
        if config.danoMinimo then
            table.insert(damageParts, "LOWEST: " .. data.lowest)
        end
        
        if config.danoMedio then
            table.insert(damageParts, "AVG: " .. string.format("%.1f", data.average))
        end
        
        if config.danoMaximo then
            table.insert(damageParts, "HIGHER: " .. data.higher)
        end
    end
    
    -- Bloco de tempo
    if config.tempoDecorrido then
        table.insert(timeParts, "TEMPO: " .. timeElapsed)
    end
    
    -- Construir o texto final
    local finalParts = {}
    
    -- Adicionar nome se disponível
    if namePart ~= "" then
        table.insert(finalParts, namePart)
    end
    
    -- Adicionar bloco de ativações se disponível
    if #activationParts > 0 then
        table.insert(finalParts, table.concat(activationParts, " | "))
    end
    
    -- Adicionar bloco de dano se disponível
    if #damageParts > 0 then
        table.insert(finalParts, table.concat(damageParts, " | "))
    end
    
    -- Adicionar bloco de tempo se disponível
    if #timeParts > 0 then
        table.insert(finalParts, table.concat(timeParts, " | "))
    end
    
    -- Se não há partes para exibir, retornar mensagem padrão
    if #finalParts == 0 then
        return "[" .. name .. "]: Nenhuma informação habilitada"
    end
    
    -- Juntar blocos com separador " - "
    return table.concat(finalParts, " - ")
end

-- Função genérica para criar ou atualizar HUD
local function createOrUpdateHud(data, name, iconX, iconY, foundCount, hudText)
    if not data[name].hud.text then
        local x = iconX - 35
        local y = iconY + 40 + (15 * foundCount)
        data[name].hud.text = createHud(x, y, hudText)
        return foundCount + 1
    else
        data[name].hud.text:setText(hudText)
        return foundCount
    end
end

-- Função para salvar posição do ícone no arquivo
local function saveIconPosition(name, value, which)
    if not name or not value or not which then
        checkAndPrint("erros", "Erro: parâmetros inválidos para saveIconPosition")
        return false
    end
    
    local path = Engine.getScriptsDirectory() .. "/" .. name
    local file = openFile(path, "r")
    if not file then
        checkAndPrint("erros", "Erro: não foi possível abrir arquivo para leitura")
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
        checkAndPrint("erros", "Erro: não foi possível ler conteúdo do arquivo")
        return false
    end

    local X = which .. "_X_POSITION = "
    local Y = which .. "_Y_POSITION = "

    local currentXValue = content:match(X .. "(%d+)")
    local currentYValue = content:match(Y .. "(%d+)")
    
    if not currentXValue or not currentYValue then
        checkAndPrint("erros", "Erro: não foi possível encontrar posições no arquivo")
        return false
    end
    
    local modifiedContent = content:gsub(X .. currentXValue, X .. value.x)
    modifiedContent = modifiedContent:gsub(Y .. currentYValue, Y .. value.y)

    file = openFile(path, "w")
    if not file then
        checkAndPrint("erros", "Erro: não foi possível abrir arquivo para escrita")
        return false
    end
    
    local success = file:write(modifiedContent)
    file:close()
    
    if not success then
        checkAndPrint("erros", "Erro: não foi possível escrever no arquivo")
        return false
    end
    
    return true
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
    if not text or type(text) ~= "string" then
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
    local damage = tonumber(text:match("(%d+) hitpoints") or 
                           text:match("(%d+) mana") or 
                           text:match("(%d+) damage") or 
                           text:match("deal (%d+)") or 
                           0)
    
    -- print("Dano extraído: " .. damage .. " do texto: " .. text)

    if not isTable(charmIcon) then
        charmIcon = HUD.new(ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION, ICON_CHARM_ID, true)
        charmIcon:setDraggable(true)
        charmIcon:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    end

    -- Configurar cooldown baseado no tipo de charm
    local cooldownData = getCooldownData("charm", charm)

    -- Processar ativação usando função genérica
    local success = processActivation(charms, charm, damage, cooldownData)
    if not success then return false end

    -- Atualizar variáveis de cooldown globais
    updateGlobalCooldown("charm", charm, cooldownData)

    -- Criar texto do HUD
    local timeElapsed = getTimeElapsedString(charms[charm].first)
    local hudText = createHudText(charm, charms[charm], damage, timeElapsed, "charm")
    
    -- Criar ou atualizar HUD
    charmsFound = createOrUpdateHud(charms, charm, ICON_CHARM_X_POSITION, ICON_CHARM_Y_POSITION, charmsFound, hudText)

    return true
end

-- Função de teste para verificar padrões de charms
local function testCharmPatterns()
    checkAndPrint("testProgram", "=== TESTE DE PADRÕES DE CHARMS ===")
    for i, testMsg in ipairs(testMessages) do
        checkAndPrint("testProgram", "\n--- Teste " .. i .. " ---")
        checkAndPrint("testProgram", "Mensagem: " .. testMsg)
        
        local result = findCharmsProc(testMsg)
        checkAndPrint("testProgram", "Resultado: " .. (result and "SUCESSO" or "FALHOU"))
        if result then
            checkAndPrint("testProgram", "Formato de exibição:")
            checkAndPrint("testProgram", "  Com dano: [Charm]: ATIVAÇÕES: X | PREV 1H: Y | LOWEST: Z | AVG: W | HIGHER: V | TEMPO: U")
            checkAndPrint("testProgram", "  Sem dano: [Charm]: ATIVAÇÕES: X | PREV 1H: Y | TEMPO: Z")
        end
    end
    checkAndPrint("testProgram", "\n=== FIM DO TESTE ===")
end

-- Função de teste para verificar diferentes configurações de VisibleInfo
local function testVisibleInfoConfigurations()
    checkAndPrint("testProgram", "=== TESTE DE CONFIGURAÇÕES VisibleInfo ===")
    
    -- Dados de teste simulados
    local testData = {
        count = 5,
        first = os.time() - 300, -- 5 minutos atrás
        inAHour = 60,
        damages = {100, 150, 200, 120, 180},
        higher = 200,
        lowest = 100,
        average = 150
    }
    
    local testDamage = 150
    local testTimeElapsed = "5m 0s"
    
    -- Teste 1: Todas as informações habilitadas
    checkAndPrint("testProgram", "\n--- Teste 1: Todas habilitadas ---")
    local originalConfig = VisibleInfo.charm
    VisibleInfo.charm = {
        charm = true,
        ativacoes = true,
        previsao = true,
        danoMinimo = true,
        danoMedio = true,
        danoMaximo = true,
        tempoDecorrido = true
    }
    local result1 = createHudText("Low Blow", testData, testDamage, testTimeElapsed, "charm")
    checkAndPrint("testProgram", "Resultado: " .. result1)
    
    -- Teste 2: Apenas ativações e previsão
    checkAndPrint("testProgram", "\n--- Teste 2: Apenas ativações e previsão ---")
    VisibleInfo.charm = {
        charm = true,
        ativacoes = true,
        previsao = true,
        danoMinimo = false,
        danoMedio = false,
        danoMaximo = false,
        tempoDecorrido = false
    }
    local result2 = createHudText("Low Blow", testData, testDamage, testTimeElapsed, "charm")
    checkAndPrint("testProgram", "Resultado: " .. result2)
    
    -- Teste 3: Apenas informações de dano
    checkAndPrint("testProgram", "\n--- Teste 3: Apenas informações de dano ---")
    VisibleInfo.charm = {
        charm = true,
        ativacoes = false,
        previsao = false,
        danoMinimo = true,
        danoMedio = true,
        danoMaximo = true,
        tempoDecorrido = false
    }
    local result3 = createHudText("Low Blow", testData, testDamage, testTimeElapsed, "charm")
    checkAndPrint("testProgram", "Resultado: " .. result3)
    
    -- Teste 4: Nenhuma informação habilitada
    checkAndPrint("testProgram", "\n--- Teste 4: Nenhuma informação habilitada ---")
    VisibleInfo.charm = {
        charm = false,
        ativacoes = false,
        previsao = false,
        danoMinimo = false,
        danoMedio = false,
        danoMaximo = false,
        tempoDecorrido = false
    }
    local result4 = createHudText("Low Blow", testData, testDamage, testTimeElapsed, "charm")
    checkAndPrint("testProgram", "Resultado: " .. result4)
    
    -- Restaurar configuração original
    VisibleInfo.charm = originalConfig
    checkAndPrint("testProgram", "\n=== FIM DO TESTE VisibleInfo ===")
end

local function findTiersProcs(tier, lastDamage)
    if not isTable(tierIcon) then
        tierIcon = HUD.new(ICON_TIER_X_POSITION, ICON_TIER_Y_POSITION, ICON_TIER_ID, true)
        tierIcon:setDraggable(true)
        tierIcon:setHorizontalAlignment(Enums.HorizontalAlign.Left)
    end

    -- Configurar cooldown baseado no tipo de tier
    local cooldownData = getCooldownData("tier", tier)

    -- Processar ativação usando função genérica
    local success = processActivation(tiers, tier, lastDamage, cooldownData)
    if not success then return end

    -- Atualizar variáveis de cooldown globais
    updateGlobalCooldown("tier", tier, cooldownData)

    -- Criar texto do HUD
    local timeElapsed = getTimeElapsedString(tiers[tier].first)
    local hudText = createHudText(tier, tiers[tier], lastDamage, timeElapsed, "tier")
    
    -- Criar ou atualizar HUD
    tiersFound = createOrUpdateHud(tiers, tier, ICON_TIER_X_POSITION, ICON_TIER_Y_POSITION, tiersFound, hudText)
end

Game.registerEvent(Game.Events.TEXT_MESSAGE, function(data)
    local procCharm = findCharmsProc(data.text)
    if procCharm then return end

    if getBotVersion() < 1712 then
        Client.showMessage(
            "Please update your zerobot version to 1.7.1.2 to get tiers metrics \nPor favor, atualize sua versao do zerobot para 1.7.1.2 para obter as metricas de tier")
        return
    end

    local myAttack = data.text:find("your")
    local ruse = data.text:find("Ruse") and "Ruse" or nil
    local dodge = data.text:find("You dodged") or data.text:find("You dodge") and "Dodge" or nil
    local momentum = data.text:find("Momentum") and "Momentum" or nil
    local transcendence = (data.text:find("Transcendance") or data.text:find("Transcendence") or data.text:find("transcendenced")) and "Transcendence" or nil
    local onslaught = myAttack and data.text:find("Onslaught") and "Fatal" or nil
    local perfectShot = myAttack and data.text:find("Perfect Shot") and "Perfect Shot" or nil
    local runicMastery = myAttack and data.text:find("Runic Mastery") and "Runic Mastery" or nil
    local reflection = myAttack and data.text:find("damage reflection") and "Reflection" or nil
    local critical = myAttack and data.text:find("critical attack") and "Critical" or nil
    local amplify = data.text:find("Amplified") and "Amplified" or nil


    local lastDamage = tonumber(data.text:match("(%d+) hitpoints") or 0)

    if critical then
        findTiersProcs("Critical", lastDamage)
    end

    if ruse or dodge then
        findTiersProcs("Ruse", lastDamage)
    end

    if amplify then
        findTiersProcs("Amplify", lastDamage)
    end

    local tier = momentum or onslaught or transcendence or perfectShot or runicMastery or reflection or amplify
    if not tier then return end
    findTiersProcs(tier, lastDamage)
end)

Timer.new("handle-charm-hud", function()
    if not charmIcon or not isTable(charmIcon) then return end
    if isTable(charmIcon) and not isTable(charmIconLastPos) then
        charmIconLastPos = charmIcon:getPos()
    end

    local currentIconPos = charmIcon:getPos()
    if hasDragged(currentIconPos, charmIconLastPos) then
        charmIconLastPos = currentIconPos
        local index = 0
        for _, charm in pairs(charms) do
            setPos(charm.hud.text, currentIconPos.x - 35, currentIconPos.y + 40 + (15 * index))
            index = index + 1
        end

        saveIconPosition(filename, currentIconPos, "ICON_CHARM")
        ICON_CHARM_X_POSITION = currentIconPos.x
        ICON_CHARM_Y_POSITION = currentIconPos.y
    end
end, 1000)

Timer.new("handle-tier-hud", function()
    if not tierIcon or not isTable(tierIcon) then return end
    if isTable(tierIcon) and not isTable(tierIconLastPos) then
        tierIconLastPos = tierIcon:getPos()
    end

    local currentIconPos = tierIcon:getPos()
    if hasDragged(currentIconPos, tierIconLastPos) then
        tierIconLastPos = currentIconPos
        local index = 0
        for _, tier in pairs(tiers) do
            setPos(tier.hud.text, currentIconPos.x - 35, currentIconPos.y + 40 + (15 * index))
            index = index + 1
        end

        saveIconPosition(filename, currentIconPos, "ICON_TIER")
        ICON_TIER_X_POSITION = currentIconPos.x
        ICON_TIER_Y_POSITION = currentIconPos.y
    end
end, 1000)
-- Nexus scripts / Charm/Tier Proc Tracker --


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
        testCharmPatterns() 
        testVisibleInfoConfigurations()
    end)
end
 