-- ================================================================
-- Fiendish/Influenced Creature Finder v1.0
-- ================================================================
-- VERSION v1.0 - Advanced Creature Detection System by The Crusty
    --- Optimized Drag Handler
    --- Delayed Save System
    --- Performance Improvements
    --- Recursion Prevention
    --- Advanced HUD Management
    --- Multi-Creature Support

-- DESCRIÇÃO:
-- Script para detectar criaturas Influenciadas ou Fiendish e criar HUDs
-- Sistema de HUD arrastável com posições salvas automaticamente
-- Detecção inteligente com auto-destruição e reorganização automática

-- FUNCIONALIDADES:
-- ✅ Detecção automática de criaturas Influenciadas/Fiendish
-- ✅ HUDs arrastáveis com posições salvas automaticamente
-- ✅ Sistema de auto-destruição após 1s de delay
-- ✅ Suporte para múltiplos monstros com posicionamento automático
-- ✅ Interface visual com ícone, outfit e label
-- ✅ Salvamento inteligente com delay
-- ✅ Prevenção de recursividade
-- ✅ Sistema de debug avançado
-- ✅ Tratamento robusto de erros

-- REQUISITOS:
-- - Resolução mínima: 800x600 (com fallback automático)

-- ================================================================
-- CONFIGURAÇÕES E FLAGS DE DEBUG
-- ================================================================
print("\n\nScript findCreatureFiendshorInfluenced carregado\n\n")

-- Flags de Debug (true = ativado, false = desativado)
local DEBUG_FLAGS = {
    GENERAL = false,        -- Mensagens gerais do script
    CREATURE_INFO = false,  -- Informações detalhadas das criaturas
    HUD_CREATION = false,   -- Debug da criação de HUDs
    TIMER = false,          -- Debug do timer
    CLEANUP = false         -- Debug de limpeza de HUDs
}

-- Configurações do Timer
local TIMER_CONFIG = {
    INTERVAL = 1000,        -- Intervalo em milissegundos (1000ms = 1x por segundo)
    ENABLED = false         -- Se o timer deve estar ativo por padrão
}

-- Configurações dos HUDs
local HUD_CONFIG = {
    NAME = {
        FONT_SIZE = 14,           -- Tamanho da fonte do nome
        COLOR = {255, 255, 0},    -- Cor do nome (R, G, B) - Amarelo
        SPACING = 30              -- Espaçamento entre HUDs em pixels
    },
    OUTFIT = {
        SPACING = 40,             -- Posição X do outfit (esquerda do texto)
        SCALE = 0.9,              -- Escala do outfit (90%)
        ANIMATION = true          -- Se deve ativar animação de movimento
    },
    ICON = {
        SPACING = 40,             -- Posição X do ícone (esquerda do texto)
        SCALE = 1.6,              -- Escala do ícone (160%)
        ICON_ID = 410             -- ID do background a ser usado
    },
    CONTROL = {
        FONT_SIZE = 10,           -- Tamanho da fonte do HUD de controle
        COLOR = {255, 0, 0}       -- Cor do HUD de controle (R, G, B) - Vermelho
    }
}

dofile(Engine.getScriptsDirectory() .. "/_Functions/Y_Support/xyzToPixels.lua")

local soundOn = false

local windowDimensions = Client.getGameWindowDimensions()
local beginPositionMenuHud = {
    x = 118,
    y = 994,
    desloc = {
        ring = { x = 0, y = 0 },
        label = { x = -7, y = 13 },
        hud = { x = 24, y = 0 }
    }
}

-- fallback para resolução menor
if Client.getGameWindowDimensions().width < beginPositionMenuHud.x then beginPositionMenuHud.x = 155 end
if Client.getGameWindowDimensions().height < beginPositionMenuHud.y then beginPositionMenuHud.y = 155 end



-- ========================================
-- FUNÇÕES DE DEBUG
-- ========================================

-- Função para imprimir mensagens de debug baseadas em flags
function printDebug(flag, message)
    if DEBUG_FLAGS[flag] then
        print("DEBUG [" .. flag .. "]: " .. tostring(message))
    end
end

-- ========================================
-- FUNÇÕES DE PERSISTÊNCIA DE POSIÇÕES
-- ========================================

-- Função para obter nome do arquivo atual
local function getThisFilename()
    return debug.getinfo(1).source:gsub("Scripts/", "")
end

-- Função para abrir arquivo com tratamento de erro
local function openFile(path, mode)
    if not path or type(path) ~= "string" then
        printDebug("GENERAL", "Erro: caminho do arquivo inválido")
        return nil
    end
    
    local file = io.open(path, mode)
    if not file then
        printDebug("GENERAL", "Erro ao abrir arquivo: " .. tostring(path))
        return nil
    end

    return file
end

-- Função para salvar posições dos HUDs do menu no arquivo
local function saveMenuPositions()
    local filename = getThisFilename()
    local path = Engine.getScriptsDirectory() .. "/" .. filename
    local file = openFile(path, "r")
    if not file then 
        printDebug("GENERAL", "Erro: não foi possível abrir arquivo para leitura")
        return false 
    end
    
    local content = file:read("*all")
    file:close()
    if not content then 
        printDebug("GENERAL", "Erro: não foi possível ler conteúdo do arquivo")
        return false 
    end

    -- Usar apenas padrão simples que funciona
    local currentX = content:match("x = (%d+),")
    local currentY = content:match("y = (%d+),")
    
    if not currentX or not currentY then 
        printDebug("GENERAL", "Não foi possível encontrar padrões de posição no arquivo")
        printDebug("GENERAL", "X encontrado: " .. tostring(currentX))
        printDebug("GENERAL", "Y encontrado: " .. tostring(currentY))
        return false 
    end

    -- Atualizar posições X e Y
    local newContent = content:gsub("x = " .. currentX .. ",", "x = " .. beginPositionMenuHud.x .. ",")
    newContent = newContent:gsub("y = " .. currentY .. ",", "y = " .. beginPositionMenuHud.y .. ",")
    
    file = openFile(path, "w")
    if not file then 
        printDebug("GENERAL", "Erro: não foi possível abrir arquivo para escrita")
        return false 
    end

    local success = file:write(newContent)
    file:close()
    
    if success then
        printDebug("GENERAL", "Posições do menu salvas: X=" .. beginPositionMenuHud.x .. ", Y=" .. beginPositionMenuHud.y)
    else
        printDebug("GENERAL", "Erro: falha ao escrever no arquivo")
    end
    
    return success
end



-- ========================================
-- SISTEMA DE DRAG HANDLER OTIMIZADO
-- ========================================

local saveTimer = nil
local SAVE_DELAY = 1000  -- 1 segundo de delay para salvar

-- Função para salvar posições com delay
local function scheduleSave()
    if saveTimer then
        saveTimer:stop()
    end
    
    saveTimer = Timer.new("delayed-save", function()
        saveMenuPositions()
        saveTimer = nil
    end, SAVE_DELAY, false)
    
    saveTimer:start()
end

-- Função para reposicionar todos os HUDs baseado na posição base
local function repositionAllHUDs(baseX, baseY)
    beginPositionMenuHud.x = baseX
    beginPositionMenuHud.y = baseY
    
    ring.icon:setPos(baseX + beginPositionMenuHud.desloc.ring.x, 
                    baseY + beginPositionMenuHud.desloc.ring.y)
    ring.label:setPos(baseX + beginPositionMenuHud.desloc.label.x, 
                     baseY + beginPositionMenuHud.desloc.label.y)
    menuHud:setPos(baseX + beginPositionMenuHud.desloc.hud.x, 
                  baseY + beginPositionMenuHud.desloc.hud.y)
    
    scheduleSave()
end

-- ========================================
-- VARIÁVEIS GLOBAIS
-- ========================================

-- Tabela para armazenar HUDs ativos por criatura
local activeHUDs = {}

-- Variável para controlar a posição vertical dos próximos HUDs
local nextHudY = 0

-- Variável de controle do script
local control = false

-- Tabela para armazenar timers de atualização de posição
local positionTimers = {}

-- ========================================
-- FUNÇÕES DE APOIO
-- ========================================
-- Função para TOCAR SOM
function playSound()
    local soundsFolder = Engine.getScriptsDirectory() .. "/Sounds/"
    if soundOn then
        -- print("playSound")
        Sound.play(soundsFolder .. '/ring-tone-68676.mp3')
    end
end 

-- ========================================
-- FUNÇÕES PRINCIPAIS
-- ========================================
-- Função para formatar e posicionar HUDs
function formatCenter(hud, posX, posY, scale)
    hud:setScale(scale or 1)
    hud:setPos(posX or 0, posY or 0)
end

-- Função encapsulada para criar HUD de texto
function createTextHUD(x, y, text, fontSize, color)
    local success, result = pcall(function()
        return HUD.new(0, 0, text, true)  -- Sempre começar em 0,0
    end)
    
    if success and result then
        result:setColor(color[1], color[2], color[3])
        result:setFontSize(fontSize)
        -- Posiciona baseado na largura da janela
        local windowDimensions = Client.getGameWindowDimensions()
        local centerX = windowDimensions and (windowDimensions.width / 2 + HUD_CONFIG.NAME.SPACING ) or 0
        formatCenter(result, centerX, y, 1)
        return result
    end
    return nil
end

-- Função encapsulada para criar HUD de outfit
function createOutfitHUD(x, y, outfitId, scale)
    if not HUD.newOutfit then
        return nil
    end
    
    local success, result = pcall(function()
        return HUD.newOutfit(0, 0, outfitId, true)  -- Sempre começar em 0,0
    end)
    
    if success and result then
        -- Posiciona baseado na largura da janela
        local windowDimensions = Client.getGameWindowDimensions()
        local outfitX = windowDimensions and (windowDimensions.width / 2 - HUD_CONFIG.OUTFIT.SPACING ) or 0
        formatCenter(result, outfitX, y, scale)
        if HUD_CONFIG.OUTFIT.ANIMATION then
            pcall(function()
                result:setOutfitMoving(true)
            end)
        end
        return result
    end
    return nil
end

-- Função encapsulada para criar HUD de ícone
function createIconHUD(x, y, iconId, scale)
    local success, result = pcall(function()
        return HUD.new(0, 0, iconId, true)  -- Sempre começar em 0,0
    end)
    
    if success and result then
        -- Posiciona baseado na largura da janela
        local windowDimensions = Client.getGameWindowDimensions()
        local iconX = windowDimensions and (windowDimensions.width / 2 - HUD_CONFIG.ICON.SPACING ) or 0
        formatCenter(result, iconX, y, scale)
        return result
    end
    return nil
end

-- Função encapsulada para criar HUD de ícone + outfit na mesma posição
function createIconAndOutfitHUD(x, y, iconId, iconScale, outfitId, outfitScale)
    local iconHud = nil
    local outfitHud = nil
    
    -- 1. Cria HUD do ícone primeiro (posição baseada na largura da janela)
    iconHud = createIconHUD(x, y, iconId, iconScale)
    
    -- 2. Cria HUD do outfit na mesma posição (posição baseada na largura da janela)
    outfitHud = createOutfitHUD(x, y, outfitId, outfitScale)
    
    return iconHud, outfitHud
end

-- Função encapsulada para criar HUD de posição do monstro
function createPositionHUD(x, y, z)
    local success, result = pcall(function()
        return HUD.new(0, 0, "↙", true)  -- Character ↙
    end)
    
    if success and result then
        result:setColor(255, 255, 0)  -- Cor amarela
        result:setFontSize(16)
        
        -- Converte coordenadas XYZ para pixels
        local pixelPos = xyzToPixels(x, y, z)
        if pixelPos and pixelPos ~= "fora da tela" and pixelPos ~= "erro: não foi possível obter posição do player" then
            result:setPos(pixelPos.x, pixelPos.y)
        else
            -- Se não conseguir converter, posiciona no centro da tela
            local windowDimensions = Client.getGameWindowDimensions()
            if windowDimensions then
                result:setPos(windowDimensions.width / 2, windowDimensions.height / 2)
            end
        end
        
        return result
    end
    return nil
end

-- Função para criar timer de atualização de posição
function createPositionTimer(creatureId, positionHud)
    local timerName = "position_update_" .. creatureId
    
    -- Destrói timer existente se houver
    if positionTimers[creatureId] then
        positionTimers[creatureId]:stop()
        destroyTimer(timerName)
    end
    
    -- Cria novo timer para atualizar posição a cada 200ms
    local timer = Timer.new(timerName, function()
        if positionHud and not positionHud.destroyed then
            local creature = Creature.new(creatureId)
            if creature then
                local position = creature:getPosition()
                if position then
                    local pixelPos = xyzToPixels(position.x, position.y, position.z)
                    if pixelPos and pixelPos ~= "fora da tela" and pixelPos ~= "erro: não foi possível obter posição do player" then
                        positionHud:setPos(pixelPos.x, pixelPos.y)
                    end
                end
            end
        end
    end, 200, true)  -- 200ms de intervalo, inicia automaticamente
    
    positionTimers[creatureId] = timer
    return timer
end

-- Função para obter próxima posição vertical disponível
function getNextHudPosition()
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        return 100  -- Posição padrão se não conseguir obter dimensões
    end
    
    -- Se não há HUDs ativos, começa a 1/3 do topo
    if nextHudY == 0 then
        nextHudY = windowDimensions.height / 3
    else
        -- Move para baixo com espaçamento
        nextHudY = nextHudY + HUD_CONFIG.NAME.SPACING
    end
    
    -- Se ultrapassar 2/3 da tela, volta ao topo
    if nextHudY > (windowDimensions.height * 2/3) then
        nextHudY = windowDimensions.height / 3
    end
    
    return nextHudY
end

-- Função para reorganizar posições dos HUDs quando um é removido
function reorganizeHUDs()
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        return
    end
    
    local hudCount = 0
    local baseY = windowDimensions.height / 3
    
    -- Reorganiza todos os HUDs ativos
    for creatureId, hudData in pairs(activeHUDs) do
        local newY = baseY + (hudCount * HUD_CONFIG.NAME.SPACING)
        
        -- Move todos os HUDs para a nova posição usando posicionamento baseado na largura da janela
        if hudData.nameHud then
            local centerX = windowDimensions.width / 2 + HUD_CONFIG.NAME.SPACING
            formatCenter(hudData.nameHud, centerX, newY, 1)
        end
        if hudData.outfitHud then
            local outfitX = windowDimensions.width / 2 - HUD_CONFIG.OUTFIT.SPACING
            formatCenter(hudData.outfitHud, outfitX, newY, HUD_CONFIG.OUTFIT.SCALE)
        end
        if hudData.iconHud then
            local iconX = windowDimensions.width / 2 - HUD_CONFIG.ICON.SPACING
            formatCenter(hudData.iconHud, iconX, newY, HUD_CONFIG.ICON.SCALE)
        end
        
        hudCount = hudCount + 1
    end
    
    -- Atualiza a próxima posição disponível
    nextHudY = baseY + (hudCount * HUD_CONFIG.NAME.SPACING)
    
    -- Se não há HUDs, reseta para posição inicial
    if hudCount == 0 then
        nextHudY = 0
    end
end

-- Função para criar HUD para uma criatura
function createCreatureHUD(creatureId, creatureName, x, y, z, iconCount, outfitId, creatureType)
    -- Verifica se já existe um HUD para esta criatura e destrói se necessário
    if activeHUDs[creatureId] then
        destroyCreatureHUD(creatureId)
    end
    
    -- Obtém as dimensões da janela do jogo
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        return
    end
    local displayName = ""
    -- Formata o nome da criatura com tipo e count do ícone
    -- local displayName = creatureType .. " " .. creatureName .. " -> " .. (iconCount or "0")
    if tonumber(iconCount) > 0 then
        displayName = "[".. iconCount .. "] " .. creatureName
    else
        displayName = creatureType .. " " .. creatureName
    end
    
    
    -- Obtém próxima posição vertical disponível
    local hudY = getNextHudPosition()
    
    -- Cria todos os HUDs usando as funções encapsuladas
    -- 1. Cria HUD do nome (texto)
    local nameHud = createTextHUD(0, hudY, displayName, HUD_CONFIG.NAME.FONT_SIZE, HUD_CONFIG.NAME.COLOR)
    if not nameHud then
        return
    end
    
    -- 2. Cria HUD do ícone + outfit na mesma posição
    local iconHud, outfitHud = createIconAndOutfitHUD(
        HUD_CONFIG.ICON.SPACING, 
        hudY, 
        HUD_CONFIG.ICON.ICON_ID, 
        HUD_CONFIG.ICON.SCALE,
        outfitId, 
        HUD_CONFIG.OUTFIT.SCALE
    )
    
    -- 3. Cria HUD de posição do monstro
    local positionHud = createPositionHUD(x, y, z)
    
    -- 4. Cria timer para atualizar posição do HUD
    local positionTimer = nil
    if positionHud then
        positionTimer = createPositionTimer(creatureId, positionHud)
    end
    
    -- Define callback para destruir todos os HUDs quando qualquer um for clicado
    if nameHud then
        nameHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    if outfitHud then
        outfitHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    if iconHud then
        iconHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    if positionHud then
        positionHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    -- Armazena todos os HUDs na tabela de HUDs ativos
    activeHUDs[creatureId] = {
        nameHud = nameHud,
        outfitHud = outfitHud,
        iconHud = iconHud,
        positionHud = positionHud,
        positionTimer = positionTimer,
        position = {x = x, y = y, z = z},
        lastSeen = os.clock(),
        creatureName = creatureName,
        iconCount = iconCount,
        hudY = hudY,
        outfitId = outfitId,
        creatureType = creatureType
    }
    
    -- Toca som se estiver ativado
    playSound()
end

-- Função para destruir HUD de uma criatura específica
function destroyCreatureHUD(creatureId)
    local hudData = activeHUDs[creatureId]
    if hudData then
        if hudData.nameHud then
            hudData.nameHud:destroy()
        end
        if hudData.outfitHud then
            hudData.outfitHud:destroy()
        end
        if hudData.iconHud then
            hudData.iconHud:destroy()
        end
        if hudData.positionHud then
            hudData.positionHud:destroy()
        end
        
        -- Destrói o timer de atualização de posição
        if positionTimers[creatureId] then
            positionTimers[creatureId]:stop()
            destroyTimer("position_update_" .. creatureId)
            positionTimers[creatureId] = nil
        end
        
        activeHUDs[creatureId] = nil
        
        -- Reorganiza os HUDs restantes
        reorganizeHUDs()
    end
end

-- Função para verificar se uma criatura ainda está na tela
function isCreatureOnScreen(creatureId)
    local creatures = Map.getCreatureIds(true, false)
    if not creatures then
        return false
    end
    
    for _, id in ipairs(creatures) do
        if id == creatureId then
            return true
        end
    end
    return false
end

-- Função para limpar HUDs de criaturas que não existem mais (com delay de 1s)
function cleanupInvalidHUDs()
    local currentTime = os.clock()
    
    for creatureId, hudData in pairs(activeHUDs) do
        local timeSinceLastSeen = currentTime - hudData.lastSeen
        
        -- Se passou mais de 1 segundo desde que vimos a criatura
        if timeSinceLastSeen > 1.0 then
            -- Verifica se a criatura realmente não está mais na tela
            if not isCreatureOnScreen(creatureId) then
                destroyCreatureHUD(creatureId)
            end
        end
    end
end

-- Função para atualizar timestamp de criaturas visíveis
function updateCreatureTimestamps()
    local creatures = Map.getCreatureIds(true, false)
    if not creatures then
        return
    end
    
    local currentTime = os.clock()
    for _, creatureId in ipairs(creatures) do
        if activeHUDs[creatureId] then
            activeHUDs[creatureId].lastSeen = currentTime
        end
    end
end

-- Função para debug completo das informações da criatura
function debugCreatureInfo(creature, creatureId)
    printDebug("CREATURE_INFO", "=== DEBUG: Criatura Detectada ===")
    printDebug("CREATURE_INFO", "ID: " .. creatureId)
    printDebug("CREATURE_INFO", "Nome: " .. (creature:getName() or "N/A"))
    
    local position = creature:getPosition()
    if position then
        printDebug("CREATURE_INFO", "Posição: X=" .. position.x .. ", Y=" .. position.y .. ", Z=" .. position.z)
    else
        printDebug("CREATURE_INFO", "Posição: N/A")
    end
    printDebug("CREATURE_INFO", "Tipo: " .. (creature:getType() or "N/A"))
    printDebug("CREATURE_INFO", "Vida: " .. (creature:getHealthPercent() or "N/A") .. "%")
    printDebug("CREATURE_INFO", "Velocidade: " .. (creature:getSpeed() or "N/A"))
    
    local outfit = creature:getOutfit()
    if outfit then
        printDebug("CREATURE_INFO", "Outfit: Type=" .. outfit.type .. ", Head=" .. outfit.head .. ", Body=" .. outfit.body .. ", Legs=" .. outfit.legs .. ", Feet=" .. outfit.feet)
    else
        printDebug("CREATURE_INFO", "Outfit: N/A")
    end
    
    local icons = creature:getIcons()
    if icons then
        printDebug("CREATURE_INFO", "Ícones:")
        for i, icon in ipairs(icons) do
            printDebug("CREATURE_INFO", "  Ícone " .. i .. ": Type=" .. icon.type .. ", ID=" .. icon.id .. ", Count=" .. icon.count)
        end
    else
        printDebug("CREATURE_INFO", "Ícones: N/A")
    end
    
    printDebug("CREATURE_INFO", "================================")
end

-- Função principal para avaliar criaturas
function evaluate_creature()
    local creatures = Map.getCreatureIds(true, false)
    if not creatures then
        return
    end
    
    for _, creatureId in ipairs(creatures) do
        local creature = Creature.new(creatureId)
        if creature then
            local creatureName = creature:getName()
            if creatureName then
                local icons = creature:getIcons()
                if icons then
                    for _, icon in ipairs(icons) do
                        if icon.id == Enums.CreatureIcons.CREATURE_ICON_INFLUENCED or icon.id == Enums.CreatureIcons.CREATURE_ICON_FIENDISH then
                            -- Debug completo das informações da criatura
                            debugCreatureInfo(creature, creatureId)
                            
                            local outfit = creature:getOutfit()
                            local outfitId = outfit and outfit.type or 0
                            
                            -- Determina o tipo baseado no ID do ícone
                            local creatureType = ""
                            if icon.id == Enums.CreatureIcons.CREATURE_ICON_INFLUENCED then
                                creatureType = "[I]"
                            elseif icon.id == Enums.CreatureIcons.CREATURE_ICON_FIENDISH then
                                creatureType = "[F]"
                            end
                            
                            createCreatureHUD(creatureId, creatureName, 0, 0, 0, icon.count, outfitId, creatureType)
                            break  -- Uma vez que encontrou um ícone válido, não precisa verificar outros
                        end
                    end
                end
            end
        end
    end
    
    -- Atualiza timestamps e limpa HUDs inválidos
    updateCreatureTimestamps()
    cleanupInvalidHUDs()
end

-- Timer para executar a verificação continuamente (NÃO INICIA AUTOMATICAMENTE)
local continuosFinder = Timer.new("creature_finder", evaluate_creature, TIMER_CONFIG.INTERVAL, false)

-- Sistema de eventos para drag (muito mais eficiente que timer)
Game.registerEvent(Game.Events.HUD_DRAG, function(hudId, x, y)
    if hudId == ring.icon:getId() then
        local newPos = ring.icon:getPos()
        repositionAllHUDs(newPos.x - beginPositionMenuHud.desloc.ring.x, 
                         newPos.y - beginPositionMenuHud.desloc.ring.y)
    elseif hudId == ring.label:getId() then
        local newPos = ring.label:getPos()
        repositionAllHUDs(newPos.x - beginPositionMenuHud.desloc.label.x, 
                         newPos.y - beginPositionMenuHud.desloc.label.y)
    elseif hudId == menuHud:getId() then
        local newPos = menuHud:getPos()
        repositionAllHUDs(newPos.x - beginPositionMenuHud.desloc.hud.x, 
                         newPos.y - beginPositionMenuHud.desloc.hud.y)
    end
end)

-- Função para parar o script
function stopCreatureFinder()
    if continuosFinder then
        continuosFinder:stop()
    end
    
    -- Limpa todos os HUDs ativos
    for creatureId, _ in pairs(activeHUDs) do
        destroyCreatureHUD(creatureId)
    end
    
    -- Limpa todos os timers de posição
    for creatureId, timer in pairs(positionTimers) do
        if timer then
            timer:stop()
            destroyTimer("position_update_" .. creatureId)
        end
    end
    positionTimers = {}
end

-- Função para iniciar o script
function startCreatureFinder()
    if continuosFinder then
        continuosFinder:start()
    end
end

-- ========================================
-- INICIALIZAÇÃO DO SCRIPT
-- ========================================

printDebug("GENERAL", "Script findCreatureFiendshorInfluenced carregado!")
printDebug("GENERAL", "Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")
printDebug("GENERAL", "Status inicial: INATIVO (clique no HUD para ativar)")




ring = {}
ring = {
    icon = HUD.new(beginPositionMenuHud.x + beginPositionMenuHud.desloc.ring.x,beginPositionMenuHud.y + beginPositionMenuHud.desloc.ring.y, 30195, true),
    label = HUD.new(beginPositionMenuHud.x + beginPositionMenuHud.desloc.label.x,beginPositionMenuHud.y + beginPositionMenuHud.desloc.label.y, "[OFF]", true)
}
ring.label:setColor(255, 0, 0)
ring.label:setFontSize(7)
ring.icon:setSize(18, 18)

function toggleRing()
    soundOn = not soundOn
    if soundOn then
        ring.label:setText("[ON]")
        ring.label:setColor(0,255,0)
    else
        ring.label:setText("[OFF]")
        ring.label:setColor(255, 0, 0)
    end
end

menuHud = HUD.new(beginPositionMenuHud.x + beginPositionMenuHud.desloc.hud.x, beginPositionMenuHud.y + beginPositionMenuHud.desloc.hud.y, "Fiendish Finder \n   [INATIVO]", true)
menuHud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])
menuHud:setFontSize(HUD_CONFIG.CONTROL.FONT_SIZE)

ring.icon:setDraggable(true)
ring.label:setDraggable(true)
menuHud:setDraggable(true)


-- Callbacks simplificados (drag é monitorado pelo timer)
ring.icon:setCallback(function()
    toggleRing()
end)

ring.label:setCallback(function()
    toggleRing()
end)

menuHud:setCallback(function()
    if control == false then
        startCreatureFinder()
        menuHud:setColor(0, 255, 0)  -- Verde quando ativo
        menuHud:setText("Fiendish Finder \n [ATIVO]")
        control = true
        printDebug("GENERAL", "Script ATIVADO pelo usuário") 
    else
        stopCreatureFinder()
        menuHud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])  -- Volta à cor original
        menuHud:setText("Fiendish Finder \n [INATIVO]")
        control = false
        printDebug("GENERAL", "Script DESATIVADO pelo usuário")
    end
end)