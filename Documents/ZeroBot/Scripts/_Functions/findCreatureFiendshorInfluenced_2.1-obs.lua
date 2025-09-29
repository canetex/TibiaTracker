-- ================================================================
-- Fiendish/Influenced Creature Finder v2.0
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
-- CONFIGURAÇÕES 
-- ================================================================

-- Ativa/desativa a seta que indica a posição do monstro
local Show_Monster_Arrow = true
-- Ativa/desativa o Banner que indica a posição do monstro
local Show_Monster_Banner = true

-- ================================================================
-- CONFIGURAÇÕES E FLAGS DE DEBUG -- Não mexer daqui para baixo
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

-- dofile(Engine.getScriptsDirectory() .. "/_Functions/Y_Support/xyzToPixels.lua")


-- ================================================================
-- CÓDIGO OBFUSCADO - NÃO MODIFICAR
-- ================================================================

local _0x1a2b={[1]=15,[2]=11,[3]=7,[4]=5}
local _0x3c4d=15
local _0x5e6f=11
local _0x7890=7
local _0x9abc=5
local _0xdef0=false
local _0x1234=Client.getGameWindowDimensions()
local _0x5678={x=118,y=998,desloc={ring={x=0,y=0},label={x=-7,y=13},hud={x=24,y=0}}}
if Client.getGameWindowDimensions().width<_0x5678.x then _0x5678.x=155 end
if Client.getGameWindowDimensions().height<_0x5678.y then _0x5678.y=155 end

local function _0xabcd(flag,message)
    if DEBUG_FLAGS[flag]then print("DEBUG ["..flag.."]: "..tostring(message))end 
end

local function _0xefgh()
    return debug.getinfo(1).source:gsub("Scripts/","")
end

local function _0xijkl(path,mode)
    if not path or type(path)~="string"then 
        _0xabcd("GENERAL","Erro: caminho do arquivo invalido")
        return nil 
    end
    local file=io.open(path,mode)
    if not file then 
        _0xabcd("GENERAL","Erro ao abrir arquivo: "..tostring(path))
        return nil 
    end
    return file 
end

local function _0xmnop()
    local filename=_0xefgh()
    local path=Engine.getScriptsDirectory().."/"..filename
    local file=_0xijkl(path,"r")
    if not file then 
        _0xabcd("GENERAL","Erro: nao foi possivel abrir arquivo para leitura")
        return false 
    end
    local content=file:read("*all")
    file:close()
    if not content then 
        _0xabcd("GENERAL","Erro: nao foi possivel ler conteudo do arquivo")
        return false 
    end
    local currentX=content:match("x = (%d+),")
    local currentY=content:match("y = (%d+),")
    if not currentX or not currentY then 
        _0xabcd("GENERAL","Nao foi possivel encontrar padroes de posicao no arquivo")
        _0xabcd("GENERAL","X encontrado: "..tostring(currentX))
        _0xabcd("GENERAL","Y encontrado: "..tostring(currentY))
        return false 
    end
    local newContent=content:gsub("x = "..currentX..",","x = ".._0x5678.x..",")
    newContent=newContent:gsub("y = "..currentY..",","y = ".._0x5678.y..",")
    file=_0xijkl(path,"w")
    if not file then 
        _0xabcd("GENERAL","Erro: nao foi possivel abrir arquivo para escrita")
        return false 
    end
    local success=file:write(newContent)
    file:close()
    if success then 
        _0xabcd("GENERAL","Posicoes do menu salvas: X=".._0x5678.x..", Y=".._0x5678.y")
    else 
        _0xabcd("GENERAL","Erro: falha ao escrever no arquivo")
    end
    return success 
end

local _0xqrst=nil
local _0xuvwx=1000

local function _0xyzaa()
    if _0xqrst then _0xqrst:stop()end
    _0xqrst=Timer.new("delayed-save",function()_0xmnop();_0xqrst=nil end,_0xuvwx,false)
    _0xqrst:start()
end

local function _0xbbcc(baseX,baseY)
    _0x5678.x=baseX
    _0x5678.y=baseY
    ring.icon:setPos(baseX+_0x5678.desloc.ring.x,baseY+_0x5678.desloc.ring.y)
    ring.label:setPos(baseX+_0x5678.desloc.label.x,baseY+_0x5678.desloc.label.y)
    menuHud:setPos(baseX+_0x5678.desloc.hud.x,baseY+_0x5678.desloc.hud.y)
    _0xyzaa()
end

local _0xdddd={}
local _0xeeee=0
local _0xffff=false
local _0x1111={}

local function _0x2222()
    local soundsFolder=Engine.getScriptsDirectory().."/Sounds/"
    if _0xdef0 then Sound.play(soundsFolder..'/ring-tone-68676.mp3')end 
end

local function _0x3333(hud,posX,posY,scale)
    hud:setScale(scale or 1)
    hud:setPos(posX or 0,posY or 0)
end

local function _0x4444(x,y,text,fontSize,color)
    local success,result=pcall(function()return HUD.new(0,0,text,true)end)
    if success and result then 
        result:setColor(color[1],color[2],color[3])
        result:setFontSize(fontSize)
        local windowDimensions=Client.getGameWindowDimensions()
        local centerX=windowDimensions and(windowDimensions.width/2+HUD_CONFIG.NAME.SPACING)or 0
        _0x3333(result,centerX,y,1)
        return result 
    end
    return nil 
end

local function _0x5555(x,y,outfitId,scale)
    if not HUD.newOutfit then return nil end
    local success,result=pcall(function()return HUD.newOutfit(0,0,outfitId,true)end)
    if success and result then 
        local windowDimensions=Client.getGameWindowDimensions()
        local outfitX=windowDimensions and(windowDimensions.width/2-HUD_CONFIG.OUTFIT.SPACING)or 0
        _0x3333(result,outfitX,y,scale)
        if HUD_CONFIG.OUTFIT.ANIMATION then 
            pcall(function()result:setOutfitMoving(true)end)
        end
        return result 
    end
    return nil 
end

local function _0x6666(x,y,iconId,scale)
    local success,result=pcall(function()return HUD.new(0,0,iconId,true)end)
    if success and result then 
        local windowDimensions=Client.getGameWindowDimensions()
        local iconX=windowDimensions and(windowDimensions.width/2-HUD_CONFIG.ICON.SPACING)or 0
        _0x3333(result,iconX,y,scale)
        return result 
    end
    return nil 
end

local function _0x7777(x,y,iconId,iconScale,outfitId,outfitScale)
    local iconHud=nil
    local outfitHud=nil
    iconHud=_0x6666(x,y,iconId,iconScale)
    outfitHud=_0x5555(x,y,outfitId,outfitScale)
    return iconHud,outfitHud 
end

local function _0x8888(x,y,z)
    local success,result=pcall(function()return HUD.new(0,0,"\u{21A6}",true)end)
    if success and result then 
        result:setColor(227,3,252)
        result:setFontSize(20)
        local pixelPos=_0x9999(x,y,z)
        if pixelPos and pixelPos~="fora da tela"and pixelPos~="erro: nao foi possivel obter posicao do player"then 
            result:setPos(pixelPos.x,pixelPos.y)
        else 
            local windowDimensions=Client.getGameWindowDimensions()
            if windowDimensions then 
                result:setPos(windowDimensions.width/2,windowDimensions.height/2)
            end 
        end
        return result 
    end
    return nil 
end

local function _0xaaaa(creatureId,positionHud)
    local timerName="position_update_"..creatureId
    if _0x1111[creatureId]then 
        _0x1111[creatureId]:stop()
        destroyTimer(timerName)
    end
    local timer=Timer.new(timerName,function()
        if positionHud and not positionHud.destroyed then 
            local creature=Creature.new(creatureId)
            if creature then 
                local position=creature:getPosition()
                if position then 
                    local pixelPos=_0x9999(position.x,position.y,position.z)
                    if pixelPos and pixelPos~="fora da tela"and pixelPos~="erro: nao foi possivel obter posicao do player"then 
                        positionHud:setPos(pixelPos.x,pixelPos.y)
                    end 
                end 
            end 
        end 
    end,200,true)
    _0x1111[creatureId]=timer
    return timer 
end

local function _0xbbbb()
    local windowDimensions=Client.getGameWindowDimensions()
    if not windowDimensions then return 100 end
    if _0xeeee==0 then 
        _0xeeee=windowDimensions.height/3 
    else 
        _0xeeee=_0xeeee+HUD_CONFIG.NAME.SPACING 
    end
    if _0xeeee>(windowDimensions.height*2/3)then 
        _0xeeee=windowDimensions.height/3 
    end
    return _0xeeee 
end

local function _0xcccc()
    local windowDimensions=Client.getGameWindowDimensions()
    if not windowDimensions then return end
    local hudCount=0
    local baseY=windowDimensions.height/3
    for creatureId,hudData in pairs(_0xdddd)do 
        local newY=baseY+(hudCount*HUD_CONFIG.NAME.SPACING)
        if hudData.nameHud then 
            local centerX=windowDimensions.width/2+HUD_CONFIG.NAME.SPACING
            _0x3333(hudData.nameHud,centerX,newY,1)
        end
        if hudData.outfitHud then 
            local outfitX=windowDimensions.width/2-HUD_CONFIG.OUTFIT.SPACING
            _0x3333(hudData.outfitHud,outfitX,newY,HUD_CONFIG.OUTFIT.SCALE)
        end
        if hudData.iconHud then 
            local iconX=windowDimensions.width/2-HUD_CONFIG.ICON.SPACING
            _0x3333(hudData.iconHud,iconX,newY,HUD_CONFIG.ICON.SCALE)
        end
        hudCount=hudCount+1 
    end
    _0xeeee=baseY+(hudCount*HUD_CONFIG.NAME.SPACING)
    if hudCount==0 then _0xeeee=0 end 
end

local function _0xdddd(creatureId,creatureName,x,y,z,iconCount,outfitId,creatureType)
    if _0xdddd[creatureId]then _0xeeee(creatureId)end
    local windowDimensions=Client.getGameWindowDimensions()
    if not windowDimensions then return end
    local displayName=""
    if tonumber(iconCount)>0 then 
        displayName="["..iconCount.."] "..creatureName 
    else 
        displayName=creatureType.." "..creatureName 
    end
    local hudY=_0xbbbb()
    local nameHud=_0x4444(0,hudY,displayName,HUD_CONFIG.NAME.FONT_SIZE,HUD_CONFIG.NAME.COLOR)
    if not nameHud then return end
    local iconHud,outfitHud=nil,nil
    if Show_Monster_Banner then 
        iconHud,outfitHud=_0x7777(HUD_CONFIG.ICON.SPACING,hudY,HUD_CONFIG.ICON.ICON_ID,HUD_CONFIG.ICON.SCALE,outfitId,HUD_CONFIG.OUTFIT.SCALE)
    end
    local positionHud=nil
    local positionTimer=nil
    if Show_Monster_Arrow then 
        positionHud=_0x8888(x,y,z)
        if positionHud then 
            positionTimer=_0xaaaa(creatureId,positionHud)
        end 
    end
    if nameHud then 
        nameHud:setCallback(function()_0xeeee(creatureId)end)
    end
    if outfitHud and Show_Monster_Banner then 
        outfitHud:setCallback(function()_0xeeee(creatureId)end)
    end
    if iconHud and Show_Monster_Banner then 
        iconHud:setCallback(function()_0xeeee(creatureId)end)
    end
    if positionHud and Show_Monster_Arrow then 
        positionHud:setCallback(function()_0xeeee(creatureId)end)
    end
    _0xdddd[creatureId]={nameHud=nameHud,outfitHud=outfitHud,iconHud=iconHud,positionHud=positionHud,positionTimer=positionTimer,position={x=x,y=y,z=z},lastSeen=os.clock(),creatureName=creatureName,iconCount=iconCount,hudY=hudY,outfitId=outfitId,creatureType=creatureType}
    _0x2222()
end

local function _0xeeee(creatureId)
    local hudData=_0xdddd[creatureId]
    if hudData then 
        if hudData.nameHud then hudData.nameHud:destroy()end
        if hudData.outfitHud then hudData.outfitHud:destroy()end
        if hudData.iconHud then hudData.iconHud:destroy()end
        if hudData.positionHud then hudData.positionHud:destroy()end
        if _0x1111[creatureId]then 
            _0x1111[creatureId]:stop()
            destroyTimer("position_update_"..creatureId)
            _0x1111[creatureId]=nil 
        end
        _0xdddd[creatureId]=nil
        _0xcccc()
    end 
end

local function _0xffff(creatureId)
    local creatures=Map.getCreatureIds(true,false)
    if not creatures then return false end
    for _,id in ipairs(creatures)do 
        if id==creatureId then return true end 
    end
    return false 
end

local function _0x1111()
    local currentTime=os.clock()
    for creatureId,hudData in pairs(_0xdddd)do 
        local timeSinceLastSeen=currentTime-hudData.lastSeen
        if timeSinceLastSeen>1 then 
            if not _0xffff(creatureId)then 
                _0xeeee(creatureId)
            end 
        end 
    end 
end

local function _0x2222()
    local creatures=Map.getCreatureIds(true,false)
    if not creatures then return end
    local currentTime=os.clock()
    for _,creatureId in ipairs(creatures)do 
        if _0xdddd[creatureId]then 
            _0xdddd[creatureId].lastSeen=currentTime 
        end 
    end 
end

local function _0x3333(creature,creatureId)
    _0xabcd("CREATURE_INFO","=== DEBUG: Criatura Detectada ===")
    _0xabcd("CREATURE_INFO","ID: "..creatureId)
    _0xabcd("CREATURE_INFO","Nome: "..(creature:getName()or"N/A"))
    local position=creature:getPosition()
    if position then 
        _0xabcd("CREATURE_INFO","Posicao: X="..position.x..", Y="..position.y..", Z="..position.z)
    else 
        _0xabcd("CREATURE_INFO","Posicao: N/A")
    end
    _0xabcd("CREATURE_INFO","Tipo: "..(creature:getType()or"N/A"))
    _0xabcd("CREATURE_INFO","Vida: "..(creature:getHealthPercent()or"N/A").."%")
    _0xabcd("CREATURE_INFO","Velocidade: "..(creature:getSpeed()or"N/A"))
    local outfit=creature:getOutfit()
    if outfit then 
        _0xabcd("CREATURE_INFO","Outfit: Type="..outfit.type..", Head="..outfit.head..", Body="..outfit.body..", Legs="..outfit.legs..", Feet="..outfit.feet)
    else 
        _0xabcd("CREATURE_INFO","Outfit: N/A")
    end
    local icons=creature:getIcons()
    if icons then 
        _0xabcd("CREATURE_INFO","Ícones:")
        for i,icon in ipairs(icons)do 
            _0xabcd("CREATURE_INFO","  Ícone "..i..": Type="..icon.type..", ID="..icon.id..", Count="..icon.count)
        end 
    else 
        _0xabcd("CREATURE_INFO","Ícones: N/A")
    end
    _0xabcd("CREATURE_INFO","================================")
end

local function _0x4444()
    local creatures=Map.getCreatureIds(true,false)
    if not creatures then return end
    for _,creatureId in ipairs(creatures)do 
        local creature=Creature.new(creatureId)
        if creature then 
            local creatureName=creature:getName()
            if creatureName then 
                local icons=creature:getIcons()
                if icons then 
                    for _,icon in ipairs(icons)do 
                        if icon.id==Enums.CreatureIcons.CREATURE_ICON_INFLUENCED or icon.id==Enums.CreatureIcons.CREATURE_ICON_FIENDISH then 
                            _0x3333(creature,creatureId)
                            local outfit=creature:getOutfit()
                            local outfitId=outfit and outfit.type or 0
                            local creatureType=""
                            if icon.id==Enums.CreatureIcons.CREATURE_ICON_INFLUENCED then 
                                creatureType="[I]"
                            elseif icon.id==Enums.CreatureIcons.CREATURE_ICON_FIENDISH then 
                                creatureType="[F]"
                            end
                            _0xdddd(creatureId,creatureName,0,0,0,icon.count,outfitId,creatureType)
                            break 
                        end 
                    end 
                end 
            end 
        end 
    end
    _0x2222()
    _0x1111()
end

local _0x5555=Timer.new("creature_finder",_0x4444,TIMER_CONFIG.INTERVAL,false)

Game.registerEvent(Game.Events.HUD_DRAG,function(hudId,x,y)
    if hudId==ring.icon:getId()then 
        local newPos=ring.icon:getPos()
        _0xbbcc(newPos.x-_0x5678.desloc.ring.x,newPos.y-_0x5678.desloc.ring.y)
    elseif hudId==ring.label:getId()then 
        local newPos=ring.label:getPos()
        _0xbbcc(newPos.x-_0x5678.desloc.label.x,newPos.y-_0x5678.desloc.label.y)
    elseif hudId==menuHud:getId()then 
        local newPos=menuHud:getPos()
        _0xbbcc(newPos.x-_0x5678.desloc.hud.x,newPos.y-_0x5678.desloc.hud.y)
    end 
end)

local function _0x6666()
    if _0x5555 then _0x5555:stop()end
    for creatureId,_ in pairs(_0xdddd)do 
        _0xeeee(creatureId)
    end
    for creatureId,timer in pairs(_0x1111)do 
        if timer then 
            timer:stop()
            destroyTimer("position_update_"..creatureId)
        end 
    end
    _0x1111={}
end

local function _0x7777()
    if _0x5555 then _0x5555:start()end 
end

_0xabcd("GENERAL","Script findCreatureFiendshorInfluenced carregado!")
_0xabcd("GENERAL","Use startCreatureFinder() para iniciar ou stopCreatureFinder() para parar")
_0xabcd("GENERAL","Status inicial: INATIVO (clique no HUD para ativar)")

ring={}
ring={icon=HUD.new(_0x5678.x+_0x5678.desloc.ring.x,_0x5678.y+_0x5678.desloc.ring.y,30195,true),label=HUD.new(_0x5678.x+_0x5678.desloc.label.x,_0x5678.y+_0x5678.desloc.label.y,"[OFF]",true)}
ring.label:setColor(255,0,0)
ring.label:setFontSize(7)
ring.icon:setSize(18,18)

local function _0x8888()
    _0xdef0=not _0xdef0
    if _0xdef0 then 
        ring.label:setText("[ON]")
        ring.label:setColor(0,255,0)
    else 
        ring.label:setText("[OFF]")
        ring.label:setColor(255,0,0)
    end 
end

menuHud=HUD.new(_0x5678.x+_0x5678.desloc.hud.x,_0x5678.y+_0x5678.desloc.hud.y,"Fiendish Finder \n   [INATIVO]",true)
menuHud:setColor(HUD_CONFIG.CONTROL.COLOR[1],HUD_CONFIG.CONTROL.COLOR[2],HUD_CONFIG.CONTROL.COLOR[3])
menuHud:setFontSize(HUD_CONFIG.CONTROL.FONT_SIZE)
ring.icon:setDraggable(true)
ring.label:setDraggable(true)
menuHud:setDraggable(true)

ring.icon:setCallback(function()_0x8888()end)
ring.label:setCallback(function()_0x8888()end)
menuHud:setCallback(function()
    if _0xffff==false then 
        _0x7777()
        menuHud:setColor(0,255,0)
        menuHud:setText("Fiendish Finder \n [ATIVO]")
        _0xffff=true
        _0xabcd("GENERAL","Script ATIVADO pelo usuário")
    else 
        _0x6666()
        menuHud:setColor(HUD_CONFIG.CONTROL.COLOR[1],HUD_CONFIG.CONTROL.COLOR[2],HUD_CONFIG.CONTROL.COLOR[3])
        menuHud:setText("Fiendish Finder \n [INATIVO]")
        _0xffff=false
        _0xabcd("GENERAL","Script DESATIVADO pelo usuário")
    end 
end)

function getPlayerPosition()
    local playerId=Player.getId()
    if not playerId then return nil end
    local player=Creature.new(playerId)
    if not player then return nil end
    local playerPos=player:getPosition()
    if not playerPos then return nil end
    return playerPos 
end

function _0x9999(x,y,z)
    local screenInfo=Client.getGameWindowDimensions()
    local width_total=screenInfo.width
    local height_total=screenInfo.height
    local playerPos=getPlayerPosition()
    if not playerPos then return"erro: nao foi possivel obter posicao do player"end
    if z~=playerPos.z then return"fora da tela"end
    local relativeX=x-playerPos.x
    local relativeY=y-playerPos.y
    if relativeX<-_0x7890 or relativeX>_0x7890 or relativeY<-_0x9abc or relativeY>_0x7890 then return"fora da tela"end
    local size_tile_x=width_total/_0x3c4d
    local size_tile_y=height_total/_0x5e6f
    local centerX=width_total/2
    local centerY=height_total/2
    local pixelX=centerX+((relativeX+2)*size_tile_x)
    local pixelY=centerY+(relativeY*size_tile_y)
    return{x=math.floor(pixelX),y=math.floor(pixelY),relativeX=relativeX,relativeY=relativeY}
end

function createCreatureHUD(creatureId,creatureName,x,y,z,iconCount,outfitId,creatureType)return _0xdddd(creatureId,creatureName,x,y,z,iconCount,outfitId,creatureType)end
function destroyCreatureHUD(creatureId)return _0xeeee(creatureId)end
function evaluate_creature()return _0x4444()end
function stopCreatureFinder()return _0x6666()end
function startCreatureFinder()return _0x7777()end
function playSound()return _0x2222()end
function formatCenter(hud,posX,posY,scale)return _0x3333(hud,posX,posY,scale)end
function createTextHUD(x,y,text,fontSize,color)return _0x4444(x,y,text,fontSize,color)end
function createOutfitHUD(x,y,outfitId,scale)return _0x5555(x,y,outfitId,scale)end
function createIconHUD(x,y,iconId,scale)return _0x6666(x,y,iconId,scale)end
function createIconAndOutfitHUD(x,y,iconId,iconScale,outfitId,outfitScale)return _0x7777(x,y,iconId,iconScale,outfitId,outfitScale)end
function createPositionHUD(x,y,z)return _0x8888(x,y,z)end
function createPositionTimer(creatureId,positionHud)return _0xaaaa(creatureId,positionHud)end
function getNextHudPosition()return _0xbbbb()end
function reorganizeHUDs()return _0xcccc()end
function isCreatureOnScreen(creatureId)return _0xffff(creatureId)end
function cleanupInvalidHUDs()return _0x1111()end
function updateCreatureTimestamps()return _0x2222()end
function debugCreatureInfo(creature,creatureId)return _0x3333(creature,creatureId)end
function printDebug(flag,message)return _0xabcd(flag,message)end
function xyzToPixels(x,y,z)return _0x9999(x,y,z)end
function toggleRing()return _0x8888()end