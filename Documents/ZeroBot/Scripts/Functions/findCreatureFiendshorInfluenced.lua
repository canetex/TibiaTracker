-- Script para detectar criaturas Influenciadas ou Fiendish e criar HUDs
-- Cada monstro terá um HUD vermelho no centro da tela com nome e tamanho 10
-- Clique no HUD destrói o HUD específico
-- Auto-destruição após 1s de delay quando monstro sai da tela/morre
-- Suporte para múltiplos monstros com posicionamento automático

-- ========================================
-- CONFIGURAÇÕES E FLAGS DE DEBUG
-- ========================================

-- Flags de Debug (true = ativado, false = desativado)
local DEBUG_FLAGS = {
    GENERAL = true,        -- Mensagens gerais do script
    CREATURE_INFO = true,  -- Informações detalhadas das criaturas
    HUD_CREATION = true,   -- Debug da criação de HUDs
    HUD_POSITION = true,   -- Debug de posicionamento
    TIMER = true,          -- Debug do timer
    CLEANUP = true         -- Debug de limpeza de HUDs
}

-- Configurações do Timer
local TIMER_CONFIG = {
    INTERVAL = 200,        -- Intervalo em milissegundos (200ms = 5x por segundo)
    ENABLED = true         -- Se o timer deve estar ativo por padrão
}

-- Configurações dos HUDs
local HUD_CONFIG = {
    NAME = {
        FONT_SIZE = 14,           -- Tamanho da fonte do nome
        COLOR = {255, 255, 0},    -- Cor do nome (R, G, B) - Amarelo
        SPACING = 30              -- Espaçamento entre HUDs em pixels
    },
    OUTFIT = {
        POSITION_X = -50,         -- Posição X do outfit (negativo = à esquerda)
        ANIMATION = true          -- Se deve ativar animação de movimento
    },
    CONTROL = {
        FONT_SIZE = 10,           -- Tamanho da fonte do HUD de controle
        COLOR = {255, 0, 0}       -- Cor do HUD de controle (R, G, B) - Vermelho
    }
}

-- ========================================
-- FUNÇÕES DE DEBUG
-- ========================================

-- Função para imprimir mensagens de debug baseadas em flags
function debugPrint(flag, message)
    if DEBUG_FLAGS[flag] then
        print("DEBUG [" .. flag .. "]: " .. message)
    end
end

-- ========================================
-- VARIÁVEIS GLOBAIS
-- ========================================

-- Tabela para armazenar HUDs ativos por criatura
local activeHUDs = {}

-- Variável para controlar a posição vertical dos próximos HUDs
local nextHudY = 0

-- ========================================
-- FUNÇÕES PRINCIPAIS
-- ========================================

-- Função para obter próxima posição vertical disponível
function getNextHudPosition()
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        debugPrint("HUD_POSITION", "Erro ao obter dimensões da janela, usando posição padrão")
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
    
    debugPrint("HUD_POSITION", "Próxima posição Y calculada: " .. tostring(nextHudY))
    return nextHudY
end

-- Função para reorganizar posições dos HUDs quando um é removido
function reorganizeHUDs()
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        debugPrint("HUD_POSITION", "Erro ao obter dimensões para reorganização")
        return
    end
    
    local hudCount = 0
    local baseY = windowDimensions.height / 3
    
    -- Reorganiza todos os HUDs ativos
    for creatureId, hudData in pairs(activeHUDs) do
        local newY = baseY + (hudCount * HUD_CONFIG.NAME.SPACING)
        
        -- Move ambos os HUDs para a nova posição
        if hudData.nameHud then
            hudData.nameHud:setPos(0, newY)
        end
        if hudData.outfitHud then
            hudData.outfitHud:setPos(HUD_CONFIG.OUTFIT.POSITION_X, newY)
        end
        
        hudCount = hudCount + 1
    end
    
    -- Atualiza a próxima posição disponível
    nextHudY = baseY + (hudCount * HUD_CONFIG.NAME.SPACING)
    
    -- Se não há HUDs, reseta para posição inicial
    if hudCount == 0 then
        nextHudY = 0
    end
    
    debugPrint("HUD_POSITION", "HUDs reorganizados. Total: " .. tostring(hudCount))
end

-- Função para criar HUD para uma criatura
function createCreatureHUD(creatureId, creatureName, x, y, z, iconCount, outfitId, creatureType)
    debugPrint("HUD_CREATION", "=== INÍCIO createCreatureHUD ===")
    debugPrint("HUD_CREATION", "Parâmetros recebidos:")
    debugPrint("HUD_CREATION", "  - creatureId: " .. tostring(creatureId))
    debugPrint("HUD_CREATION", "  - creatureName: " .. tostring(creatureName))
    debugPrint("HUD_CREATION", "  - x: " .. tostring(x) .. ", y: " .. tostring(y) .. ", z: " .. tostring(z))
    debugPrint("HUD_CREATION", "  - iconCount: " .. tostring(iconCount))
    debugPrint("HUD_CREATION", "  - outfitId: " .. tostring(outfitId))
    debugPrint("HUD_CREATION", "  - creatureType: " .. tostring(creatureType))
    
    -- Verifica se já existe um HUD para esta criatura e destrói se necessário
    if activeHUDs[creatureId] then
        debugPrint("HUD_CREATION", "HUD já existe para esta criatura, destruindo anterior...")
        destroyCreatureHUD(creatureId)
    end
    
    debugPrint("HUD_CREATION", "Verificando dimensões da janela...")
    
    -- Obtém as dimensões da janela do jogo
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        debugPrint("HUD_CREATION", "Erro ao obter dimensões da janela")
        return
    end
    
    debugPrint("HUD_CREATION", "Dimensões obtidas - Width: " .. tostring(windowDimensions.width) .. ", Height: " .. tostring(windowDimensions.height))
    
    -- Formata o nome da criatura com tipo e count do ícone
    local displayName = creatureType .. " " .. creatureName .. " -> " .. (iconCount or "0")
    debugPrint("HUD_CREATION", "Nome formatado: " .. tostring(displayName))
    
    -- Obtém próxima posição vertical disponível
    local hudY = getNextHudPosition()
    debugPrint("HUD_CREATION", "Posição Y calculada: " .. tostring(hudY))
    
    -- Debug: Verifica se as funções estão disponíveis
    debugPrint("HUD_CREATION", "Criando HUDs para criatura...")
    debugPrint("HUD_CREATION", "outfitId (Outfit Type): " .. tostring(outfitId))
    debugPrint("HUD_CREATION", "Posição Y calculada: " .. tostring(hudY))
    
    -- Cria o HUD do nome centralizado horizontalmente
    local nameHud = nil
    local outfitHud = nil
    
    debugPrint("HUD_CREATION", "Tentando criar HUD do nome...")
    
    -- Tenta criar o HUD do nome
    local success, result = pcall(function()
        return HUD.new(0, hudY, displayName, true)
    end)
    
    debugPrint("HUD_CREATION", "Resultado HUD nome - success: " .. tostring(success) .. ", result: " .. tostring(result))
    
    if success and result then
        nameHud = result
        nameHud:setColor(HUD_CONFIG.NAME.COLOR[1], HUD_CONFIG.NAME.COLOR[2], HUD_CONFIG.NAME.COLOR[3])
        nameHud:setFontSize(HUD_CONFIG.NAME.FONT_SIZE)
        nameHud:setHorizontalAlignment(Enums.HorizontalAlign.Center)
        debugPrint("HUD_CREATION", "HUD do nome criado com sucesso")
    else
        debugPrint("HUD_CREATION", "ERRO - Falha ao criar HUD do nome: " .. tostring(result))
        return
    end
    
    -- Tenta criar o HUD da imagem do outfit
    debugPrint("HUD_CREATION", "=== INÍCIO CRIAÇÃO HUD OUTFIT ===")
    debugPrint("HUD_CREATION", "HUD.newOutfit disponível: " .. tostring(HUD.newOutfit ~= nil))
    debugPrint("HUD_CREATION", "Tipo de HUD.newOutfit: " .. type(HUD.newOutfit))
    
    if HUD.newOutfit then
        debugPrint("HUD_CREATION", "Criando HUD do outfit com ID: " .. tostring(outfitId))
        debugPrint("HUD_CREATION", "Parâmetros - X: " .. tostring(HUD_CONFIG.OUTFIT.POSITION_X) .. ", Y: " .. tostring(hudY) .. ", outfitId: " .. tostring(outfitId) .. ", newFeatures: true")
        
        -- Testa diferentes posições X para o outfit
        local outfitX = HUD_CONFIG.OUTFIT.POSITION_X
        debugPrint("HUD_CREATION", "Tentando posição X: " .. tostring(outfitX))
        
        local success2, result2 = pcall(function()
            return HUD.newOutfit(outfitX, hudY, outfitId, true)
        end)
        
        debugPrint("HUD_CREATION", "Resultado pcall - success2: " .. tostring(success2))
        debugPrint("HUD_CREATION", "Resultado pcall - result2: " .. tostring(result2))
        debugPrint("HUD_CREATION", "Tipo do result2: " .. type(result2))
        
        if success2 and result2 then
            outfitHud = result2
            debugPrint("HUD_CREATION", "HUD do outfit criado com sucesso")
            debugPrint("HUD_CREATION", "outfitHud válido: " .. tostring(outfitHud ~= nil))
            
            -- Tenta ativar a animação de movimento se configurado
            if HUD_CONFIG.OUTFIT.ANIMATION then
                debugPrint("HUD_CREATION", "Tentando ativar animação de movimento...")
                local success3, result3 = pcall(function()
                    outfitHud:setOutfitMoving(true)
                    return true
                end)
                
                debugPrint("HUD_CREATION", "Animação - success3: " .. tostring(success3))
                debugPrint("HUD_CREATION", "Animação - result3: " .. tostring(result3))
                
                if success3 then
                    debugPrint("HUD_CREATION", "Animação de movimento ativada com sucesso")
                else
                    debugPrint("HUD_CREATION", "Aviso - Falha ao ativar animação: " .. tostring(result3))
                end
            end
            
            -- Tenta definir posição específica
            debugPrint("HUD_CREATION", "Tentando definir posição específica...")
            local success4, result4 = pcall(function()
                outfitHud:setPos(outfitX, hudY)
                return true
            end)
            
            debugPrint("HUD_CREATION", "setPos - success4: " .. tostring(success4))
            debugPrint("HUD_CREATION", "setPos - result4: " .. tostring(result4))
            
        else
            debugPrint("HUD_CREATION", "ERRO - Falha ao criar HUD do outfit")
            debugPrint("HUD_CREATION", "success2 = " .. tostring(success2))
            debugPrint("HUD_CREATION", "result2 = " .. tostring(result2))
            
            -- Tenta criar com parâmetros diferentes
            debugPrint("HUD_CREATION", "Tentando criar com parâmetros alternativos...")
            local successAlt, resultAlt = pcall(function()
                return HUD.newOutfit(0, hudY, outfitId, false)
            end)
            
            debugPrint("HUD_CREATION", "Alternativo - successAlt: " .. tostring(successAlt))
            debugPrint("HUD_CREATION", "Alternativo - resultAlt: " .. tostring(resultAlt))
            
            if successAlt and resultAlt then
                outfitHud = resultAlt
                debugPrint("HUD_CREATION", "HUD do outfit criado com parâmetros alternativos")
            else
                -- Tenta criar com HUD.new como fallback
                debugPrint("HUD_CREATION", "Tentando HUD.new como fallback...")
                local successFallback, resultFallback = pcall(function()
                    return HUD.new(HUD_CONFIG.OUTFIT.POSITION_X, hudY, "OUTFIT:" .. tostring(outfitId), true)
                end)
                
                debugPrint("HUD_CREATION", "Fallback - successFallback: " .. tostring(successFallback))
                debugPrint("HUD_CREATION", "Fallback - resultFallback: " .. tostring(resultFallback))
                
                if successFallback and resultFallback then
                    outfitHud = resultFallback
                    debugPrint("HUD_CREATION", "HUD fallback criado com HUD.new")
                end
            end
        end
    else
        debugPrint("HUD_CREATION", "ERRO - HUD.newOutfit não está disponível")
        debugPrint("HUD_CREATION", "HUD.newOutfit = " .. tostring(HUD.newOutfit))
        
        -- Tenta usar HUD.new com outfit
        debugPrint("HUD_CREATION", "Tentando HUD.new com outfit...")
        local successAlt2, resultAlt2 = pcall(function()
            return HUD.new(HUD_CONFIG.OUTFIT.POSITION_X, hudY, "OUTFIT:" .. tostring(outfitId), true)
        end)
        
        debugPrint("HUD_CREATION", "HUD.new alternativo - successAlt2: " .. tostring(successAlt2))
        debugPrint("HUD_CREATION", "HUD.new alternativo - resultAlt2: " .. tostring(resultAlt2))
        
        if successAlt2 and resultAlt2 then
            outfitHud = resultAlt2
            debugPrint("HUD_CREATION", "HUD alternativo criado com HUD.new")
        end
    end
    
    debugPrint("HUD_CREATION", "=== FIM CRIAÇÃO HUD OUTFIT ===")
    debugPrint("HUD_CREATION", "outfitHud final: " .. tostring(outfitHud ~= nil))
    
    -- Define callback para destruir ambos os HUDs quando o nome for clicado
    if nameHud then
        nameHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    -- Define callback para destruir ambos os HUDs quando a imagem for clicada
    if outfitHud then
        outfitHud:setCallback(function()
            destroyCreatureHUD(creatureId)
        end)
    end
    
    -- Armazena ambos os HUDs na tabela de HUDs ativos
    activeHUDs[creatureId] = {
        nameHud = nameHud,
        outfitHud = outfitHud,
        position = {x = x, y = y, z = z},
        lastSeen = os.clock(),
        creatureName = creatureName,
        iconCount = iconCount,
        hudY = hudY,
        outfitId = outfitId,
        creatureType = creatureType
    }
    
    debugPrint("GENERAL", "HUDs criados para: " .. displayName .. " (ID: " .. creatureId .. ") na posição Y: " .. hudY .. " com outfit ID: " .. (outfitId or "N/A"))
    debugPrint("GENERAL", "HUD do nome criado: " .. tostring(nameHud ~= nil))
    debugPrint("GENERAL", "HUD do outfit criado: " .. tostring(outfitHud ~= nil))
    
    -- Conta HUDs ativos de forma segura
    local hudCount = 0
    for _ in pairs(activeHUDs) do
        hudCount = hudCount + 1
    end
    debugPrint("GENERAL", "Total de HUDs ativos: " .. tostring(hudCount))
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
        activeHUDs[creatureId] = nil
        debugPrint("GENERAL", "HUDs destruídos para criatura ID: " .. creatureId)
        
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
                debugPrint("CLEANUP", "Auto-destruindo HUD para " .. hudData.creatureName .. " (ID: " .. creatureId .. ") após " .. string.format("%.1f", timeSinceLastSeen) .. "s")
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
    debugPrint("CREATURE_INFO", "=== DEBUG: Criatura Detectada ===")
    debugPrint("CREATURE_INFO", "ID: " .. creatureId)
    debugPrint("CREATURE_INFO", "Nome: " .. (creature:getName() or "N/A"))
    
    local position = creature:getPosition()
    if position then
        debugPrint("CREATURE_INFO", "Posição: X=" .. position.x .. ", Y=" .. position.y .. ", Z=" .. position.z)
    else
        debugPrint("CREATURE_INFO", "Posição: N/A")
    end
    
    debugPrint("CREATURE_INFO", "Tipo: " .. (creature:getType() or "N/A"))
    debugPrint("CREATURE_INFO", "Vida: " .. (creature:getHealthPercent() or "N/A") .. "%")
    debugPrint("CREATURE_INFO", "Velocidade: " .. (creature:getSpeed() or "N/A"))
    
    local outfit = creature:getOutfit()
    if outfit then
        debugPrint("CREATURE_INFO", "Outfit: Type=" .. outfit.type .. ", Head=" .. outfit.head .. ", Body=" .. outfit.body .. ", Legs=" .. outfit.legs .. ", Feet=" .. outfit.feet)
    else
        debugPrint("CREATURE_INFO", "Outfit: N/A")
    end
    
    local icons = creature:getIcons()
    if icons then
        debugPrint("CREATURE_INFO", "Ícones:")
        for i, icon in ipairs(icons) do
            debugPrint("CREATURE_INFO", "  Ícone " .. i .. ": Type=" .. icon.type .. ", ID=" .. icon.id .. ", Count=" .. icon.count)
        end
    else
        debugPrint("CREATURE_INFO", "Ícones: N/A")
    end
    
    debugPrint("CREATURE_INFO", "================================")
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
                            
                            local position = creature:getPosition()
                            if position then
                                local outfit = creature:getOutfit()
                                local outfitId = outfit and outfit.type or 0
                                
                                -- Determina o tipo baseado no ID do ícone
                                local creatureType = ""
                                if icon.id == Enums.CreatureIcons.CREATURE_ICON_INFLUENCED then
                                    creatureType = "[I]"
                                elseif icon.id == Enums.CreatureIcons.CREATURE_ICON_FIENDISH then
                                    creatureType = "[F]"
                                end
                                
                                debugPrint("HUD_CREATION", "Chamando createCreatureHUD com:")
                                debugPrint("HUD_CREATION", "  - creatureId: " .. tostring(creatureId))
                                debugPrint("HUD_CREATION", "  - creatureName: " .. tostring(creatureName))
                                debugPrint("HUD_CREATION", "  - position: X=" .. tostring(position.x) .. ", Y=" .. tostring(position.y) .. ", Z=" .. tostring(position.z))
                                debugPrint("HUD_CREATION", "  - icon.count: " .. tostring(icon.count))
                                debugPrint("HUD_CREATION", "  - outfitId: " .. tostring(outfitId))
                                debugPrint("HUD_CREATION", "  - creatureType: " .. tostring(creatureType))
                                
                                createCreatureHUD(creatureId, creatureName, position.x, position.y, position.z, icon.count, outfitId, creatureType)
                                
                                debugPrint("HUD_CREATION", "createCreatureHUD executada")
                            end
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

-- Timer para executar a verificação continuamente
local continuosFinder = Timer.new("creature_finder", evaluate_creature, TIMER_CONFIG.INTERVAL, true)

-- Função para parar o script
function stopCreatureFinder()
    if continuosFinder then
        continuosFinder:stop()
        debugPrint("GENERAL", "Script de busca de criaturas parado")
    end
    
    -- Limpa todos os HUDs ativos
    for creatureId, _ in pairs(activeHUDs) do
        destroyCreatureHUD(creatureId)
    end
end

local control = false

-- Função para iniciar o script
function startCreatureFinder()
    if continuosFinder then
        continuosFinder:start()
        debugPrint("GENERAL", "Script de busca de criaturas iniciado")
    end
end

debugPrint("GENERAL", "Script findCreatureFiendshorInfluenced carregado!")
debugPrint("GENERAL", "Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")
debugPrint("TIMER", "Timer configurado com intervalo de " .. TIMER_CONFIG.INTERVAL .. "ms")

-- HUD de controle principal
hud = HUD.new(100, Client.getGameWindowDimensions().height - HUD_CONFIG.NAME.SPACING, "Fiendish Finder", true)
hud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])
hud:setFontSize(HUD_CONFIG.CONTROL.FONT_SIZE)
hud:setDraggable(true)
hud:setCallback(function()
  if control == false then
    startCreatureFinder()
    hud:setColor(0, 255, 0)  -- Verde quando ativo
    control = true
  else
    stopCreatureFinder()
    hud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])  -- Volta à cor original
    control = false
  end
end)