import React from 'react'
import { Button } from './ui/button'
import { Input } from './ui/input'
import { Card, CardContent } from './ui/card'

type Filters = {
  server?: string
  world?: string
  vocation?: string
  guild?: string
  search?: string
  minLevel?: string
  maxLevel?: string
  isFavorited?: string
  activityFilter?: string[]
  recoveryActive?: string
  limit?: string
}

type Props = {
  filters: Filters
  onFiltersChange: (f: Filters) => void
  onApplyFilters: (f: Filters) => void
  onClearFilters: () => void
}

export default function CharacterFilters({ filters, onFiltersChange, onApplyFilters, onClearFilters }: Props): JSX.Element {
  const update = (key: keyof Filters) => (e: React.ChangeEvent<HTMLInputElement>) => {
    onFiltersChange({ ...filters, [key]: e.target.value })
  }

  return (
    <Card>
      <CardContent className="p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        <Input placeholder="Servidor" value={filters.server || ''} onChange={update('server')} />
        <Input placeholder="Mundo" value={filters.world || ''} onChange={update('world')} />
        <Input placeholder="Vocação" value={filters.vocation || ''} onChange={update('vocation')} />
        <Input placeholder="Guild" value={filters.guild || ''} onChange={update('guild')} />
        <Input placeholder="Busca" value={filters.search || ''} onChange={update('search')} />
        <Input placeholder="Nível mínimo" value={filters.minLevel || ''} onChange={update('minLevel')} />
        <Input placeholder="Nível máximo" value={filters.maxLevel || ''} onChange={update('maxLevel')} />
        <div className="col-span-full flex gap-2 justify-end pt-2">
          <Button variant="outline" onClick={onClearFilters}>Limpar</Button>
          <Button onClick={() => onApplyFilters(filters)}>Aplicar</Button>
        </div>
      </CardContent>
    </Card>
  )
} 