import React, { useState } from 'react';
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
} from '@mui/material';
import {
  FilterList,
  Clear,
  ExpandMore,
  ExpandLess,
} from '@mui/icons-material';

const CharacterFilters = ({ onFilterChange, onClearFilters }) => {
  const [expanded, setExpanded] = useState(false);
  const [filters, setFilters] = useState({
    server: '',
    world: '',
    vocation: '',
    search: '',
    minLevel: '',
    maxLevel: '',
    isFavorited: '',
    limit: 'all',
  });

  const handleFilterChange = (field, value) => {
    const newFilters = { ...filters, [field]: value };
    setFilters(newFilters);
    onFilterChange(newFilters);
  };

  const handleClearFilters = () => {
    const clearedFilters = {
      server: '',
      world: '',
      vocation: '',
      search: '',
      minLevel: '',
      maxLevel: '',
      isFavorited: '',
      limit: 'all',
    };
    setFilters(clearedFilters);
    onClearFilters();
  };

  const hasActiveFilters = Object.values(filters).some(value => value !== '');

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
              onChange={(e) => handleFilterChange('search', e.target.value)}
              placeholder="Digite o nome..."
            />
          </Grid>
          
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth size="small">
              <InputLabel>Servidor</InputLabel>
              <Select
                value={filters.server}
                onChange={(e) => handleFilterChange('server', e.target.value)}
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
                onChange={(e) => handleFilterChange('world', e.target.value)}
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
                onChange={(e) => handleFilterChange('vocation', e.target.value)}
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
                onChange={(e) => handleFilterChange('minLevel', e.target.value)}
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
                onChange={(e) => handleFilterChange('maxLevel', e.target.value)}
                placeholder="9999"
              />
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Favoritos</InputLabel>
                <Select
                  value={filters.isFavorited}
                  onChange={(e) => handleFilterChange('isFavorited', e.target.value)}
                  label="Favoritos"
                >
                  <MenuItem value="">Todos</MenuItem>
                  <MenuItem value="true">Apenas Favoritos</MenuItem>
                  <MenuItem value="false">Não Favoritos</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Mostrar</InputLabel>
                <Select
                  value={filters.limit}
                  onChange={(e) => handleFilterChange('limit', e.target.value)}
                  label="Mostrar"
                >
                  <MenuItem value="all">Todos</MenuItem>
                  <MenuItem value="3">3 Personagens</MenuItem>
                  <MenuItem value="30">30 Personagens</MenuItem>
                  <MenuItem value="60">60 Personagens</MenuItem>
                  <MenuItem value="90">90 Personagens</MenuItem>
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