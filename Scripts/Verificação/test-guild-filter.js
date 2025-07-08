// Script de teste para verificar o filtro por guild
const API_BASE = 'http://localhost:8000/api/v1';

async function testGuildFilter() {
  console.log('🧪 Testando filtro por guild...\n');
  
  try {
    // 1. Buscar personagens com guild "Final"
    console.log('1. Testando filtro por guild "Final":');
    const response1 = await fetch(`${API_BASE}/characters/?guild=Final&limit=5`);
    const data1 = await response1.json();
    
    console.log(`   Encontrados ${data1.characters.length} personagens:`);
    data1.characters.forEach(char => {
      console.log(`   - ${char.name} (${char.guild})`);
    });
    
    // 2. Buscar personagens com guild "Monster"
    console.log('\n2. Testando filtro por guild "Monster":');
    const response2 = await fetch(`${API_BASE}/characters/?guild=Monster&limit=5`);
    const data2 = await response2.json();
    
    console.log(`   Encontrados ${data2.characters.length} personagens:`);
    data2.characters.forEach(char => {
      console.log(`   - ${char.name} (${char.guild})`);
    });
    
    // 3. Verificar endpoint /recent
    console.log('\n3. Verificando endpoint /recent:');
    const response3 = await fetch(`${API_BASE}/characters/recent?limit=5`);
    const data3 = await response3.json();
    
    console.log(`   Primeiros 5 personagens recentes:`);
    data3.forEach(char => {
      console.log(`   - ${char.name} (${char.guild || 'Sem guild'})`);
    });
    
    console.log('\n✅ Teste concluído!');
    
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  }
}

// Executar o teste
testGuildFilter(); 