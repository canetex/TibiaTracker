import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Input } from './ui/input';
import { Button } from './ui/button';
import Spinner from './ui/spinner';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Checkbox } from './ui/checkbox';
import { Search, Filter, Users } from 'lucide-react';
import { apiService } from '../services/api';
import logger from '../lib/logger';

interface Character {
  id: number;
  name: string;
  level: number;
  vocation: string;
  world: string;
  server: string;
  guild?: string;
}

interface CharacterSelectionProps {
  characters: Character[];
  onCompare: (characters: Character[]) => void;
}

export function CharacterSelection({ characters, onCompare }: CharacterSelectionProps) {
  const [searchTerm, setSearchTerm] = useState('');
  // Função utilitária para atualizar vocations/servers/guilds a partir de lista de personagens
  const deriveFilterOptions = (chars: Character[]) => {
    const vocs = Array.from(new Set(chars.map(c => c.vocation))).sort();
    const srvs = Array.from(new Set(chars.map(c => c.server))).sort();
    const glds = Array.from(new Set(chars.filter(c => c.guild).map(c => c.guild!))).sort();
    if (vocations.length === 0) setVocations(vocs);
    if (servers.length === 0) setServers(srvs);
    if (guilds.length === 0) setGuilds(glds);
  };

  const [selectedCharacters, setSelectedCharacters] = useState<number[]>([]);
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState({
    vocation: '',
    server: '',
    guild: '',
    minLevel: '',
    maxLevel: '',
  });
  const [vocations, setVocations] = useState<string[]>([]);
  const [servers, setServers] = useState<string[]>([]);
  const [guilds, setGuilds] = useState<string[]>([]);
  const [filteredCharacters, setFilteredCharacters] = useState<Character[]>([]);
  const [isFiltering, setIsFiltering] = useState(false);

  useEffect(() => {
    const loadFilters = async () => {
      try {
        const [vocationsData, serversData] = await Promise.all([
          apiService.getVocations(),
          apiService.getServers()
        ]);
        setVocations(vocationsData);
        setServers(serversData);
        // Para guilds, vamos extrair das vocações existentes por enquanto
        // Em uma implementação futura, podemos criar um endpoint específico para guilds
        setGuilds([]);
      } catch (error) {
        logger.error('Erro ao carregar filtros:', error);
      }
    };
    loadFilters();
  }, []);

  // Aplicar filtros via API quando necessário
  const applyFilters = async () => {
    setIsFiltering(true);
    const activeFilters = Object.fromEntries(
      Object.entries(filters).filter(([_, value]) => value !== '')
    );
    try {
      if (Object.keys(activeFilters).length === 0) {
        // Se não há filtros ativos, usar todos os personagens
        setFilteredCharacters(characters);
        return;
      }

      // Aplicar filtros via API
      const filteredData = await apiService.getFilteredCharacters(activeFilters);
      
      // Validação adicional para garantir que filteredData é um array
      if (Array.isArray(filteredData)) {
        setFilteredCharacters(filteredData);
      } else {
        logger.warn('[CharacterSelection] Dados filtrados não são um array:', filteredData);
        setFilteredCharacters([]);
      }
    } catch (error) {
      logger.warn('API de filtros indisponível, aplicando filtragem local.');
      // Fallback local
      const locallyFiltered = localFilter(characters, activeFilters);
      setFilteredCharacters(locallyFiltered);
    } finally {
      setIsFiltering(false);
    }
  };

  // Filtragem local genérica
  const localFilter = (chars: Character[], activeFilters: Record<string, any>) => {
    return chars.filter(char => {
      const fn = (field: keyof typeof activeFilters, predicate: (v:any)=>boolean) => {
        if (!activeFilters[field]) return true;
        return predicate(activeFilters[field]);
      };
      return (
        fn('vocation', (v) => char.vocation === v) &&
        fn('server', (v) => char.server === v) &&
        fn('guild', (v) => (char.guild || '').toLowerCase().includes(String(v).toLowerCase())) &&
        fn('minLevel', (v) => char.level >= Number(v)) &&
        fn('maxLevel', (v) => char.level <= Number(v)) &&
        fn('search', (v) => char.name.toLowerCase().includes(String(v).toLowerCase()))
      );
    });
  };

  // Aplicar filtros quando os filtros mudarem
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      applyFilters();
    }, 500); // Debounce de 500ms

    return () => clearTimeout(timeoutId);
  }, [filters]);

  // Inicializar com todos os personagens
  useEffect(() => {
    if (Array.isArray(characters)) {
      setFilteredCharacters(characters);
      deriveFilterOptions(characters);
    } else {
      logger.warn('[CharacterSelection] characters não é um array:', characters);
      setFilteredCharacters([]);
    }
  }, [characters]);

  // Atualizar lista em tempo real com searchTerm sem esperar debounce
  useEffect(() => {
    if (!searchTerm) return; // handled by filters
    const newFilters = { ...filters, search: searchTerm };
    setFilters(newFilters);
  }, [searchTerm]);

  const handleSearch = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value || '';
    setSearchTerm(value);
  };

  const handleCharacterSelect = (characterId: number) => {
    setSelectedCharacters(prev =>
      prev.includes(characterId)
        ? prev.filter(id => id !== characterId)
        : [...prev, characterId]
    );
  };

  const handleSelectAll = () => {
    if (Array.isArray(filteredCharacters) && Array.isArray(selectedCharacters)) {
      if (selectedCharacters.length === filteredCharacters.length) {
        setSelectedCharacters([]);
      } else {
        setSelectedCharacters(filteredCharacters.map(char => char.id));
      }
    } else {
      logger.warn('[CharacterSelection] Dados inválidos para seleção:', { filteredCharacters, selectedCharacters });
    }
  };

  const handleCompare = () => {
    if (Array.isArray(characters) && Array.isArray(selectedCharacters)) {
      const selectedChars = characters.filter(char => selectedCharacters.includes(char.id));
      onCompare(selectedChars);
    } else {
      logger.warn('[CharacterSelection] Dados inválidos para comparação:', { characters, selectedCharacters });
    }
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <CardTitle className="text-lg font-medium">Personagens</CardTitle>
          <div className="flex items-center gap-2 w-full md:w-auto">
            <div className="relative flex-1 md:w-64">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Buscar personagem..."
                value={searchTerm}
                onChange={handleSearch}
                className="pl-9"
              />
            </div>
            <Button
              variant="outline"
              size="icon"
              onClick={() => setShowFilters(!showFilters)}
            >
              <Filter className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        {showFilters && (
          <div className="mb-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Select
              value={filters.vocation}
              onValueChange={(value) => setFilters(prev => ({ ...prev, vocation: value }))}
            >
              <SelectTrigger>
                <SelectValue placeholder="Vocação" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Todas</SelectItem>
                {vocations.map(vocation => (
                  <SelectItem key={vocation} value={vocation}>
                    {vocation}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Select
              value={filters.server}
              onValueChange={(value) => setFilters(prev => ({ ...prev, server: value }))}
            >
              <SelectTrigger>
                <SelectValue placeholder="Servidor" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Todos</SelectItem>
                {servers.map(server => (
                  <SelectItem key={server} value={server}>
                    {server}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Input
              placeholder="Guild"
              value={filters.guild}
              onChange={(e) => setFilters(prev => ({ ...prev, guild: e.target.value }))}
            />

            <Input
              type="number"
              placeholder="Level mínimo"
              value={filters.minLevel}
              onChange={(e) => setFilters(prev => ({ ...prev, minLevel: e.target.value }))}
            />

            <Input
              type="number"
              placeholder="Level máximo"
              value={filters.maxLevel}
              onChange={(e) => setFilters(prev => ({ ...prev, maxLevel: e.target.value }))}
            />
          </div>
        )}

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Checkbox
                id="select-all"
                checked={selectedCharacters.length === filteredCharacters.length && filteredCharacters.length > 0}
                onCheckedChange={handleSelectAll}
              />
              <label
                htmlFor="select-all"
                className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
              >
                Selecionar todos
              </label>
            </div>

            <div className="flex items-center gap-2">
              {isFiltering && <Spinner size={20} />}
              <Button
                variant="default"
                size="sm"
                onClick={handleCompare}
                disabled={selectedCharacters.length === 0}
                className="flex items-center gap-2"
              >
                <Users className="h-4 w-4" />
                Comparar ({selectedCharacters.length})
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {Array.isArray(filteredCharacters) && filteredCharacters.length > 0 ? (
              filteredCharacters.map((char) => (
                <Card
                  key={char.id}
                  className={`p-4 cursor-pointer hover:bg-muted/50 transition-colors ${
                    selectedCharacters.includes(char.id) ? 'ring-2 ring-primary' : ''
                  }`}
                  onClick={() => handleCharacterSelect(char.id)}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <Checkbox
                        checked={selectedCharacters.includes(char.id)}
                        onCheckedChange={() => handleCharacterSelect(char.id)}
                      />
                      <div>
                        <p className="font-medium">{char.name}</p>
                        <p className="text-sm text-muted-foreground">
                          Level {char.level} {char.vocation}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {char.server} • {char.world}
                        </p>
                      </div>
                    </div>
                  </div>
                </Card>
              ))
            ) : (
              <div className="col-span-full text-center py-8 text-muted-foreground">
                {isFiltering ? 'Aplicando filtros...' : 'Nenhum personagem encontrado com os filtros aplicados.'}
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
} 