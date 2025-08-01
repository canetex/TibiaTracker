import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  Button,
  Chip,
  Grid,
  IconButton,
  Collapse,
  Divider,
  OutlinedInput,
  Checkbox,
  ListItemText,
} from '@mui/material';
import {
  FilterList,
  Clear,
  ExpandMore,
  ExpandLess,
  TrendingUp,
  Star,
} from '@mui/icons-material';
import { useFavorites } from '../contexts/FavoritesContext';

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
    recoveryActive: '', // Novo filtro para recovery
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
      recoveryActive: externalFilters.recoveryActive || '', // Sincroniza o novo filtro
      limit: externalFilters.limit || 'all',
    });
  }, [externalFilters]);

  const handleFieldChange = (field, value) => {
    const newFilters = { ...filters, [field]: value };
    setFilters(newFilters);
    
    // Removido: aplicação automática do filtro de favoritos
    // Agora todos os filtros são aplicados apenas ao clicar no botão "Filtrar"
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
      recoveryActive: '', // Limpa o novo filtro
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
    <Card sx={{ mb: 3 }}>
      <CardContent>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            <FilterList sx={{ mr: 1, color: 'primary.main' }} />
            <Typography variant="h6" component="h3" sx={{ fontWeight: 600 }}>
              Filtros
            </Typography>
            {hasActiveFilters && (
              <Chip 
                label="Ativo" 
                size="small" 
                color="primary" 
                sx={{ ml: 1 }}
              />
            )}
          </Box>
          
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button
              size="small"
              startIcon={<FilterList />}
              onClick={handleApplyFilters}
              variant="contained"
              color="primary"
            >
              Filtrar
            </Button>
            
            {filteredCount > 0 && (
              <Button
                size="small"
                startIcon={<TrendingUp />}
                onClick={onShowChart}
                variant="outlined"
                color="secondary"
              >
                Gráfico ({filteredCount})
              </Button>
            )}
            
            {hasActiveFilters && (
              <Button
                size="small"
                startIcon={<Clear />}
                onClick={handleClearFilters}
                variant="outlined"
              >
                Limpar
              </Button>
            )}
            <IconButton
              size="small"
              onClick={() => setExpanded(!expanded)}
            >
              {expanded ? <ExpandLess /> : <ExpandMore />}
            </IconButton>
          </Box>
        </Box>

        {/* Filtros Básicos (sempre visíveis) */}
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              fullWidth
              size="small"
              label="Buscar por nome"
              value={filters.search}
              onChange={(e) => handleFieldChange('search', e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Digite o nome..."
            />
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth size="small">
              <InputLabel>Servidor</InputLabel>
              <Select
                value={filters.server}
                onChange={(e) => handleFieldChange('server', e.target.value)}
                onKeyPress={handleKeyPress}
                label="Servidor"
              >
                <MenuItem value="">Todos</MenuItem>
                {servers.map((server) => (
                  <MenuItem key={server.value} value={server.value}>
                    {server.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth size="small">
              <InputLabel>Mundo</InputLabel>
              <Select
                value={filters.world}
                onChange={(e) => handleFieldChange('world', e.target.value)}
                onKeyPress={handleKeyPress}
                label="Mundo"
              >
                <MenuItem value="">Todos</MenuItem>
                {worlds.map((world) => (
                  <MenuItem key={world.value} value={world.value}>
                    {world.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth size="small">
              <InputLabel>Vocação</InputLabel>
              <Select
                value={filters.vocation}
                onChange={(e) => handleFieldChange('vocation', e.target.value)}
                onKeyPress={handleKeyPress}
                label="Vocação"
              >
                <MenuItem value="">Todas</MenuItem>
                {vocations.map((vocation) => (
                  <MenuItem key={vocation} value={vocation}>
                    {vocation}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              fullWidth
              size="small"
              label="Guild"
              value={filters.guild}
              onChange={(e) => handleFieldChange('guild', e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Digite o nome da guild..."
            />
          </Grid>
        </Grid>

        {/* Filtros Avançados (colapsáveis) */}
        <Collapse in={expanded}>
          <Divider sx={{ my: 2 }} />
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Filtros Avançados
          </Typography>
          
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                label="Level Mínimo"
                type="number"
                value={filters.minLevel}
                onChange={(e) => handleFieldChange('minLevel', e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder="0"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                label="Level Máximo"
                type="number"
                value={filters.maxLevel}
                onChange={(e) => handleFieldChange('maxLevel', e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder="9999"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Favoritos</InputLabel>
                <Select
                  value={filters.isFavorited}
                  onChange={(e) => handleFieldChange('isFavorited', e.target.value)}
                  onKeyPress={handleKeyPress}
                  label="Favoritos"
                  startAdornment={
                    <Star sx={{ mr: 1, color: 'action.active' }} />
                  }
                >
                  <MenuItem value="">Todos</MenuItem>
                  <MenuItem value="true">
                    Apenas Favoritos ({getFavoritesCount()})
                  </MenuItem>
                  <MenuItem value="false">Não Favoritos</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Atividade</InputLabel>
                <Select
                  multiple
                  value={filters.activityFilter}
                  onChange={(e) => handleFieldChange('activityFilter', e.target.value)}
                  onKeyPress={handleKeyPress}
                  input={<OutlinedInput label="Atividade" />}
                  renderValue={(selected) => (
                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                      {selected.map((value) => {
                        const filter = activityFilters.find(f => f.value === value);
                        return (
                          <Chip key={value} label={filter?.label || value} size="small" />
                        );
                      })}
                    </Box>
                  )}
                >
                  {activityFilters.map((filter) => (
                    <MenuItem key={filter.value} value={filter.value}>
                      <Checkbox checked={filters.activityFilter.indexOf(filter.value) > -1} />
                      <ListItemText primary={filter.label} />
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Recovery Ativo</InputLabel>
                <Select
                  value={filters.recoveryActive}
                  onChange={(e) => handleFieldChange('recoveryActive', e.target.value)}
                  onKeyPress={handleKeyPress}
                  label="Recovery Ativo"
                >
                  <MenuItem value="">Todos</MenuItem>
                  <MenuItem value="true">
                    Apenas Recovery Ativo
                  </MenuItem>
                  <MenuItem value="false">Não Recovery Ativo</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Mostrar</InputLabel>
                <Select
                  value={filters.limit}
                  onChange={(e) => handleFieldChange('limit', e.target.value)}
                  onKeyPress={handleKeyPress}
                  label="Mostrar"
                >
                  <MenuItem value="all">Todos</MenuItem>
                  <MenuItem value="3">3 Personagens</MenuItem>
                  <MenuItem value="10">10 Personagens</MenuItem>
                  <MenuItem value="30">30 Personagens</MenuItem>
                  <MenuItem value="60">60 Personagens</MenuItem>
                  <MenuItem value="90">90 Personagens</MenuItem>
                  <MenuItem value="150">150 Personagens</MenuItem>
                </Select>
              </FormControl>
            </Grid>
          </Grid>
        </Collapse>
      </CardContent>
    </Card>
  );
};

export default CharacterFilters; 