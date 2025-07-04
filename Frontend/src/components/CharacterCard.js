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
            {latest?.outfit_image_url ? (
              <Box
                component="img"
                src={latest.outfit_image_url}
                alt={`Outfit de ${character.name}`}
                sx={{
                  width: 40,
                  height: 40,
                  mr: 1,
                  borderRadius: 1,
                  border: '1px solid',
                  borderColor: 'divider'
                }}
              />
            ) : (
              <Person sx={{ mr: 1, color: 'primary.main' }} />
            )}
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="h6" component="h3" noWrap sx={{ fontWeight: 600 }}>
                {character.name}
              </Typography>
              {latest?.profile_url && (
                <Tooltip title="Ver perfil original">
                  <IconButton
                    size="small"
                    onClick={() => window.open(latest.profile_url, '_blank')}
                    sx={{ color: 'primary.main' }}
                  >
                    <OpenInNew fontSize="small" />
                  </IconButton>
                </Tooltip>
              )}
            </Box>
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