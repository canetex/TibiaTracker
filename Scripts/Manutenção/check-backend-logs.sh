#!/bin/bash

echo "=== VERIFICAÇÃO DOS LOGS DO BACKEND ==="
echo ""

echo "1. Status do container backend:"
docker-compose ps backend
echo ""

echo "2. Últimos 30 logs do backend:"
docker-compose logs --tail=30 backend
echo ""

echo "3. Verificando se há erros de importação:"
docker-compose logs backend | grep -i "error\|exception\|traceback" | tail -10
echo ""

echo "4. Verificando se as rotas estão sendo registradas:"
docker-compose logs backend | grep -i "router\|route\|endpoint" | tail -10
echo ""

echo "5. Testando se o backend está respondendo na porta correta:"
netstat -tlnp | grep :8000
echo ""

echo "6. Verificando se o arquivo de rotas existe no container:"
docker-compose exec backend ls -la /app/app/api/routes/
echo ""

echo "=== FIM DA VERIFICAÇÃO ===" 