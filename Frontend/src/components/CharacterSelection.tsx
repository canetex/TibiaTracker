import React, { useState, useEffect } from 'react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Checkbox } from './ui/checkbox';
import { Input } from './ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { GitCompare, Search, Filter } from 'lucide-react';

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

interface Filters {
  search: string;
  vocation: string;
  world: string;
  guild: string;
  minLevel: string;
  maxLevel: string;
  isOnline: boolean;
  recoveryActive: boolean;
  isFavorite: boolean;
}

const vocations = [
  'Elite Knight',
  'Royal Paladin',
  'Master Sorcerer',
  'Elder Druid',
];

const worlds = [
  'Antica',
  'Secura',
  'Monza',
  'Premia',
  'Celesta',
];

export function CharacterSelection({ characters, onCompare }: CharacterSelectionProps) {
  const [selectedCharacters, setSelectedCharacters] = useState<Set<string>>(new Set());
  const [filters, setFilters] = useState<Filters>({
    search: '',
    vocation: '',
    world: '',
    guild: '',
    minLevel: '',
    maxLevel: '',
    isOnline: false,
    recoveryActive: false,
    isFavorite: false,
  });
  const [filteredCharacters, setFilteredCharacters] = useState<Character[]>(characters);

  useEffect(() => {
    applyFilters();
  }, [characters, filters]);

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
    if (selectedCharacters.size === filteredCharacters.length) {
      setSelectedCharacters(new Set());
    } else {
      setSelectedCharacters(new Set(filteredCharacters.map(char => char.id)));
    }
  };

  const handleCompare = () => {
    const selectedChars = filteredCharacters.filter(char => selectedCharacters.has(char.id));
    onCompare(selectedChars);
  };

  const applyFilters = () => {
    let filtered = [...characters];

    // Search filter
    if (filters.search) {
      const searchTerm = filters.search.toLowerCase();
      filtered = filtered.filter(char => 
        char.name.toLowerCase().includes(searchTerm) ||
        char.guild?.toLowerCase().includes(searchTerm)
      );
    }

    // Vocation filter
    if (filters.vocation) {
      filtered = filtered.filter(char => char.vocation === filters.vocation);
    }

    // World filter
    if (filters.world) {
      filtered = filtered.filter(char => char.world === filters.world);
    }

    // Guild filter
    if (filters.guild) {
      filtered = filtered.filter(char => char.guild?.toLowerCase().includes(filters.guild.toLowerCase()));
    }

    // Level range filter
    if (filters.minLevel) {
      filtered = filtered.filter(char => char.level >= parseInt(filters.minLevel));
    }
    if (filters.maxLevel) {
      filtered = filtered.filter(char => char.level <= parseInt(filters.maxLevel));
    }

    // Status filters
    if (filters.isOnline) {
      filtered = filtered.filter(char => char.isOnline);
    }
    if (filters.recoveryActive) {
      filtered = filtered.filter(char => char.recoveryActive);
    }
    if (filters.isFavorite) {
      filtered = filtered.filter(char => char.isFavorite);
    }

    setFilteredCharacters(filtered);
  };

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="flex gap-2">
          <Input
            placeholder="Buscar por nome ou guild..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="w-full"
          />
          <Button variant="outline" size="icon">
            <Search className="h-4 w-4" />
          </Button>
        </div>

        <Select
          value={filters.vocation}
          onValueChange={(value) => setFilters({ ...filters, vocation: value })}
        >
          <SelectTrigger>
            <SelectValue placeholder="Vocação" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">Todas</SelectItem>
            {vocations.map((voc) => (
              <SelectItem key={voc} value={voc}>{voc}</SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={filters.world}
          onValueChange={(value) => setFilters({ ...filters, world: value })}
        >
          <SelectTrigger>
            <SelectValue placeholder="Mundo" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">Todos</SelectItem>
            {worlds.map((world) => (
              <SelectItem key={world} value={world}>{world}</SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Input
          placeholder="Guild"
          value={filters.guild}
          onChange={(e) => setFilters({ ...filters, guild: e.target.value })}
        />

        <div className="flex gap-2">
          <Input
            type="number"
            placeholder="Level min"
            value={filters.minLevel}
            onChange={(e) => setFilters({ ...filters, minLevel: e.target.value })}
          />
          <Input
            type="number"
            placeholder="Level max"
            value={filters.maxLevel}
            onChange={(e) => setFilters({ ...filters, maxLevel: e.target.value })}
          />
        </div>

        <div className="flex items-center gap-4">
          <label className="flex items-center gap-2">
            <Checkbox
              checked={filters.isOnline}
              onCheckedChange={(checked) => setFilters({ ...filters, isOnline: checked as boolean })}
            />
            <span className="text-sm">Online</span>
          </label>
          <label className="flex items-center gap-2">
            <Checkbox
              checked={filters.recoveryActive}
              onCheckedChange={(checked) => setFilters({ ...filters, recoveryActive: checked as boolean })}
            />
            <span className="text-sm">Em recuperação</span>
          </label>
          <label className="flex items-center gap-2">
            <Checkbox
              checked={filters.isFavorite}
              onCheckedChange={(checked) => setFilters({ ...filters, isFavorite: checked as boolean })}
            />
            <span className="text-sm">Favoritos</span>
          </label>
        </div>

        <Button
          variant="outline"
          onClick={() => setFilters({
            search: '',
            vocation: '',
            world: '',
            guild: '',
            minLevel: '',
            maxLevel: '',
            isOnline: false,
            recoveryActive: false,
            isFavorite: false,
          })}
          className="flex items-center gap-2"
        >
          <Filter className="h-4 w-4" />
          Limpar filtros
        </Button>
      </div>

      {/* Selection controls */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            onClick={handleSelectAll}
            className="text-sm"
          >
            {selectedCharacters.size === filteredCharacters.length ? 'Deselect All' : 'Select All'}
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

      {/* Character grid */}
      <div className="tibia-stats-grid">
        {filteredCharacters.map((char) => (
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