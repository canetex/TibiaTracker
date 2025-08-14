import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Button } from './ui/button';
import Spinner from './ui/spinner';
import { TrendingUp, RefreshCw } from 'lucide-react';
import { apiService } from '../services/api';
import logger from '../lib/logger';
import { formatNumber } from '../lib/utils';

interface TopExpCharacter {
  id: number;
  name: string;
  level: number;
  vocation: string;
  world: string;
  server: string;
  guild?: string;
  total_exp_gained: number;
  days_tracked: number;
}

interface TopExpPanelProps {
  onCharacterClick?: (character: TopExpCharacter) => void;
}

const periodOptions = [
  { value: '7', label: '7 dias' },
  { value: '15', label: '15 dias' },
  { value: '30', label: '30 dias' },
  { value: '60', label: '60 dias' },
  { value: '90', label: '90 dias' },
];

export function TopExpPanel({ onCharacterClick }: TopExpPanelProps) {
  const [period, setPeriod] = useState('30');
  const [loading, setLoading] = useState(false);
  const [characters, setCharacters] = useState<TopExpCharacter[]>([]);

  useEffect(() => {
    loadTopExp();
  }, []);

  const loadTopExp = async () => {
    try {
      setLoading(true);
      const data = await apiService.getTopExp(parseInt(period));
      setCharacters(data);
    } catch (error) {
      logger.error('Erro ao carregar Top Exp:', error);
    } finally {
      setLoading(false);
    }
  };

  const handlePeriodChange = (value: string) => {
    setPeriod(value);
    loadTopExp();
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-lg font-medium flex items-center gap-2">
          <TrendingUp className="h-4 w-4" />
          Top Exp
        </CardTitle>
        <div className="flex items-center gap-2">
          <Select value={period} onValueChange={handlePeriodChange}>
            <SelectTrigger className="w-[120px]">
              <SelectValue placeholder="Período" />
            </SelectTrigger>
            <SelectContent>
              {periodOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            variant="outline"
            size="icon"
            onClick={loadTopExp}
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {loading ? (
          <div className="flex items-center justify-center h-[400px]">
            <Spinner size={64} />
          </div>
        ) : (
          <div className="space-y-4">
            {characters.map((char) => (
              <Card
                key={char.id}
                className={`p-4 cursor-pointer hover:bg-muted/50 transition-colors`}
                onClick={() => onCharacterClick?.(char)}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="font-semibold text-foreground">{char.name}</h4>
                    <p className="text-sm text-muted-foreground">
                      Level {char.level}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {char.vocation} • {char.world}
                      {char.guild && ` • ${char.guild}`}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-primary">
                      +{formatNumber(char.total_exp_gained)}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {formatNumber(char.total_exp_gained / char.days_tracked)}/dia
                    </p>
                  </div>
                </div>
              </Card>
            ))}

            {characters.length === 0 && (
              <div className="text-center text-muted-foreground py-8">
                Nenhum personagem encontrado
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
} 