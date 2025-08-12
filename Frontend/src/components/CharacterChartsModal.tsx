import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Tabs, TabsList, TabsTrigger, TabsContent } from './ui/tabs';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Button } from './ui/button';
import { Zap, Target, TrendingUp, Activity } from 'lucide-react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend
} from 'recharts';
import { apiService } from '../services/api';
import { formatNumber, formatDate } from '../lib/utils';

interface CharacterChartsModalProps {
  character: {
    id: number;
    name: string;
  };
  isOpen: boolean;
  onClose: () => void;
}

export function CharacterChartsModal({ character, isOpen, onClose }: CharacterChartsModalProps) {
  const [period, setPeriod] = useState('30');
  const [loading, setLoading] = useState(false);
  const [experienceData, setExperienceData] = useState<any[]>([]);
  const [levelData, setLevelData] = useState<any[]>([]);

  useEffect(() => {
    if (isOpen && character.id) {
      loadData();
    }
  }, [isOpen, character.id, period]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [expData, lvlData] = await Promise.all([
        apiService.getCharacterExperienceData(character.id, parseInt(period)),
        apiService.getCharacterLevelData(character.id, parseInt(period))
      ]);
      setExperienceData(expData);
      setLevelData(lvlData);
    } catch (error) {
      console.error('Erro ao carregar dados:', error);
    } finally {
      setLoading(false);
    }
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <Card className="p-3 !bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
          <p className="text-sm font-medium">{formatDate(label)}</p>
          <div className="mt-2 space-y-1">
            {payload.map((entry: any, index: number) => (
              <p key={index} className="text-sm" style={{ color: entry.color }}>
                {entry.name}: {formatNumber(entry.value)}
              </p>
            ))}
          </div>
        </Card>
      );
    }
    return null;
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-[95vw] md:max-w-6xl max-h-[90vh] overflow-auto">
        <DialogHeader>
          <DialogTitle>Gráficos - {character.name}</DialogTitle>
        </DialogHeader>

        <div className="flex items-center justify-between mb-6">
          <Select value={period} onValueChange={setPeriod}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Selecione o período" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="7">7 dias</SelectItem>
              <SelectItem value="15">15 dias</SelectItem>
              <SelectItem value="30">30 dias</SelectItem>
              <SelectItem value="60">60 dias</SelectItem>
              <SelectItem value="90">90 dias</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {loading ? (
          <div className="flex items-center justify-center h-[400px]">
            <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary"></div>
          </div>
        ) : (
          <Tabs defaultValue="experience" className="w-full">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="experience" className="flex items-center gap-2">
                <Zap className="h-4 w-4" />
                Experiência
              </TabsTrigger>
              <TabsTrigger value="level" className="flex items-center gap-2">
                <Target className="h-4 w-4" />
                Level
              </TabsTrigger>
              <TabsTrigger value="daily" className="flex items-center gap-2">
                <TrendingUp className="h-4 w-4" />
                Diário
              </TabsTrigger>
              <TabsTrigger value="activity" className="flex items-center gap-2">
                <Activity className="h-4 w-4" />
                Atividade
              </TabsTrigger>
            </TabsList>

            <TabsContent value="experience">
              <Card>
                <CardHeader>
                  <CardTitle>Evolução de Experiência</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={400}>
                    <AreaChart data={experienceData}>
                      <defs>
                        <linearGradient id="experienceGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.8} />
                          <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-xs text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={formatNumber}
                        className="text-xs text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="experience"
                        stroke="hsl(var(--primary))"
                        fill="url(#experienceGradient)"
                        strokeWidth={2}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="level">
              <Card>
                <CardHeader>
                  <CardTitle>Evolução de Level</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={400}>
                    <LineChart data={levelData}>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-xs text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={(value) => Math.floor(value)}
                        className="text-xs text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Line
                        type="stepAfter"
                        dataKey="level"
                        stroke="hsl(var(--success))"
                        strokeWidth={3}
                        strokeDasharray="8 4"
                        dot={{ fill: "hsl(var(--success))", r: 5, strokeWidth: 2 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="daily">
              <Card>
                <CardHeader>
                  <CardTitle>Experiência Diária</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={400}>
                    <AreaChart data={experienceData}>
                      <defs>
                        <linearGradient id="dailyGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(var(--warning))" stopOpacity={0.8} />
                          <stop offset="95%" stopColor="hsl(var(--warning))" stopOpacity={0.1} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-xs text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={formatNumber}
                        className="text-xs text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="daily_experience"
                        stroke="hsl(var(--warning))"
                        fill="url(#dailyGradient)"
                        strokeWidth={2}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="activity">
              <Card>
                <CardHeader>
                  <CardTitle>Atividade</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={400}>
                    <LineChart data={experienceData}>
                      <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                      <XAxis
                        dataKey="date"
                        tickFormatter={formatDate}
                        className="text-xs text-muted-foreground"
                      />
                      <YAxis
                        tickFormatter={(value) => `${value}%`}
                        className="text-xs text-muted-foreground"
                      />
                      <Tooltip content={<CustomTooltip />} />
                      <Line
                        type="monotone"
                        dataKey="activity"
                        stroke="hsl(var(--info))"
                        strokeWidth={2}
                        strokeDasharray="4 2"
                        dot={{ fill: "hsl(var(--info))", r: 4 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  );
} 