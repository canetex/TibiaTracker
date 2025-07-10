#!/bin/bash
# Script para configurar CRON para sites de mortes (a cada 3 dias)
# ================================================================

echo "🎯 Configurando CRON para sites de mortes (a cada 3 dias)..."

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
(crontab -l 2>/dev/null | grep -v "auto-load-new-chars.py.*--deaths-only") | crontab -

# Adicionar nova entrada para mortes (a cada 3 dias às 2:00 AM)
echo "⏰ Adicionando entrada no CRON: mortes a cada 3 dias às 2:00 AM"
SCRIPT_PATH=$(pwd)/auto-load-new-chars.py
LOG_FILE=$(pwd)/auto-load-deaths-cron.log

(crontab -l 2>/dev/null; echo "0 2 */3 * * cd $(pwd) && python3 $SCRIPT_PATH --deaths-only --max-chars 100 >> $LOG_FILE 2>&1") | crontab -

echo "✅ CRON configurado com sucesso!"
echo ""
echo "📊 Configuração:"
echo "   ⏰ Frequência: A cada 3 dias às 2:00 AM"
echo "   🎯 Sites: Apenas mortes (deaths.php)"
echo "   📝 Log: $LOG_FILE"
echo "   🔧 Comando: python3 $SCRIPT_PATH --deaths-only --max-chars 100"
echo ""
echo "📋 Para verificar:"
echo "   crontab -l"
echo ""
echo "📝 Para ver logs:"
echo "   tail -f $LOG_FILE"
echo ""
echo "🔄 Para executar manualmente:"
echo "   python3 $SCRIPT_PATH --deaths-only" 