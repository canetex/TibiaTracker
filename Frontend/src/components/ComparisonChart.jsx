import React, { useState, useEffect, useMemo } from 'react';
import {
  Box,
  Paper,
  Typography,
  IconButton,
  FormControlLabel,
  Checkbox,
  Chip,
  Grid,
  Fade,
} from '@mui/material';
import {
  Close,
  Visibility,
  VisibilityOff,
  TrendingUp,
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
  const [loading, setLoading] = useState(false);

  // Data mínima: 03/07/2024
  const MIN_DATE = new Date('2024-07-03');

  // Função para formatar experiência em milhões (KK)
  const formatExperience = (value) => {
    if (!value || isNaN(value)) return '0';
    const millions = value / 1000000;
    return `${millions.toFixed(1)}KK`;
  };

  // Função para formatar data completa
  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  };

  // Cores únicas para cada personagem
  const colors = useMemo(() => [
    '#1976d2', '#388e3c', '#fbc02d', '#d32f2f', '#7b1fa2', '#0288d1', '#c2185b', '#ffa000', '#388e3c', '#455a64',
    '#8d6e63', '#f57c00', '#0288d1', '#c2185b', '#7b1fa2', '#1976d2', '#388e3c', '#fbc02d', '#d32f2f', '#7b1fa2'
  ], []);

  useEffect(() => {
    if (!open || characters.length === 0) return;
    const fetchChartData = async () => {
      setLoading(true);
      try {
        const characterDataPromises = characters.map(async (character, index) => {
          try {
            const [levelResponse, expResponse] = await Promise.all([
              fetch(`/api/v1/characters/${character.id}/charts/level?days=30`),
              fetch(`/api/v1/characters/${character.id}/charts/experience?days=30`)
            ]);
            const levelData = await levelResponse.json();
            const expData = await expResponse.json();
            return {
              character,
              color: colors[index % colors.length],
              levelData: levelData.data || [],
              expData: expData.data || []
            };
          } catch (error) {
            console.error(`Erro ao buscar dados para ${character.name}:`, error);
            return {
              character,
              color: colors[index % colors.length],
              levelData: [],
              expData: []
            };
          }
        });
        const allCharacterData = await Promise.all(characterDataPromises);
        const combinedData = {};
        
        console.log('🔍 DEBUG - Dados recebidos para comparação:');
        console.log('MIN_DATE:', MIN_DATE);
        
        allCharacterData.forEach(({ character, color, levelData, expData }) => {
          console.log(`🔍 DEBUG - Personagem ${character.name}:`);
          console.log('Level data:', levelData);
          console.log('Exp data:', expData);
          
          // Filtrar dados de level a partir de 03/07/2024
          levelData.forEach(item => {
            const itemDate = new Date(item.date);
            console.log(`🔍 DEBUG - Level item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
            if (itemDate >= MIN_DATE) {
              const date = item.date;
              if (!combinedData[date]) {
                combinedData[date] = { date };
              }
              combinedData[date][`${character.name}_level`] = item.level;
            }
          });
          
          // Filtrar dados de experiência a partir de 03/07/2024
          expData.forEach(item => {
            const itemDate = new Date(item.date);
            console.log(`🔍 DEBUG - Exp item date: ${item.date}, parsed: ${itemDate}, >= MIN_DATE: ${itemDate >= MIN_DATE}`);
            if (itemDate >= MIN_DATE) {
              const date = item.date;
              if (!combinedData[date]) {
                combinedData[date] = { date };
              }
              combinedData[date][`${character.name}_exp`] = item.experience || item.experience_gained || 0;
            }
          });
        });
        
        const chartDataArray = Object.values(combinedData).sort((a, b) => new Date(a.date) - new Date(b.date));
        console.log('🔍 DEBUG - Dados filtrados finais para comparação:', chartDataArray);
        setChartData(chartDataArray);
      } catch (error) {
        console.error('Erro ao preparar dados do gráfico:', error);
      } finally {
        setLoading(false);
      }
    };
    fetchChartData();
  }, [open, characters, colors]);

  useEffect(() => {
    if (characters.length > 0) {
      const initialVisibility = {};
      characters.forEach(char => {
        initialVisibility[char.id] = true;
      });
      setVisibility(initialVisibility);
    }
  }, [characters]);

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

  // Função para calcular limites do gráfico com 1% de margem
  const getLevelDomain = () => {
    let min = Infinity;
    let max = -Infinity;
    chartData.forEach(row => {
      Object.keys(row).forEach(key => {
        if (key.endsWith('_level') && typeof row[key] === 'number') {
          if (row[key] < min) min = row[key];
          if (row[key] > max) max = row[key];
        }
      });
    });
    if (min === Infinity || max === -Infinity) {
      return [0, 100]; // fallback
    }
    
    // Calcular 1% de margem
    const margin = (max - min) * 0.01;
    const yMin = Math.floor(min - margin);
    const yMax = Math.ceil(max + margin);
    
    // Garantir diferença mínima
    if (yMax - yMin < 10) {
      return [yMin - 5, yMax + 5];
    }
    
    return [yMin, yMax];
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
          width: '95vw',
          height: '85vh',
          zIndex: 2000,
          p: 3,
          overflow: 'hidden',
        }}
      >
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <TrendingUp sx={{ color: 'primary.main' }} />
            <Typography variant="h4" sx={{ 
              fontSize: '2.5rem',
              fontWeight: 600,
              lineHeight: 1.2
            }}>
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
        <Box sx={{ mb: 2 }}>
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
        <Box sx={{ mb: 2 }}>
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
        <Box sx={{ height: 'calc(100% - 200px)', position: 'relative' }}>
          {loading ? (
            <Box sx={{ 
              display: 'flex', 
              justifyContent: 'center', 
              alignItems: 'center', 
              height: '100%' 
            }}>
              <Typography>Carregando dados...</Typography>
            </Box>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="date" 
                  type="category"
                  tick={{ fontSize: 12, fill: '#ffffff', fontWeight: 500 }}
                  axisLine={{ stroke: '#ffffff' }}
                  tickLine={{ stroke: '#ffffff' }}
                  angle={-45}
                  textAnchor="end"
                  height={80}
                  tickFormatter={(value) => {
                    const date = new Date(value);
                    return date.toLocaleDateString('pt-BR', {
                      day: '2-digit',
                      month: '2-digit'
                    });
                  }}
                />
                <YAxis 
                  yAxisId="level" 
                  orientation="left"
                  type="number"
                  domain={getLevelDomain()}
                  allowDataOverflow={true}
                  label={{ value: 'Level', angle: -90, position: 'insideLeft', fill: '#ffffff', fontSize: 14, fontWeight: 600 }}
                  tick={{ fontSize: 12, fill: '#ffffff', fontWeight: 500 }}
                  axisLine={{ stroke: '#ffffff' }}
                  tickLine={{ stroke: '#ffffff' }}
                  tickFormatter={(value) => value.toLocaleString('pt-BR')}
                />
                <YAxis 
                  yAxisId="experience" 
                  orientation="right"
                  label={{ value: 'Experiência', angle: 90, position: 'insideRight', fill: '#ffffff', fontSize: 14, fontWeight: 600 }}
                  tick={{ fontSize: 12, fill: '#ffffff', fontWeight: 500 }}
                  axisLine={{ stroke: '#ffffff' }}
                  tickLine={{ stroke: '#ffffff' }}
                  tickFormatter={formatExperience}
                />
                
                <RechartsTooltip 
                  content={({ active, payload, label }) => {
                    if (active && payload && payload.length) {
                      return (
                        <Box sx={{ 
                          bgcolor: 'background.paper', 
                          border: 1, 
                          borderColor: 'divider', 
                          borderRadius: 1, 
                          p: 2,
                          boxShadow: 3
                        }}>
                          <Typography variant="subtitle2" gutterBottom sx={{ fontWeight: 600 }}>
                            {formatDate(label)}
                          </Typography>
                          {payload.map((entry, index) => {
                            const isExperience = entry.name.includes('Experiência');
                            const displayValue = isExperience 
                              ? formatExperience(entry.value)
                              : entry.value?.toLocaleString('pt-BR');
                            
                            return (
                              <Typography key={index} variant="body2" sx={{ 
                                color: entry.color,
                                display: 'flex',
                                justifyContent: 'space-between',
                                gap: 2
                              }}>
                                <span>{entry.name}:</span>
                                <span style={{ fontWeight: 600 }}>
                                  {displayValue}
                                </span>
                              </Typography>
                            );
                          })}
                        </Box>
                      );
                    }
                    return null;
                  }}
                />
                
                <Legend />
                
                {/* Level Lines (sólidas) */}
                {showLevel && characters.map((character) => {
                  const color = getCharacterColor(character.id);
                  const dataKey = `${character.name}_level`;
                  
                  return (
                    <Line
                      key={`level-${character.id}`}
                      type="monotone"
                      dataKey={dataKey}
                      yAxisId="level"
                      stroke={color}
                      strokeWidth={3}
                      dot={{ fill: color, strokeWidth: 2, r: 4 }}
                      activeDot={{ r: 6 }}
                      name={`${character.name} - Level`}
                      hide={!visibility[character.id]}
                    />
                  );
                })}
                
                {/* Experience Lines (tracejadas) */}
                {showExperience && characters.map((character) => {
                  const color = getCharacterColor(character.id);
                  const dataKey = `${character.name}_exp`;
                  
                  return (
                    <Line
                      key={`exp-${character.id}`}
                      type="monotone"
                      dataKey={dataKey}
                      yAxisId="experience"
                      stroke={color}
                      strokeWidth={2}
                      strokeDasharray="5 5"
                      dot={{ fill: color, strokeWidth: 2, r: 3 }}
                      activeDot={{ r: 5 }}
                      name={`${character.name} - Experiência`}
                      hide={!visibility[character.id]}
                    />
                  );
                })}
              </LineChart>
            </ResponsiveContainer>
          )}
        </Box>

        {/* Legend */}
        <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
          <Typography variant="subtitle2" gutterBottom>
            Legenda:
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 20, height: 3, bgcolor: 'grey.600' }} />
              <Typography variant="body2">Linha sólida = Level</Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 20, height: 2, bgcolor: 'grey.600', borderTop: '2px dashed grey.600' }} />
              <Typography variant="body2">Linha tracejada = Experiência</Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="body2" color="text.secondary">
                Dados a partir de 03/07/2024
              </Typography>
            </Box>
          </Box>
        </Box>
      </Paper>
    </Fade>
  );
};

export default ComparisonChart; 