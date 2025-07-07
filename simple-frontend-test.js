// Teste simples para verificar o frontend
const fetch = require('node-fetch');

async function simpleFrontendTest() {
  console.log('🧪 Teste simples do frontend...\n');
  
  try {
    // 1. Verificar se o frontend está respondendo
    console.log('1. Verificando resposta do frontend...');
    const response = await fetch('http://192.168.1.227:3000');
    const html = await response.text();
    
    if (html.includes('Tibia Tracker')) {
      console.log('   ✅ Frontend carregando corretamente');
    } else {
      console.log('   ❌ Frontend não está carregando corretamente');
      return;
    }
    
    // 2. Verificar se o JavaScript está sendo referenciado
    if (html.includes('main.5f05c106.js')) {
      console.log('   ✅ JavaScript correto referenciado');
    } else {
      console.log('   ❌ JavaScript incorreto referenciado');
    }
    
    // 3. Verificar se há elementos específicos no HTML
    console.log('\n2. Verificando elementos no HTML...');
    
    if (html.includes('id="root"')) {
      console.log('   ✅ Elemento root encontrado');
    } else {
      console.log('   ❌ Elemento root não encontrado');
    }
    
    if (html.includes('noscript')) {
      console.log('   ✅ Mensagem noscript encontrada');
    } else {
      console.log('   ❌ Mensagem noscript não encontrada');
    }
    
    // 4. Verificar se há problemas específicos
    console.log('\n3. Verificando possíveis problemas...');
    
    if (html.includes('error')) {
      console.log('   ⚠️ Possível erro encontrado no HTML');
    } else {
      console.log('   ✅ Nenhum erro aparente no HTML');
    }
    
    // 5. Instruções para verificar no navegador
    console.log('\n4. Para verificar no navegador:');
    console.log('   - Acesse: http://192.168.1.227:3000');
    console.log('   - Abra o console do navegador (F12)');
    console.log('   - Verifique se há erros JavaScript');
    console.log('   - Verifique se os componentes estão sendo renderizados');
    console.log('   - Se não aparecer nada, pode ser problema de JavaScript');
    console.log('   - Se aparecer mas sem botões, pode ser problema de CSS ou lógica');
    
    console.log('\n✅ Teste concluído!');
    
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  }
}

// Executar o teste
simpleFrontendTest(); 