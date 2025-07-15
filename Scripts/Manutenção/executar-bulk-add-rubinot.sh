#!/bin/bash

# =============================================================================
# SCRIPT PARA EXECUTAR ADIÇÃO EM MASSA DO RUBINOT
# =============================================================================

echo "=== EXECUTANDO ADIÇÃO EM MASSA DO RUBINOT ==="
echo ""

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Execute este script na raiz do projeto (onde está o docker-compose.yml)"
    exit 1
fi

# Verificar se o arquivo CSV existe
if [ ! -f "Scripts/InitialLoad/Rubinot.csv" ]; then
    echo "❌ Arquivo Rubinot.csv não encontrado em Scripts/InitialLoad/"
    echo "Certifique-se de que o arquivo existe antes de executar este script"
    exit 1
fi

# Verificar se o container do backend está rodando
if ! docker-compose ps | grep -q "backend.*Up"; then
    echo "❌ Container do backend não está rodando"
    echo "Inicie com: docker-compose up -d"
    exit 1
fi

# Tornar script executável
echo "🔧 Tornando script executável..."
chmod +x Scripts/Manutenção/bulk-add-rubinot.sh

# Criar diretório de log se não existir
echo "📁 Criando diretório de logs..."
mkdir -p /var/log/tibia-tracker

# Mostrar informações do arquivo CSV
echo "📊 Informações do arquivo CSV:"
echo "   - Arquivo: Scripts/InitialLoad/Rubinot.csv"
echo "   - Linhas: $(wc -l < Scripts/InitialLoad/Rubinot.csv)"
echo "   - Tamanho: $(du -h Scripts/InitialLoad/Rubinot.csv | cut -f1)"
echo ""

# Mostrar distribuição por mundo
echo "📋 Distribuição por mundo:"
tail -n +2 Scripts/InitialLoad/Rubinot.csv | cut -d';' -f1 | sort | uniq -c | sort -nr | while read count world; do
    echo "   - $world: $count personagens"
done
echo ""

# Confirmação do usuário
echo "⚠️ ATENÇÃO: Este script irá processar TODOS os personagens do Rubinot.csv"
echo "   - Isso pode levar várias horas"
echo "   - Certifique-se de que o backend está funcionando corretamente"
echo "   - O log será salvo em: /var/log/tibia-tracker/bulk-add-rubinot.log"
echo ""
read -p "Deseja continuar? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada pelo usuário"
    exit 1
fi

# Executar o script
echo "🚀 Executando adição em massa do Rubinot..."
echo ""

Scripts/Manutenção/bulk-add-rubinot.sh

echo ""
echo "=== EXECUÇÃO CONCLUÍDA ==="
echo "📄 Log completo disponível em: /var/log/tibia-tracker/bulk-add-rubinot.log"
echo "📊 Para monitorar em tempo real: tail -f /var/log/tibia-tracker/bulk-add-rubinot.log"
echo ""
echo "🔍 Para verificar o progresso:"
echo "   - Total de personagens: curl http://localhost:8000/api/v1/characters/stats/global"
echo "   - Personagens por mundo: curl http://localhost:8000/api/v1/bulk/stats/rubinot/auroria"
echo ""
echo "📈 Para acompanhar o processamento:"
echo "   - Logs do backend: docker-compose logs -f backend"
echo "   - Logs do script: tail -f /var/log/tibia-tracker/bulk-add-rubinot.log" 