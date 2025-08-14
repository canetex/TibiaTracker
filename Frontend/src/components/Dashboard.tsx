import React, { useState, useEffect } from 'react';
import { CharacterSelection } from './CharacterSelection';
import { ComparisonChart } from './ComparisonChart';
import { TopExpPanel } from './TopExpPanel';
import { LinearityPanel } from './LinearityPanel';
import { Dialog, DialogContent } from './ui/dialog';
import { Card } from './ui/card';
import { Users, Activity, TrendingUp, BarChart3 } from 'lucide-react';
import Spinner from './ui/spinner';
import { apiService } from '../services/api';
import logger from '../lib/logger';

interface Character {
  id: number;
  name: string;
  level: number;
  vocation: string;
  world: string;
  server: string;
  guild?: string;
}

interface GlobalStats {
  total_characters: number;
  active_today: number;
  total_exp_today: number;
  total_servers: number;
}

interface ChartDataPoint {
  date: string;
  [key: string]: any;
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
          apiService.getAllCharacters(),
          apiService.getGlobalStats()
        ]);
        setCharacters(chars);
        setGlobalStats(stats);
      } catch (err) {
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
      const statsPerChar = await Promise.all(
        chars.map((char) => apiService.getCharacterStats(char.id))
      );

      // Combinar por data
      const merged: Record<string, any> = {};
      statsPerChar.forEach((statArray, idx) => {
        const char = chars[idx];
        statArray.forEach((point: any) => {
          const dateKey = point.date;
          if (!merged[dateKey]) merged[dateKey] = { date: dateKey };
          merged[dateKey][`exp_${char.id}`] = point.experience ?? point.exp ?? 0;
          merged[dateKey][`level_${char.id}`] = point.level ?? 0;
        });
      });

      // Converter para array ordenado por data
      const combinedData = Object.values(merged).sort((a: any, b: any) => new Date(a.date).getTime() - new Date(b.date).getTime());

      setChartData(combinedData as any);
      setSelectedCharacters(chars);
      setIsComparisonOpen(true);
    } catch (err) {
      logger.error('Erro ao carregar dados para comparação', err);
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
        <Spinner size={64} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-destructive">{error}</div>
      </div>
    );
  }

  return (
    <div className="container mx-auto max-w-7xl px-6 md:px-8 lg:px-12 py-8 space-y-8">
      <h1 className="text-2xl md:text-3xl font-bold gradient-text text-center md:text-left">Dashboard</h1>
      
      {/* Global Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
        <Card className="p-4 md:p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Total de Personagens</p>
              <p className="text-lg md:text-2xl font-bold">{globalStats?.total_characters || 0}</p>
            </div>
            <Users className="h-6 w-6 md:h-8 md:w-8 text-primary" />
          </div>
        </Card>

        <Card className="p-4 md:p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Ativos Hoje</p>
              <p className="text-lg md:text-2xl font-bold">{globalStats?.active_today || 0}</p>
            </div>
            <Activity className="h-6 w-6 md:h-8 md:w-8 text-success" />
          </div>
        </Card>

        <Card className="p-4 md:p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs md:text-sm text-muted-foreground">Exp. Total Hoje</p>
              <p className="text-lg md:text-2xl font-bold">{formatExperience(globalStats?.total_exp_today || 0)}</p>
            </div>
            <TrendingUp className="h-6 w-6 md:h-8 md:w-8 text-warning" />
          </div>
        </Card>

        <Card className="p-4 md:p-6">
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
      <div className="grid grid-cols-1 lg:grid-cols-[1fr,350px] gap-8">
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