// Script para testar o filtro por guild no frontend
const FRONTEND_URL = 'http://localhost:3000';
const API_URL = 'http://localhost:8000/api/v1';

async function testFrontendGuildFilter() {
  console.log('🧪 Testando filtro por guild no frontend...\n');
  
  try {
    // 1. Verificar se o frontend está carregando dados
    console.log('1. Verificando carregamento inicial do frontend:');
    
    // Simular a requisição que o frontend faz
    const recentResponse = await fetch(`${API_URL}/characters/recent?limit=10`);
    const recentData = await recentResponse.json();
    
    console.log(`   Carregados ${recentData.length} personagens recentes:`);
    const guilds = recentData.filter(char => char.guild).map(char => char.guild);
    const uniqueGuilds = [...new Set(guilds)];
    
    console.log(`   Guilds encontradas: ${uniqueGuilds.join(', ')}`);
    
    // 2. Testar filtro por guild específica
    if (uniqueGuilds.length > 0) {
      const testGuild = uniqueGuilds[0];
      console.log(`\n2. Testando filtro por guild "${testGuild}":`);
      
      const filterResponse = await fetch(`${API_URL}/characters/?guild=${encodeURIComponent(testGuild)}&limit=5`);
      const filterData = await filterResponse.json();
      
      console.log(`   Encontrados ${filterData.characters.length} personagens da guild "${testGuild}":`);
      filterData.characters.forEach(char => {
        console.log(`   - ${char.name} (${char.guild})`);
      });
    }
    
    // 3. Verificar se há personagens sem guild
    const noGuild = recentData.filter(char => !char.guild);
    console.log(`\n3. Personagens sem guild: ${noGuild.length}`);
    
    // 4. Instruções para teste manual
    console.log('\n4. Para testar no navegador:');
    console.log(`   - Acesse: ${FRONTEND_URL}`);
    console.log(`   - No campo "Guild", digite: "Final" ou "Monster"`);
    console.log(`   - Verifique se os personagens são filtrados corretamente`);
    
    console.log('\n✅ Teste do frontend concluído!');
    
  } catch (error) {
    console.error('❌ Erro no teste do frontend:', error);
  }
}

// Executar o teste
testFrontendGuildFilter(); 