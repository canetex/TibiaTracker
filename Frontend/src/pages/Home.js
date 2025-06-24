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
} from '@mui/icons-material';

import CharacterCard from '../components/CharacterCard';
import CharacterSearch from '../components/CharacterSearch';
import { apiService } from '../services/api';

const Home = () => {
  const [searchLoading, setSearchLoading] = useState(false);
  const [recentCharacters, setRecentCharacters] = useState([]);
  const [loadingRecent, setLoadingRecent] = useState(false);
  const [globalStats, setGlobalStats] = useState(null);
  const [searchResult, setSearchResult] = useState(null);
  const [error, setError] = useState(null);

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
      setGlobalStats(stats);
      
    } catch (err) {
      console.error('Erro ao carregar dados iniciais:', err);
      setError('Erro ao carregar dados. Tente novamente.');
    } finally {
      setLoadingRecent(false);
    }
  };

  const handleCharacterSearch = async (searchData) => {
    try {
      setSearchLoading(true);
      setError(null);
      
      const character = await apiService.searchCharacter(
        searchData.name,
        searchData.server,
        searchData.world
      );
      
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

      {/* Search Result */}
      {searchResult && (
        <Box sx={{ mb: 4 }}>
          <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
            <Analytics sx={{ mr: 1 }} />
            Resultado da Busca
          </Typography>
          <CharacterCard character={searchResult} />
        </Box>
      )}

      {/* Recent Characters */}
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h6" component="h2" sx={{ display: 'flex', alignItems: 'center' }}>
            <TrendingUp sx={{ mr: 1 }} />
            {searchResult ? 'Outros Personagens Recentes' : 'Personagens Adicionados Recentemente'}
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
        ) : recentCharacters.length > 0 ? (
          <Grid container spacing={3}>
            {recentCharacters.map((character) => (
              <Grid item xs={12} md={6} lg={4} key={character.id}>
                <CharacterCard character={character} />
              </Grid>
            ))}
          </Grid>
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
    </Box>
  );
};

export default Home; 