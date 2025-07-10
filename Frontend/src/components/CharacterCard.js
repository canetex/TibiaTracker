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
  Star,
  StarBorder,
  Refresh,
  TrendingUp,
  Person,
  Public,
  Schedule,
  Analytics,
  OpenInNew,
  Compare,
  CompareOutlined,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const CharacterCard = ({ 
  character, 
  onRefresh, 
  onToggleFavorite, 
  onViewCharts, 
  onAddToComparison, 
  onRemoveFromComparison, 
  isInComparison = false,
  onQuickFilter // Nova prop para filtros rápidos
}) => {
  const [refreshing, setRefreshing] = useState(false);
  const [favoriting, setFavoriting] = useState(false);

  // Log dos dados do personagem para debug
  console.log(`[CHARACTER_CARD] Renderizando card para ${character.name}:`, {
    id: character.id,
    name: character.name,
    last_experience: character.last_experience,
    last_experience_date: character.last_experience_date,
    previous_experience: character.previous_experience,
    latest_snapshot: character.latest_snapshot ? {
      experience: character.latest_snapshot.experience,
      level: character.latest_snapshot.level
    } : null,
    total_exp_gained: character.total_exp_gained,
    exp_gained: character.exp_gained
  });

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

  const handleToggleComparison = () => {
    if (isInComparison) {
      onRemoveFromComparison?.(character.id);
    } else {
      onAddToComparison?.(character);
    }
  };

  // Função para filtros rápidos via tags
  const handleQuickFilter = (filterType, value) => {
    console.log(`[CHARACTER_CARD] handleQuickFilter chamado: ${filterType} = ${value}`);
    if (onQuickFilter) {
      console.log(`[CHARACTER_CARD] Chamando onQuickFilter...`);
      onQuickFilter(filterType, value);
    } else {
      console.log(`[CHARACTER_CARD] onQuickFilter não está definido`);
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
        },
        border: isInComparison ? '2px solid #1976d2' : 'none',
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
          
          <Box sx={{ display: 'flex', gap: 0.5 }}>
            {onToggleFavorite && (
              <IconButton
                onClick={handleToggleFavorite}
                disabled={favoriting}
                size="small"
                sx={{ color: character.is_favorited ? 'error.main' : 'action.disabled' }}
              >
                {character.is_favorited ? <Star /> : <StarBorder />}
              </IconButton>
            )}
            
            {onAddToComparison && (
              <Tooltip title={isInComparison ? "Remover da Comparação" : "Adicionar à Comparação"}>
                <IconButton
                  onClick={handleToggleComparison}
                  size="small"
                  sx={{ 
                    color: isInComparison ? 'primary.main' : 'action.disabled',
                    bgcolor: isInComparison ? 'primary.50' : 'transparent'
                  }}
                >
                  {isInComparison ? <Compare /> : <CompareOutlined />}
                </IconButton>
              </Tooltip>
            )}
          </Box>
        </Box>

        {/* Server/World Info - Tags clicáveis para filtros rápidos */}
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip 
            label={`${character.server}/${character.world}`}
            size="small"
            color="primary"
            variant="outlined"
            onClick={() => handleQuickFilter('server', character.server)}
            sx={{ cursor: 'pointer', '&:hover': { bgcolor: 'primary.50' } }}
          />
          {character.vocation && (
            <Chip 
              label={character.vocation}
              size="small"
              color={getVocationColor(character.vocation)}
              variant="outlined"
              onClick={() => handleQuickFilter('vocation', character.vocation)}
              sx={{ cursor: 'pointer', '&:hover': { bgcolor: 'primary.50' } }}
            />
          )}
          {character.guild && (
            <Chip 
              label={character.guild}
              size="small"
              color="secondary"
              variant="outlined"
              onClick={() => handleQuickFilter('guild', character.guild)}
              sx={{ cursor: 'pointer', '&:hover': { bgcolor: 'secondary.50' } }}
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
                {(latest?.level || character.level || 0).toLocaleString('pt-BR')}
              </Typography>
            </Box>
          </Grid>
          
          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                {character.last_experience_date 
                  ? `Experiência (último dia - ${character.last_experience_date})`
                  : 'Experiência (último dia)'
                }
              </Typography>
              <Tooltip title={(!character.snapshots || character.snapshots.length === 0) ? 'Dados de experiência detalhados não disponíveis para este personagem filtrado.' : ''}>
                <Typography variant="body1" sx={{ fontWeight: 500 }}>
                  {character.last_experience 
                    ? character.last_experience.toLocaleString('pt-BR')
                    : 'N/A'
                  }
                </Typography>
              </Tooltip>
            </Box>
          </Grid>
          
          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Mortes
              </Typography>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>
                {(latest?.deaths || character.deaths || 0).toLocaleString('pt-BR')}
              </Typography>
            </Box>
          </Grid>
          
          <Grid item xs={6}>
            <Box>
              <Typography variant="body2" color="text.secondary">
                Snapshots
              </Typography>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>
                {(character.total_snapshots || character.snapshots_count || 0).toLocaleString('pt-BR')}
              </Typography>
            </Box>
          </Grid>
        </Grid>

        {/* Experience Progress */}
        {(() => {
          const exp = latest?.experience || character.experience;
          const totalGained = character.total_exp_gained || character.exp_gained || 0;
          return exp ? (
            <Box sx={{ mb: 2 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                <Typography variant="body2" color="text.secondary">
                  Progresso (30 dias)
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  +{totalGained.toLocaleString('pt-BR')}
                </Typography>
              </Box>
              <LinearProgress 
                variant="determinate" 
                value={Math.min(totalGained / 1000000 * 100, 100)}
                sx={{ height: 6, borderRadius: 3 }}
              />
            </Box>
          ) : null;
        })()}

        {/* Last Update */}
        <Box sx={{ display: 'flex', alignItems: 'center', color: 'text.secondary' }}>
          <Schedule sx={{ fontSize: 16, mr: 0.5 }} />
          <Typography variant="caption">
            Atualizado: {formatDate(character.last_scraped_at)}
          </Typography>
        </Box>
      </CardContent>

      {/* Actions */}
      <CardActions sx={{ pt: 0, justifyContent: 'space-between' }}>
        <Button
          size="small"
          startIcon={<Analytics />}
          onClick={handleViewCharts}
          variant="outlined"
        >
          Gráficos
        </Button>
        
        {onRefresh && (
          <Button
            size="small"
            startIcon={<Refresh />}
            onClick={handleRefresh}
            disabled={refreshing}
            variant="outlined"
          >
            {refreshing ? 'Atualizando...' : 'Atualizar'}
          </Button>
        )}
      </CardActions>
    </Card>
  );
};

export default CharacterCard; 