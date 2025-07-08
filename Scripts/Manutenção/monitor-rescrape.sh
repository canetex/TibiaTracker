#!/bin/bash

# Script para monitorar o processo de rescraping e notificar quando terminar
# Uso: ./monitor-rescrape.sh [PID]

SCRIPT_NAME="full-rescrape-all-characters.py"
PID=${1:-""}

echo "🔍 Monitorando processo de rescraping..."
echo "Script: $SCRIPT_NAME"
echo "PID fornecido: $PID"
echo "Data/Hora início: $(date)"
echo "----------------------------------------"

# Função para verificar se o processo ainda está rodando
check_process() {
    if [ -n "$PID" ]; then
        # Verificar por PID específico
        docker exec tibia-tracker-backend python -c "
import psutil
try:
    p = psutil.Process($PID)
    if p.is_running():
        print('RUNNING')
    else:
        print('STOPPED')
except psutil.NoSuchProcess:
    print('NOT_FOUND')
"
    else
        # Verificar por nome do script
        docker exec tibia-tracker-backend python -c "
import psutil
running = False
for p in psutil.process_iter(['pid', 'name', 'cmdline']):
    if p.info['name'] == 'python' and '$SCRIPT_NAME' in ' '.join(p.info['cmdline']):
        running = True
        print('RUNNING')
        break
if not running:
    print('STOPPED')
"
    fi
}

# Função para enviar notificação
send_notification() {
    echo "🎉 PROCESSAMENTO FINALIZADO!"
    echo "Data/Hora fim: $(date)"
    echo "----------------------------------------"
    
    # Mostrar logs finais
    echo "📋 Últimos logs do processamento:"
    docker exec tibia-tracker-backend tail -n 20 /app/logs/app.log
    
    # Opcional: tocar um beep (se disponível)
    if command -v beep >/dev/null 2>&1; then
        beep -f 1000 -l 500 -r 3
    fi
    
    # Opcional: enviar email (se configurado)
    # echo "Processamento de rescraping finalizado em $(date)" | mail -s "Tibia Tracker - Rescraping Concluído" seu-email@exemplo.com
    
    echo "✅ Monitoramento finalizado!"
}

# Loop principal de monitoramento
while true; do
    STATUS=$(check_process)
    
    case $STATUS in
        "RUNNING")
            echo "$(date '+%H:%M:%S') - ⏳ Processo ainda rodando..."
            sleep 30  # Verificar a cada 30 segundos
            ;;
        "STOPPED"|"NOT_FOUND")
            echo "$(date '+%H:%M:%S') - 🛑 Processo parou!"
            send_notification
            break
            ;;
        *)
            echo "$(date '+%H:%M:%S') - ❓ Status desconhecido: $STATUS"
            sleep 10
            ;;
    esac
done 