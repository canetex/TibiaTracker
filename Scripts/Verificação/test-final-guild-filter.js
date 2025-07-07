// Script de teste final para verificar o filtro por guild
const API_URL = 'http://localhost:8000/api/v1';

async function testFinalGuildFilter() {
  console.log('🎯 Teste Final do Filtro por Guild\n');
  
  try {
    // 1. Verificar se o backend está funcionando
    console.log('1. Verificando backend...');
    const healthResponse = await fetch(`${API_URL.replace('/api/v1', '')}/health`);
    if (healthResponse.ok) {
      console.log('   ✅ Backend funcionando');
    } else {
      console.log('   ❌ Backend com problemas');
      return;
    }
    
    // 2. Testar endpoint /recent com guild
    console.log('\n2. Testando endpoint /recent:');
    const recentResponse = await fetch(`${API_URL}/characters/recent?limit=5`);
    const recentData = await recentResponse.json();
    
    const guilds = recentData.filter(char => char.guild).map(char => char.guild);
    const uniqueGuilds = [...new Set(guilds)];
    
    console.log(`   Guilds encontradas: ${uniqueGuilds.join(', ')}`);
    
    // 3. Testar filtro por guild específica
    if (uniqueGuilds.length > 0) {
      const testGuild = uniqueGuilds[0];
      console.log(`\n3. Testando filtro por "${testGuild}":`);
      
      const filterResponse = await fetch(`${API_URL}/characters/?guild=${encodeURIComponent(testGuild)}&limit=3`);
      const filterData = await filterResponse.json();
      
      console.log(`   Encontrados ${filterData.characters.length} personagens:`);
      filterData.characters.forEach(char => {
        console.log(`   - ${char.name} (${char.guild})`);
      });
    }
    
    // 4. Instruções para teste no navegador
    console.log('\n4. Para testar no navegador:');
    console.log('   - Acesse: http://localhost:3000');
    console.log('   - No campo "Guild", digite: "Final" ou "Monster"');
    console.log('   - Verifique se os personagens são filtrados corretamente');
    console.log('   - Abra o console do navegador (F12) para ver os logs de debug');
    
    console.log('\n🎉 Teste final concluído!');
    console.log('   Se o filtro não funcionar no navegador, verifique:');
    console.log('   - Console do navegador para erros');
    console.log('   - Network tab para ver as requisições');
    console.log('   - Se o campo guild está sendo preenchido nos dados');
    
  } catch (error) {
    console.error('❌ Erro no teste final:', error);
  }
}

// Executar o teste
testFinalGuildFilter(); 