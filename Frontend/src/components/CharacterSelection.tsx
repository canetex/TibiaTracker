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
  const [showFilters, setShowFilters] = useState(false);

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

  const clearFilters = () => {
    setFilters({
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
    setShowFilters(false);
  };

  return (
    <div className="space-y-4">
      {/* Search and Filter Toggle */}
      <div className="flex flex-col md:flex-row gap-2">
        <div className="flex-1 flex gap-2">
          <Input
            placeholder="Buscar por nome ou guild..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="w-full"
          />
          <Button variant="outline" size="icon" onClick={() => setShowFilters(!showFilters)} className="md:hidden">
            <Filter className="h-4 w-4" />
          </Button>
        </div>

        {/* Desktop Filters */}
        <div className="hidden md:flex gap-2 flex-wrap">
          <Select
            value={filters.vocation}
            onValueChange={(value) => setFilters({ ...filters, vocation: value })}
          >
            <SelectTrigger className="w-[150px]">
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
            <SelectTrigger className="w-[150px]">
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
            className="w-[150px]"
          />

          <div className="flex gap-2">
            <Input
              type="number"
              placeholder="Level min"
              value={filters.minLevel}
              onChange={(e) => setFilters({ ...filters, minLevel: e.target.value })}
              className="w-[100px]"
            />
            <Input
              type="number"
              placeholder="Level max"
              value={filters.maxLevel}
              onChange={(e) => setFilters({ ...filters, maxLevel: e.target.value })}
              className="w-[100px]"
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
            onClick={clearFilters}
            className="flex items-center gap-2"
          >
            <Filter className="h-4 w-4" />
            Limpar
          </Button>
        </div>
      </div>

      {/* Mobile Filters */}
      {showFilters && (
        <Card className="p-4 md:hidden">
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-2">
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
            </div>

            <Input
              placeholder="Guild"
              value={filters.guild}
              onChange={(e) => setFilters({ ...filters, guild: e.target.value })}
            />

            <div className="grid grid-cols-2 gap-2">
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

            <div className="grid grid-cols-2 gap-2">
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
            </div>

            <label className="flex items-center gap-2">
              <Checkbox
                checked={filters.isFavorite}
                onCheckedChange={(checked) => setFilters({ ...filters, isFavorite: checked as boolean })}
              />
              <span className="text-sm">Favoritos</span>
            </label>

            <Button
              variant="outline"
              onClick={clearFilters}
              className="w-full flex items-center justify-center gap-2"
            >
              <Filter className="h-4 w-4" />
              Limpar filtros
            </Button>
          </div>
        </Card>
      )}

      {/* Selection controls */}
      <div className="flex flex-col md:flex-row items-center justify-between gap-2">
        <div className="flex items-center gap-2 w-full md:w-auto">
          <Button
            variant="outline"
            onClick={handleSelectAll}
            className="text-sm flex-1 md:flex-none"
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
            className="flex items-center gap-2 w-full md:w-auto"
          >
            <GitCompare className="h-4 w-4" />
            Compare Selected
          </Button>
        )}
      </div>

      {/* Character grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-4">
        {filteredCharacters.map((char) => (
          <Card key={char.id} className={`tibia-card p-3 md:p-4 ${selectedCharacters.has(char.id) ? 'ring-2 ring-primary' : ''}`}>
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