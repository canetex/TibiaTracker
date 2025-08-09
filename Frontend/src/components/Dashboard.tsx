import React from 'react'

export default function Dashboard(): JSX.Element {
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold gradient-text">Dashboard</h1>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div className="tibia-card p-4">Card 1</div>
        <div className="tibia-card p-4">Card 2</div>
        <div className="tibia-card p-4">Card 3</div>
      </div>
      <div className="tibia-stats-grid">
        <div className="tibia-card p-4">Personagem 1</div>
        <div className="tibia-card p-4">Personagem 2</div>
        <div className="tibia-card p-4">Personagem 3</div>
        <div className="tibia-card p-4">Personagem 4</div>
      </div>
    </div>
  )
} 