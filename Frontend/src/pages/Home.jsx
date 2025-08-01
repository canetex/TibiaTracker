import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Input } from '../components/ui/input';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import {
  Search,
  RefreshCw,
  TrendingUp,
  Users,
  BarChart3,
  Filter,
  Star,
  Activity,
} from 'lucide-react';
import { toast } from 'sonner';

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

  // Carregar dados iniciais
  useEffect(() => {
    loadInitialData();
  }, []);

  const loadInitialData = async () => {
    try {
      setLoadingRecent(true);
      setError(null);
      
      const [recent, stats] = await Promise.all([
        apiService.getRecentCharacters(10),
        apiService.getGlobalStats(),
      ]);
      
      setRecentCharacters(recent);
      setFilteredCharacters(recent);
      setGlobalStats(stats);
      
    } catch (err) {
      console.error('Erro ao carregar dados iniciais:', err);
      setError('Erro ao carregar dados. Tente novamente.');
      toast.error('Erro ao carregar dados iniciais');
    } finally {
      setLoadingRecent(false);
    }
  };

  const loadAllCharacters = async () => {
    try {
      setLoadingRecent(true);
      const allCharacters = await apiService.getAllCharacters();
      setRecentCharacters(allCharacters);
      setFilteredCharacters(allCharacters);
    } catch (err) {
      console.error('Erro ao carregar todos os personagens:', err);
      toast.error('Erro ao carregar personagens');
    } finally {
      setLoadingRecent(false);
    }
  };

  const handleSearch = async (characterName) => {
    if (!characterName.trim()) {
      toast.error('Digite o nome do personagem');
      return;
    }

    try {
      setSearchLoading(true);
      setError(null);
      
      const result = await apiService.searchCharacter(characterName);
      setSearchResult(result);
      toast.success('Personagem encontrado!');
      
    } catch (err) {
      console.error('Erro na busca:', err);
      setError('Personagem não encontrado ou erro na busca');
      toast.error('Personagem não encontrado');
    } finally {
      setSearchLoading(false);
    }
  };

  const handleRefreshCharacter = async (characterId) => {
    try {
      await apiService.refreshCharacter(characterId);
      await loadInitialData();
      toast.success('Personagem atualizado!');
    } catch (err) {
      console.error('Erro ao atualizar personagem:', err);
      toast.error('Erro ao atualizar personagem');
    }
  };

  const handleViewCharts = (character) => {
    setSelectedCharacterForCharts(character);
    setChartsModalOpen(true);
  };

  const handleAddToComparison = (character) => {
    if (comparisonCharacters.length >= 5) {
      toast.error('Máximo de 5 personagens para comparação');
      return;
    }
    
    if (!comparisonCharacters.find(c => c.id === character.id)) {
      setComparisonCharacters([...comparisonCharacters, character]);
      toast.success(`${character.name} adicionado à comparação`);
    }
  };

  const handleRemoveFromComparison = (characterId) => {
    setComparisonCharacters(comparisonCharacters.filter(c => c.id !== characterId));
    toast.success('Personagem removido da comparação');
  };

  const handleQuickFilter = (filterType, value) => {
    const newFilters = { ...filters, [filterType]: value };
    setFilters(newFilters);
    applyFilters(newFilters);
  };

  const applyFilters = async (currentFilters) => {
    try {
      if (Object.values(currentFilters).some(v => v && v !== '')) {
        if (recentCharacters.length < 50) {
          await loadAllCharacters();
        }
        
        const filtered = await apiService.getFilteredCharacters(currentFilters);
        setFilteredCharacters(filtered);
      } else {
        setFilteredCharacters(recentCharacters);
      }
    } catch (err) {
      console.error('Erro ao aplicar filtros:', err);
      toast.error('Erro ao aplicar filtros');
    }
  };

  const handleToggleRecovery = async (characterId) => {
    try {
      await apiService.toggleRecoveryStatus(characterId);
      await loadInitialData();
    } catch (err) {
      console.error('Erro ao alterar status de recuperação:', err);
      throw err;
    }
  };

  return (
    <div className="space-y-6">
      {/* Hero Section */}
      <div className="text-center py-8">
        <h1 className="text-4xl font-bold text-gradient mb-4">
          Tibia Tracker
        </h1>
        <p className="text-lg text-muted-foreground mb-6">
          Monitor completo de personagens para servidores Tibia
        </p>
        
        {/* Search Section */}
        <CharacterSearch 
          onSearch={handleSearch}
          loading={searchLoading}
          searchResult={searchResult}
          onAddCharacter={() => loadInitialData()}
        />
      </div>

      {/* Global Stats */}
      {globalStats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total de Personagens</p>
                  <p className="text-2xl font-bold">{globalStats.total_characters}</p>
                </div>
                <Users className="h-8 w-8 text-primary" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Ativos Hoje</p>
                  <p className="text-2xl font-bold">{globalStats.active_today}</p>
                </div>
                <Activity className="h-8 w-8 text-green-500" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Exp. Total Hoje</p>
                  <p className="text-2xl font-bold">
                    {(globalStats.total_exp_today / 1000000).toFixed(1)}M
                  </p>
                </div>
                <TrendingUp className="h-8 w-8 text-yellow-500" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Servidores</p>
                  <p className="text-2xl font-bold">{globalStats.total_servers}</p>
                </div>
                <BarChart3 className="h-8 w-8 text-blue-500" />
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Main Content */}
      <Tabs defaultValue="characters" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="characters">Personagens</TabsTrigger>
          <TabsTrigger value="comparison">
            Comparação {comparisonCharacters.length > 0 && `(${comparisonCharacters.length})`}
          </TabsTrigger>
          <TabsTrigger value="favorites">
            Favoritos {favorites.length > 0 && `(${favorites.length})`}
          </TabsTrigger>
        </TabsList>

        <TabsContent value="characters" className="space-y-6">
          {/* Filters */}
          <CharacterFilters 
            filters={filters}
            onFiltersChange={setFilters}
            onApplyFilters={applyFilters}
            onClearFilters={() => {
              setFilters({
                server: '', world: '', vocation: '', guild: '', search: '',
                minLevel: '', maxLevel: '', isFavorited: '', activityFilter: [],
                recoveryActive: '', limit: 'all',
              });
              setFilteredCharacters(recentCharacters);
            }}
          />

          {/* Characters Grid */}
          {loadingRecent ? (
            <div className="flex items-center justify-center py-12">
              <div className="flex items-center space-x-2">
                <RefreshCw className="h-6 w-6 animate-spin" />
                <span>Carregando personagens...</span>
              </div>
            </div>
          ) : filteredCharacters.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {filteredCharacters.map((character) => (
                <CharacterCard
                  key={character.id}
                  character={character}
                  onRefresh={handleRefreshCharacter}
                  onViewCharts={handleViewCharts}
                  onAddToComparison={handleAddToComparison}
                  onRemoveFromComparison={handleRemoveFromComparison}
                  isInComparison={comparisonCharacters.some(c => c.id === character.id)}
                  onQuickFilter={handleQuickFilter}
                  onToggleRecovery={handleToggleRecovery}
                />
              ))}
            </div>
          ) : (
            <Card>
              <CardContent className="p-12 text-center">
                <p className="text-lg text-muted-foreground">
                  Nenhum personagem encontrado com os filtros aplicados
                </p>
                <Button 
                  variant="outline" 
                  onClick={loadInitialData}
                  className="mt-4"
                >
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Recarregar
                </Button>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="comparison">
          <ComparisonPanel 
            characters={comparisonCharacters}
            onRemoveCharacter={handleRemoveFromComparison}
            onClearAll={() => setComparisonCharacters([])}
            onShowChart={() => setComparisonChartOpen(true)}
          />
        </TabsContent>

        <TabsContent value="favorites">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {filteredCharacters.filter(char => isFavorite(char.id)).map((character) => (
              <CharacterCard
                key={character.id}
                character={character}
                onRefresh={handleRefreshCharacter}
                onViewCharts={handleViewCharts}
                onAddToComparison={handleAddToComparison}
                onRemoveFromComparison={handleRemoveFromComparison}
                isInComparison={comparisonCharacters.some(c => c.id === character.id)}
                onQuickFilter={handleQuickFilter}
                onToggleRecovery={handleToggleRecovery}
              />
            ))}
          </div>
        </TabsContent>
      </Tabs>

      {/* Modals */}
      {chartsModalOpen && selectedCharacterForCharts && (
        <CharacterChartsModal
          character={selectedCharacterForCharts}
          open={chartsModalOpen}
          onClose={() => {
            setChartsModalOpen(false);
            setSelectedCharacterForCharts(null);
          }}
        />
      )}

      {comparisonChartOpen && (
        <ComparisonChart
          characters={comparisonCharacters}
          open={comparisonChartOpen}
          onClose={() => setComparisonChartOpen(false)}
        />
      )}

      {error && (
        <Card className="border-destructive">
          <CardContent className="p-6">
            <p className="text-destructive">{error}</p>
          </CardContent>
        </Card>
      )}
    </div>
  );
};

export default Home;