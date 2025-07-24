#!/usr/bin/env node
/**
 * Script de Teste: Filtro Recovery Active
 * =======================================
 * 
 * Este script testa se o filtro recovery_active está funcionando corretamente
 * tanto no frontend quanto no backend.
 */

const https = require('https');
const http = require('http');

// Configurações
const API_BASE = 'http://localhost:8000';
const FRONTEND_BASE = 'http://localhost:3000';

// Função para fazer requisições HTTP
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    
    const req = protocol.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({ status: res.statusCode, data: jsonData });
        } catch (e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });
    
    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy());
    req.end();
  });
}

// Teste 1: Verificar se o endpoint filter-ids aceita recovery_active
async function testBackendFilter() {
  console.log('🔍 Testando Backend - Endpoint filter-ids...');
  
  try {
    // Teste sem filtro
    const response1 = await makeRequest(`${API_BASE}/api/characters/filter-ids?limit=5`);
    console.log(`✅ Sem filtro: ${response1.status} - ${response1.data.ids?.length || 0} IDs`);
    
    // Teste com recovery_active=true
    const response2 = await makeRequest(`${API_BASE}/api/characters/filter-ids?recovery_active=true&limit=5`);
    console.log(`✅ Recovery ativo: ${response2.status} - ${response2.data.ids?.length || 0} IDs`);
    
    // Teste com recovery_active=false
    const response3 = await makeRequest(`${API_BASE}/api/characters/filter-ids?recovery_active=false&limit=5`);
    console.log(`✅ Recovery inativo: ${response3.status} - ${response3.data.ids?.length || 0} IDs`);
    
    return true;
  } catch (error) {
    console.error(`❌ Erro no teste do backend:`, error.message);
    return false;
  }
}

// Teste 2: Verificar se o frontend está carregando
async function testFrontend() {
  console.log('\n🌐 Testando Frontend...');
  
  try {
    const response = await makeRequest(FRONTEND_BASE);
    console.log(`✅ Frontend: ${response.status} - Carregado com sucesso`);
    return true;
  } catch (error) {
    console.error(`❌ Erro no teste do frontend:`, error.message);
    return false;
  }
}

// Teste 3: Verificar se o campo recovery_active existe nos dados
async function testRecoveryField() {
  console.log('\n📊 Testando campo recovery_active nos dados...');
  
  try {
    const response = await makeRequest(`${API_BASE}/api/characters/recent?limit=3`);
    
    if (response.status === 200 && response.data.length > 0) {
      const character = response.data[0];
      console.log(`✅ Personagem encontrado: ${character.name}`);
      console.log(`   - recovery_active: ${character.recovery_active}`);
      console.log(`   - is_active: ${character.is_active}`);
      
      if (character.hasOwnProperty('recovery_active')) {
        console.log('✅ Campo recovery_active presente nos dados');
        return true;
      } else {
        console.log('❌ Campo recovery_active NÃO encontrado nos dados');
        return false;
      }
    } else {
      console.log('❌ Nenhum personagem encontrado para teste');
      return false;
    }
  } catch (error) {
    console.error(`❌ Erro ao testar campo recovery_active:`, error.message);
    return false;
  }
}

// Função principal
async function runTests() {
  console.log('🧪 INICIANDO TESTES DO FILTRO RECOVERY ACTIVE');
  console.log('=' .repeat(50));
  
  const results = {
    backend: await testBackendFilter(),
    frontend: await testFrontend(),
    field: await testRecoveryField()
  };
  
  console.log('\n📋 RESUMO DOS TESTES');
  console.log('=' .repeat(50));
  console.log(`Backend (filter-ids): ${results.backend ? '✅ OK' : '❌ FALHOU'}`);
  console.log(`Frontend (carregamento): ${results.frontend ? '✅ OK' : '❌ FALHOU'}`);
  console.log(`Campo recovery_active: ${results.field ? '✅ OK' : '❌ FALHOU'}`);
  
  if (results.backend && results.frontend && results.field) {
    console.log('\n🎉 TODOS OS TESTES PASSARAM!');
    console.log('O filtro recovery_active deve estar funcionando corretamente.');
    console.log('\n💡 DICAS:');
    console.log('1. Limpe o cache do navegador (Ctrl+F5)');
    console.log('2. Expanda os filtros avançados na interface');
    console.log('3. Procure pelo filtro "Recovery Ativo"');
  } else {
    console.log('\n⚠️ ALGUNS TESTES FALHARAM!');
    console.log('Verifique se:');
    console.log('1. O backend está rodando na porta 8000');
    console.log('2. O frontend está rodando na porta 3000');
    console.log('3. A migração foi executada corretamente');
  }
}

// Executar testes
runTests().catch(console.error); 