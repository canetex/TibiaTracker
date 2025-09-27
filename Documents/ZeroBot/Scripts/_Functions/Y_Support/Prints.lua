print("BeginLoad Prints.lua")
--- Função auxiliar que converte uma tabela Lua em uma string formatada.
--- This function is a wrapper around the external function cavebotGetWaypointTypeById.
--- @param tbl (table) - A tabela a ser convertida.
--- @return (string) - Uma string representando a tabela, com chaves e valores.
  function tableToString(tbl)
    -- Inicializa a string resultante com um cabeçalho.
    local result = "key | valor\n-----------\n"
  
    --- Função recursiva para processar tabelas aninhadas.
    -- @param subTbl A subtabela atual sendo processada.
    -- @param prefix Prefixo da chave, usado para indicar aninhamento.
    local function processTable(subTbl, prefix)
      -- Itera sobre cada par chave-valor na tabela.
      for key, value in pairs(subTbl) do
        -- Concatena o prefixo com a chave atual.
        local fullKey = prefix .. key
  
        -- Verifica se o valor é outra tabela.
        if type(value) == "table" then
          -- Se for, chama a função recursivamente para processar a subtabela.
          processTable(value, fullKey .. ".") -- Adiciona um "." para separar os níveis.
        else
          -- Se não for, adiciona a chave e o valor à string resultante.
          result = result .. fullKey .. " = " .. tostring(value) .. "\n"
        end
      end
    end
  
    -- Chama a função recursiva para iniciar o processamento.
    processTable(tbl, "")
  
    -- Retorna a string formatada.
    return result
  end
  
  
  --- Função para imprimir o conteúdo de uma tabela no console.
  --- This function is a wrapper around the external function cavebotGetWaypointTypeById.
  --- @param tbl (table) - A tabela a ser impressa.
  --- @param hide (boolean) - Opcional - indica se a tabela deve ser impressa (true) ou não (false), Default: true.
  --- @return (string) - Uma string representando a tabela, com chaves e valores.
  function printTable(tbl, hide)
    -- Converte a tabela em uma string formatada.
    local tableString = tableToString(tbl)
  
    -- Imprime a string apenas se show_or_no for true.
    if hide == false or hide == nil then
      print(tableString)
    end
  end
  
  --- Função para imprimir qualquer dado como uma string no console.
  --- @param scope (any) - dado a ser impresso.
  --- @return (none)
  function printString(scope)
    print(tostring(scope))
  end
  
  --- Função para exibir mensagens no console e no cliente.
  --- @param message (string): A mensagem a ser exibida.
  --- @return (none)
  function showMessage(message)
    print(message)
    Client.showMessage(message)
  end


  

--- Função para obter estatísticas das coordenadas dos tiles do mapa.
--- Executa Map.getTiles() e retorna estatísticas de x, y e z.
--- @return (table) - Tabela com estatísticas: {x = {maior, menor, quantidade}, y = {maior, menor, quantidade}, z = {maior, menor, quantidade}}
function getMapTilesStats()
    local tiles = Map.getTiles()
    
    if not tiles or type(tiles) ~= "table" then
        return {
            x = {maior = 0, menor = 0, quantidade = 0},
            y = {maior = 0, menor = 0, quantidade = 0},
            z = {maior = 0, menor = 0, quantidade = 0}
        }
    end
    
    local stats = {
        x = {maior = -math.huge, menor = math.huge, quantidade = 0},
        y = {maior = -math.huge, menor = math.huge, quantidade = 0},
        z = {maior = -math.huge, menor = math.huge, quantidade = 0}
    }
    
    -- Processa cada tile
    for _, tile in pairs(tiles) do
        if tile and tile.pos then
            -- Processa coordenada X
            if tile.pos.x then
                stats.x.quantidade = stats.x.quantidade + 1
                if tile.pos.x > stats.x.maior then
                    stats.x.maior = tile.pos.x
                end
                if tile.pos.x < stats.x.menor then
                    stats.x.menor = tile.pos.x
                end
            end
            
            -- Processa coordenada Y
            if tile.pos.y then
                stats.y.quantidade = stats.y.quantidade + 1
                if tile.pos.y > stats.y.maior then
                    stats.y.maior = tile.pos.y
                end
                if tile.pos.y < stats.y.menor then
                    stats.y.menor = tile.pos.y
                end
            end
            
            -- Processa coordenada Z
            if tile.pos.z then
                stats.z.quantidade = stats.z.quantidade + 1
                if tile.pos.z > stats.z.maior then
                    stats.z.maior = tile.pos.z
                end
                if tile.pos.z < stats.z.menor then
                    stats.z.menor = tile.pos.z
                end
            end
        end
    end
    
    -- Ajusta valores se não houver tiles
    if stats.x.quantidade == 0 then
        stats.x.maior = 0
        stats.x.menor = 0
    end
    if stats.y.quantidade == 0 then
        stats.y.maior = 0
        stats.y.menor = 0
    end
    if stats.z.quantidade == 0 then
        stats.z.maior = 0
        stats.z.menor = 0
    end
    
    return stats
end

print("EndLoad Prints.lua")

--- testes

printTable(Map.getCameraPosition(), false)
print("--------------------------------")
printTable(Map.getTiles(), false)
print("--------------------------------")
printTable(getMapTilesStats(), false)
