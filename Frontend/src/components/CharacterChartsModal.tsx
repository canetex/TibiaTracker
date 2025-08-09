import React from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'

type Props = {
  character: any
  open: boolean
  onClose: () => void
}

export default function CharacterChartsModal({ character, open, onClose }: Props): JSX.Element | null {
  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="max-w-6xl w-full max-h-[90vh] overflow-auto p-4">
        <Card className="tibia-card">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Gráficos - {character?.name || 'Personagem'}</CardTitle>
            <Button variant="outline" onClick={onClose}>Fechar</Button>
          </CardHeader>
          <CardContent>
            <div className="h-[400px] grid place-items-center text-muted-foreground">Gráfico em breve</div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
} 