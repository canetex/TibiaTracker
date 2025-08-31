-- Script para detectar criaturas Influenciadas ou Fiendish e criar HUDs
-- Cada monstro terá um HUD vermelho no centro da tela com nome e tamanho 10
-- Clique no HUD destrói o HUD específico
-- Auto-destruição após 1s de delay quando monstro sai da tela/morre
-- Suporte para múltiplos monstros com posicionamento automático

-- Tabela para armazenar HUDs ativos por criatura
local activeHUDs = {}

-- Variável para controlar a posição vertical dos próximos HUDs
local nextHudY = 0
local hudSpacing = 30  -- Espaçamento entre HUDs em pixels

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
        nextHudY = nextHudY + hudSpacing
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
        local newY = baseY + (hudCount * hudSpacing)
        
        -- Move ambos os HUDs para a nova posição
        if hudData.nameHud then
            hudData.nameHud:setPos(0, newY)
        end
        if hudData.outfitHud then
            hudData.outfitHud:setPos(-50, newY)
        end
        
        hudCount = hudCount + 1
    end
    
    -- Atualiza a próxima posição disponível
    nextHudY = baseY + (hudCount * hudSpacing)
    
    -- Se não há HUDs, reseta para posição inicial
    if hudCount == 0 then
        nextHudY = 0
    end
end

-- Função para criar HUD para uma criatura
function createCreatureHUD(creatureId, creatureName, x, y, z, iconCount, outfitId)
    -- Verifica se já existe um HUD para esta criatura
    if activeHUDs[creatureId] then
        return
    end
    
    -- Obtém as dimensões da janela do jogo
    local windowDimensions = Client.getGameWindowDimensions()
    if not windowDimensions then
        print("DEBUG: Erro ao obter dimensões da janela")
        return
    end
    
    -- Formata o nome da criatura com o count do ícone
    local displayName = creatureName .. " -> " .. (iconCount or "0")
    
    -- Obtém próxima posição vertical disponível
    local hudY = getNextHudPosition()
    
    -- Debug: Verifica se as funções estão disponíveis
    print("DEBUG: Criando HUDs para criatura...")
    print("outfitId (Outfit Type):", outfitId)
    print("Posição Y calculada:", hudY)
    
    -- Cria o HUD do nome centralizado horizontalmente
    local nameHud = nil
    local outfitHud = nil
    
    -- Tenta criar o HUD do nome
    local success, result = pcall(function()
        return HUD.new(0, hudY, displayName, true)
    end)
    
    if success and result then
        nameHud = result
        nameHud:setColor(255, 255, 0)  -- Amarelo
        nameHud:setFontSize(14)
        nameHud:setHorizontalAlignment(Enums.HorizontalAlign.Center)
        print("DEBUG: HUD do nome criado com sucesso")
    else
        print("DEBUG: ERRO - Falha ao criar HUD do nome:", result)
        return
    end
    
    -- Tenta criar o HUD da imagem do outfit
    if HUD.newOutfit then
        print("DEBUG: Criando HUD do outfit com ID:", outfitId)
        
        local success2, result2 = pcall(function()
            return HUD.newOutfit(-50, hudY, outfitId, true)
        end)
        
        if success2 and result2 then
            outfitHud = result2
            print("DEBUG: HUD do outfit criado com sucesso")
            
            -- Tenta ativar a animação de movimento
            local success3, result3 = pcall(function()
                outfitHud:setOutfitMoving(true)
                return true
            end)
            
            if success3 then
                print("DEBUG: Animação de movimento ativada")
            else
                print("DEBUG: Aviso - Falha ao ativar animação:", result3)
            end
        else
            print("DEBUG: ERRO - Falha ao criar HUD do outfit:", result2)
        end
    else
        print("DEBUG: ERRO - HUD.newOutfit não está disponível")
    end
    
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
        outfitId = outfitId
    }
    
    print("HUDs criados para: " .. displayName .. " (ID: " .. creatureId .. ") na posição Y: " .. hudY .. " com outfit ID: " .. (outfitId or "N/A"))
    print("HUD do nome criado:", nameHud ~= nil)
    print("HUD do outfit criado:", outfitHud ~= nil)
    
    -- Conta HUDs ativos de forma segura
    local hudCount = 0
    for _ in pairs(activeHUDs) do
        hudCount = hudCount + 1
    end
    print("Total de HUDs ativos:", hudCount)
end

-- Função para destruir HUD de uma criatura específica
function destroyCreatureHUD(creatureId)
    local hudData = activeHUDs[creatureId]
    if hudData then
        hudData.nameHud:destroy()
        hudData.outfitHud:destroy()
        activeHUDs[creatureId] = nil
        print("HUDs destruídos para criatura ID: " .. creatureId)
        
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
                print("Auto-destruindo HUD para " .. hudData.creatureName .. " (ID: " .. creatureId .. ") após " .. string.format("%.1f", timeSinceLastSeen) .. "s")
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
    print("=== DEBUG: Criatura Detectada ===")
    print("ID: " .. creatureId)
    print("Nome: " .. (creature:getName() or "N/A"))
    
    local position = creature:getPosition()
    if position then
        print("Posição: X=" .. position.x .. ", Y=" .. position.y .. ", Z=" .. position.z)
    else
        print("Posição: N/A")
    end
    
    print("Tipo: " .. (creature:getType() or "N/A"))
    print("Vida: " .. (creature:getHealthPercent() or "N/A") .. "%")
    print("Velocidade: " .. (creature:getSpeed() or "N/A"))
    
    local outfit = creature:getOutfit()
    if outfit then
        print("Outfit: Type=" .. outfit.type .. ", Head=" .. outfit.head .. ", Body=" .. outfit.body .. ", Legs=" .. outfit.legs .. ", Feet=" .. outfit.feet)
    else
        print("Outfit: N/A")
    end
    
    local icons = creature:getIcons()
    if icons then
        print("Ícones:")
        for i, icon in ipairs(icons) do
            print("  Ícone " .. i .. ": Type=" .. icon.type .. ", ID=" .. icon.id .. ", Count=" .. icon.count)
        end
    else
        print("Ícones: N/A")
    end
    
    print("================================")
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
                                createCreatureHUD(creatureId, creatureName, position.x, position.y, position.z, icon.count, outfitId)
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
local continuosFinder = Timer.new("creature_finder", evaluate_creature, 200, true)

-- Função para parar o script
function stopCreatureFinder()
    if continuosFinder then
        continuosFinder:stop()
        print("Script de busca de criaturas parado")
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
        print("Script de busca de criaturas iniciado")
    end
end

print("Script findCreatureFiendshorInfluenced carregado!")
print("Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")

-- HUD de controle principal
hud = HUD.new(100, 100, "Fiendish Finder", true)
hud:setColor(255,0, 0)
hud:setFontSize(10)
hud:setDraggable(true)
hud:setCallback(function()
  if control == false then
    startCreatureFinder()
    hud:setColor(0,255, 0)
    control = true
  else
    stopCreatureFinder()
    hud:setColor(255,0, 0)
    control = false
  end
end)