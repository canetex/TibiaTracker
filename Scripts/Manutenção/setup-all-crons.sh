#!/bin/bash
# Script para configurar todos os CRONs do sistema de auto-load
# ================================================================

echo "🎯 Configurando todos os CRONs do sistema de auto-load..."
echo ""

# Verificar se estamos no diretório correto
if [ ! -f "auto-load-new-chars.py" ]; then
    echo "❌ Erro: Execute este script no diretório Scripts/Manutenção/"
    exit 1
fi

# Verificar se Python 3 está disponível
if ! command -v python3 &> /dev/null; then
    echo "❌ Erro: Python 3 não encontrado"
    exit 1
fi

# Tornar o script principal executável
chmod +x auto-load-new-chars.py

# Backup do CRON atual
echo "📋 Fazendo backup do CRON atual..."
crontab -l > cron_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || echo "Nenhum CRON existente"

# Remover entradas antigas do script (se existirem)
echo "🧹 Removendo entradas antigas do CRON..."
(crontab -l 2>/dev/null | grep -v "auto-load-new-chars.py") | crontab -

# Configurar CRONs
SCRIPT_PATH=$(pwd)/auto-load-new-chars.py

echo "⏰ Configurando CRONs..."

# 1. Mortes (a cada 3 dias às 2:00 AM)
echo "   📊 Mortes: a cada 3 dias às 2:00 AM"
LOG_FILE_DEATHS=$(pwd)/auto-load-deaths-cron.log
(crontab -l 2>/dev/null; echo "0 2 */3 * * cd $(pwd) && python3 $SCRIPT_PATH --deaths-only --max-chars 100 >> $LOG_FILE_DEATHS 2>&1") | crontab -

# 2. Powergamers (diário às 3:00 AM)
echo "   📊 Powergamers: diário às 3:00 AM"
LOG_FILE_POWERGAMERS=$(pwd)/auto-load-powergamers-cron.log
(crontab -l 2>/dev/null; echo "0 3 * * * cd $(pwd) && python3 $SCRIPT_PATH --powergamers-only --max-chars 150 >> $LOG_FILE_POWERGAMERS 2>&1") | crontab -

# 3. Online (a cada hora)
echo "   📊 Online: a cada hora"
LOG_FILE_ONLINE=$(pwd)/auto-load-online-cron.log
(crontab -l 2>/dev/null; echo "0 * * * * cd $(pwd) && python3 $SCRIPT_PATH --online-only --max-chars 200 >> $LOG_FILE_ONLINE 2>&1") | crontab -

echo ""
echo "✅ Todos os CRONs configurados com sucesso!"
echo ""
echo "📊 Resumo da Configuração:"
echo "   🕐 02:00 AM a cada 3 dias: Mortes (100 chars/site)"
echo "   🕐 03:00 AM diário: Powergamers (150 chars/site)"
echo "   🕐 A cada hora: Online (200 chars/site)"
echo ""
echo "📝 Arquivos de Log:"
echo "   📄 $LOG_FILE_DEATHS"
echo "   📄 $LOG_FILE_POWERGAMERS"
echo "   📄 $LOG_FILE_ONLINE"
echo ""
echo "📋 Para verificar todos os CRONs:"
echo "   crontab -l"
echo ""
echo "📝 Para monitorar logs em tempo real:"
echo "   tail -f $LOG_FILE_DEATHS"
echo "   tail -f $LOG_FILE_POWERGAMERS"
echo "   tail -f $LOG_FILE_ONLINE"
echo ""
echo "🔄 Para executar manualmente:"
echo "   python3 $SCRIPT_PATH --deaths-only"
echo "   python3 $SCRIPT_PATH --powergamers-only"
echo "   python3 $SCRIPT_PATH --online-only"
echo ""
echo "❌ Para remover todos os CRONs:"
echo "   crontab -r" 