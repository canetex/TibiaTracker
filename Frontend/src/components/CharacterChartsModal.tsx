import React, { useEffect, useMemo, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs'
import { ResponsiveContainer, AreaChart, Area, LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from 'recharts'
import { apiService } from '../services/api'
import { Zap, Target, TrendingUp, Activity } from 'lucide-react'

interface ChartData {
  date: string;
  level: number;
  experience: number;
  experienceGained: number;
  deaths: number;
}

interface Props {
  character: any;
  open: boolean;
  onClose: () => void;
}

const timeRanges = [
  { value: "7d", label: "7 dias" },
  { value: "30d", label: "30 dias" },
  { value: "90d", label: "90 dias" },
  { value: "1y", label: "1 ano" },
];

const chartTypes = [
  { value: "experience", label: "Experience", icon: Zap },
  { value: "level", label: "Level", icon: Target },
  { value: "daily", label: "Daily Gain", icon: TrendingUp },
  { value: "deaths", label: "Deaths", icon: Activity },
];

export default function CharacterChartsModal({ character, open, onClose }: Props): JSX.Element | null {
  const [days, setDays] = useState(30)
  const [selectedChart, setSelectedChart] = useState("experience")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [data, setData] = useState<Array<any>>([])

  useEffect(() => {
    if (!open || !character?.id) return
    let isMounted = true
    const fetchData = async () => {
      try {
        setLoading(true)
        setError(null)
        const stats = await apiService.getCharacterStats(character.id, days)
        if (!isMounted) return
        setData(Array.isArray(stats) ? stats : [])
      } catch (err: any) {
        if (!isMounted) return
        setError('Erro ao carregar estatísticas do personagem')
      } finally {
        if (isMounted) setLoading(false)
      }
    }
    fetchData()
    return () => {
      isMounted = false
    }
  }, [open, character?.id, days])

  const chartData = useMemo(() => {
    return (data || []).map((d) => ({
      date: d.date || d.day || d.label,
      level: d.level ?? d.latest_snapshot?.level ?? 0,
      experience: d.experience ?? d.latest_snapshot?.experience ?? 0,
      experienceGained: d.experienceGained ?? d.exp_gained ?? d.exp ?? 0,
      deaths: d.deaths ?? 0,
    }))
  }, [data])

  // Calculate statistics
  const latestData = data[data.length - 1];
  const oldestData = data[0];
  const totalExpGained = latestData?.experience - oldestData?.experience || 0;
  const levelGained = latestData?.level - oldestData?.level || 0;
  const avgDailyExp = totalExpGained / data.length || 0;
  const totalDeaths = data.reduce((sum, entry) => sum + (entry.deaths || 0), 0);

  const formatExperience = (exp: number) => {
    if (exp >= 1000000000) return `${(exp / 1000000000).toFixed(1)}B`;
    if (exp >= 1000000) return `${(exp / 1000000).toFixed(1)}M`;
    if (exp >= 1000) return `${(exp / 1000).toFixed(1)}K`;
    return exp.toString();
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString("pt-BR", { month: "short", day: "numeric" });
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <Card className="border shadow-lg">
          <CardContent className="p-3">
            <p className="font-medium">{formatDate(label)}</p>
            {payload.map((entry: any, index: number) => (
              <p key={index} style={{ color: entry.color }}>
                {entry.name}: {
                  entry.dataKey === "experience" || entry.dataKey === "experienceGained"
                    ? formatExperience(entry.value)
                    : entry.value
                }
              </p>
            ))}
          </CardContent>
        </Card>
      );
    }
    return null;
  };

  if (!open) return null;

  if (loading) {
    return (
      <Card className="tibia-card">
        <CardHeader>
          <div className="flex items-center gap-2">
            <div className="h-6 w-32 bg-muted animate-pulse rounded" />
            <div className="h-4 w-16 bg-muted animate-pulse rounded" />
          </div>
        </CardHeader>
        <CardContent>
          <div className="h-80 bg-muted animate-pulse rounded" />
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="max-w-6xl w-full max-h-[90vh] overflow-auto p-4">
        <Card className="tibia-card">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="gradient-text">{character?.name || 'Personagem'}</CardTitle>
                <p className="text-muted-foreground">Character Evolution Analysis</p>
              </div>
              
              <div className="flex gap-2">
                <select
                  className="h-9 rounded-md border bg-background px-3 text-sm"
                  value={days}
                  onChange={(e) => setDays(Number(e.target.value))}
                >
                  {timeRanges.map((range) => (
                    <option key={range.value} value={range.value}>
                      {range.label}
                    </option>
                  ))}
                </select>
                <Button variant="outline" onClick={onClose}>Fechar</Button>
              </div>
            </div>

            {/* Statistics Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
              <div className="bg-gradient-card p-4 rounded-lg border">
                <div className="flex items-center gap-2">
                  <Zap className="h-4 w-4 text-warning" />
                  <span className="text-sm font-medium">Total Exp</span>
                </div>
                <p className="text-2xl font-bold text-primary">
                  +{formatExperience(totalExpGained)}
                </p>
              </div>

              <div className="bg-gradient-card p-4 rounded-lg border">
                <div className="flex items-center gap-2">
                  <Target className="h-4 w-4 text-success" />
                  <span className="text-sm font-medium">Levels</span>
                </div>
                <p className="text-2xl font-bold text-success">+{levelGained}</p>
              </div>

              <div className="bg-gradient-card p-4 rounded-lg border">
                <div className="flex items-center gap-2">
                  <TrendingUp className="h-4 w-4 text-info" />
                  <span className="text-sm font-medium">Avg Daily</span>
                </div>
                <p className="text-2xl font-bold text-info">
                  {formatExperience(avgDailyExp)}
                </p>
              </div>

              <div className="bg-gradient-card p-4 rounded-lg border">
                <div className="flex items-center gap-2">
                  <Activity className="h-4 w-4 text-destructive" />
                  <span className="text-sm font-medium">Deaths</span>
                </div>
                <p className="text-2xl font-bold text-destructive">{totalDeaths}</p>
              </div>
            </div>
          </CardHeader>

          <CardContent>
            <Tabs value={selectedChart} onValueChange={setSelectedChart}>
              <TabsList className="grid w-full grid-cols-4">
                {chartTypes.map((type) => {
                  const Icon = type.icon;
                  return (
                    <TabsTrigger key={type.value} value={type.value} className="flex items-center gap-1">
                      <Icon className="h-3 w-3" />
                      <span className="hidden sm:inline">{type.label}</span>
                    </TabsTrigger>
                  );
                })}
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
                      <YAxis className="text-muted-foreground" />
                      <Tooltip content={<CustomTooltip />} />
                      <Line
                        type="stepAfter"
                        dataKey="level"
                        stroke="hsl(var(--success))"
                        strokeWidth={3}
                        dot={{ fill: "hsl(var(--success))", strokeWidth: 2, r: 4 }}
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
                        name="Daily Experience"
                        radius={[4, 4, 0, 0]}
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
                      <YAxis className="text-muted-foreground" />
                      <Tooltip content={<CustomTooltip />} />
                      <Bar
                        dataKey="deaths"
                        fill="hsl(var(--destructive))"
                        name="Deaths"
                        radius={[4, 4, 0, 0]}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 