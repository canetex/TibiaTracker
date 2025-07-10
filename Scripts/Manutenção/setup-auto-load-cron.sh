#!/bin/bash
"""
Script para configurar CRON do Auto-Load de Personagens
=======================================================

Este script configura o CRON para executar o auto-load-new-chars.py a cada 3 dias.
"""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Configurando CRON para Auto-Load de Personagens${NC}"
echo "=================================================="

# Verificar se estamos no diretório correto
if [ ! -f "auto-load-new-chars.py" ]; then
    echo -e "${RED}❌ Erro: auto-load-new-chars.py não encontrado no diretório atual${NC}"
    echo "Execute este script no diretório Scripts/Manutenção/"
    exit 1
fi

# Obter caminho absoluto do script
SCRIPT_PATH=$(pwd)/auto-load-new-chars.py
echo -e "${BLUE}📁 Caminho do script: ${SCRIPT_PATH}${NC}"

# Verificar se o script é executável
if [ ! -x "$SCRIPT_PATH" ]; then
    echo -e "${YELLOW}⚠️  Tornando script executável...${NC}"
    chmod +x "$SCRIPT_PATH"
fi

# Verificar se Python 3 está disponível
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Erro: Python 3 não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Python 3 encontrado${NC}"

# Criar entrada do CRON
CRON_ENTRY="0 2 */3 * * cd $(pwd) && python3 $SCRIPT_PATH >> auto-load-cron.log 2>&1"

echo -e "${BLUE}📅 Entrada do CRON que será adicionada:${NC}"
echo -e "${YELLOW}$CRON_ENTRY${NC}"
echo ""

echo -e "${BLUE}📋 Explicação:${NC}"
echo "   - 0 2: Executar às 2:00 da manhã"
echo "   - */3: A cada 3 dias"
echo "   - * *: Todos os meses, todos os dias da semana"
echo "   - cd $(pwd): Mudar para o diretório do script"
echo "   - python3 $SCRIPT_PATH: Executar o script"
echo "   - >> auto-load-cron.log 2>&1: Salvar logs no arquivo"
echo ""

# Perguntar se deseja continuar
read -p "Deseja adicionar esta entrada ao CRON? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔧 Adicionando entrada ao CRON...${NC}"
    
    # Criar backup do CRON atual
    crontab -l > crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true
    
    # Adicionar nova entrada
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Entrada do CRON adicionada com sucesso!${NC}"
        
        echo -e "${BLUE}📋 CRON atual:${NC}"
        crontab -l
        
        echo ""
        echo -e "${GREEN}🎉 Configuração concluída!${NC}"
        echo -e "${BLUE}📝 O script será executado automaticamente a cada 3 dias às 2:00 da manhã${NC}"
        echo -e "${BLUE}📊 Logs serão salvos em: auto-load-cron.log${NC}"
        
    else
        echo -e "${RED}❌ Erro ao adicionar entrada do CRON${NC}"
        exit 1
    fi
    
else
    echo -e "${YELLOW}⚠️  Operação cancelada${NC}"
    echo ""
    echo -e "${BLUE}💡 Para adicionar manualmente, execute:${NC}"
    echo -e "${YELLOW}crontab -e${NC}"
    echo -e "${BLUE}E adicione a linha:${NC}"
    echo -e "${YELLOW}$CRON_ENTRY${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Comandos úteis:${NC}"
echo -e "${YELLOW}crontab -l${NC}          # Ver entradas do CRON"
echo -e "${YELLOW}crontab -e${NC}          # Editar CRON"
echo -e "${YELLOW}tail -f auto-load-cron.log${NC}  # Acompanhar logs em tempo real"
echo -e "${YELLOW}python3 auto-load-new-chars.py${NC}  # Executar manualmente" 