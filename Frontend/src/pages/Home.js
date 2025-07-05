import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  TextField,
  Button,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
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
import { apiService } from '../services/api';

const Home = () => {
  const [searchLoading, setSearchLoading] = useState(false);
  const [recentCharacters, setRecentCharacters] = useState([]);
  const [loadingRecent, setLoadingRecent] = useState(false);
  const [globalStats, setGlobalStats] = useState(null);
  const [searchResult, setSearchResult] = useState(null);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({});
  const [filteredCharacters, setFilteredCharacters] = useState([]);
  
  // Estados para o modal de gráficos
  const [chartsModalOpen, setChartsModalOpen] = useState(false);
  const [selectedCharacterForCharts, setSelectedCharacterForCharts] = useState(null);

  // Carregar dados iniciais
  useEffect(() => {
    loadInitialData();
  }, []);

  const loadInitialData = async () => {
    try {
      setLoadingRecent(true);
      setError(null);
      
      // Carregar personagens recentes e estatísticas globais em paralelo
      const [recent, stats] = await Promise.all([
        apiService.getRecentCharacters(),
        apiService.getGlobalStats(),
      ]);
      
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

  // Função para aplicar filtros
  const applyFilters = (characters, currentFilters) => {
    if (!currentFilters || Object.keys(currentFilters).length === 0) {
      return characters;
    }

    return characters.filter(character => {
      // Filtro por nome
      if (currentFilters.search && !character.name.toLowerCase().includes(currentFilters.search.toLowerCase())) {
        return false;
      }

      // Filtro por servidor
      if (currentFilters.server && character.server !== currentFilters.server) {
        return false;
      }

      // Filtro por mundo
      if (currentFilters.world && character.world !== currentFilters.world) {
        return false;
      }

      // Filtro por vocação
      if (currentFilters.vocation && character.vocation !== currentFilters.vocation) {
        return false;
      }

      // Filtro por level mínimo
      if (currentFilters.minLevel) {
        const level = character.latest_snapshot?.level || character.level || 0;
        if (level < parseInt(currentFilters.minLevel)) {
          return false;
        }
      }

      // Filtro por level máximo
      if (currentFilters.maxLevel) {
        const level = character.latest_snapshot?.level || character.level || 0;
        if (level > parseInt(currentFilters.maxLevel)) {
          return false;
        }
      }

      // Filtro por favoritos
      if (currentFilters.isFavorited !== '') {
        const isFavorited = currentFilters.isFavorited === 'true';
        if (character.is_favorited !== isFavorited) {
          return false;
        }
      }

      return true;
    });
  };

  const handleFilterChange = (newFilters) => {
    setFilters(newFilters);
    const filtered = applyFilters(recentCharacters, newFilters);
    setFilteredCharacters(filtered);
  };

  const handleClearFilters = () => {
    setFilters({});
    setFilteredCharacters(recentCharacters);
  };

  const handleCharacterSearch = async (searchData) => {
    try {
      setSearchLoading(true);
      setError(null);
      
      // Primeiro fazer busca normal
      const searchResult = await apiService.searchCharacter(
        searchData.name,
        searchData.server,
        searchData.world
      );
      
      // Extrair o character corretamente da resposta
      let character = null;
      if (searchResult.success && searchResult.character) {
        character = searchResult.character;
      } else {
        throw new Error('Resposta inválida do servidor');
      }
      
      // Se encontrou o character, fazer scraping com histórico para obter dados completos
      if (character.id) {
        try {
          console.log('Fazendo scraping com histórico para dados completos...');
          await apiService.scrapeWithHistory(
            searchData.name,
            searchData.server,
            searchData.world
          );
          console.log('Scraping com histórico concluído');
        } catch (historyError) {
          console.warn('Erro no scraping com histórico, usando dados básicos:', historyError);
          // Continua com os dados básicos se houver erro no histórico
        }
      }
      
      setSearchResult(character);
      
      // Atualizar lista de recentes após busca bem-sucedida
      setTimeout(loadInitialData, 1000);
      
    } catch (err) {
      console.error('Erro na busca:', err);
      setError(err.response?.data?.detail?.message || 'Personagem não encontrado ou erro no servidor');
      setSearchResult(null);
    } finally {
      setSearchLoading(false);
    }
  };

  const handleViewCharts = (character) => {
    console.log('HandleViewCharts chamado com:', character);
    // Verificar se o character tem ID válido
    if (!character || !character.id) {
      console.error('Character sem ID válido:', character);
      setError('Erro: Personagem sem ID válido');
      return;
    }
    
    setSelectedCharacterForCharts(character);
    setChartsModalOpen(true);
  };

  const handleCloseChartsModal = () => {
    try {
      setChartsModalOpen(false);
      setSelectedCharacterForCharts(null);
    } catch (error) {
      console.error('Erro ao fechar modal:', error);
      // Force reset se houver erro
      setTimeout(() => {
        setChartsModalOpen(false);
        setSelectedCharacterForCharts(null);
      }, 100);
    }
  };

  return (
    <Box>
      {/* Header/Welcome Section */}
      <Paper 
        elevation={0} 
        sx={{ 
          background: 'linear-gradient(135deg, #1565C0 0%, #42A5F5 100%)',
          color: 'white',
          p: 4,
          mb: 4,
          borderRadius: 2
        }}
      >
        <Typography variant="h3" component="h1" gutterBottom sx={{ fontWeight: 700 }}>
          🏰 Bem-vindo ao Tibia Tracker
        </Typography>
        <Typography variant="h6" sx={{ opacity: 0.9, mb: 2 }}>
          Monitore a evolução dos seus personagens favoritos do Tibia
        </Typography>
        
        {/* Estatísticas Globais */}
        {globalStats && (
          <Grid container spacing={2} sx={{ mt: 2 }}>
            <Grid item xs={12} sm={4}>
              <Box sx={{ textAlign: 'center' }}>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {globalStats.total_characters || 0}
                </Typography>
                <Typography variant="body2" sx={{ opacity: 0.8 }}>
                  Personagens Monitorados
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={12} sm={4}>
              <Box sx={{ textAlign: 'center' }}>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {globalStats.total_snapshots || 0}
                </Typography>
                <Typography variant="body2" sx={{ opacity: 0.8 }}>
                  Snapshots Coletados
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={12} sm={4}>
              <Box sx={{ textAlign: 'center' }}>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {globalStats.favorited_characters || 0}
                </Typography>
                <Typography variant="body2" sx={{ opacity: 0.8 }}>
                  Personagens Favoritados
                </Typography>
              </Box>
            </Grid>
          </Grid>
        )}
      </Paper>

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
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
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
          />
        </Box>
      )}

      {/* Recent Characters */}
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h6" component="h2" sx={{ display: 'flex', alignItems: 'center' }}>
            <TrendingUp sx={{ mr: 1 }} />
            {searchResult ? 'Outros Personagens Recentes' : 'Personagens Adicionados Recentemente'}
            {Object.keys(filters).length > 0 && (
              <Chip 
                label={`${filteredCharacters.length} de ${recentCharacters.length}`}
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
              Tente ajustar os filtros ou limpar para ver todos os personagens
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
    </Box>
  );
};

export default Home; 