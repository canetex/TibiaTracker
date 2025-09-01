-- ========================================
-- FUNÇÃO DE CONVERSÃO DE CORES HEX PARA RGB
-- ========================================

-- Função para converter cor hexadecimal para RGB
-- Parâmetros:
--   hexString: string com cor em hexadecimal (ex: "FFFFFF", "#FFFFFF", "FFF")
-- Retorna:
--   table com estrutura RGB {r = valor, g = valor, b = valor} ou nil se inválido
function ColorHEX(hexString)
    -- Verifica se o parâmetro é válido
    if not hexString or type(hexString) ~= "string" then
        return nil
    end
    
    -- Remove o # se existir
    local hex = hexString:gsub("#", "")
    
    -- Verifica se a string tem tamanho válido (3, 6 ou 8 caracteres)
    local len = #hex
    if len ~= 3 and len ~= 6 and len ~= 8 then
        return nil
    end
    
    -- Verifica se contém apenas caracteres hexadecimais válidos
    if not hex:match("^[0-9A-Fa-f]+$") then
        return nil
    end
    
    local r, g, b
    
    if len == 3 then
        -- Formato de 3 caracteres (RGB)
        r = tonumber(hex:sub(1, 1) .. hex:sub(1, 1), 16)
        g = tonumber(hex:sub(2, 2) .. hex:sub(2, 2), 16)
        b = tonumber(hex:sub(3, 3) .. hex:sub(3, 3), 16)
    elseif len == 6 then
        -- Formato de 6 caracteres (RRGGBB)
        r = tonumber(hex:sub(1, 2), 16)
        g = tonumber(hex:sub(3, 4), 16)
        b = tonumber(hex:sub(5, 6), 16)
    elseif len == 8 then
        -- Formato de 8 caracteres (RRGGBBAA) - ignora o alpha
        r = tonumber(hex:sub(1, 2), 16)
        g = tonumber(hex:sub(3, 4), 16)
        b = tonumber(hex:sub(5, 6), 16)
    end
    
    -- Verifica se a conversão foi bem-sucedida
    if r and g and b then
        return {r = r, g = g, b = b}
    else
        return nil
    end
end

-- ========================================
-- FUNÇÕES AUXILIARES
-- ========================================

-- Função para validar se uma cor RGB é válida
function IsValidRGB(r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return false
    end
    return r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255
end

-- Função para converter RGB para hexadecimal
function RGBToHEX(r, g, b)
    if not IsValidRGB(r, g, b) then
        return nil
    end
    
    return string.format("#%02X%02X%02X", r, g, b)
end

-- ========================================
-- EXEMPLOS DE USO E TESTES
-- ========================================

-- Função para testar a conversão
function TestColorConversion()
    local testCases = {
        "FFFFFF",    -- Branco
        "#FF0000",   -- Vermelho
        "00FF00",    -- Verde
        "0000FF",    -- Azul
        "FFF",       -- Branco (3 chars)
        "F00",       -- Vermelho (3 chars)
        "FFFF0000",  -- Vermelho com alpha
        "invalid",   -- Inválido
        "",          -- Vazio
        nil          -- Nil
    }
    
    print("=== TESTE DE CONVERSÃO DE CORES ===")
    for i, testCase in ipairs(testCases) do
        local result = ColorHEX(testCase)
        if result then
            print(string.format("'%s' -> RGB(r=%d, g=%d, b=%d)", testCase or "nil", result.r, result.g, result.b))
        else
            print(string.format("'%s' -> INVÁLIDO", testCase or "nil"))
        end
    end
    print("==================================")
end

-- ========================================
-- DOCUMENTAÇÃO DE USO
-- ========================================

--[[
EXEMPLOS DE USO:

-- Conversão básica
local rgb = ColorHEX("FFFFFF")  -- Retorna {r = 255, g = 255, b = 255}
local rgb2 = ColorHEX("#FF0000") -- Retorna {r = 255, g = 0, b = 0}
local rgb3 = ColorHEX("FFF")     -- Retorna {r = 255, g = 255, b = 255}

-- Uso em configurações de HUD
local hudColor = ColorHEX("FFFF00")  -- Amarelo
if hudColor then
    hud:setColor(hudColor.r, hudColor.g, hudColor.b)
end

-- Acesso aos valores RGB
local color = ColorHEX("FF0000")
if color then
    print("Vermelho: " .. color.r)
    print("Verde: " .. color.g)
    print("Azul: " .. color.b)
end

-- Validação
local color = ColorHEX("invalid")
if not color then
    print("Cor inválida!")
end

FORMATOS SUPORTADOS:
- 3 caracteres: "FFF" -> RGB(r=255, g=255, b=255)
- 6 caracteres: "FFFFFF" -> RGB(r=255, g=255, b=255)
- 8 caracteres: "FFFFFFFF" -> RGB(r=255, g=255, b=255) (ignora alpha)
- Com #: "#FFFFFF" -> RGB(r=255, g=255, b=255)

ESTRUTURA DE RETORNO:
{
    r = valor_vermelho,    -- 0-255
    g = valor_verde,       -- 0-255
    b = valor_azul         -- 0-255
}

CARACTERÍSTICAS:
- Case insensitive (aceita maiúsculas e minúsculas)
- Remove automaticamente o # se presente
- Retorna nil para cores inválidas
- Validação completa de entrada
- Totalmente encapsulada e reutilizável
- Retorna estrutura RGB com campos nomeados
]]

print("Função ColorHEX carregada!")
print("Use ColorHEX(\"FFFFFF\") para converter cores hex para RGB")
print("Use TestColorConversion() para testar a função")
