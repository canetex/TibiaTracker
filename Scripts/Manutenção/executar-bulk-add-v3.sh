#!/bin/bash

# =============================================================================
# SCRIPT PARA EXECUTAR ADIÇÃO EM MASSA V3
# =============================================================================

echo "=== EXECUTANDO ADIÇÃO EM MASSA V3 ==="
echo ""

# Baixar a versão V3
echo "📥 Baixando versão V3 do script..."
wget https://raw.githubusercontent.com/canetex/TibiaTracker/stable-version/Scripts/Manutenção/bulk-add-characters-fixed-v3.sh -O /opt/tibia-tracker/Scripts/Manutenção/bulk-add-characters-fixed-v3.sh

# Tornar executável
echo "🔧 Tornando script executável..."
chmod +x /opt/tibia-tracker/Scripts/Manutenção/bulk-add-characters-fixed-v3.sh

# Criar diretório de log se não existir
echo "📁 Criando diretório de logs..."
mkdir -p /var/log/tibia-tracker

# Executar o script
echo "🚀 Executando adição em massa..."
echo ""

/opt/tibia-tracker/Scripts/Manutenção/bulk-add-characters-fixed-v3.sh

echo ""
echo "=== EXECUÇÃO CONCLUÍDA ==="
echo "📄 Log completo disponível em: /var/log/tibia-tracker/bulk-add.log"
echo "📊 Para monitorar em tempo real: tail -f /var/log/tibia-tracker/bulk-add.log" 