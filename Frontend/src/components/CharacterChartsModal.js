import React, { useState, useEffect } from 'react';
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
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  TimeScale,
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import 'chartjs-adapter-date-fns';
import { ptBR } from 'date-fns/locale';

import { apiService } from '../services/api';

// Registrar componentes do Chart.js (fora do componente)
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
);

const CharacterChartsModal = ({ open, onClose, character }) => {
  const [loading, setLoading] = useState(false);
  const [chartData, setChartData] = useState(null);
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

  useEffect(() => {
    if (open && character?.id) {
      loadChartData();
    } else if (!open) {
      // Cleanup quando modal é fechado
      setChartData(null);
      setError(null);
      setLoading(false);
    }
  }, [open, character, timeRange]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      setChartData(null);
      setError(null);
      setLoading(false);
    };
  }, []);

  const loadChartData = async () => {
    if (!character?.id) {
      console.log('CharacterChartsModal: Nenhum personagem ou ID fornecido');
      setError('Erro: ID do personagem não encontrado');
      return;
    }
    
    console.log('CharacterChartsModal: Carregando dados para personagem:', character);
    
    try {
      setLoading(true);
      setError(null);

      console.log('CharacterChartsModal: Fazendo requisições para API...');
      const [experienceData, levelData] = await Promise.all([
        apiService.getCharacterExperienceChart(character.id, timeRange),
        apiService.getCharacterLevelChart(character.id, timeRange)
      ]);

      console.log('CharacterChartsModal: Dados recebidos:', { experienceData, levelData });
      
      setChartData({
        experience: experienceData,
        level: levelData,
      });

    } catch (err) {
      console.error('CharacterChartsModal: Erro ao carregar dados dos gráficos:', err);
      setError(`Erro ao carregar dados dos gráficos: ${err.message}`);
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

  const getChartConfig = () => {
    if (!chartData) return null;

    const datasets = [];
    const colors = [
      'rgb(53, 162, 235)', // Azul
      'rgb(255, 99, 132)', // Vermelho  
      'rgb(75, 192, 192)', // Verde
      'rgb(255, 159, 64)', // Laranja
      'rgb(153, 102, 255)', // Roxo
      'rgb(255, 206, 86)', // Amarelo
    ];
    let colorIndex = 0;

    if (chartOptions.experience && chartData.experience?.data) {
      datasets.push({
        label: 'Experiência',
        data: chartData.experience.data.map(item => ({
          x: item.date, // Usar a data diretamente como string
          y: item.experience_gained || item.experience || 0
        })),
        borderColor: colors[colorIndex++],
        backgroundColor: colors[colorIndex - 1] + '20',
        tension: 0.1,
        yAxisID: 'y',
      });
    }

    if (chartOptions.level && chartData.level?.data) {
      datasets.push({
        label: 'Level',
        data: chartData.level.data.map(item => ({
          x: item.date, // Usar a data diretamente como string
          y: item.level
        })),
        borderColor: colors[colorIndex++],
        backgroundColor: colors[colorIndex - 1] + '20',
        tension: 0.1,
        yAxisID: 'y1',
      });
    }

    return {
      datasets,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          title: {
            display: true,
            text: `Evolução de ${character?.name || 'Personagem'} (${timeRange} dias)`,
            font: {
              size: 16,
              weight: 'bold'
            }
          },
          legend: {
            position: 'top',
          },
          tooltip: {
            callbacks: {
              title: function(context) {
                // Converter string para data e formatar
                const dateStr = context[0].label;
                try {
                  return new Date(dateStr).toLocaleDateString('pt-BR', {
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric'
                  });
                } catch {
                  return dateStr;
                }
              },
              label: function(context) {
                let label = context.dataset.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.dataset.label === 'Experiência') {
                  label += context.parsed.y.toLocaleString('pt-BR');
                } else {
                  label += context.parsed.y;
                }
                return label;
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              parser: 'YYYY-MM-DD',
              unit: 'day',
              displayFormats: {
                day: 'DD/MM'
              }
            },
            title: {
              display: true,
              text: 'Data'
            },
            adapters: {
              date: {
                locale: ptBR
              }
            }
          },
          y: {
            type: 'linear',
            display: chartOptions.experience,
            position: 'left',
            title: {
              display: true,
              text: 'Experiência'
            },
            ticks: {
              callback: function(value) {
                return value.toLocaleString('pt-BR');
              }
            }
          },
          y1: {
            type: 'linear',
            display: chartOptions.level,
            position: 'right',
            title: {
              display: true,
              text: 'Level'
            },
            grid: {
              drawOnChartArea: false,
            },
          },
        },
      }
    };
  };

  const chartConfig = getChartConfig();
  const hasData = chartData && chartConfig && chartConfig.datasets.length > 0;

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
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={chartOptions.deaths}
                        onChange={() => handleOptionChange('deaths')}
                        color="primary"
                        disabled
                      />
                    }
                    label="Mortes (em breve)"
                  />
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={chartOptions.charmPoints}
                        onChange={() => handleOptionChange('charmPoints')}
                        color="primary"
                        disabled
                      />
                    }
                    label="Charm Points (em breve)"
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
              <Box sx={{ height: '500px', position: 'relative' }}>
                <Line data={chartConfig} options={chartConfig.options} />
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

        {/* Estatísticas Resumidas */}
        {chartData && (
          <Card sx={{ mt: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Estatísticas do Período
              </Typography>
              <Grid container spacing={3}>
                {chartData.experience?.summary && (
                  <Grid item xs={12} md={4}>
                    <Box>
                      <Typography variant="body2" color="text.secondary">
                        Experiência Total Ganha
                      </Typography>
                      <Typography variant="h6">
                        {chartData.experience.summary.total_gained?.toLocaleString('pt-BR') || 'N/A'}
                      </Typography>
                    </Box>
                  </Grid>
                )}
                {chartData.level?.summary && (
                  <Grid item xs={12} md={4}>
                    <Box>
                      <Typography variant="body2" color="text.secondary">
                        Levels Ganhos
                      </Typography>
                      <Typography variant="h6">
                        {chartData.level.summary.levels_gained || 0}
                      </Typography>
                    </Box>
                  </Grid>
                )}
                <Grid item xs={12} md={4}>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      Dados Coletados
                    </Typography>
                    <Typography variant="h6">
                      {chartData.experience?.data?.length || 0} snapshots
                    </Typography>
                  </Box>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        )}
      </DialogContent>

      <DialogActions sx={{ p: 3 }}>
        <Button onClick={loadChartData} disabled={loading}>
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