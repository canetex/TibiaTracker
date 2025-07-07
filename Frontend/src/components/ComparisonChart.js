import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Typography,
  IconButton,
  Button,
  FormControlLabel,
  Checkbox,
  Chip,
  Grid,
  Tooltip,
  Fade,
} from '@mui/material';
import {
  Close,
  Visibility,
  VisibilityOff,
  TrendingUp,
  TrendingDown,
} from '@mui/icons-material';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

const ComparisonChart = ({ 
  characters = [], 
  onClose, 
  open = false 
}) => {
  const [visibility, setVisibility] = useState({});
  const [showLevel, setShowLevel] = useState(true);
  const [showExperience, setShowExperience] = useState(true);
  const [chartData, setChartData] = useState([]);

  // Cores únicas para cada personagem
  const colors = [
    '#1976d2', '#dc004e', '#2e7d32', '#ed6c02', '#9c27b0',
    '#d32f2f', '#388e3c', '#f57c00', '#7b1fa2', '#c62828'
  ];

  useEffect(() => {
    if (characters.length > 0) {
      // Inicializar visibilidade para todos os personagens
      const initialVisibility = {};
      characters.forEach(char => {
        initialVisibility[char.id] = true;
      });
      setVisibility(initialVisibility);
      
      // Preparar dados do gráfico
      prepareChartData();
    }
  }, [characters]);

  const prepareChartData = () => {
    // Aqui você pode implementar a lógica para buscar dados históricos
    // Por enquanto, vamos usar dados simulados
    const data = characters.map((char, index) => ({
      name: char.name,
      level: char.level || 0,
      experience: char.latest_snapshot?.experience || 0,
      color: colors[index % colors.length],
      character: char,
    }));
    
    setChartData(data);
  };

  const handleToggleCharacter = (characterId) => {
    setVisibility(prev => ({
      ...prev,
      [characterId]: !prev[characterId]
    }));
  };

  const handleToggleAllLevels = () => {
    setShowLevel(!showLevel);
  };

  const handleToggleAllExperience = () => {
    setShowExperience(!showExperience);
  };

  const getCharacterColor = (characterId) => {
    const index = characters.findIndex(char => char.id === characterId);
    return colors[index % colors.length];
  };

  if (!open || characters.length === 0) {
    return null;
  }

  return (
    <Fade in={open}>
      <Paper
        elevation={24}
        sx={{
          position: 'fixed',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '90vw',
          maxWidth: 1200,
          height: '80vh',
          zIndex: 2000,
          p: 3,
          overflow: 'hidden',
        }}
      >
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <TrendingUp sx={{ color: 'primary.main' }} />
            <Typography variant="h5" sx={{ fontWeight: 600 }}>
              Comparação de Personagens
            </Typography>
            <Chip 
              label={`${characters.length} personagens`}
              size="small"
              color="primary"
            />
          </Box>
          
          <IconButton onClick={onClose} size="large">
            <Close />
          </IconButton>
        </Box>

        {/* Controls */}
        <Box sx={{ mb: 3 }}>
          <Grid container spacing={2} alignItems="center">
            <Grid item>
              <Typography variant="subtitle2" color="text.secondary">
                Controles Globais:
              </Typography>
            </Grid>
            
            <Grid item>
              <FormControlLabel
                control={
                  <Checkbox
                    checked={showLevel}
                    onChange={handleToggleAllLevels}
                    icon={<VisibilityOff />}
                    checkedIcon={<Visibility />}
                  />
                }
                label="Mostrar Levels"
              />
            </Grid>
            
            <Grid item>
              <FormControlLabel
                control={
                  <Checkbox
                    checked={showExperience}
                    onChange={handleToggleAllExperience}
                    icon={<VisibilityOff />}
                    checkedIcon={<Visibility />}
                  />
                }
                label="Mostrar Experiência"
              />
            </Grid>
          </Grid>
        </Box>

        {/* Character Controls */}
        <Box sx={{ mb: 3 }}>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Visibilidade por Personagem:
          </Typography>
          <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
            {characters.map((character) => (
              <Chip
                key={character.id}
                label={character.name}
                onClick={() => handleToggleCharacter(character.id)}
                onDelete={() => handleToggleCharacter(character.id)}
                deleteIcon={visibility[character.id] ? <Visibility /> : <VisibilityOff />}
                variant={visibility[character.id] ? 'filled' : 'outlined'}
                sx={{
                  bgcolor: visibility[character.id] ? getCharacterColor(character.id) : 'transparent',
                  color: visibility[character.id] ? 'white' : 'text.primary',
                  borderColor: getCharacterColor(character.id),
                  '&:hover': {
                    bgcolor: visibility[character.id] ? getCharacterColor(character.id) : 'grey.100',
                  }
                }}
              />
            ))}
          </Box>
        </Box>

        {/* Chart */}
        <Box sx={{ height: 'calc(100% - 200px)', minHeight: 400 }}>
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="name" 
                angle={-45}
                textAnchor="end"
                height={80}
                tick={{ fontSize: 12 }}
              />
              <YAxis yAxisId="level" />
              <YAxis yAxisId="experience" orientation="right" />
              
              <RechartsTooltip 
                content={({ active, payload, label }) => {
                  if (active && payload && payload.length) {
                    return (
                      <Paper sx={{ p: 2, bgcolor: 'background.paper' }}>
                        <Typography variant="subtitle2" gutterBottom>
                          {label}
                        </Typography>
                        {payload.map((entry, index) => (
                          <Typography key={index} variant="body2" sx={{ color: entry.color }}>
                            {entry.name}: {entry.value?.toLocaleString('pt-BR')}
                          </Typography>
                        ))}
                      </Paper>
                    );
                  }
                  return null;
                }}
              />
              
              <Legend />
              
              {/* Level Lines */}
              {showLevel && characters.map((character, index) => (
                <Line
                  key={`level-${character.id}`}
                  type="monotone"
                  dataKey="level"
                  yAxisId="level"
                  stroke={getCharacterColor(character.id)}
                  strokeWidth={3}
                  dot={{ fill: getCharacterColor(character.id), strokeWidth: 2, r: 4 }}
                  activeDot={{ r: 6 }}
                  name={`${character.name} - Level`}
                  hide={!visibility[character.id]}
                />
              ))}
              
              {/* Experience Lines */}
              {showExperience && characters.map((character, index) => (
                <Line
                  key={`exp-${character.id}`}
                  type="monotone"
                  dataKey="experience"
                  yAxisId="experience"
                  stroke={getCharacterColor(character.id)}
                  strokeWidth={2}
                  strokeDasharray="5 5"
                  dot={{ fill: getCharacterColor(character.id), strokeWidth: 2, r: 3 }}
                  activeDot={{ r: 5 }}
                  name={`${character.name} - Experiência`}
                  hide={!visibility[character.id]}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </Box>

        {/* Legend */}
        <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
          <Typography variant="body2" color="text.secondary" gutterBottom>
            Legenda:
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 20, height: 3, bgcolor: 'black' }} />
              <Typography variant="body2">Level (linha sólida)</Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 20, height: 3, bgcolor: 'black', borderTop: '2px dashed black' }} />
              <Typography variant="body2">Experiência (linha tracejada)</Typography>
            </Box>
          </Box>
        </Box>
      </Paper>
    </Fade>
  );
};

export default ComparisonChart; 