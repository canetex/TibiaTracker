import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Checkbox } from './ui/checkbox';
import { GitCompare } from 'lucide-react';

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

interface CharacterSelectionProps {
  characters: Character[];
  onCompare: (selectedCharacters: Character[]) => void;
}

export function CharacterSelection({ characters, onCompare }: CharacterSelectionProps) {
  const [selectedCharacters, setSelectedCharacters] = useState<Set<string>>(new Set());

  const handleCharacterSelect = (id: string) => {
    const newSelected = new Set(selectedCharacters);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedCharacters(newSelected);
  };

  const handleSelectAll = () => {
    if (selectedCharacters.size === characters.length) {
      setSelectedCharacters(new Set());
    } else {
      setSelectedCharacters(new Set(characters.map(char => char.id)));
    }
  };

  const handleCompare = () => {
    const selectedChars = characters.filter(char => selectedCharacters.has(char.id));
    onCompare(selectedChars);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            onClick={handleSelectAll}
            className="text-sm"
          >
            {selectedCharacters.size === characters.length ? 'Deselect All' : 'Select All'}
          </Button>
          <span className="text-sm text-muted-foreground">
            {selectedCharacters.size} characters selected
          </span>
        </div>
        {selectedCharacters.size > 1 && (
          <Button
            onClick={handleCompare}
            className="flex items-center gap-2"
          >
            <GitCompare className="h-4 w-4" />
            Compare Selected
          </Button>
        )}
      </div>

      <div className="tibia-stats-grid">
        {characters.map((char) => (
          <Card key={char.id} className={`tibia-card p-4 ${selectedCharacters.has(char.id) ? 'ring-2 ring-primary' : ''}`}>
            <div className="flex items-center gap-3">
              <Checkbox
                checked={selectedCharacters.has(char.id)}
                onCheckedChange={() => handleCharacterSelect(char.id)}
              />
              <div>
                <h4 className="font-semibold text-foreground">{char.name}</h4>
                <p className="text-sm text-muted-foreground">
                  Level {char.level} {char.vocation}
                </p>
                <p className="text-xs text-muted-foreground">{char.world}</p>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
} 