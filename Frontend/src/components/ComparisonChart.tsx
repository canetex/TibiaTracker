import React, { useEffect, useMemo, useState } from 'react'
import { Card, CardContent } from './ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend, BarChart, Bar, AreaChart, Area } from 'recharts'
import { apiService } from '../services/api'

const PALETTE = ["#1565C0", "#FFA726", "#4CAF50", "#F44336", "#9C27B0", "#FF5722", "#607D8B", "#795548"]

type Character = { id: number; name?: string }

type Props = {
  characters: Character[]
  open: boolean
  onClose: () => void
}

function AxisProps() {
  return {
    stroke: 'hsl(var(--muted-foreground))',
    tick: { fontSize: 12, fill: 'hsl(var(--muted-foreground))' },
  }
}

export default function ComparisonChart({ characters }: Props): JSX.Element {
  const [days] = useState(30)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [series, setSeries] = useState<Record<number, Array<any>>>({})

  useEffect(() => {
    let isMounted = true
    const fetchAll = async () => {
      try {
        setLoading(true)
        setError(null)
        const results = await Promise.all(
          characters.map(async (c) => {
            try {
              const stats = await apiService.getCharacterStats(c.id, days)
              return { id: c.id, data: Array.isArray(stats) ? stats : [] }
            } catch {
              return { id: c.id, data: [] }
            }
          })
        )
        if (!isMounted) return
        const map: Record<number, Array<any>> = {}
        results.forEach(({ id, data }) => { map[id] = data })
        setSeries(map)
      } catch (err: any) {
        if (!isMounted) return
        setError('Erro ao carregar dados para comparação')
      } finally {
        if (isMounted) setLoading(false)
      }
    }
    if (characters?.length) fetchAll()
    return () => { isMounted = false }
  }, [characters, days])

  const mergedBy = (key: 'level' | 'experience' | 'experienceGained') => {
    // Assume todas as séries possuem mesmo número de pontos por dia
    const maxLen = Math.max(0, ...Object.values(series).map(arr => arr.length))
    const out: any[] = []
    for (let i = 0; i < maxLen; i++) {
      const row: any = { date: undefined }
      characters.forEach((c) => {
        const d = series[c.id]?.[i] || {}
        row.date = row.date || d.date || d.day || d.label
        const level = d.level ?? d.latest_snapshot?.level ?? 0
        const exp = d.experience ?? d.latest_snapshot?.experience ?? 0
        const gained = d.experienceGained ?? d.exp_gained ?? d.exp ?? 0
        row[c.name || `c${c.id}`] = key === 'level' ? level : key === 'experience' ? exp : gained
      })
      out.push(row)
    }
    return out
  }

  const dataLevel = useMemo(() => mergedBy('level'), [series, characters])
  const dataExp = useMemo(() => mergedBy('experience'), [series, characters])
  const dataGained = useMemo(() => mergedBy('experienceGained'), [series, characters])

  return (
    <Card className="tibia-card">
      <CardContent className="p-4">
        {error && <div className="text-destructive mb-4">{error}</div>}
        {loading ? (
          <div className="h-[400px] grid place-items-center text-muted-foreground">Carregando...</div>
        ) : (
          <Tabs defaultValue="level" className="w-full">
            <TabsList className="grid w-full grid-cols-3 sm:w-auto mb-4">
              <TabsTrigger value="level">Level</TabsTrigger>
              <TabsTrigger value="experience">Experiência</TabsTrigger>
              <TabsTrigger value="gained">Exp. Diária</TabsTrigger>
            </TabsList>

            <TabsContent value="level">
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={dataLevel}>
                    <XAxis dataKey="date" {...AxisProps()} />
                    <YAxis {...AxisProps()} />
                    <Tooltip />
                    <Legend />
                    {characters.map((c, i) => (
                      <Line key={c.id} type="monotone" dot={false} dataKey={c.name || `c${c.id}`} stroke={PALETTE[i % PALETTE.length]} />
                    ))}
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </TabsContent>

            <TabsContent value="experience">
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={dataExp}>
                    <XAxis dataKey="date" {...AxisProps()} />
                    <YAxis {...AxisProps()} />
                    <Tooltip />
                    <Legend />
                    {characters.map((c, i) => (
                      <Area key={c.id} type="monotone" dataKey={c.name || `c${c.id}`} stroke={PALETTE[i % PALETTE.length]} fill={PALETTE[i % PALETTE.length]} fillOpacity={0.2} />
                    ))}
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </TabsContent>

            <TabsContent value="gained">
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={dataGained}>
                    <XAxis dataKey="date" {...AxisProps()} />
                    <YAxis {...AxisProps()} />
                    <Tooltip />
                    <Legend />
                    {characters.map((c, i) => (
                      <Bar key={c.id} dataKey={c.name || `c${c.id}`} fill={PALETTE[i % PALETTE.length]} />
                    ))}
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </TabsContent>
          </Tabs>
        )}
      </CardContent>
    </Card>
  )
} 