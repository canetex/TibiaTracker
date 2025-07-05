import React, { useState } from 'react';
import {
  Box,
  TextField,
  Button,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  CircularProgress,
} from '@mui/material';
import { Search as SearchIcon } from '@mui/icons-material';

const CharacterSearch = ({ onSearch, loading = false }) => {
  const [formData, setFormData] = useState({
    name: '',
    server: 'taleon',
    world: 'san',
  });

  const [errors, setErrors] = useState({});

  // Configuração dos servidores e mundos
  const serverConfig = {
    taleon: {
      label: 'Taleon',
      worlds: [
        { value: 'san', label: 'San' },
        { value: 'aura', label: 'Aura' },
        { value: 'gaia', label: 'Gaia' },
      ],
    },
    // Adicionar outros servidores no futuro
    rubini: {
      label: 'Rubini',
      worlds: [],
      disabled: true,
    },
    deus_ot: {
      label: 'DeusOT',
      worlds: [],
      disabled: true,
    },
    tibia: {
      label: 'Tibia',
      worlds: [],
      disabled: true,
    },
    pegasus_ot: {
      label: 'PegasusOT',
      worlds: [],
      disabled: true,
    },
  };

  const handleInputChange = (field) => (event) => {
    const value = event.target.value;
    
    setFormData(prev => {
      const newData = { ...prev, [field]: value };
      
      // Se mudou o servidor, resetar o mundo para o primeiro disponível
      if (field === 'server') {
        const worlds = serverConfig[value]?.worlds || [];
        newData.world = worlds.length > 0 ? worlds[0].value : '';
      }
      
      return newData;
    });

    // Limpar erro do campo
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: null }));
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Nome do personagem é obrigatório';
    } else if (formData.name.trim().length < 2) {
      newErrors.name = 'Nome deve ter pelo menos 2 caracteres';
    }

    if (!formData.server) {
      newErrors.server = 'Selecione um servidor';
    }

    if (!formData.world) {
      newErrors.world = 'Selecione um mundo';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    
    if (validateForm() && !loading) {
      onSearch({
        name: formData.name.trim(),
        server: formData.server,
        world: formData.world,
      });
    }
  };

  const handleKeyPress = (event) => {
    if (event.key === 'Enter') {
      handleSubmit(event);
    }
  };

  const currentServer = serverConfig[formData.server];
  const availableWorlds = currentServer?.worlds || [];

  return (
    <Box component="form" onSubmit={handleSubmit}>
      <Grid container spacing={3} alignItems="start">
        {/* Nome do Personagem */}
        <Grid item xs={12} md={4}>
          <TextField
            fullWidth
            label="Nome do Personagem"
            value={formData.name}
            onChange={handleInputChange('name')}
            onKeyPress={handleKeyPress}
            error={!!errors.name}
            helperText={errors.name}
            placeholder="Ex: Gates, Galado, Wild Warior"
            disabled={loading}
            autoComplete="off"
          />
        </Grid>

        {/* Servidor */}
        <Grid item xs={12} md={3}>
          <FormControl fullWidth error={!!errors.server}>
            <InputLabel>Servidor</InputLabel>
            <Select
              value={formData.server}
              onChange={handleInputChange('server')}
              label="Servidor"
              disabled={loading}
            >
              {Object.entries(serverConfig).map(([key, config]) => (
                <MenuItem 
                  key={key} 
                  value={key}
                  disabled={config.disabled}
                >
                  {config.label}
                  {config.disabled && ' (Em breve)'}
                </MenuItem>
              ))}
            </Select>
            {errors.server && (
              <Box sx={{ mt: 0.5, fontSize: '0.75rem', color: 'error.main' }}>
                {errors.server}
              </Box>
            )}
          </FormControl>
        </Grid>

        {/* Mundo */}
        <Grid item xs={12} md={3}>
          <FormControl fullWidth error={!!errors.world}>
            <InputLabel>Mundo</InputLabel>
            <Select
              value={formData.world}
              onChange={handleInputChange('world')}
              label="Mundo"
              disabled={loading || availableWorlds.length === 0}
            >
              {availableWorlds.map((world) => (
                <MenuItem key={world.value} value={world.value}>
                  {world.label}
                </MenuItem>
              ))}
            </Select>
            {errors.world && (
              <Box sx={{ mt: 0.5, fontSize: '0.75rem', color: 'error.main' }}>
                {errors.world}
              </Box>
            )}
          </FormControl>
        </Grid>

        {/* Botão de Busca */}
        <Grid item xs={12} md={2}>
          <Button
            type="submit"
            variant="contained"
            fullWidth
            size="large"
            startIcon={loading ? <CircularProgress size={20} color="inherit" /> : <SearchIcon />}
            disabled={loading}
            sx={{ height: 56 }} // Mesma altura dos outros campos
          >
            {loading ? 'Processando...' : 'Buscar/Adicionar'}
          </Button>
        </Grid>
      </Grid>

      {/* Dica para o usuário */}
      <Box sx={{ mt: 2, fontSize: '0.875rem', color: 'text.secondary' }}>
        💡 <strong>Dica:</strong> O botão "Buscar/Adicionar" primeiro verifica se o personagem já existe. 
        Se existir, mostra como filtro. Se não existir, adiciona automaticamente!
      </Box>
    </Box>
  );
};

export default CharacterSearch; 