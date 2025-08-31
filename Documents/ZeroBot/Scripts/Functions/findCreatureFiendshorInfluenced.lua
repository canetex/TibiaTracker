-- Script para detectar criaturas Influenciadas ou Fiendish e criar HUDs
-- Cada monstro terá um HUD vermelho acima dele com nome e tamanho 10
-- Clique no HUD destrói o HUD específico

-- Tabela para armazenar HUDs ativos por criatura
local activeHUDs = {}

-- Função para criar HUD para uma criatura
function createCreatureHUD(creatureId, creatureName, x, y, z)
    -- Verifica se já existe um HUD para esta criatura
    if activeHUDs[creatureId] then
        return
    end
    
    -- Obtém a posição da câmera para calcular posição do HUD
    local cameraPos = Map.getCameraPosition()
    if not cameraPos then
        return
    end
    
    -- Calcula posição relativa do HUD (acima da criatura)
    local hudX = (x - cameraPos.x) * 32 + 16  -- 32 pixels por SQM, centralizado
    local hudY = (y - cameraPos.y) * 32 - 20  -- 20 pixels acima da criatura
    
    -- Cria o HUD com texto vermelho e tamanho 10
    local hud = HUD.new(hudX, hudY, creatureName, true)
    hud:setColor(255, 0, 0)  -- Vermelho
    hud:setFontSize(10)
    
    -- Define callback para destruir o HUD quando clicado
    hud:setCallback(function()
        destroyCreatureHUD(creatureId)
    end)
    
    -- Armazena o HUD na tabela de HUDs ativos
    activeHUDs[creatureId] = {
        hud = hud,
        position = {x = x, y = y, z = z}
    }
    
    print("HUD criado para: " .. creatureName .. " (ID: " .. creatureId .. ")")
end

-- Função para destruir HUD de uma criatura específica
function destroyCreatureHUD(creatureId)
    local hudData = activeHUDs[creatureId]
    if hudData then
        hudData.hud:destroy()
        activeHUDs[creatureId] = nil
        print("HUD destruído para criatura ID: " .. creatureId)
    end
end

-- Função para limpar HUDs de criaturas que não existem mais
function cleanupInvalidHUDs()
    local creatures = Map.getCreatureIds(true, false)
    local validCreatureIds = {}
    
    -- Coleta IDs de criaturas válidas
    if creatures then
        for _, id in ipairs(creatures) do
            validCreatureIds[id] = true
        end
    end
    
    -- Remove HUDs de criaturas que não existem mais
    for creatureId, hudData in pairs(activeHUDs) do
        if not validCreatureIds[creatureId] then
            destroyCreatureHUD(creatureId)
        end
    end
end

-- Função para atualizar posições dos HUDs existentes
function updateHUDPositions()
    local cameraPos = Map.getCameraPosition()
    if not cameraPos then
        return
    end
    
    for creatureId, hudData in pairs(activeHUDs) do
        local pos = hudData.position
        local hudX = (pos.x - cameraPos.x) * 32 + 16
        local hudY = (pos.y - cameraPos.y) * 32 - 20
        hudData.hud:setPos(hudX, hudY)
    end
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
                            local position = creature:getPosition()
                            if position then
                                createCreatureHUD(creatureId, creatureName, position.x, position.y, position.z)
                            end
                            break  -- Uma vez que encontrou um ícone válido, não precisa verificar outros
                        end
                    end
                end
            end
        end
    end
    
    -- Limpa HUDs inválidos e atualiza posições
    cleanupInvalidHUDs()
    updateHUDPositions()
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

-- Função para iniciar o script
function startCreatureFinder()
    if continuosFinder then
        continuosFinder:start()
        print("Script de busca de criaturas iniciado")
    end
end

print("Script findCreatureFiendshorInfluenced carregado!")
print("Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")