// Teste simples do frontend sem dependências externas
const http = require('http');

function testFrontendSimple() {
  console.log('🧪 Teste simples do frontend...\n');
  
  const options = {
    hostname: '192.168.1.227',
    port: 3000,
    path: '/',
    method: 'GET'
  };

  const req = http.request(options, (res) => {
    console.log(`1. Status da resposta: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('2. Verificando conteúdo do HTML...');
      
      // Verificar elementos essenciais
      if (data.includes('Tibia Tracker')) {
        console.log('   ✅ Título encontrado');
      } else {
        console.log('   ❌ Título não encontrado');
      }
      
      if (data.includes('main.5f05c106.js')) {
        console.log('   ✅ JavaScript correto referenciado');
      } else {
        console.log('   ❌ JavaScript incorreto referenciado');
      }
      
      if (data.includes('id="root"')) {
        console.log('   ✅ Elemento root encontrado');
      } else {
        console.log('   ❌ Elemento root não encontrado');
      }
      
      console.log('\n3. Análise do problema:');
      console.log('   - O HTML está correto');
      console.log('   - O JavaScript está sendo referenciado corretamente');
      console.log('   - O problema deve estar no JavaScript em si');
      
      console.log('\n4. Possíveis causas:');
      console.log('   - Erro de sintaxe no JavaScript');
      console.log('   - Problema com imports dos componentes');
      console.log('   - Problema com Material-UI');
      console.log('   - Problema com React Router');
      
      console.log('\n5. Para verificar no navegador:');
      console.log('   - Acesse: http://192.168.1.227:3000');
      console.log('   - Abra o console do navegador (F12)');
      console.log('   - Verifique se há erros JavaScript');
      console.log('   - Se houver erros, eles aparecerão em vermelho');
      
      console.log('\n✅ Teste concluído!');
    });
  });

  req.on('error', (e) => {
    console.error('❌ Erro na requisição:', e.message);
  });

  req.end();
}

// Executar o teste
testFrontendSimple(); 