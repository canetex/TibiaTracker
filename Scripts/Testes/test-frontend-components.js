// Script para testar se os componentes do frontend estão funcionando
const FRONTEND_URL = 'http://192.168.1.227:3000';
const API_URL = 'http://192.168.1.227:8000/api/v1';

async function testFrontendComponents() {
  console.log('🧪 Testando componentes do frontend...\n');
  
  try {
    // 1. Verificar se o frontend está carregando
    console.log('1. Verificando carregamento do frontend:');
    const response = await fetch(FRONTEND_URL);
    if (response.ok) {
      console.log('   ✅ Frontend carregando corretamente');
    } else {
      console.log('   ❌ Erro ao carregar frontend');
      return;
    }
    
    // 2. Verificar se a API está funcionando
    console.log('\n2. Verificando API:');
    const apiResponse = await fetch(`${API_URL}/characters/recent?limit=5`);
    if (apiResponse.ok) {
      const data = await apiResponse.json();
      console.log(`   ✅ API funcionando - ${data.length} personagens recentes`);
      
      // Verificar se os personagens têm os campos necessários
      if (data.length > 0) {
        const char = data[0];
        console.log(`   📋 Campos do personagem:`, {
          id: char.id,
          name: char.name,
          server: char.server,
          world: char.world,
          guild: char.guild,
          vocation: char.vocation,
          level: char.level
        });
      }
    } else {
      console.log('   ❌ Erro na API');
      return;
    }
    
    // 3. Instruções para verificar no navegador
    console.log('\n3. Para verificar no navegador:');
    console.log(`   - Acesse: ${FRONTEND_URL}`);
    console.log('   - Abra o console do navegador (F12)');
    console.log('   - Verifique se há erros JavaScript');
    console.log('   - Verifique se os componentes estão sendo renderizados');
    console.log('   - Teste os filtros e botões de comparação');
    
    // 4. Verificar se há problemas específicos
    console.log('\n4. Possíveis problemas:');
    console.log('   - Se os botões não aparecem, pode ser problema de CSS');
    console.log('   - Se há erros no console, pode ser problema de JavaScript');
    console.log('   - Se a página não carrega, pode ser problema de build');
    console.log('   - Se os dados não aparecem, pode ser problema de API');
    
    console.log('\n✅ Teste concluído!');
    
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  }
}

// Executar o teste
testFrontendComponents(); 