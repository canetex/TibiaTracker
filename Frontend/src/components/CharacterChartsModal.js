import React, { useState, useEffect, useCallback } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  FormControlLabel,
  Checkbox,
  FormGroup,
  Grid,
  Card,
  CardContent,
  Alert,
  CircularProgress,
  Divider,
  Chip,
} from '@mui/material';
import {
  Close as CloseIcon,
  TrendingUp,
  Analytics,
  Timeline,
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

import { apiService } from '../services/api';

const CharacterChartsModal = ({ open, onClose, character }) => {
  const [loading, setLoading] = useState(false);
  const [chartData, setChartData] = useState([]);
  const [error, setError] = useState(null);
  
  // Controles de visualização
  const [chartOptions, setChartOptions] = useState({
    experience: true,
    level: true,
    deaths: false,
    charmPoints: false,
    bossTierPoints: false,
    achievementPoints: false,
  });
  
  const [timeRange, setTimeRange] = useState(30); // días

  const loadChartData = useCallback(async () => {
    if (!character?.id) {
      setError('Erro: ID do personagem não encontrado');
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const [experienceData, levelData] = await Promise.all([
        apiService.getCharacterExperienceChart(character.id, timeRange),
        apiService.getCharacterLevelChart(character.id, timeRange)
      ]);
      const combinedData = {};
      if (experienceData?.data) {
        experienceData.data.forEach(item => {
          const date = item.date;
          if (!combinedData[date]) {
            combinedData[date] = { date };
          }
          combinedData[date].experience = item.experience_gained || item.experience || 0;
        });
      }
      if (levelData?.data) {
        levelData.data.forEach(item => {
          const date = item.date;
          if (!combinedData[date]) {
            combinedData[date] = { date };
          }
          combinedData[date].level = item.level;
        });
      }
      const chartDataArray = Object.values(combinedData).sort((a, b) => new Date(a.date) - new Date(b.date));
      setChartData(chartDataArray);
    } catch (err) {
      setError(`Erro ao carregar dados dos gráficos: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [character, timeRange]);

  useEffect(() => {
    loadChartData();
  }, [loadChartData]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      setChartData([]);
      setError(null);
      setLoading(false);
    };
  }, []);

  const refreshCharacterData = async () => {
    if (!character?.id) {
      setError('Erro: ID do personagem não encontrado');
      return;
    }
    
    try {
      setLoading(true);
      setError(null);

      console.log('CharacterChartsModal: Fazendo novo scraping...');
      
      // Fazer novo scraping
      await apiService.refreshCharacter(character.id);
      
      // Recarregar dados dos gráficos após scraping
      await loadChartData();

    } catch (err) {
      console.error('CharacterChartsModal: Erro ao atualizar dados:', err);
      setError(`Erro ao atualizar dados: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleOptionChange = (option) => {
    setChartOptions(prev => ({
      ...prev,
      [option]: !prev[option]
    }));
  };

  const hasData = chartData.length > 0 && (chartOptions.experience || chartOptions.level);

  const roundDown100 = (value) => Math.floor(value / 100) * 100;
  const roundUp100 = (value) => Math.ceil(value / 100) * 100;
  const getLevelDomain = () => {
    let min = Infinity;
    let max = -Infinity;
    chartData.forEach(row => {
      if (typeof row.level === 'number') {
        if (row.level < min) min = row.level;
        if (row.level > max) max = row.level;
      }
    });
    if (min === Infinity || max === -Infinity) {
      return [0, 100]; // fallback
    }
    let yMin = roundDown100(min * 0.9);
    let yMax = roundUp100(max * 1.05);
    if (yMax - yMin < 100) {
      yMax = yMin + 100;
    }
    return [yMin, yMax];
  };

  return (
    <Dialog 
      open={open} 
      onClose={onClose}
      maxWidth="xl"
      fullWidth
      PaperProps={{
        sx: { height: '90vh' }
      }}
    >
      <DialogTitle sx={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center',
        pb: 2
      }}>
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          {/* Imagem do outfit */}
          {character?.outfit_image_url && (
            <img
              src={character.outfit_image_url}
              alt={`Outfit de ${character.name}`}
              className="outfitImg"
              style={{ marginRight: 8 }}
            />
          )}
          <Analytics sx={{ mr: 1, color: 'primary.main' }} />
          <Typography variant="h6">
            Gráficos - {character?.name}
          </Typography>
        </Box>
        <Button onClick={onClose} color="inherit">
          <CloseIcon />
        </Button>
      </DialogTitle>

      <DialogContent sx={{ p: 3 }}>
        {/* Controles */}
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
              <Timeline sx={{ mr: 1 }} />
              Controles de Visualização
            </Typography>
            
            <Grid container spacing={3}>
              {/* Período */}
              <Grid item xs={12} md={3}>
                <Typography variant="subtitle2" gutterBottom>
                  Período
                </Typography>
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                  {[7, 15, 30, 60, 90].map(days => (
                    <Chip
                      key={days}
                      label={`${days} dias`}
                      onClick={() => setTimeRange(days)}
                      color={timeRange === days ? 'primary' : 'default'}
                      variant={timeRange === days ? 'filled' : 'outlined'}
                      size="small"
                    />
                  ))}
                </Box>
              </Grid>

              {/* Métricas */}
              <Grid item xs={12} md={9}>
                <Typography variant="subtitle2" gutterBottom>
                  Métricas para Exibir
                </Typography>
                <FormGroup row>
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={chartOptions.experience}
                        onChange={() => handleOptionChange('experience')}
                        color="primary"
                      />
                    }
                    label="Experiência"
                  />
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={chartOptions.level}
                        onChange={() => handleOptionChange('level')}
                        color="primary"
                      />
                    }
                    label="Level"
                  />

                </FormGroup>
              </Grid>
            </Grid>
          </CardContent>
        </Card>

        <Divider sx={{ my: 2 }} />

        {/* Gráfico */}
        <Card>
          <CardContent>
            {loading ? (
              <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
                <CircularProgress />
              </Box>
            ) : error ? (
              <Alert severity="error" sx={{ my: 2 }}>
                {error}
              </Alert>
            ) : hasData ? (
              <Box sx={{ height: '500px', width: '100%' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis 
                      dataKey="date" 
                      tickFormatter={(value) => {
                        const date = new Date(value);
                        return date.toLocaleDateString('pt-BR', {
                          day: '2-digit',
                          month: '2-digit'
                        });
                      }}
                    />
                    {/* Renderização condicional dos eixos Y */}
                    {chartOptions.experience && chartOptions.level && (
                      <>
                        <YAxis 
                          yAxisId="left"
                          orientation="left"
                          tickFormatter={(value) => value.toLocaleString('pt-BR')}
                        />
                        <YAxis 
                          yAxisId="right"
                          orientation="right"
                          type="number"
                          domain={getLevelDomain()}
                          allowDataOverflow={true}
                        />
                      </>
                    )}
                    {chartOptions.level && !chartOptions.experience && (
                      <YAxis 
                        yAxisId="right"
                        orientation="right"
                        type="number"
                        domain={getLevelDomain()}
                        allowDataOverflow={true}
                      />
                    )}
                    {chartOptions.experience && !chartOptions.level && (
                      <YAxis 
                        yAxisId="left"
                        orientation="left"
                        tickFormatter={(value) => value.toLocaleString('pt-BR')}
                      />
                    )}
                    <RechartsTooltip
                      formatter={(value, name) => [
                        !isNaN(value) ? value.toLocaleString('pt-BR') : value,
                        name
                      ]}
                      labelFormatter={(label) => {
                        const date = new Date(label);
                        return date.toLocaleDateString('pt-BR', {
                          day: '2-digit',
                          month: '2-digit',
                          year: 'numeric'
                        });
                      }}
                    />
                    <Legend />
                    {chartOptions.experience && (
                      <Line
                        type="monotone"
                        dataKey="experience"
                        stroke="#1976d2"
                        strokeWidth={2}
                        dot={{ fill: '#1976d2', strokeWidth: 2, r: 4 }}
                        activeDot={{ r: 6 }}
                        yAxisId="left"
                        name="Experiência"
                      />
                    )}
                    {chartOptions.level && (
                      <Line
                        type="monotone"
                        dataKey="level"
                        stroke="#dc004e"
                        strokeWidth={2}
                        strokeDasharray="5 5"
                        dot={{ fill: '#dc004e', strokeWidth: 2, r: 4 }}
                        activeDot={{ r: 6 }}
                        yAxisId="right"
                        name="Level"
                      />
                    )}
                  </LineChart>
                </ResponsiveContainer>
              </Box>
            ) : (
              <Box sx={{ textAlign: 'center', py: 8 }}>
                <TrendingUp sx={{ fontSize: 64, color: 'grey.300', mb: 2 }} />
                <Typography variant="h6" color="text.secondary">
                  Nenhum dado disponível
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Selecione pelo menos uma métrica ou tente um período diferente
                </Typography>
              </Box>
            )}
          </CardContent>
        </Card>
      </DialogContent>

      <DialogActions sx={{ p: 3 }}>
        <Button onClick={refreshCharacterData} disabled={loading}>
          Atualizar Dados
        </Button>
        <Button onClick={onClose} variant="contained">
          Fechar
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default CharacterChartsModal; 