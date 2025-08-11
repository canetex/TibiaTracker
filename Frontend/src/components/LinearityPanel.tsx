import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Button } from './ui/button';
import { Activity, RefreshCw } from 'lucide-react';
import { apiService } from '../services/api';
import { formatNumber } from '../lib/utils';

interface LinearityCharacter {
  id: string;
  name: string;
  level: number;
  vocation: string;
  world: string;
  server: string;
  guild?: string;
  daily_gains: number[];
  average_gain: number;
  linearity_index: number;
  total_exp_gained: number;
  days_tracked: number;
  min_gain: number;
  max_gain: number;
}

interface LinearityPanelProps {
  onCharacterClick?: (character: LinearityCharacter) => void;
}

const periodOptions = [
  { value: '7', label: '7 dias' },
  { value: '15', label: '15 dias' },
  { value: '30', label: '30 dias' },
  { value: '60', label: '60 dias' },
  { value: '90', label: '90 dias' },
];

export function LinearityPanel({ onCharacterClick }: LinearityPanelProps) {
  const [period, setPeriod] = useState('30');
  const [loading, setLoading] = useState(false);
  const [characters, setCharacters] = useState<LinearityCharacter[]>([]);

  const loadLinearity = async () => {
    try {
      setLoading(true);
      const data = await apiService.getLinearity(parseInt(period));
      setCharacters(data);
    } catch (error) {
      console.error('Erro ao carregar Linearidade:', error);
    } finally {
      setLoading(false);
    }
  };

  const handlePeriodChange = (value: string) => {
    setPeriod(value);
    loadLinearity();
  };

  const formatPercentage = (value: number) => {
    return `${(value * 100).toFixed(1)}%`;
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-lg font-medium flex items-center gap-2">
          <Activity className="h-4 w-4" />
          Top Linearidade
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
            onClick={loadLinearity}
            disabled={loading}
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {loading ? (
          <div className="flex items-center justify-center h-[400px]">
            <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary"></div>
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
                      {char.vocation} • {char.world}
                      {char.guild && ` • ${char.guild}`}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {char.days_tracked} dias • Média: {formatNumber(char.average_gain)}/dia
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-primary">
                      {formatPercentage(char.linearity_index)}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      Total: +{formatNumber(char.total_exp_gained)}
                    </p>
                  </div>
                </div>
                <div className="mt-2 h-1 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary transition-all"
                    style={{
                      width: `${100 - (char.linearity_index * 100)}%`,
                    }}
                  />
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