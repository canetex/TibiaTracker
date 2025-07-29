import React, { useState, useEffect, useCallback } from 'react';
import { X, TrendingUp, BarChart3 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
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

import { apiService } from '@/services/api';

const CharacterChartsModal = ({ open, onClose, character }) => {
  const [loading, setLoading] = useState(false);
  const [chartData, setChartData] = useState([]);
  const [error, setError] = useState(null);
  
  // Controles de visualização
  const [chartOptions, setChartOptions] = useState({
    experience: true,
    level: true,
    deaths: false,
    charmPoints: false,
    bossTierPoints: false,
    achievementPoints: false,
  });
  
  const [timeRange, setTimeRange] = useState(30); // días

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

  const loadChartData = useCallback(async () => {
    if (!character?.id) {
      setError('Erro: ID do personagem não encontrado');
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const [experienceData, levelData] = await Promise.all([
        apiService.getCharacterExperienceChart(character.id, timeRange),
        apiService.getCharacterLevelChart(character.id, timeRange)
      ]);
      
      console.log('🔍 DEBUG - Dados recebidos da API:');
      console.log('MIN_DATE:', MIN_DATE);
      console.log('Experience data:', experienceData?.data);
      console.log('Level data:', levelData?.data);
      
      const combinedData = {};
      
      // Processar dados de experiência
      if (experienceData?.data) {
        experienceData.data.forEach(item => {
          const itemDate = new Date(item.date);
          console.log(`🔍 DEBUG - Item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
          // Filtrar apenas dados a partir de 03/07/2024
          if (itemDate >= MIN_DATE) {
            const date = item.date;
            if (!combinedData[date]) {
              combinedData[date] = { date };
            }
            combinedData[date].experience = item.experience_gained || item.experience || 0;
          }
        });
      }
      
      // Processar dados de level
      if (levelData?.data) {
        levelData.data.forEach(item => {
          const itemDate = new Date(item.date);
          console.log(`🔍 DEBUG - Level item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
          // Filtrar apenas dados a partir de 03/07/2024
          if (itemDate >= MIN_DATE) {
            const date = item.date;
            if (!combinedData[date]) {
              combinedData[date] = { date };
            }
            combinedData[date].level = item.level;
          }
        });
      }
      
      const chartDataArray = Object.values(combinedData).sort((a, b) => new Date(a.date) - new Date(b.date));
      console.log('🔍 DEBUG - Dados filtrados finais:', chartDataArray);
      setChartData(chartDataArray);
    } catch (err) {
      setError(`Erro ao carregar dados dos gráficos: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [character, timeRange]);

  useEffect(() => {
    loadChartData();
  }, [loadChartData]);

  const refreshCharacterData = async () => {
    await loadChartData();
  };

  const handleOptionChange = (option) => {
    setChartOptions(prev => ({
      ...prev,
      [option]: !prev[option]
    }));
  };

  const hasData = chartData.length > 0 && (chartOptions.experience || chartOptions.level);

  // Função para calcular limites do gráfico com 1% de margem
  const getLevelDomain = () => {
    let min = Infinity;
    let max = -Infinity;
    chartData.forEach(row => {
      if (typeof row.level === 'number') {
        if (row.level < min) min = row.level;
        if (row.level > max) max = row.level;
      }
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

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-6xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              {/* Imagem do outfit */}
              {character?.outfit_image_url && (
                <img
                  src={character.outfit_image_url}
                  alt={`Outfit de ${character.name}`}
                  className="w-8 h-8 rounded"
                />
              )}
              <BarChart3 className="h-6 w-6 text-primary" />
              <DialogTitle className="text-2xl font-semibold">
                Gráficos - {character?.name}
              </DialogTitle>
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
          {/* Controles */}
          <Card>
            <CardHeader>
              <div className="flex items-center space-x-2">
                <BarChart3 className="h-5 w-5" />
                <CardTitle className="text-lg">Controles de Visualização</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                {/* Período */}
                <div className="space-y-3">
                  <Label className="text-sm font-medium">Período</Label>
                  <div className="flex flex-wrap gap-2">
                    {[7, 15, 30, 60, 90].map(days => (
                      <Badge
                        key={days}
                        variant={timeRange === days ? "default" : "outline"}
                        className="cursor-pointer hover:bg-primary/10"
                        onClick={() => setTimeRange(days)}
                      >
                        {days} dias
                      </Badge>
                    ))}
                  </div>
                </div>

                {/* Métricas */}
                <div className="md:col-span-3 space-y-3">
                  <Label className="text-sm font-medium">Métricas para Exibir</Label>
                  <div className="flex flex-wrap gap-4">
                    <div className="flex items-center space-x-2">
                      <Checkbox
                        id="experience"
                        checked={chartOptions.experience}
                        onCheckedChange={() => handleOptionChange('experience')}
                      />
                      <Label htmlFor="experience" className="text-sm">
                        Experiência
                      </Label>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Checkbox
                        id="level"
                        checked={chartOptions.level}
                        onCheckedChange={() => handleOptionChange('level')}
                      />
                      <Label htmlFor="level" className="text-sm">
                        Level
                      </Label>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Gráfico */}
          <Card>
            <CardContent className="p-6">
              {loading ? (
                <div className="flex justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                </div>
              ) : error ? (
                <Alert>
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              ) : hasData ? (
                <div className="h-[500px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis 
                        dataKey="date" 
                        tickFormatter={(value) => {
                          const date = new Date(value);
                          return date.toLocaleDateString('pt-BR', {
                            day: '2-digit',
                            month: '2-digit'
                          });
                        }}
                        tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                        axisLine={{ stroke: 'hsl(var(--border))' }}
                        tickLine={{ stroke: 'hsl(var(--border))' }}
                      />
                      {/* Renderização condicional dos eixos Y */}
                      {chartOptions.experience && chartOptions.level && (
                        <>
                          <YAxis 
                            yAxisId="left"
                            orientation="left"
                            tickFormatter={formatExperience}
                            tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                            axisLine={{ stroke: 'hsl(var(--border))' }}
                            tickLine={{ stroke: 'hsl(var(--border))' }}
                            label={{ value: 'Experiência', angle: -90, position: 'insideLeft', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                          />
                          <YAxis 
                            yAxisId="right"
                            orientation="right"
                            type="number"
                            domain={getLevelDomain()}
                            allowDataOverflow={true}
                            tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                            axisLine={{ stroke: 'hsl(var(--border))' }}
                            tickLine={{ stroke: 'hsl(var(--border))' }}
                            label={{ value: 'Level', angle: 90, position: 'insideRight', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                          />
                        </>
                      )}
                      {chartOptions.level && !chartOptions.experience && (
                        <YAxis 
                          yAxisId="right"
                          orientation="right"
                          type="number"
                          domain={getLevelDomain()}
                          allowDataOverflow={true}
                          tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                          axisLine={{ stroke: 'hsl(var(--border))' }}
                          tickLine={{ stroke: 'hsl(var(--border))' }}
                          label={{ value: 'Level', angle: 90, position: 'insideRight', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                        />
                      )}
                      {chartOptions.experience && !chartOptions.level && (
                        <YAxis 
                          yAxisId="left"
                          orientation="left"
                          tickFormatter={formatExperience}
                          tick={{ fontSize: 12, fill: 'hsl(var(--foreground))', fontWeight: 500 }}
                          axisLine={{ stroke: 'hsl(var(--border))' }}
                          tickLine={{ stroke: 'hsl(var(--border))' }}
                          label={{ value: 'Experiência', angle: -90, position: 'insideLeft', fill: 'hsl(var(--foreground))', fontSize: 14, fontWeight: 600 }}
                        />
                      )}
                      <RechartsTooltip
                        formatter={(value, name) => {
                          if (name === 'Experiência') {
                            return [formatExperience(value), name];
                          }
                          return [value, name];
                        }}
                        labelFormatter={(label) => {
                          return formatDate(label);
                        }}
                        content={({ active, payload, label }) => {
                          if (active && payload && payload.length) {
                            return (
                              <div className="bg-background border border-border rounded-lg p-4 shadow-lg">
                                <p className="font-semibold text-sm mb-2">
                                  {formatDate(label)}
                                </p>
                                {payload.map((entry, index) => (
                                  <div key={index} className="flex justify-between gap-4 text-sm">
                                    <span>{entry.name}:</span>
                                    <span className="font-semibold">
                                      {entry.name === 'Experiência' 
                                        ? formatExperience(entry.value)
                                        : entry.value?.toLocaleString('pt-BR')
                                      }
                                    </span>
                                  </div>
                                ))}
                              </div>
                            );
                          }
                          return null;
                        }}
                      />
                      <Legend />
                      {chartOptions.experience && (
                        <Line
                          type="monotone"
                          dataKey="experience"
                          stroke="hsl(var(--primary))"
                          strokeWidth={2}
                          dot={{ fill: 'hsl(var(--primary))', strokeWidth: 2, r: 4 }}
                          activeDot={{ r: 6 }}
                          yAxisId="left"
                          name="Experiência"
                        />
                      )}
                      {chartOptions.level && (
                        <Line
                          type="monotone"
                          dataKey="level"
                          stroke="hsl(var(--destructive))"
                          strokeWidth={2}
                          strokeDasharray="5 5"
                          dot={{ fill: 'hsl(var(--destructive))', strokeWidth: 2, r: 4 }}
                          activeDot={{ r: 6 }}
                          yAxisId="right"
                          name="Level"
                        />
                      )}
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div className="text-center py-8">
                  <TrendingUp className="h-16 w-16 text-muted-foreground mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-muted-foreground mb-2">
                    Nenhum dado disponível
                  </h3>
                  <p className="text-sm text-muted-foreground mb-2">
                    Selecione pelo menos uma métrica ou tente um período diferente
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Dados disponíveis apenas a partir de 03/07/2024
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        <DialogFooter>
          <Button onClick={refreshCharacterData} disabled={loading}>
            Atualizar Dados
          </Button>
          <Button onClick={onClose}>
            Fechar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default CharacterChartsModal; 