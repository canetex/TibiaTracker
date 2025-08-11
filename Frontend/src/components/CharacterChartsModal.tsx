import React, { useState, useEffect } from 'react';
import { Dialog, DialogContent } from './ui/dialog';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Zap, Target, TrendingUp, Activity } from 'lucide-react';
import { AreaChart, Area, LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { apiService } from '../services/api';
import { formatNumber } from '../lib/utils';

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

interface CharacterChartsModalProps {
  character: Character;
  open: boolean;
  onClose: () => void;
}

const timeRanges = [
  { value: '7', label: '7 dias' },
  { value: '15', label: '15 dias' },
  { value: '30', label: '30 dias' },
  { value: '60', label: '60 dias' },
  { value: '90', label: '90 dias' },
];

const chartTypes = [
  { value: 'experience', label: 'Experiência', icon: <Zap className="h-4 w-4" /> },
  { value: 'level', label: 'Level', icon: <Target className="h-4 w-4" /> },
  { value: 'daily', label: 'Exp. Diária', icon: <TrendingUp className="h-4 w-4" /> },
  { value: 'deaths', label: 'Mortes', icon: <Activity className="h-4 w-4" /> },
];

export function CharacterChartsModal({ character, open, onClose }: CharacterChartsModalProps) {
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState('30');
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);

  useEffect(() => {
    if (open && character) {
      loadChartData();
    }
  }, [open, character, timeRange]);

  const loadChartData = async () => {
    try {
      setLoading(true);
      const [expData, levelData] = await Promise.all([
        apiService.getCharacterExperienceData(character.id, parseInt(timeRange)),
        apiService.getCharacterLevelData(character.id, parseInt(timeRange))
      ]);
      
      const mergedData = expData.data.map((exp: any, index: number) => ({
        date: exp.date,
        experience: exp.experience,
        experienceGained: exp.experience_gained,
        level: levelData.data[index]?.level || 0,
        deaths: levelData.data[index]?.deaths || 0,
      }));

      setChartData(mergedData);
    } catch (error) {
      console.error('Erro ao carregar dados dos gráficos:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (date: string) => {
    return new Date(date).toLocaleDateString('pt-BR');
  };

  const formatExperience = (exp: number) => {
    return formatNumber(exp);
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <Card>
          <CardContent className="p-3">
            <p className="text-sm font-semibold">{formatDate(label)}</p>
            {payload.map((item: any) => (
              <p key={item.name} className="text-sm">
                {item.name}: {formatExperience(item.value)}
              </p>
            ))}
          </CardContent>
        </Card>
      );
    }
    return null;
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent
        className="max-w-6xl max-h-[90vh] overflow-auto"
        description={`Análise de progresso de ${character.name} nos últimos ${timeRange} dias`}
      >
        <div className="space-y-6">
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>{character.name}</span>
              <Select value={timeRange} onValueChange={setTimeRange}>
                <SelectTrigger className="w-32">
                  <SelectValue placeholder="Período" />
                </SelectTrigger>
                <SelectContent>
                  {timeRanges.map((range) => (
                    <SelectItem key={range.value} value={range.value}>
                      {range.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </CardTitle>
          </CardHeader>

          {loading ? (
            <div className="flex items-center justify-center h-[400px]">
              <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary"></div>
            </div>
          ) : (
            <Tabs defaultValue="experience">
              <TabsList className="grid w-full grid-cols-4">
                {chartTypes.map((type) => (
                  <TabsTrigger key={type.value} value={type.value} className="flex items-center gap-2">
                    {type.icon}
                    {type.label}
                  </TabsTrigger>
                ))}
              </TabsList>

              <TabsContent value="experience" className="mt-6">
                <div className="h-[400px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={chartData}>
                      <defs>
                        <linearGradient id="experienceGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.3} />
                          <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={formatExperience}
                        className="text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="experience"
                        stroke="hsl(var(--primary))"
                        strokeWidth={2}
                        fill="url(#experienceGradient)"
                        name="Experience"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </TabsContent>

              <TabsContent value="level" className="mt-6">
                <div className="h-[400px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-muted-foreground"
                      />
                      <YAxis
                        domain={['dataMin - 1', 'dataMax + 1']}
                        className="text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Line
                        type="stepAfter"
                        dataKey="level"
                        stroke="hsl(var(--success))"
                        strokeWidth={2}
                        dot={{ fill: "hsl(var(--success))", r: 4 }}
                        name="Level"
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </TabsContent>

              <TabsContent value="daily" className="mt-6">
                <div className="h-[400px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={formatExperience}
                        className="text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Bar
                        dataKey="experienceGained"
                        fill="hsl(var(--warning))"
                        radius={[4, 4, 0, 0]}
                        name="Exp. Diária"
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </TabsContent>

              <TabsContent value="deaths" className="mt-6">
                <div className="h-[400px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-muted-foreground"
                      />
                      <YAxis
                        domain={[0, 'dataMax + 1']}
                        className="text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Bar
                        dataKey="deaths"
                        fill="hsl(var(--destructive))"
                        radius={[4, 4, 0, 0]}
                        name="Mortes"
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </TabsContent>
            </Tabs>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
} 