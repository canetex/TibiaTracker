import React, { useEffect, useMemo, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs'
import { ResponsiveContainer, AreaChart, Area, LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, Legend } from 'recharts'
import { apiService } from '../services/api'

function AxisProps() {
  return {
    stroke: 'hsl(var(--muted-foreground))',
    tick: { fontSize: 12, fill: 'hsl(var(--muted-foreground))' },
  }
}

type Props = {
  character: any
  open: boolean
  onClose: () => void
}

export default function CharacterChartsModal({ character, open, onClose }: Props): JSX.Element | null {
  const [days, setDays] = useState(30)
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

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="max-w-6xl w-full max-h-[90vh] overflow-auto p-4">
        <Card className="tibia-card">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Gráficos - {character?.name || 'Personagem'}</CardTitle>
            <div className="flex items-center gap-2">
              <select
                className="h-9 rounded-md border bg-background px-3 text-sm"
                value={days}
                onChange={(e) => setDays(Number(e.target.value))}
              >
                <option value={7}>7 dias</option>
                <option value={14}>14 dias</option>
                <option value={30}>30 dias</option>
                <option value={60}>60 dias</option>
                <option value={90}>90 dias</option>
              </select>
              <Button variant="outline" onClick={onClose}>Fechar</Button>
            </div>
          </CardHeader>
          <CardContent>
            {error && <div className="text-destructive mb-4">{error}</div>}
            {loading ? (
              <div className="h-[400px] grid place-items-center text-muted-foreground">Carregando...</div>
            ) : (
              <Tabs defaultValue="experience" className="w-full">
                <TabsList className="grid w-full grid-cols-4 sm:w-auto mb-4">
                  <TabsTrigger value="experience">Experiência</TabsTrigger>
                  <TabsTrigger value="level">Level</TabsTrigger>
                  <TabsTrigger value="gained">Exp. Diária</TabsTrigger>
                  <TabsTrigger value="deaths">Mortes</TabsTrigger>
                </TabsList>

                <TabsContent value="experience">
                  <div className="h-[400px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={chartData} margin={{ left: 8, right: 8, top: 8, bottom: 8 }}>
                        <defs>
                          <linearGradient id="experienceGradient" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor={"hsl(var(--primary))"} stopOpacity={0.6} />
                            <stop offset="95%" stopColor={"hsl(var(--primary))"} stopOpacity={0.1} />
                          </linearGradient>
                        </defs>
                        <XAxis dataKey="date" {...AxisProps()} />
                        <YAxis {...AxisProps()} />
                        <Tooltip />
                        <Legend />
                        <Area type="monotone" dataKey="experience" stroke={"hsl(var(--primary))"} fillOpacity={1} fill="url(#experienceGradient)" />
                      </AreaChart>
                    </ResponsiveContainer>
                  </div>
                </TabsContent>

                <TabsContent value="level">
                  <div className="h-[400px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={chartData} margin={{ left: 8, right: 8, top: 8, bottom: 8 }}>
                        <XAxis dataKey="date" {...AxisProps()} />
                        <YAxis {...AxisProps()} />
                        <Tooltip />
                        <Legend />
                        <Line type="monotone" dataKey="level" stroke="hsl(var(--success))" dot={false} />
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </TabsContent>

                <TabsContent value="gained">
                  <div className="h-[400px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={chartData} margin={{ left: 8, right: 8, top: 8, bottom: 8 }}>
                        <XAxis dataKey="date" {...AxisProps()} />
                        <YAxis {...AxisProps()} />
                        <Tooltip />
                        <Legend />
                        <Bar dataKey="experienceGained" fill="hsl(var(--warning))" />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </TabsContent>

                <TabsContent value="deaths">
                  <div className="h-[400px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={chartData} margin={{ left: 8, right: 8, top: 8, bottom: 8 }}>
                        <XAxis dataKey="date" {...AxisProps()} />
                        <YAxis {...AxisProps()} />
                        <Tooltip />
                        <Legend />
                        <Bar dataKey="deaths" fill="hsl(var(--destructive))" />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </TabsContent>
              </Tabs>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
} 