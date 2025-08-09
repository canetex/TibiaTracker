import React, { useState } from 'react'
import { Search } from 'lucide-react'
import { Button } from './ui/button'
import { Input } from './ui/input'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'

type Props = {
  onSearch: (name: string) => Promise<void> | void
  loading?: boolean
  searchResult?: any
  onAddCharacter?: () => void
}

export default function CharacterSearch({ onSearch, loading, searchResult, onAddCharacter }: Props): JSX.Element {
  const [name, setName] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return
    onSearch(name.trim())
  }

  return (
    <div className="w-full max-w-2xl mx-auto">
      <form onSubmit={handleSubmit} className="relative flex items-center gap-2">
        <Search className="absolute left-3 h-4 w-4 text-muted-foreground" />
        <Input
          className="pl-10"
          placeholder="Digite o nome do personagem"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <Button type="submit" disabled={loading}>
          {loading ? 'Buscando...' : 'Buscar'}
        </Button>
      </form>

      {searchResult && (
        <Card className="mt-4">
          <CardHeader>
            <CardTitle>Resultado</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-between">
              <div>
                <div className="font-medium">{searchResult.name || 'Personagem'}</div>
                {searchResult.world && (
                  <div className="text-sm text-muted-foreground">{searchResult.world}</div>
                )}
              </div>
              {onAddCharacter && (
                <Button variant="outline" onClick={onAddCharacter}>Adicionar</Button>
              )}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
} 