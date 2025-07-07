// Script de debug para verificar problemas no frontend
const puppeteer = require('puppeteer');

async function debugFrontend() {
  console.log('🔍 Debugando frontend...\n');
  
  let browser;
  try {
    // Iniciar navegador
    browser = await puppeteer.launch({ 
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Interceptar requisições para ver se há erros
    page.on('console', msg => {
      console.log('Console:', msg.text());
    });
    
    page.on('pageerror', error => {
      console.log('Erro na página:', error.message);
    });
    
    // Navegar para o frontend
    console.log('1. Navegando para o frontend...');
    await page.goto('http://192.168.1.227:3000', { waitUntil: 'networkidle0' });
    
    // Verificar se a página carregou
    console.log('2. Verificando se a página carregou...');
    const title = await page.title();
    console.log(`   Título da página: ${title}`);
    
    // Verificar se há elementos específicos
    console.log('3. Verificando elementos da página...');
    
    // Verificar se há personagens
    const characters = await page.$$('[data-testid="character-card"]');
    console.log(`   Personagens encontrados: ${characters.length}`);
    
    // Verificar se há filtros
    const filters = await page.$$('button[aria-label*="Filtrar"]');
    console.log(`   Botões de filtro encontrados: ${filters.length}`);
    
    // Verificar se há botões de comparação
    const compareButtons = await page.$$('button[aria-label*="Comparação"]');
    console.log(`   Botões de comparação encontrados: ${compareButtons.length}`);
    
    // Verificar se há erros no console
    console.log('4. Verificando console...');
    const logs = await page.evaluate(() => {
      return window.console.logs || [];
    });
    
    if (logs.length > 0) {
      console.log('   Logs encontrados:', logs);
    } else {
      console.log('   Nenhum log encontrado');
    }
    
    // Verificar se há erros JavaScript
    const errors = await page.evaluate(() => {
      return window.console.errors || [];
    });
    
    if (errors.length > 0) {
      console.log('   Erros encontrados:', errors);
    } else {
      console.log('   Nenhum erro encontrado');
    }
    
    console.log('\n✅ Debug concluído!');
    
  } catch (error) {
    console.error('❌ Erro no debug:', error);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// Executar o debug
debugFrontend(); 