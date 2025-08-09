import React from 'react'
import { Button } from './ui/button'
import { Card, CardContent } from './ui/card'

type Character = { id: number; name?: string }

type Props = {
  characters: Character[]
  onRemoveCharacter: (id: number) => void
  onClearAll: () => void
  onShowChart: () => void
}

export default function ComparisonPanel({ characters, onRemoveCharacter, onClearAll, onShowChart }: Props): JSX.Element {
  return (
    <Card>
      <CardContent className="p-4 space-y-3">
        <div className="flex gap-2 justify-between items-center">
          <div className="font-medium">Comparação ({characters.length})</div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={onClearAll}>Limpar</Button>
            <Button onClick={onShowChart} disabled={characters.length === 0}>Ver Gráfico</Button>
          </div>
        </div>
        <ul className="space-y-2">
          {characters.map(c => (
            <li key={c.id} className="flex items-center justify-between p-2 rounded-md border">
              <span>{c.name || `#${c.id}`}</span>
              <Button variant="ghost" onClick={() => onRemoveCharacter(c.id)}>Remover</Button>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  )
} 