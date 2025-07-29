import React, { useState, useEffect, useMemo } from 'react';
import { X, Eye, EyeOff, TrendingUp } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

const ComparisonChart = ({ 
  characters = [], 
  onClose, 
  open = false 
}) => {
  const [visibility, setVisibility] = useState({});
  const [showLevel, setShowLevel] = useState(true);
  const [showExperience, setShowExperience] = useState(true);
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(false);

  // Data mínima: 03/07/2024
  const MIN_DATE = new Date('2024-07-03');

  // Função para formatar experiência em milhões (KK)
  const formatExperience = (value) => {
    if (!value || isNaN(value)) return '0';
    const millions = value / 1000000;
    return `${millions.toFixed(1)}KK`;
  };

  // Função para formatar data completa
  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  };

  // Cores únicas para cada personagem
  const colors = useMemo(() => [
    'hsl(var(--primary))', 'hsl(var(--secondary))', 'hsl(var(--accent))', 'hsl(var(--destructive))', 
    'hsl(var(--muted))', 'hsl(var(--popover))', 'hsl(var(--card))', 'hsl(var(--border))',
    '#8d6e63', '#f57c00', '#0288d1', '#c2185b', '#7b1fa2', '#1976d2', '#388e3c', '#fbc02d', '#d32f2f', '#7b1fa2'
  ], []);

  useEffect(() => {
    if (!open || characters.length === 0) return;
    const fetchChartData = async () => {
      setLoading(true);
      try {
        const characterDataPromises = characters.map(async (character, index) => {
          try {
            const [levelResponse, expResponse] = await Promise.all([
              fetch(`/api/v1/characters/${character.id}/charts/level?days=30`),
              fetch(`/api/v1/characters/${character.id}/charts/experience?days=30`)
            ]);
            const levelData = await levelResponse.json();
            const expData = await expResponse.json();
            return {
              character,
              color: colors[index % colors.length],
              levelData: levelData.data || [],
              expData: expData.data || []
            };
          } catch (error) {
            console.error(`Erro ao buscar dados para ${character.name}:`, error);
            return {
              character,
              color: colors[index % colors.length],
              levelData: [],
              expData: []
            };
          }
        });
        const allCharacterData = await Promise.all(characterDataPromises);
        const combinedData = {};
        
        console.log('🔍 DEBUG - Dados recebidos para comparação:');
        console.log('MIN_DATE:', MIN_DATE);
        
        allCharacterData.forEach(({ character, color, levelData, expData }) => {
          console.log(`🔍 DEBUG - Personagem ${character.name}:`);
          console.log('Level data:', levelData);
          console.log('Exp data:', expData);
          
          // Filtrar dados de level a partir de 03/07/2024
          levelData.forEach(item => {
            const itemDate = new Date(item.date);
            console.log(`🔍 DEBUG - Level item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
            if (itemDate >= MIN_DATE) {
              const date = item.date;
              if (!combinedData[date]) {
                combinedData[date] = { date };
              }
              combinedData[date][`${character.name}_level`] = item.level;
            }
          });
          
          // Filtrar dados de experiência a partir de 03/07/2024
          expData.forEach(item => {
            const itemDate = new Date(item.date);
            console.log(`🔍 DEBUG - Exp item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
            if (itemDate >= MIN_DATE) {
              const date = item.date;
              if (!combinedData[date]) {
                combinedData[date] = { date };
              }
              combinedData[date][`${character.name}_exp`] = item.experience || item.experience_gained || 0;
            }
          });
        });
        
        const chartDataArray = Object.values(combinedData).sort((a, b) => new Date(a.date) - new Date(b.date));
        console.log('🔍 DEBUG - Dados filtrados finais para comparação:', chartDataArray);
        setChartData(chartDataArray);
      } catch (error) {
        console.error('Erro ao preparar dados do gráfico:', error);
      } finally {
        setLoading(false);
      }
    };
    fetchChartData();
  }, [open, characters, colors]);

  useEffect(() => {
    if (characters.length > 0) {
      const initialVisibility = {};
      characters.forEach(char => {
        initialVisibility[char.id] = true;
      });
      setVisibility(initialVisibility);
    }
  }, [characters]);

  const handleToggleCharacter = (characterId) => {
    setVisibility(prev => ({
      ...prev,
      [characterId]: !prev[characterId]
    }));
  };

  const handleToggleAllLevels = () => {
    setShowLevel(!showLevel);
  };

  const handleToggleAllExperience = () => {
    setShowExperience(!showExperience);
  };

  const getCharacterColor = (characterId) => {
    const index = characters.findIndex(char => char.id === characterId);
    return colors[index % colors.length];
  };

  // Função para calcular limites do gráfico com 1% de margem
  const getLevelDomain = () => {
    let min = Infinity;
    let max = -Infinity;
    chartData.forEach(row => {
      Object.keys(row).forEach(key => {
        if (key.endsWith('_level') && typeof row[key] === 'number') {
          if (row[key] < min) min = row[key];
          if (row[key] > max) max = row[key];
        }
      });
    });
    if (min === Infinity || max === -Infinity) {
      return [0, 100]; // fallback
    }
    
    // Calcular 1% de margem
    const margin = (max - min) * 0.01;
    const yMin = Math.floor(min - margin);
    const yMax = Math.ceil(max + margin);
    
    // Garantir diferença mínima
    if (yMax - yMin < 10) {
      return [yMin - 5, yMax + 5];
    }
    
    return [yMin, yMax];
  };

  if (!open || characters.length === 0) {
    return null;
  }

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-7xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <TrendingUp className="h-6 w-6 text-primary" />
              <DialogTitle className="text-2xl font-semibold">
                Comparação de Personagens
              </DialogTitle>
              <Badge variant="secondary">
                {characters.length} personagens
              </Badge>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={onClose}
              className="h-8 w-8 p-0"
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </DialogHeader>

        <div className="space-y-6">
          {/* Controls */}
          <div className="space-y-4">
            <div className="flex items-center gap-4">
              <Label className="text-sm font-medium text-muted-foreground">
                Controles Globais:
              </Label>
              
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="showLevel"
                  checked={showLevel}
                  onCheckedChange={handleToggleAllLevels}
                />
                <Label htmlFor="showLevel" className="text-sm">
                  Mostrar Levels
                </Label>
              </div>
              
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="showExperience"
                  checked={showExperience}
                  onCheckedChange={handleToggleAllExperience}
                />
                <Label htmlFor="showExperience" className="text-sm">
                  Mostrar Experiência
                </Label>
              </div>
            </div>

            {/* Character Controls */}
            <div className="space-y-2">
              <Label className="text-sm font-medium text-muted-foreground">
                Visibilidade por Personagem:
              </Label>
              <div className="flex gap-2 flex-wrap">
                {characters.map((character) => (
                  <Badge
                    key={character.id}
                    variant={visibility[character.id] ? "default" : "outline"}
                    className="cursor-pointer hover:bg-primary/10"
                    onClick={() => handleToggleCharacter(character.id)}
                    style={{
                      backgroundColor: visibility[character.id] ? getCharacterColor(character.id) : 'transparent',
                      color: visibility[character.id] ? 'white' : 'inherit',
                      borderColor: getCharacterColor(character.id),
                    }}
                  >
                    {character.name}
                    {visibility[character.id] ? (
                      <Eye className="ml-1 h-3 w-3" />
                    ) : (
                      <EyeOff className="ml-1 h-3 w-3" />
                    )}
                  </Badge>
                ))}
              </div>
            </div>
          </div>

          {/* Chart */}
          <div className="h-[500px] relative">
            {loading ? (
              <div className="flex justify-center items-center h-full">
                <p>Carregando dados...</p>
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis 
                    dataKey="date" 
                    type="category"
                    tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                    axisLine={{ stroke: 'hsl(var(--border))' }}
                    tickLine={{ stroke: 'hsl(var(--border))' }}
                    angle={-45}
                    textAnchor="end"
                    height={80}
                    tickFormatter={(value) => {
                      const date = new Date(value);
                      return date.toLocaleDateString('pt-BR', {
                        day: '2-digit',
                        month: '2-digit'
                      });
                    }}
                  />
                  <YAxis 
                    yAxisId="level" 
                    orientation="left"
                    type="number"
                    domain={getLevelDomain()}
                    allowDataOverflow={true}
                    label={{ value: 'Level', angle: -90, position: 'insideLeft', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                    tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                    axisLine={{ stroke: 'hsl(var(--border))' }}
                    tickLine={{ stroke: 'hsl(var(--border))' }}
                    tickFormatter={(value) => value.toLocaleString('pt-BR')}
                  />
                  <YAxis 
                    yAxisId="experience" 
                    orientation="right"
                    label={{ value: 'Experiência', angle: 90, position: 'insideRight', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                    tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                    axisLine={{ stroke: 'hsl(var(--border))' }}
                    tickLine={{ stroke: 'hsl(var(--border))' }}
                    tickFormatter={formatExperience}
                  />
                  
                  <RechartsTooltip 
                    content={({ active, payload, label }) => {
                      if (active && payload && payload.length) {
                        return (
                          <div className="bg-background border border-border rounded-lg p-4 shadow-lg">
                            <p className="font-semibold text-sm mb-2">
                              {formatDate(label)}
                            </p>
                            {payload.map((entry, index) => {
                              const isExperience = entry.name.includes('Experiência');
                              const displayValue = isExperience 
                                ? formatExperience(entry.value)
                                : entry.value?.toLocaleString('pt-BR');
                              
                              return (
                                <div key={index} className="flex justify-between gap-4 text-sm">
                                  <span>{entry.name}:</span>
                                  <span className="font-semibold">
                                    {displayValue}
                                  </span>
                                </div>
                              );
                            })}
                          </div>
                        );
                      }
                      return null;
                    }}
                  />
                  
                  <Legend />
                  
                  {/* Level Lines (sólidas) */}
                  {showLevel && characters.map((character) => {
                    const color = getCharacterColor(character.id);
                    const dataKey = `${character.name}_level`;
                    
                    return (
                      <Line
                        key={`level-${character.id}`}
                        type="monotone"
                        dataKey={dataKey}
                        yAxisId="level"
                        stroke={color}
                        strokeWidth={3}
                        dot={{ fill: color, strokeWidth: 2, r: 4 }}
                        activeDot={{ r: 6 }}
                        name={`${character.name} - Level`}
                        hide={!visibility[character.id]}
                      />
                    );
                  })}
                  
                  {/* Experience Lines (tracejadas) */}
                  {showExperience && characters.map((character) => {
                    const color = getCharacterColor(character.id);
                    const dataKey = `${character.name}_exp`;
                    
                    return (
                      <Line
                        key={`exp-${character.id}`}
                        type="monotone"
                        dataKey={dataKey}
                        yAxisId="experience"
                        stroke={color}
                        strokeWidth={2}
                        strokeDasharray="5 5"
                        dot={{ fill: color, strokeWidth: 2, r: 3 }}
                        activeDot={{ r: 5 }}
                        name={`${character.name} - Experiência`}
                        hide={!visibility[character.id]}
                      />
                    );
                  })}
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>

          {/* Legend */}
          <div className="bg-muted/50 p-4 rounded-lg">
            <h4 className="text-sm font-medium mb-2">Legenda:</h4>
            <div className="flex gap-4 flex-wrap">
              <div className="flex items-center gap-2">
                <div className="w-5 h-1 bg-foreground" />
                <span className="text-sm">Linha sólida = Level</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-5 h-1 bg-foreground border-t-2 border-dashed border-foreground" />
                <span className="text-sm">Linha tracejada = Experiência</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-sm text-muted-foreground">
                  Dados a partir de 03/07/2024
                </span>
              </div>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button onClick={onClose}>
            Fechar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default ComparisonChart; 