import React, { useState, useEffect } from 'react';
import { Routes, Route } from 'react-router-dom';
import { Box, Container, AppBar, Toolbar, Typography, IconButton } from '@mui/material';
import { Brightness4, Brightness7 } from '@mui/icons-material';

import Home from './pages/Home';
import { useTheme } from './contexts/ThemeContext';
import ErrorBoundary from './components/ErrorBoundary';

function App() {
  const { isDarkMode, toggleTheme } = useTheme();

  return (
    <ErrorBoundary>
      <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
        {/* Header */}
        <AppBar position="static" elevation={0} sx={{ bgcolor: 'primary.main' }}>
          <Toolbar>
            <Typography
              variant="h6"
              component="div"
              sx={{ 
                flexGrow: 1, 
                fontFamily: 'Montserrat, sans-serif',
                fontWeight: 600
              }}
            >
              🏰 Tibia Tracker
            </Typography>
            
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
            © 2024 Tibia Tracker - Desenvolvido com ❤️ para a comunidade Tibia
          </Typography>
        </Box>
      </Box>
    </ErrorBoundary>
  );
}

export default App; 