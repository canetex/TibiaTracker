import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Grid,
  Alert,
  CircularProgress,
  Chip,
  Paper,
} from '@mui/material';
import {
  Search as SearchIcon,
  Refresh as RefreshIcon,
  TrendingUp,
  Person,
  Analytics,
  FilterList,
} from '@mui/icons-material';

import CharacterCard from '../components/CharacterCard';
import CharacterSearch from '../components/CharacterSearch';
import CharacterChartsModal from '../components/CharacterChartsModal';
import CharacterFilters from '../components/CharacterFilters';
import ComparisonPanel from '../components/ComparisonPanel';
import ComparisonChart from '../components/ComparisonChart';
import { apiService } from '../services/api';
import { useFavorites } from '../contexts/FavoritesContext';

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
    recoveryActive: '', // Adicionar campo recoveryActive
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

  // Função para aplicar filtros de favoritos no frontend (REMOVIDA - agora via API)
  // const applyFavoritesFilter = (characters, isFavoritedFilter) => {
  //   if (isFavoritedFilter === 'true') {
  //     return characters.filter(character => isFavorite(character.id));
  //   } else if (isFavoritedFilter === 'false') {
  //     return characters.filter(character => !isFavorite(character.id));
  //   }
  //   return characters;
  // };

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
      recoveryActive: '', // Adicionar campo recoveryActive
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
    <Box sx={{ p: 3 }}>
      {/* Header - Removido título duplicado */}


      {/* Search Section */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
            <SearchIcon sx={{ mr: 1, color: 'primary.main' }} />
            <Typography variant="h5" component="h2" sx={{ fontWeight: 600 }}>
              Pesquisar Personagem
            </Typography>
          </Box>
          
          <CharacterSearch 
            onSearch={handleCharacterSearch}
            loading={searchLoading}
          />
          
          {error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {error}
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
        <Box sx={{ mb: 4 }}>
          <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
            <Analytics sx={{ mr: 1 }} />
            Resultado da Busca
          </Typography>
          <CharacterCard 
            character={searchResult} 
            onViewCharts={handleViewCharts}
            onRefresh={handleRefreshCharacter}
            onQuickFilter={handleQuickFilter}
          />
        </Box>
      )}

      {/* Recent Characters */}
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h6" component="h2" sx={{ display: 'flex', alignItems: 'center' }}>
            <TrendingUp sx={{ mr: 1 }} />
            {hasActiveFilters ? 'Personagens Filtrados' : (searchResult ? 'Outros Recentes' : 'Personagens Recentes')}
            {Object.keys(filters).length > 0 && (
              <Chip 
                label={`${filteredCharacters.length.toLocaleString('pt-BR')} de ${globalStats?.total_characters?.toLocaleString('pt-BR') || recentCharacters.length.toLocaleString('pt-BR')}`}
                size="small"
                color="primary"
                sx={{ ml: 1 }}
              />
            )}
          </Typography>
          
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={loadInitialData}
            disabled={loadingRecent}
            size="small"
          >
            Atualizar
          </Button>
        </Box>

        {loadingRecent ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
            <CircularProgress />
          </Box>
        ) : filteredCharacters.length > 0 ? (
          <Grid container spacing={3}>
            {filteredCharacters.map((character) => (
              <Grid item xs={12} md={6} lg={4} key={character.id}>
                <CharacterCard 
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
              </Grid>
            ))}
          </Grid>
        ) : recentCharacters.length > 0 ? (
          <Paper 
            elevation={0} 
            sx={{ 
              p: 4, 
              textAlign: 'center', 
              bgcolor: 'grey.50',
              border: '2px dashed',
              borderColor: 'grey.300'
            }}
          >
            <FilterList sx={{ fontSize: 48, color: 'grey.400', mb: 2 }} />
            <Typography variant="h6" color="text.secondary">
              Nenhum personagem encontrado com os filtros aplicados
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Tente ajustar os filtros ou limpar para ver todos
            </Typography>
          </Paper>
        ) : (
          <Paper 
            elevation={0} 
            sx={{ 
              p: 4, 
              textAlign: 'center', 
              bgcolor: 'grey.50',
              border: '2px dashed',
              borderColor: 'grey.300'
            }}
          >
            <Person sx={{ fontSize: 48, color: 'grey.400', mb: 2 }} />
            <Typography variant="h6" color="text.secondary">
              Nenhum personagem encontrado
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Seja o primeiro a adicionar um personagem!
            </Typography>
          </Paper>
        )}
      </Box>

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
    </Box>
  );
};

export default Home; 