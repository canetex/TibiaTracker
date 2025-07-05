import React, { useState } from 'react';
import {
  Card,
  CardContent,
  CardActions,
  Typography,
  Box,
  Chip,
  Button,
  IconButton,
  Tooltip,
  LinearProgress,
  Grid,
} from '@mui/material';
import {
  Favorite,
  FavoriteBorder,
  Refresh,
  TrendingUp,
  Person,
  Public,
  Schedule,
  Analytics,
  OpenInNew,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const CharacterCard = ({ character, onRefresh, onToggleFavorite, onViewCharts }) => {
  const [refreshing, setRefreshing] = useState(false);
  const [favoriting, setFavoriting] = useState(false);

  const handleRefresh = async () => {
    if (onRefresh && !refreshing) {
      setRefreshing(true);
      try {
        await onRefresh(character.id);
      } finally {
        setRefreshing(false);
      }
    }
  };

  const handleToggleFavorite = async () => {
    if (onToggleFavorite && !favoriting) {
      setFavoriting(true);
      try {
        await onToggleFavorite(character.id, !character.is_favorited);
      } finally {
        setFavoriting(false);
      }
    }
  };

  const handleViewCharts = () => {
    if (onViewCharts) {
      onViewCharts(character);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'Nunca';
    try {
      return format(new Date(dateString), 'dd/MM/yyyy HH:mm', { locale: ptBR });
    } catch {
      return 'Data inválida';
    }
  };

  const getVocationColor = (vocation) => {
    const colors = {
      'Sorcerer': 'primary',
      'Master Sorcerer': 'primary',
      'Druid': 'success',
      'Elder Druid': 'success',
      'Paladin': 'warning',
      'Royal Paladin': 'warning',
      'Knight': 'error',
      'Elite Knight': 'error',
    };
    return colors[vocation] || 'default';
  };

  const getTibiaUrl = (character) => {
    // Mapear servidores para URLs corretas
    const serverUrls = {
      'taleon': `https://${character.world}.taleon.online`,
      'rubini': 'https://rubini.com.br',
      // Adicionar outros servidores conforme necessário
    };
    
    const baseUrl = serverUrls[character.server] || 'https://tibia.com';
    return `${baseUrl}/characterprofile.php?name=${encodeURIComponent(character.name)}`;
  };

  const latest = character.latest_snapshot;

  return (
    <Card 
      sx={{ 
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        transition: 'transform 0.2s, box-shadow 0.2s',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: 4,
        }
      }}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', flexGrow: 1 }}>
            {/* Outfit Image or Fallback Icon */}
            {character.outfit_image_url ? (
              <img
                src={character.outfit_image_url}
                alt={`Outfit de ${character.name}`}
                className="outfitImg"
                onError={(e) => { e.target.style.display = 'none'; }}
              />
            ) : (
              <Person sx={{ mr: 1, color: 'primary.main' }} />
            )}
            <Typography variant="h6" component="h3" noWrap sx={{ fontWeight: 600 }}>
              {character.name}
            </Typography>
            <Tooltip title="Ver no Tibia">
              <IconButton
                component="a"
                href={getTibiaUrl(character)}
                target="_blank"
                rel="noopener noreferrer"
                size="small"
                sx={{ ml: 1, color: 'primary.main' }}
              >
                <OpenInNew fontSize="small" />
              </IconButton>
            </Tooltip>
          </Box>
          
          {onToggleFavorite && (
            <IconButton
              onClick={handleToggleFavorite}
              disabled={favoriting}
              size="small"
              sx={{ color: character.is_favorited ? 'error.main' : 'action.disabled' }}
            >
              {character.is_favorited ? <Favorite /> : <FavoriteBorder />}
            </IconButton>
          )}
        </Box>

        {/* Server/World Info */}
        <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
          <Chip 
            label={`${character.server}/${character.world}`}
            size="small"
            color="primary"
            variant="outlined"
          />
          {character.vocation && (
            <Chip 
              label={character.vocation}
              size="small"
              color={getVocationColor(character.vocation)}
              variant="outlined"
            />
          )}
          {character.guild && (
            <Chip 
              label={character.guild}
              size="small"
              color="secondary"
              variant="outlined"
            />
          )}
        </Box>

        {/* Stats Grid */}
        <Grid container spacing={2} sx={{ mb: 2 }}>
          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Level
              </Typography>
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                {latest?.level || character.level || 0}
              </Typography>
            </Box>
          </Grid>
          
          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Experiência
              </Typography>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>
                {latest?.experience ? latest.experience.toLocaleString('pt-BR') : 'N/A'}
              </Typography>
            </Box>
          </Grid>

          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Mortes
              </Typography>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>
                {latest?.deaths || 0}
              </Typography>
            </Box>
          </Grid>

          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Snapshots
              </Typography>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>
                {character.total_snapshots || 0}
              </Typography>
            </Box>
          </Grid>
        </Grid>

        {/* Quick Stats - Média Diária */}
        {character.total_snapshots > 1 && (
          <Box sx={{ mb: 2, p: 1.5, bgcolor: 'grey.50', borderRadius: 1 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              📊 Estatísticas Rápidas (30 dias)
            </Typography>
            <Grid container spacing={2}>
              <Grid item xs={6}>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Média Diária
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600, color: 'primary.main' }}>
                    {character.average_daily_exp ? 
                      `${character.average_daily_exp.toLocaleString('pt-BR')} exp/dia` : 
                      'Clique em "Ver Gráficos" para ver'
                    }
                  </Typography>
                </Box>
              </Grid>
              <Grid item xs={6}>
                <Box>
                  <Typography variant="caption" color="text.secondary">
                    Total Período
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {character.total_exp_gained ? 
                      `${character.total_exp_gained.toLocaleString('pt-BR')} exp` : 
                      'Clique em "Ver Gráficos" para ver'
                    }
                  </Typography>
                </Box>
              </Grid>
            </Grid>
          </Box>
        )}

        {/* Additional Stats (if available) */}
        {(latest?.charm_points || latest?.bosstiary_points || latest?.achievement_points) && (
          <Box sx={{ mb: 2 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              Pontos Especiais
            </Typography>
            <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
              {latest.charm_points && (
                <Chip 
                  label={`Charm: ${latest.charm_points}`}
                  size="small"
                  variant="outlined"
                />
              )}
              {latest.bosstiary_points && (
                <Chip 
                  label={`Bosstiary: ${latest.bosstiary_points}`}
                  size="small"
                  variant="outlined"
                />
              )}
              {latest.achievement_points && (
                <Chip 
                  label={`Achievements: ${latest.achievement_points}`}
                  size="small"
                  variant="outlined"
                />
              )}
            </Box>
          </Box>
        )}

        {/* Last Update */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Schedule sx={{ fontSize: '1rem', color: 'text.secondary' }} />
          <Typography variant="body2" color="text.secondary">
            Última atualização: {formatDate(character.last_scraped_at)}
          </Typography>
        </Box>

        {/* Error indicator */}
        {character.scrape_error_count > 0 && (
          <Box sx={{ mt: 1 }}>
            <Typography variant="body2" color="error.main">
              ⚠️ {character.scrape_error_count} erro(s) de atualização
            </Typography>
          </Box>
        )}
      </CardContent>

      {/* Actions */}
      <CardActions sx={{ justifyContent: 'space-between', px: 2, pb: 2 }}>
        <Button
          size="small"
          startIcon={<Analytics />}
          disabled={!onViewCharts}
          onClick={handleViewCharts}
          sx={{ color: 'text.secondary' }}
        >
          Ver Gráficos
        </Button>

        {onRefresh && (
          <Tooltip title="Atualizar dados">
            <IconButton
              onClick={handleRefresh}
              disabled={refreshing}
              size="small"
              color="primary"
            >
              <Refresh />
            </IconButton>
          </Tooltip>
        )}
      </CardActions>

      {/* Loading indicator */}
      {refreshing && (
        <LinearProgress 
          sx={{ 
            position: 'absolute', 
            bottom: 0, 
            left: 0, 
            right: 0 
          }} 
        />
      )}
    </Card>
  );
};

export default CharacterCard; 