import React, { useState, useEffect } from 'react';
import { Filter, X, ChevronDown, ChevronUp, TrendingUp, Star } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible';
import { Checkbox } from '@/components/ui/checkbox';
import { useFavorites } from '@/contexts/FavoritesContext';

const CharacterFilters = ({ filters: externalFilters = {}, onFilterChange, onClearFilters, onShowChart, filteredCount = 0 }) => {
  const [expanded, setExpanded] = useState(false);
  const { getFavoritesCount } = useFavorites();
  const [filters, setFilters] = useState({
    server: '',
    world: '',
    vocation: '',
    guild: '',
    search: '',
    minLevel: '',
    maxLevel: '',
    isFavorited: '',
    activityFilter: [],
    recoveryActive: '',
    limit: 'all',
  });

  // Sincroniza o estado local com o prop filters
  useEffect(() => {
    console.log('[CHARACTER_FILTERS] externalFilters mudou:', externalFilters);
    setFilters({
      server: externalFilters.server || '',
      world: externalFilters.world || '',
      vocation: externalFilters.vocation || '',
      guild: externalFilters.guild || '',
      search: externalFilters.search || '',
      minLevel: externalFilters.minLevel || '',
      maxLevel: externalFilters.maxLevel || '',
      isFavorited: externalFilters.isFavorited || '',
      activityFilter: externalFilters.activityFilter || [],
      recoveryActive: externalFilters.recoveryActive || '',
      limit: externalFilters.limit || 'all',
    });
  }, [externalFilters]);

  const handleFieldChange = (field, value) => {
    const newFilters = { ...filters, [field]: value };
    setFilters(newFilters);
  };

  const handleApplyFilters = () => {
    onFilterChange(filters);
  };

  const handleClearFilters = () => {
    const clearedFilters = {
      server: '',
      world: '',
      vocation: '',
      guild: '',
      search: '',
      minLevel: '',
      maxLevel: '',
      isFavorited: '',
      activityFilter: [],
      recoveryActive: '',
      limit: 'all',
    };
    setFilters(clearedFilters);
    onClearFilters();
  };

  // Função para lidar com tecla Enter
  const handleKeyPress = (event) => {
    if (event.key === 'Enter') {
      handleApplyFilters();
    }
  };

  const hasActiveFilters = Object.values(filters).some(value => {
    if (Array.isArray(value)) {
      return value.length > 0;
    }
    return value !== '' && value !== 'all';
  });

  const vocations = [
    'Sorcerer',
    'Druid', 
    'Paladin',
    'Knight',
    'Master Sorcerer',
    'Elder Druid',
    'Royal Paladin',
    'Elite Knight'
  ];

  const servers = [
    { value: 'taleon', label: 'Taleon' },
    { value: 'rubini', label: 'Rubini' },
  ];

  const worlds = [
    { value: 'san', label: 'San' },
    { value: 'aura', label: 'Aura' },
    { value: 'gaia', label: 'Gaia' },
  ];

  const activityFilters = [
    { value: 'active_today', label: `Ativos Hoje (${new Date().toLocaleDateString('pt-BR')})` },
    { value: 'active_yesterday', label: `Ativos Ontem (${new Date(Date.now() - 24*60*60*1000).toLocaleDateString('pt-BR')})` },
    { value: 'active_2days', label: `Ativos Últimos 2 dias (${new Date(Date.now() - 2*24*60*60*1000).toLocaleDateString('pt-BR')})` },
    { value: 'active_3days', label: `Ativos Últimos 3 dias (${new Date(Date.now() - 3*24*60*60*1000).toLocaleDateString('pt-BR')})` },
  ];

  return (
    <Card className="mb-6">
      <CardContent className="p-6">
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2">
            <Filter className="h-5 w-5 text-primary" />
            <CardTitle className="text-lg font-semibold">
              Filtros
            </CardTitle>
            {hasActiveFilters && (
              <Badge variant="secondary">Ativo</Badge>
            )}
          </div>
          
          <div className="flex gap-2">
            <Button
              size="sm"
              onClick={handleApplyFilters}
            >
              <Filter className="mr-2 h-4 w-4" />
              Filtrar
            </Button>
            
            {filteredCount > 0 && (
              <Button
                size="sm"
                variant="outline"
                onClick={onShowChart}
              >
                <TrendingUp className="mr-2 h-4 w-4" />
                Gráfico ({filteredCount})
              </Button>
            )}
            
            {hasActiveFilters && (
              <Button
                size="sm"
                variant="outline"
                onClick={handleClearFilters}
              >
                <X className="mr-2 h-4 w-4" />
                Limpar
              </Button>
            )}
            
            <CollapsibleTrigger asChild>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setExpanded(!expanded)}
              >
                {expanded ? (
                  <ChevronUp className="h-4 w-4" />
                ) : (
                  <ChevronDown className="h-4 w-4" />
                )}
              </Button>
            </CollapsibleTrigger>
          </div>
        </div>

        {/* Filtros Básicos (sempre visíveis) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
          <div className="space-y-2">
            <Label htmlFor="search">Buscar por nome</Label>
            <Input
              id="search"
              value={filters.search}
              onChange={(e) => handleFieldChange('search', e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Digite o nome..."
            />
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="server">Servidor</Label>
            <Select
              value={filters.server}
              onValueChange={(value) => handleFieldChange('server', value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Todos" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Todos</SelectItem>
                {servers.map((server) => (
                  <SelectItem key={server.value} value={server.value}>
                    {server.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="world">Mundo</Label>
            <Select
              value={filters.world}
              onValueChange={(value) => handleFieldChange('world', value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Todos" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Todos</SelectItem>
                {worlds.map((world) => (
                  <SelectItem key={world.value} value={world.value}>
                    {world.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="vocation">Vocação</Label>
            <Select
              value={filters.vocation}
              onValueChange={(value) => handleFieldChange('vocation', value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Todas" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Todas</SelectItem>
                {vocations.map((vocation) => (
                  <SelectItem key={vocation} value={vocation}>
                    {vocation}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="guild">Guild</Label>
            <Input
              id="guild"
              value={filters.guild}
              onChange={(e) => handleFieldChange('guild', e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Digite o nome da guild..."
            />
          </div>
        </div>

        {/* Filtros Avançados (colapsáveis) */}
        <Collapsible open={expanded}>
          <CollapsibleContent>
            <div className="border-t pt-4 mt-4">
              <h4 className="text-sm font-medium text-muted-foreground mb-4">
                Filtros Avançados
              </h4>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="minLevel">Level Mínimo</Label>
                  <Input
                    id="minLevel"
                    type="number"
                    value={filters.minLevel}
                    onChange={(e) => handleFieldChange('minLevel', e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="0"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="maxLevel">Level Máximo</Label>
                  <Input
                    id="maxLevel"
                    type="number"
                    value={filters.maxLevel}
                    onChange={(e) => handleFieldChange('maxLevel', e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="9999"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="isFavorited">Favoritos</Label>
                  <Select
                    value={filters.isFavorited}
                    onValueChange={(value) => handleFieldChange('isFavorited', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Todos" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Todos</SelectItem>
                      <SelectItem value="true">
                        Apenas Favoritos ({getFavoritesCount()})
                      </SelectItem>
                      <SelectItem value="false">Não Favoritos</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="recoveryActive">Recovery Ativo</Label>
                  <Select
                    value={filters.recoveryActive}
                    onValueChange={(value) => handleFieldChange('recoveryActive', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Todos" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Todos</SelectItem>
                      <SelectItem value="true">
                        Apenas Recovery Ativo
                      </SelectItem>
                      <SelectItem value="false">Não Recovery Ativo</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="limit">Mostrar</Label>
                  <Select
                    value={filters.limit}
                    onValueChange={(value) => handleFieldChange('limit', value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Todos" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Todos</SelectItem>
                      <SelectItem value="3">3 Personagens</SelectItem>
                      <SelectItem value="10">10 Personagens</SelectItem>
                      <SelectItem value="30">30 Personagens</SelectItem>
                      <SelectItem value="60">60 Personagens</SelectItem>
                      <SelectItem value="90">90 Personagens</SelectItem>
                      <SelectItem value="150">150 Personagens</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                
                <div className="space-y-2">
                  <Label>Atividade</Label>
                  <div className="space-y-2">
                    {activityFilters.map((filter) => (
                      <div key={filter.value} className="flex items-center space-x-2">
                        <Checkbox
                          id={filter.value}
                          checked={filters.activityFilter.includes(filter.value)}
                          onCheckedChange={(checked) => {
                            const newActivityFilter = checked
                              ? [...filters.activityFilter, filter.value]
                              : filters.activityFilter.filter(v => v !== filter.value);
                            handleFieldChange('activityFilter', newActivityFilter);
                          }}
                        />
                        <Label htmlFor={filter.value} className="text-sm">
                          {filter.label}
                        </Label>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </CollapsibleContent>
        </Collapsible>
      </CardContent>
    </Card>
  );
};

export default CharacterFilters; 