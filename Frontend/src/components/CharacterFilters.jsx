import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import { 
  Filter, 
  X, 
  ChevronDown, 
  ChevronUp, 
  TrendingUp, 
  Star,
  RotateCcw,
  Users,
  Globe
} from 'lucide-react';
import { useFavorites } from '@/contexts/FavoritesContext';
import { useToast } from '@/hooks/use-toast';

const CharacterFilters = ({ 
  filters: externalFilters = {}, 
  onFilterChange, 
  onClearFilters, 
  onShowChart, 
  filteredCount = 0 
}) => {
  const [expanded, setExpanded] = useState(false);
  const { getFavoritesCount } = useFavorites();
  const { toast } = useToast();
  
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

  const handleActivityFilterChange = (activity) => {
    const newActivityFilter = filters.activityFilter.includes(activity)
      ? filters.activityFilter.filter(a => a !== activity)
      : [...filters.activityFilter, activity];
    
    setFilters(prev => ({ ...prev, activityFilter: newActivityFilter }));
  };

  const handleApplyFilters = () => {
    onFilterChange(filters);
    toast({
      title: "Filtros aplicados",
      description: `${filteredCount} personagens encontrados`,
      variant: "success"
    });
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
    toast({
      title: "Filtros limpos",
      description: "Todos os filtros foram removidos",
      variant: "info"
    });
  };

  const handleKeyPress = (event) => {
    if (event.key === 'Enter') {
      handleApplyFilters();
    }
  };

  const vocations = [
    'Knight', 'Elite Knight', 'Paladin', 'Royal Paladin',
    'Sorcerer', 'Master Sorcerer', 'Druid', 'Elder Druid'
  ];

  const servers = [
    { value: 'taleon', label: 'Taleon' },
    { value: 'rubini', label: 'Rubini' },
    { value: 'deus_ot', label: 'DeusOT' },
    { value: 'tibia', label: 'Tibia' },
    { value: 'pegasus_ot', label: 'PegasusOT' }
  ];

  const worlds = [
    { value: 'san', label: 'San' },
    { value: 'aura', label: 'Aura' },
    { value: 'gaia', label: 'Gaia' }
  ];

  const activityFilters = [
    { value: 'active_today', label: 'Ativo Hoje' },
    { value: 'active_yesterday', label: 'Ativo Ontem' },
    { value: 'active_2days', label: 'Ativo 2 Dias' },
    { value: 'active_3days', label: 'Ativo 3 Dias' }
  ];

  const hasActiveFilters = Object.values(filters).some(value => 
    value !== '' && value !== 'all' && 
    (Array.isArray(value) ? value.length > 0 : true)
  );

  return (
    <Card className="tibia-card">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center space-x-2">
            <Filter className="h-5 w-5" />
            <span>Filtros</span>
            {hasActiveFilters && (
              <Badge variant="secondary" className="ml-2">
                {filteredCount} encontrados
              </Badge>
            )}
          </CardTitle>
          <div className="flex items-center space-x-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setExpanded(!expanded)}
            >
              {expanded ? (
                <ChevronUp className="h-4 w-4" />
              ) : (
                <ChevronDown className="h-4 w-4" />
              )}
            </Button>
            {hasActiveFilters && (
              <Button
                variant="ghost"
                size="sm"
                onClick={handleClearFilters}
                className="text-destructive hover:text-destructive"
              >
                <X className="h-4 w-4" />
              </Button>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className={expanded ? 'block' : 'hidden'}>
        <div className="space-y-6">
          {/* Filtros Básicos */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Busca */}
            <div className="space-y-2">
              <Label htmlFor="search">Buscar</Label>
              <Input
                id="search"
                placeholder="Nome do personagem"
                value={filters.search}
                onChange={(e) => handleFieldChange('search', e.target.value)}
                onKeyPress={handleKeyPress}
              />
            </div>

            {/* Servidor */}
            <div className="space-y-2">
              <Label htmlFor="server">Servidor</Label>
              <Select
                value={filters.server}
                onValueChange={(value) => handleFieldChange('server', value)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Todos os servidores" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Todos os servidores</SelectItem>
                  {servers.map((server) => (
                    <SelectItem key={server.value} value={server.value}>
                      {server.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Mundo */}
            <div className="space-y-2">
              <Label htmlFor="world">Mundo</Label>
              <Select
                value={filters.world}
                onValueChange={(value) => handleFieldChange('world', value)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Todos os mundos" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Todos os mundos</SelectItem>
                  {worlds.map((world) => (
                    <SelectItem key={world.value} value={world.value}>
                      {world.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Vocação */}
            <div className="space-y-2">
              <Label htmlFor="vocation">Vocação</Label>
              <Select
                value={filters.vocation}
                onValueChange={(value) => handleFieldChange('vocation', value)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Todas as vocações" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Todas as vocações</SelectItem>
                  {vocations.map((vocation) => (
                    <SelectItem key={vocation} value={vocation}>
                      {vocation}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Filtros Avançados */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Nível Mínimo */}
            <div className="space-y-2">
              <Label htmlFor="minLevel">Nível Mínimo</Label>
              <Input
                id="minLevel"
                type="number"
                placeholder="1"
                value={filters.minLevel}
                onChange={(e) => handleFieldChange('minLevel', e.target.value)}
                onKeyPress={handleKeyPress}
              />
            </div>

            {/* Nível Máximo */}
            <div className="space-y-2">
              <Label htmlFor="maxLevel">Nível Máximo</Label>
              <Input
                id="maxLevel"
                type="number"
                placeholder="2000"
                value={filters.maxLevel}
                onChange={(e) => handleFieldChange('maxLevel', e.target.value)}
                onKeyPress={handleKeyPress}
              />
            </div>

            {/* Guild */}
            <div className="space-y-2">
              <Label htmlFor="guild">Guild</Label>
              <Input
                id="guild"
                placeholder="Nome da guild"
                value={filters.guild}
                onChange={(e) => handleFieldChange('guild', e.target.value)}
                onKeyPress={handleKeyPress}
              />
            </div>

            {/* Favoritos */}
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
                  <SelectItem value="true">Apenas favoritos</SelectItem>
                  <SelectItem value="false">Apenas não favoritos</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Filtros de Atividade */}
          <div className="space-y-3">
            <Label>Filtros de Atividade</Label>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {activityFilters.map((activity) => (
                <div key={activity.value} className="flex items-center space-x-2">
                  <Checkbox
                    id={activity.value}
                    checked={filters.activityFilter.includes(activity.value)}
                    onCheckedChange={() => handleActivityFilterChange(activity.value)}
                  />
                  <Label htmlFor={activity.value} className="text-sm">
                    {activity.label}
                  </Label>
                </div>
              ))}
            </div>
          </div>

          {/* Recovery Active */}
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
                <SelectItem value="true">Apenas com recovery ativo</SelectItem>
                <SelectItem value="false">Apenas sem recovery ativo</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Ações */}
          <div className="flex items-center justify-between pt-4 border-t">
            <div className="flex items-center space-x-2">
              <Button
                variant="tibia"
                onClick={handleApplyFilters}
                className="min-w-[120px]"
              >
                <Filter className="mr-2 h-4 w-4" />
                Aplicar Filtros
              </Button>
              
              {onShowChart && (
                <Button
                  variant="outline"
                  onClick={onShowChart}
                  className="min-w-[120px]"
                >
                  <TrendingUp className="mr-2 h-4 w-4" />
                  Ver Gráficos
                </Button>
              )}
            </div>

            <div className="flex items-center space-x-2 text-sm text-muted-foreground">
              <Users className="h-4 w-4" />
              <span>{getFavoritesCount()} favoritos</span>
              <Globe className="h-4 w-4 ml-2" />
              <span>{filteredCount} encontrados</span>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default CharacterFilters; 