import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Box, Container, AppBar, Toolbar, Typography, IconButton } from '@mui/material';
import { Brightness4, Brightness7 } from '@mui/icons-material';

import Home from './pages/Home';
import { useTheme } from './contexts/ThemeContext';
import { FavoritesProvider } from './contexts/FavoritesContext';
import ErrorBoundary from './components/ErrorBoundary';

function App() {
  const { isDarkMode, toggleTheme } = useTheme();

  return (
    <ErrorBoundary>
      <FavoritesProvider>
        <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
          {/* Header */}
          <AppBar position="static" elevation={0} sx={{ bgcolor: 'primary.main' }}>
            <Toolbar>
              <Box sx={{ display: 'flex', alignItems: 'center', flexGrow: 1 }}>
                <img 
                  src={process.env.PUBLIC_URL + '/LogoTibiaTracker.png'} 
                  alt="Tibia Tracker" 
                  style={{ width: 32, height: 32, marginRight: 12 }}
                />
                <Typography
                  variant="h6"
                  component="div"
                  sx={{ 
                    fontFamily: 'Montserrat, sans-serif',
                    fontWeight: 600
                  }}
                >
                  Tibia Tracker
                </Typography>
              </Box>
              
              <IconButton
                color="inherit"
                onClick={toggleTheme}
                aria-label="toggle theme"
              >
                {isDarkMode ? <Brightness7 /> : <Brightness4 />}
              </IconButton>
            </Toolbar>
          </AppBar>

          {/* Main Content */}
          <Container maxWidth="xl" sx={{ py: 3 }}>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/character/:id" element={<div>Character Details (Coming Soon)</div>} />
            </Routes>
          </Container>

          {/* Footer */}
          <Box
            component="footer"
            sx={{
              mt: 'auto',
              py: 2,
              textAlign: 'center',
              borderTop: 1,
              borderColor: 'divider',
              bgcolor: 'background.paper'
            }}
          >
            <Typography variant="body2" color="text.secondary">
              © 2025 Tibia Tracker - Desenvolvido com ❤️ para a comunidade Tibia
            </Typography>
          </Box>
        </Box>
      </FavoritesProvider>
    </ErrorBoundary>
  );
}

export default App; 