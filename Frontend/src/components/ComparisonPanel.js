import React from 'react';
import {
  Box,
  Paper,
  Typography,
  Chip,
  IconButton,
  Button,
  Tooltip,
  Slide,
  Fade,
} from '@mui/material';
import {
  Close,
  Compare,
  TrendingUp,
  Person,
} from '@mui/icons-material';

const ComparisonPanel = ({ 
  characters = [], 
  onRemoveCharacter, 
  onShowComparison, 
  onClearAll,
  maxCharacters = 10 
}) => {
  if (characters.length === 0) {
    return null;
  }

  return (
    <Slide direction="up" in={characters.length > 0} mountOnEnter unmountOnExit>
      <Paper
        elevation={8}
        sx={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: 1000,
          p: 2,
          bgcolor: 'background.paper',
          borderTop: '2px solid',
          borderColor: 'primary.main',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Compare sx={{ color: 'primary.main' }} />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Comparação de Personagens
            </Typography>
            <Chip 
              label={`${characters.length}/${maxCharacters}`}
              size="small"
              color={characters.length >= maxCharacters ? 'error' : 'primary'}
              variant="outlined"
            />
          </Box>
          
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button
              variant="contained"
              startIcon={<TrendingUp />}
              onClick={onShowComparison}
              disabled={characters.length < 2}
              size="small"
            >
              Comparar ({characters.length})
            </Button>
            
            <Button
              variant="outlined"
              onClick={onClearAll}
              size="small"
            >
              Limpar Todos
            </Button>
          </Box>
        </Box>

        {/* Character Mini Cards */}
        <Box sx={{ 
          display: 'flex', 
          gap: 1, 
          overflowX: 'auto',
          pb: 1,
          '&::-webkit-scrollbar': {
            height: 6,
          },
          '&::-webkit-scrollbar-track': {
            bgcolor: 'grey.100',
            borderRadius: 3,
          },
          '&::-webkit-scrollbar-thumb': {
            bgcolor: 'grey.400',
            borderRadius: 3,
          },
        }}>
          {characters.map((character) => (
            <Paper
              key={character.id}
              elevation={2}
              sx={{
                minWidth: 200,
                p: 1.5,
                border: '1px solid',
                borderColor: 'primary.main',
                bgcolor: 'primary.50',
                position: 'relative',
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Person sx={{ fontSize: 16, color: 'primary.main' }} />
                  <Typography variant="body2" sx={{ fontWeight: 600, fontSize: '0.875rem' }}>
                    {character.name}
                  </Typography>
                </Box>
                
                <Tooltip title="Remover da comparação">
                  <IconButton
                    size="small"
                    onClick={() => onRemoveCharacter(character.id)}
                    sx={{ 
                      p: 0.5,
                      color: 'error.main',
                      '&:hover': { bgcolor: 'error.50' }
                    }}
                  >
                    <Close fontSize="small" />
                  </IconButton>
                </Tooltip>
              </Box>

              <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap', mb: 1 }}>
                <Chip 
                  label={`${character.server}/${character.world}`}
                  size="small"
                  variant="outlined"
                  sx={{ fontSize: '0.7rem', height: 20 }}
                />
                {character.vocation && (
                  <Chip 
                    label={character.vocation}
                    size="small"
                    variant="outlined"
                    sx={{ fontSize: '0.7rem', height: 20 }}
                  />
                )}
              </Box>

              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Typography variant="body2" color="text.secondary">
                  Level:
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                  {character.level || 0}
                </Typography>
              </Box>

              {character.guild && (
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 0.5 }}>
                  <Typography variant="body2" color="text.secondary">
                    Guild:
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500, fontSize: '0.75rem' }}>
                    {character.guild}
                  </Typography>
                </Box>
              )}
            </Paper>
          ))}
        </Box>

        {/* Warning when max characters reached */}
        {characters.length >= maxCharacters && (
          <Fade in={characters.length >= maxCharacters}>
            <Box sx={{ 
              mt: 1, 
              p: 1, 
              bgcolor: 'warning.50', 
              border: '1px solid', 
              borderColor: 'warning.main',
              borderRadius: 1,
              display: 'flex',
              alignItems: 'center',
              gap: 1
            }}>
              <Typography variant="body2" color="warning.dark" sx={{ fontWeight: 500 }}>
                ⚠️ Limite máximo de {maxCharacters} personagens atingido. 
                Remova um personagem para adicionar outro.
              </Typography>
            </Box>
          </Fade>
        )}
      </Paper>
    </Slide>
  );
};

export default ComparisonPanel; 