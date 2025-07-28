import React, { useState } from 'react';
import Header from '@/components/Header';
import CharacterSearch from '@/components/CharacterSearch';
import CharacterFilters from '@/components/CharacterFilters';
import CharacterCard from '@/components/CharacterCard';
import ComparisonPanel from '@/components/ComparisonPanel';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Users, TrendingUp, Globe, Crown } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

const Home = () => {
  const [characters, setCharacters] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showComparison, setShowComparison] = useState(false);
  const { toast } = useToast();

  const handleSearch = async (searchData) => {
    setLoading(true);
    try {
      // Simular busca - será integrado com a API real
      toast({
        title: "Busca realizada",
        description: "Procurando por personagens...",
        variant: "info"
      });
      
      // Aqui será integrado com a API real
      setTimeout(() => {
        setLoading(false);
        toast({
          title: "Sucesso!",
          description: "Personagens encontrados",
          variant: "success"
        });
      }, 2000);
    } catch (error) {
      setLoading(false);
      toast({
        title: "Erro",
        description: "Erro ao buscar personagens",
        variant: "destructive"
      });
    }
  };

  const handleFavoriteToggle = (characterId) => {
    toast({
      title: "Favorito atualizado",
      description: "Lista de favoritos atualizada",
      variant: "success"
    });
  };

  const handleRefresh = (characterId) => {
    toast({
      title: "Atualizando...",
      description: "Dados do personagem sendo atualizados",
      variant: "info"
    });
  };

  return (
    <div className="min-h-screen bg-background">
      <Header onMenuClick={() => {}} />
      
      <main className="container mx-auto p-6 space-y-6">
        {/* Hero Section */}
        <div className="text-center space-y-4 py-8">
          <h1 className="text-4xl font-bold gradient-text">
            Monitoramento de Personagens Tibia
          </h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Acompanhe a evolução dos seus personagens favoritos com estatísticas detalhadas e gráficos interativos
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <Card className="tibia-card">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total de Personagens</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">1,234</div>
              <p className="text-xs text-muted-foreground">
                +12% em relação ao mês passado
              </p>
            </CardContent>
          </Card>

          <Card className="tibia-card">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Personagens Online</CardTitle>
              <Globe className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">89</div>
              <p className="text-xs text-muted-foreground">
                7.2% dos personagens ativos
              </p>
            </CardContent>
          </Card>

          <Card className="tibia-card">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Experiência Total</CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">2.5B</div>
              <p className="text-xs text-muted-foreground">
                +8.5% esta semana
              </p>
            </CardContent>
          </Card>

          <Card className="tibia-card">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Nível Médio</CardTitle>
              <Crown className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">156</div>
              <p className="text-xs text-muted-foreground">
                +3 níveis em média
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Search and Filters */}
        <div className="space-y-6">
          <CharacterSearch onSearch={handleSearch} loading={loading} />
          <CharacterFilters />
        </div>

        {/* Characters Grid */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">Personagens</h2>
            <Button 
              variant="tibia" 
              onClick={() => setShowComparison(!showComparison)}
            >
              Comparar Personagens
            </Button>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Character cards will be rendered here */}
            {characters.map((character) => (
              <CharacterCard
                key={character.id}
                character={character}
                onFavoriteToggle={handleFavoriteToggle}
                onRefresh={handleRefresh}
              />
            ))}
          </div>
        </div>

        {/* Comparison Panel */}
        {showComparison && (
          <ComparisonPanel />
        )}
      </main>
    </div>
  );
};

export default Home; 