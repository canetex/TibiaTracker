import React from 'react'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend } from 'recharts'
import { Card, CardContent } from './ui/card'

type Character = { id: number; name?: string; data?: Array<{ date: string; value: number }> }

type Props = {
  characters: Character[]
  open: boolean
  onClose: () => void
}

const PALETTE = ["#1565C0", "#FFA726", "#4CAF50", "#F44336", "#9C27B0", "#FF5722", "#607D8B", "#795548"]

export default function ComparisonChart({ characters }: Props): JSX.Element {
  const merged = (characters[0]?.data || []).map((p, idx) => {
    const entry: any = { date: p.date }
    characters.forEach((c, i) => {
      entry[c.name || `c${i+1}`] = c.data?.[idx]?.value ?? 0
    })
    return entry
  })

  return (
    <Card className="tibia-card">
      <CardContent className="p-4">
        <div className="h-[400px]">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={merged}>
              <XAxis dataKey="date" stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} />
              <YAxis stroke="hsl(var(--muted-foreground))" tick={{ fontSize: 12 }} />
              <Tooltip />
              <Legend />
              {characters.map((c, i) => (
                <Line key={c.id} type="monotone" dot={false} dataKey={c.name || `c${i+1}`} stroke={PALETTE[i % PALETTE.length]} />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  )
} 