import React, { useState, useEffect } from 'react';
import { CharacterSelection } from './CharacterSelection';
import { ComparisonChart } from './ComparisonChart';
import { TopExpPanel } from './TopExpPanel';
import { LinearityPanel } from './LinearityPanel';
import { Dialog, DialogContent } from './ui/dialog';
import { Card } from './ui/card';
import { Users, Activity, TrendingUp, BarChart3 } from 'lucide-react';
import { apiService } from '../services/api';
import logger from '../lib/logger';

interface Character {
  id: string;
  name: string;
  level: number;
  vocation: string;
  world: string;
  experience: number;
  guild?: string;
  isOnline: boolean;
  recoveryActive: boolean;
  isFavorite: boolean;
  deaths: number;
  lastLogin: string;
  experienceGained24h?: number;
  levelProgress: number;
  pvpType: "Optional PvP" | "Open PvP" | "Retro Open PvP" | "Hardcore PvP";
}

interface ChartDataPoint {
  date: string;
  level: number;
  experience: number;
  experienceGained: number;
  deaths: number;
}

interface GlobalStats {
  total_characters: number;
  active_today: number;
  total_exp_today: number;
  total_servers: number;
}

export default function Dashboard(): JSX.Element {
  const [isComparisonOpen, setIsComparisonOpen] = useState(false);
  const [selectedCharacters, setSelectedCharacters] = useState<Character[]>([]);
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);
  const [characters, setCharacters] = useState<Character[]>([]);
  const [globalStats, setGlobalStats] = useState<GlobalStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadInitialData = async () => {
      try {
        setLoading(true);
        setError(null);
        const [chars, stats] = await Promise.all([
          apiService.getRecentCharacters(),
          apiService.getCharacterStats()
        ]);
        setCharacters(chars);
        setGlobalStats(stats);
      } catch (err) {
        logger.error('Erro ao carregar dados iniciais:', err);
        setError('Erro ao carregar dados iniciais');
      } finally {
        setLoading(false);
      }
    };

    loadInitialData();
  }, []);

  const handleCompare = async (chars: Character[]) => {
    try {
      setLoading(true);
      const data = await Promise.all(
        chars.map(char => apiService.getCharacterStats(char.id))
      );
      setChartData(data.flat());
      setSelectedCharacters(chars);
      setIsComparisonOpen(true);
    } catch (err) {
      logger.error('Erro ao carregar dados para comparação:', err);
      setError('Erro ao carregar dados para comparação');
    } finally {
      setLoading(false);
    }
  };

  const formatExperience = (exp: number) => {
    if (!exp || isNaN(exp)) return '0';
    if (exp >= 1000000000) return `${(exp / 1000000000).toFixed(1)}B`;
    if (exp >= 1000000) return `${(exp / 1000000).toFixed(1)}M`;
    if (exp >= 1000) return `${(exp / 1000).toFixed(1)}K`;
    return exp.toString();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center text-destructive p-4">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6 p-4 md:p-6">
      <h1 className="text-2xl md:text-3xl font-bold gradient-text text-center md:text-left">Dashboard</h1>
      
      {/* Global Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-4">
        <Card className="p-3 md:p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Total de Personagens</p>
              <p className="text-lg md:text-2xl font-bold">{globalStats?.total_characters || 0}</p>
            </div>
            <Users className="h-6 w-6 md:h-8 md:w-8 text-primary" />
          </div>
        </Card>

        <Card className="p-3 md:p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Ativos Hoje</p>
              <p className="text-lg md:text-2xl font-bold">{globalStats?.active_today || 0}</p>
            </div>
            <Activity className="h-6 w-6 md:h-8 md:w-8 text-success" />
          </div>
        </Card>

        <Card className="p-3 md:p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Exp. Total Hoje</p>
              <p className="text-lg md:text-2xl font-bold">{formatExperience(globalStats?.total_exp_today || 0)}</p>
            </div>
            <TrendingUp className="h-6 w-6 md:h-8 md:w-8 text-warning" />
          </div>
        </Card>

        <Card className="p-3 md:p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Servidores</p>
              <p className="text-lg md:text-2xl font-bold">{globalStats?.total_servers || 0}</p>
            </div>
            <BarChart3 className="h-6 w-6 md:h-8 md:w-8 text-info" />
          </div>
        </Card>
      </div>

      {/* Main Content */}
      <div className="grid grid-cols-1 lg:grid-cols-[1fr,300px] gap-6">
        <div className="space-y-6">
          <CharacterSelection
            characters={characters}
            onCompare={handleCompare}
          />
        </div>

        <div className="space-y-6">
          <TopExpPanel />
          <LinearityPanel />
        </div>
      </div>

      <Dialog open={isComparisonOpen} onOpenChange={setIsComparisonOpen}>
        <DialogContent className="max-w-[95vw] md:max-w-6xl max-h-[90vh] overflow-auto" description={`Comparando ${selectedCharacters.length} personagens`}>
          <ComparisonChart
            characters={selectedCharacters}
            data={chartData}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
} 