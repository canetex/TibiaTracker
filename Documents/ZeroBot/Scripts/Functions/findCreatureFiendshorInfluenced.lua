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
    INTERVAL = 1000,        -- Intervalo em milissegundos (1000ms = 1x por segundo)
    ENABLED = false         -- Se o timer deve estar ativo por padrão (MUDADO PARA FALSE)
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

-- Variável de controle do script
local control = false

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
    
    -- Tenta diferentes métodos para criar o HUD do outfit
    local outfitX = HUD_CONFIG.OUTFIT.POSITION_X
    
    -- Método 1: HUD.newOutfit se disponível
    if HUD.newOutfit then
        debugPrint("HUD_CREATION", "Tentando HUD.newOutfit...")
        local success2, result2 = pcall(function()
            return HUD.newOutfit(outfitX, hudY, outfitId, true)
        end)
        
        if success2 and result2 then
            outfitHud = result2
            debugPrint("HUD_CREATION", "HUD do outfit criado com HUD.newOutfit")
            
            -- Tenta ativar animação se configurado
            if HUD_CONFIG.OUTFIT.ANIMATION then
                pcall(function()
                    outfitHud:setOutfitMoving(true)
                end)
            end
        else
            debugPrint("HUD_CREATION", "Falha com HUD.newOutfit, tentando alternativas...")
        end
    end
    
    -- Método 2: HUD.new com texto do outfit se o primeiro falhou
    if not outfitHud then
        debugPrint("HUD_CREATION", "Tentando HUD.new com texto do outfit...")
        local success3, result3 = pcall(function()
            return HUD.new(outfitX, hudY, "OUTFIT:" .. tostring(outfitId), true)
        end)
        
        if success3 and result3 then
            outfitHud = result3
            outfitHud:setColor(255, 255, 255)  -- Branco para destacar
            outfitHud:setFontSize(12)
            debugPrint("HUD_CREATION", "HUD do outfit criado com HUD.new (texto)")
        end
    end
    
    -- Método 3: HUD.new com ícone se disponível
    if not outfitHud then
        debugPrint("HUD_CREATION", "Tentando HUD.new com ícone...")
        local success4, result4 = pcall(function()
            return HUD.new(outfitX, hudY, "👤", true)  -- Emoji como fallback
        end)
        
        if success4 and result4 then
            outfitHud = result4
            outfitHud:setColor(255, 255, 255)
            outfitHud:setFontSize(16)
            debugPrint("HUD_CREATION", "HUD do outfit criado com emoji")
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
    debugPrint("TIMER", "Executando evaluate_creature...")
    
    local creatures = Map.getCreatureIds(true, false)
    if not creatures then
        debugPrint("TIMER", "Nenhuma criatura encontrada na tela")
        return
    end
    
    debugPrint("TIMER", "Verificando " .. #creatures .. " criaturas na tela")
    
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

-- Timer para executar a verificação continuamente (NÃO INICIA AUTOMATICAMENTE)
local continuosFinder = Timer.new("creature_finder", evaluate_creature, TIMER_CONFIG.INTERVAL, false)  -- MUDADO PARA FALSE

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

-- Função para iniciar o script
function startCreatureFinder()
    if continuosFinder then
        continuosFinder:start()
        debugPrint("GENERAL", "Script de busca de criaturas iniciado")
    end
end

-- ========================================
-- INICIALIZAÇÃO DO SCRIPT
-- ========================================

-- Debug inicial para verificar se o script está carregando
print("=== SCRIPT findCreatureFiendshorInfluenced CARREGADO ===")
print("DEBUG: Verificando se as funções estão disponíveis...")

-- Testa se as funções básicas estão disponíveis
if HUD then
    print("DEBUG: HUD disponível ✓")
else
    print("DEBUG: HUD NÃO disponível ✗")
end

if Timer then
    print("DEBUG: Timer disponível ✓")
else
    print("DEBUG: Timer NÃO disponível ✗")
end

if Client then
    print("DEBUG: Client disponível ✓")
else
    print("DEBUG: Client NÃO disponível ✗")
end

if Map then
    print("DEBUG: Map disponível ✓")
else
    print("DEBUG: Map NÃO disponível ✗")
end

if Creature then
    print("DEBUG: Creature disponível ✓")
else
    print("DEBUG: Creature NÃO disponível ✗")
end

debugPrint("GENERAL", "Script findCreatureFiendshorInfluenced carregado!")
debugPrint("GENERAL", "Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")
debugPrint("TIMER", "Timer configurado com intervalo de " .. TIMER_CONFIG.INTERVAL .. "ms")
debugPrint("GENERAL", "Status inicial: INATIVO (clique no HUD para ativar)")

-- HUD de controle principal
local windowDimensions = Client.getGameWindowDimensions()
local hudY = windowDimensions and (windowDimensions.height - HUD_CONFIG.NAME.SPACING) or 100

hud = HUD.new(100, hudY, "Fiendish Finder [INATIVO]", true)
hud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])
hud:setFontSize(HUD_CONFIG.CONTROL.FONT_SIZE)
hud:setDraggable(true)
hud:setCallback(function()
  if control == false then
    startCreatureFinder()
    hud:setColor(0, 255, 0)  -- Verde quando ativo
    hud:setText("Fiendish Finder [ATIVO]")
    control = true
    debugPrint("GENERAL", "Script ATIVADO pelo usuário")
  else
    stopCreatureFinder()
    hud:setColor(HUD_CONFIG.CONTROL.COLOR[1], HUD_CONFIG.CONTROL.COLOR[2], HUD_CONFIG.CONTROL.COLOR[3])  -- Volta à cor original
    hud:setText("Fiendish Finder [INATIVO]")
    control = false
    debugPrint("GENERAL", "Script DESATIVADO pelo usuário")
  end
end)

print("=== SCRIPT INICIALIZADO COM SUCESSO ===")
print("Clique no HUD 'Fiendish Finder' para ativar/desativar o script")