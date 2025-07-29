import React, { useState, useEffect } from 'react';
import { Search, RefreshCw, TrendingUp, User, BarChart3, Filter } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { useToast } from '@/hooks/use-toast';

import CharacterCard from '@/components/CharacterCard';
import CharacterSearch from '@/components/CharacterSearch';
import CharacterChartsModal from '@/components/CharacterChartsModal';
import CharacterFilters from '@/components/CharacterFilters';
import ComparisonPanel from '@/components/ComparisonPanel';
import ComparisonChart from '@/components/ComparisonChart';
import { apiService } from '@/services/api';
import { useFavorites } from '@/contexts/FavoritesContext';

const Home = () => {
  const [searchLoading, setSearchLoading] = useState(false);
  const [recentCharacters, setRecentCharacters] = useState([]);
  const [loadingRecent, setLoadingRecent] = useState(false);
  const [globalStats, setGlobalStats] = useState(null);
  const [searchResult, setSearchResult] = useState(null);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({
    server: '',
    world: '',
    vocation: '',
    guild: '',
    search: '',
    minLevel: '',
    maxLevel: '',
    isFavorited: '',
    activityFilter: [],
    recoveryActive: '',
    limit: 'all',
  });
  const [filteredCharacters, setFilteredCharacters] = useState([]);
  
  // Estados para o modal de gráficos
  const [chartsModalOpen, setChartsModalOpen] = useState(false);
  const [selectedCharacterForCharts, setSelectedCharacterForCharts] = useState(null);
  
  // Estados para comparação de personagens
  const [comparisonCharacters, setComparisonCharacters] = useState([]);
  const [comparisonChartOpen, setComparisonChartOpen] = useState(false);
  const [filteredChartOpen, setFilteredChartOpen] = useState(false);

  // Contexto de favoritos
  const { isFavorite, favorites } = useFavorites();
  const { toast } = useToast();

  // Carregar dados iniciais
  useEffect(() => {
    loadInitialData();
  }, []);

  const loadInitialData = async () => {
    try {
      console.log('[LOAD] Iniciando carregamento de dados iniciais...');
      setLoadingRecent(true);
      setError(null);
      
      // Carregar personagens recentes (limitado) e estatísticas globais em paralelo
      console.log('[LOAD] Carregando personagens recentes e estatísticas globais...');
      const [recent, stats] = await Promise.all([
        apiService.getRecentCharacters(10), // Carregar apenas 10 recentes
        apiService.getGlobalStats(),
      ]);
      
      console.log('[LOAD] Personagens recentes recebidos:', recent);
      console.log('[LOAD] Estatísticas globais recebidas:', stats);
      
      setRecentCharacters(recent);
      setFilteredCharacters(recent);
      setGlobalStats(stats);
      
    } catch (err) {
      console.error('Erro ao carregar dados iniciais:', err);
      setError('Erro ao carregar dados. Tente novamente.');
    } finally {
      setLoadingRecent(false);
    }
  };

  // Função para carregar todos os personagens quando necessário para filtros
  const loadAllCharacters = async () => {
    try {
      console.log('[LOAD] Iniciando carregamento de todos os personagens...');
      setLoadingRecent(true);
      setError(null);
      
      // Carregar TODOS os personagens para filtros (usando limite alto)
      const allCharacters = await apiService.listCharacters({ limit: 1000 });
      
      console.log(`[LOAD] Carregados ${allCharacters.characters?.length || 0} personagens`);
      setRecentCharacters(allCharacters.characters || []);
      setFilteredCharacters(allCharacters.characters || []);
      
    } catch (err) {
      console.error('Erro ao carregar todos os personagens:', err);
      setError('Erro ao carregar dados. Tente novamente.');
    } finally {
      setLoadingRecent(false);
    }
  };

  const handleFilterChange = async (newFilters) => {
    console.log('[FILTER] handleFilterChange chamado com:', newFilters);
    setFilters(newFilters);
    setLoadingRecent(true);
    setError(null);

    // Verificar se há filtros ativos (incluindo favoritos)
    const hasActiveFilters = Object.entries(newFilters).some(([key, value]) => {
      if (Array.isArray(value)) {
        return value.length > 0;
      }
      return value !== '' && value !== 'all';
    });

    if (hasActiveFilters) {
      try {
        // Montar parâmetros para a API de filtro de IDs (incluindo favoritos)
        const filterParams = {};
        if (newFilters.search) filterParams.search = newFilters.search;
        if (newFilters.server) filterParams.server = newFilters.server;
        if (newFilters.world) filterParams.world = newFilters.world;
        if (newFilters.vocation) filterParams.vocation = newFilters.vocation;
        if (newFilters.guild) filterParams.guild = newFilters.guild;
        if (newFilters.minLevel) filterParams.min_level = newFilters.minLevel;
        if (newFilters.maxLevel) filterParams.max_level = newFilters.maxLevel;
        if (newFilters.activityFilter && newFilters.activityFilter.length > 0) {
          filterParams.activity_filter = newFilters.activityFilter;
        }
        if (newFilters.isFavorited === 'true') {
          filterParams.is_favorited = 'true';
          filterParams.favorite_ids = favorites;
          console.log('[FAVORITES] IDs enviados:', favorites);
        } else if (newFilters.isFavorited === 'false') {
          filterParams.is_favorited = 'false';
          filterParams.favorite_ids = favorites;
          console.log('[FAVORITES] IDs enviados:', favorites);
        }
        if (newFilters.recoveryActive === 'true') {
          filterParams.recovery_active = 'true';
        } else if (newFilters.recoveryActive === 'false') {
          filterParams.recovery_active = 'false';
        }
        if (newFilters.limit && newFilters.limit !== 'all') {
          filterParams.limit = newFilters.limit;
        } else {
          filterParams.limit = 1000;
        }

        // 1. Buscar IDs filtrados (incluindo favoritos via API)
        console.log('[FILTER] Buscando IDs filtrados com parâmetros:', filterParams);
        const idsResult = await apiService.filterCharacterIds(filterParams);
        const ids = idsResult.ids || [];
        console.log('[FILTER] IDs encontrados:', ids);
        
        // 2. Buscar dados completos por IDs
        let chars = [];
        if (ids.length > 0) {
          console.log('[FILTER] Buscando dados completos para', ids.length, 'personagens');
          chars = await apiService.getCharactersByIds(ids);
          console.log('[FILTER] Dados completos recebidos:', chars);
        }
        
        setFilteredCharacters(chars);
      } catch (err) {
        console.error('Erro ao aplicar filtros:', err);
        setError('Erro ao aplicar filtros. Tente novamente.');
      } finally {
        setLoadingRecent(false);
      }
    } else {
      // Se não há filtros ativos, usar apenas os personagens recentes
      setFilteredCharacters(recentCharacters);
      setLoadingRecent(false);
    }
  };

  const handleClearFilters = () => {
    const clearedFilters = {
      server: '',
      world: '',
      vocation: '',
      guild: '',
      search: '',
      minLevel: '',
      maxLevel: '',
      isFavorited: '',
      activityFilter: [],
      recoveryActive: '',
      limit: 'all',
    };
    setFilters(clearedFilters);
    setFilteredCharacters(recentCharacters);
  };

  // Função para filtros rápidos via tags dos cards
  const handleQuickFilter = (filterType, value) => {
    console.log(`[QUICK_FILTER] Aplicando filtro rápido: ${filterType} = ${value}`);
    console.log(`[QUICK_FILTER] Filtros atuais:`, filters);
    
    const newFilters = { ...filters };
    
    switch (filterType) {
      case 'server':
        newFilters.server = value;
        break;
      case 'world':
        newFilters.world = value;
        break;
      case 'vocation':
        newFilters.vocation = value;
        break;
      case 'guild':
        newFilters.guild = value;
        break;
      default:
        console.log(`[QUICK_FILTER] Tipo de filtro não reconhecido: ${filterType}`);
        break;
    }
    
    console.log(`[QUICK_FILTER] Novos filtros:`, newFilters);
    setFilters(newFilters); // Atualiza o estado global dos filtros
    handleFilterChange(newFilters);
  };

  const handleAddToComparison = (character) => {
    if (!comparisonCharacters.some(c => c.id === character.id)) {
      setComparisonCharacters([...comparisonCharacters, character]);
      toast({
        title: "Adicionado à comparação",
        description: `${character.name} foi adicionado ao painel de comparação.`,
      });
    }
  };

  const handleRemoveFromComparison = (characterId) => {
    setComparisonCharacters(comparisonCharacters.filter(c => c.id !== characterId));
  };

  const handleClearComparison = () => {
    setComparisonCharacters([]);
  };

  const handleShowComparison = () => {
    if (comparisonCharacters.length > 1) {
      setComparisonChartOpen(true);
    }
  };

  const handleShowFilteredChart = () => {
    if (filteredCharacters.length > 1) {
      setFilteredChartOpen(true);
    }
  };

  const handleCharacterSearch = async (searchData) => {
    try {
      setSearchLoading(true);
      setError(null);
      
      const result = await apiService.searchCharacter(searchData.name, searchData.server);
      
      if (result) {
        setSearchResult(result);
        // Carregar todos os personagens para mostrar na lista
        await loadAllCharacters();
      } else {
        setError('Personagem não encontrado.');
      }
    } catch (err) {
      console.error('Erro na busca:', err);
      setError('Erro ao buscar personagem. Tente novamente.');
    } finally {
      setSearchLoading(false);
    }
  };

  // Função para atualizar personagem
  const handleRefreshCharacter = async (characterId) => {
    try {
      console.log(`[REFRESH] Atualizando personagem ${characterId}`);
      
      // Chamar API para atualizar personagem
      await apiService.refreshCharacter(characterId);
      
      // Recarregar dados e re-aplicar filtros
      await loadInitialData();
      
      // Re-aplicar filtros se houver filtros ativos
      if (hasActiveFilters) {
        console.log(`[REFRESH] Re-aplicando filtros após refresh...`);
        await handleFilterChange(filters);
      }
      
      console.log(`[REFRESH] Personagem ${characterId} atualizado com sucesso`);
      toast({
        title: "Personagem atualizado",
        description: "Os dados do personagem foram atualizados com sucesso.",
      });
      
    } catch (err) {
      console.error('Erro ao atualizar personagem:', err);
      setError('Erro ao atualizar personagem. Tente novamente.');
    }
  };

  const handleViewCharts = (character) => {
    setSelectedCharacterForCharts(character);
    setChartsModalOpen(true);
  };

  const handleCloseChartsModal = () => {
    setChartsModalOpen(false);
    setSelectedCharacterForCharts(null);
  };

  const handleToggleRecovery = async (characterId) => {
    try {
      const response = await apiService.toggleRecovery(characterId);
      if (response.success) {
        // Atualizar o personagem na lista
        const updatedCharacters = recentCharacters.map(char => 
          char.id === characterId 
            ? { ...char, recovery_active: response.recovery_active }
            : char
        );
        setRecentCharacters(updatedCharacters);
        setFilteredCharacters(updatedCharacters);
        
        toast({
          title: "Recovery alterado",
          description: `Status de recovery foi ${response.recovery_active ? 'ativado' : 'desativado'}.`,
        });
      }
    } catch (error) {
      console.error('Erro ao alterar recovery:', error);
      setError('Erro ao alterar status de recovery');
    }
  };

  const handleManualScrape = async (characterId) => {
    try {
      const response = await apiService.manualScrape(characterId);
      if (response.success) {
        // Recarregar dados do personagem
        await handleRefreshCharacter(characterId);
      } else {
        setError(`Erro no scraping: ${response.message}`);
      }
    } catch (error) {
      console.error('Erro no scraping manual:', error);
      setError('Erro ao fazer scraping manual');
    }
  };

  // Função utilitária para saber se há filtros ativos
  const hasActiveFilters = Object.values(filters).some(value => {
    if (Array.isArray(value)) {
      return value.length > 0;
    }
    return value !== '' && value !== 'all';
  });

  return (
    <div className="p-6 space-y-6">
      {/* Search Section */}
      <Card>
        <CardHeader>
          <div className="flex items-center space-x-2">
            <Search className="h-5 w-5 text-primary" />
            <CardTitle className="text-xl font-semibold">
              Pesquisar Personagem
            </CardTitle>
          </div>
        </CardHeader>
        <CardContent>
          <CharacterSearch 
            onSearch={handleCharacterSearch}
            loading={searchLoading}
          />
          
          {error && (
            <Alert className="mt-4">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Filters Section */}
      <CharacterFilters 
        filters={filters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
        onShowChart={handleShowFilteredChart}
        filteredCount={filteredCharacters.length}
      />

      {/* Search Result */}
      {searchResult && (
        <div className="space-y-4">
          <div className="flex items-center space-x-2">
            <BarChart3 className="h-5 w-5" />
            <h2 className="text-lg font-semibold">Resultado da Busca</h2>
          </div>
          <CharacterCard 
            character={searchResult} 
            onViewCharts={handleViewCharts}
            onRefresh={handleRefreshCharacter}
            onQuickFilter={handleQuickFilter}
          />
        </div>
      )}

      {/* Recent Characters */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <TrendingUp className="h-5 w-5" />
            <h2 className="text-lg font-semibold">
              {hasActiveFilters ? 'Personagens Filtrados' : (searchResult ? 'Outros Recentes' : 'Personagens Recentes')}
            </h2>
            {Object.keys(filters).length > 0 && (
              <Badge variant="secondary">
                {filteredCharacters.length.toLocaleString('pt-BR')} de {globalStats?.total_characters?.toLocaleString('pt-BR') || recentCharacters.length.toLocaleString('pt-BR')}
              </Badge>
            )}
          </div>
          
          <Button
            variant="outline"
            size="sm"
            onClick={loadInitialData}
            disabled={loadingRecent}
          >
            <RefreshCw className="mr-2 h-4 w-4" />
            Atualizar
          </Button>
        </div>

        {loadingRecent ? (
          <div className="flex justify-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
          </div>
        ) : filteredCharacters.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredCharacters.map((character) => (
              <CharacterCard 
                key={character.id}
                character={character} 
                onViewCharts={handleViewCharts}
                onRefresh={handleRefreshCharacter}
                onAddToComparison={handleAddToComparison}
                onRemoveFromComparison={handleRemoveFromComparison}
                isInComparison={comparisonCharacters.some(c => c.id === character.id)}
                onQuickFilter={handleQuickFilter}
                onToggleRecovery={handleToggleRecovery}
                onManualScrape={handleManualScrape}
              />
            ))}
          </div>
        ) : recentCharacters.length > 0 ? (
          <Card className="p-8 text-center">
            <div className="flex flex-col items-center space-y-4">
              <Filter className="h-12 w-12 text-muted-foreground" />
              <div>
                <h3 className="text-lg font-medium text-muted-foreground">
                  Nenhum personagem encontrado com os filtros aplicados
                </h3>
                <p className="text-sm text-muted-foreground">
                  Tente ajustar os filtros ou limpar para ver todos
                </p>
              </div>
            </div>
          </Card>
        ) : (
          <Card className="p-8 text-center">
            <div className="flex flex-col items-center space-y-4">
              <User className="h-12 w-12 text-muted-foreground" />
              <div>
                <h3 className="text-lg font-medium text-muted-foreground">
                  Nenhum personagem encontrado
                </h3>
                <p className="text-sm text-muted-foreground">
                  Seja o primeiro a adicionar um personagem!
                </p>
              </div>
            </div>
          </Card>
        )}
      </div>

      {/* Modal de Gráficos */}
      <CharacterChartsModal
        open={chartsModalOpen}
        onClose={handleCloseChartsModal}
        character={selectedCharacterForCharts}
      />

      {/* Painel de Comparação */}
      <ComparisonPanel
        characters={comparisonCharacters}
        onRemoveCharacter={handleRemoveFromComparison}
        onShowComparison={handleShowComparison}
        onClearAll={handleClearComparison}
      />

      {/* Gráfico de Comparação */}
      <ComparisonChart
        characters={comparisonCharacters}
        open={comparisonChartOpen}
        onClose={() => setComparisonChartOpen(false)}
      />

      {/* Gráfico dos Filtrados */}
      <ComparisonChart
        characters={filteredCharacters}
        open={filteredChartOpen}
        onClose={() => setFilteredChartOpen(false)}
      />
    </div>
  );
};

export default Home; 