import React, { useState } from 'react';
import { CharacterSelection } from './CharacterSelection';
import { ComparisonChart } from './ComparisonChart';
import { Dialog, DialogContent } from './ui/dialog';

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

export default function Dashboard(): JSX.Element {
  const [isComparisonOpen, setIsComparisonOpen] = useState(false);
  const [selectedCharacters, setSelectedCharacters] = useState<Character[]>([]);
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);

  const handleCompare = async (characters: Character[]) => {
    // TODO: Fetch chart data for selected characters
    setSelectedCharacters(characters);
    setIsComparisonOpen(true);
  };

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold gradient-text">Dashboard</h1>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div className="tibia-card p-4">Card 1</div>
        <div className="tibia-card p-4">Card 2</div>
        <div className="tibia-card p-4">Card 3</div>
      </div>

      <CharacterSelection
        characters={[]} // TODO: Pass actual characters
        onCompare={handleCompare}
      />

      <Dialog open={isComparisonOpen} onOpenChange={setIsComparisonOpen}>
        <DialogContent className="max-w-6xl max-h-[90vh] overflow-auto">
          <ComparisonChart
            characters={selectedCharacters}
            data={chartData}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
} 