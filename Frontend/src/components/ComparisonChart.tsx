import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  AreaChart,
  Area
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs";

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

interface ComparisonChartProps {
  characters: Character[];
  data: ChartDataPoint[];
}

const colors = ["#1565C0", "#FFA726", "#4CAF50", "#F44336", "#9C27B0", "#FF5722", "#607D8B", "#795548"];

export function ComparisonChart({ characters, data }: ComparisonChartProps) {
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
                  entry.name.includes('experience') 
                    ? formatExperience(entry.value)
                    : entry.value.toLocaleString()
                }
              </p>
            ))}
          </CardContent>
        </Card>
      );
    }
    return null;
  };

  return (
    <div className="space-y-6">
      {/* Character Summary */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {characters.map((char, index) => (
          <Card key={char.id} className="tibia-card">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div 
                  className="w-4 h-4 rounded-full" 
                  style={{ backgroundColor: colors[index % colors.length] }}
                />
                <div>
                  <h4 className="font-semibold text-foreground">{char.name}</h4>
                  <p className="text-sm text-muted-foreground">
                    Level {char.level} {char.vocation}
                  </p>
                  <p className="text-xs text-muted-foreground">{char.world}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Charts */}
      <Tabs defaultValue="level" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="level">Level Comparison</TabsTrigger>
          <TabsTrigger value="experience">Experience Comparison</TabsTrigger>
          <TabsTrigger value="experienceGained">Daily Experience</TabsTrigger>
        </TabsList>

        <TabsContent value="level" className="space-y-4">
          <Card className="tibia-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                Level Evolution Comparison
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={data}>
                    <CartesianGrid strokeDasharray="3 3" className="opacity-30" />
                    <XAxis 
                      dataKey="date" 
                      tickFormatter={formatDate}
                      className="text-muted-foreground"
                    />
                    <YAxis 
                      className="text-muted-foreground"
                    />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend />
                    {characters.map((char, index) => (
                      <Line
                        key={char.id}
                        type="monotone"
                        dataKey="level"
                        stroke={colors[index % colors.length]}
                        strokeWidth={3}
                        name={`${char.name} Level`}
                        dot={{ r: 4 }}
                        activeDot={{ r: 6 }}
                      />
                    ))}
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="experience" className="space-y-4">
          <Card className="tibia-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                Experience Evolution Comparison
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data}>
                    <defs>
                      {characters.map((char, index) => (
                        <linearGradient
                          key={char.id}
                          id={`gradient-${char.id}`}
                          x1="0"
                          y1="0"
                          x2="0"
                          y2="1"
                        >
                          <stop
                            offset="5%"
                            stopColor={colors[index % colors.length]}
                            stopOpacity={0.3}
                          />
                          <stop
                            offset="95%"
                            stopColor={colors[index % colors.length]}
                            stopOpacity={0}
                          />
                        </linearGradient>
                      ))}
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
                    <Legend />
                    {characters.map((char, index) => (
                      <Area
                        key={char.id}
                        type="monotone"
                        dataKey="experience"
                        stroke={colors[index % colors.length]}
                        fill={`url(#gradient-${char.id})`}
                        name={`${char.name} Experience`}
                        strokeWidth={2}
                      />
                    ))}
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="experienceGained" className="space-y-4">
          <Card className="tibia-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                Daily Experience Gain Comparison
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={data}>
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
                    <Legend />
                    {characters.map((char, index) => (
                      <Bar
                        key={char.id}
                        dataKey="experienceGained"
                        fill={colors[index % colors.length]}
                        name={`${char.name} Daily Exp`}
                        radius={[4, 4, 0, 0]}
                        opacity={0.8}
                      />
                    ))}
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
} 