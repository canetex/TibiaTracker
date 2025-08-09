import React from 'react'

export default function Sidebar(): JSX.Element {
  return (
    <aside className="hidden md:block w-64 border-r bg-card text-card-foreground">
      <div className="p-4">
        <div className="text-sm text-muted-foreground mb-2">Filtros</div>
        <div className="space-y-2">
          <div className="h-10 rounded-md bg-muted/50 border border-border" />
          <div className="h-10 rounded-md bg-muted/50 border border-border" />
          <div className="h-10 rounded-md bg-muted/50 border border-border" />
        </div>
      </div>
    </aside>
  )
} 