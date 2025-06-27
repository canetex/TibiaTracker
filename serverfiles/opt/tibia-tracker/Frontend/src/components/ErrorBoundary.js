import React from 'react';
import { Box, Typography, Button, Card, CardContent } from '@mui/material';
import { Error as ErrorIcon, Refresh } from '@mui/icons-material';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary capturou um erro:', error, errorInfo);
  }

  handleReload = () => {
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <Box
          sx={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            bgcolor: 'background.default',
            p: 3,
          }}
        >
          <Card sx={{ maxWidth: 500, textAlign: 'center' }}>
            <CardContent sx={{ p: 4 }}>
              <ErrorIcon 
                sx={{ 
                  fontSize: 64, 
                  color: 'error.main', 
                  mb: 2 
                }} 
              />
              
              <Typography variant="h5" gutterBottom>
                Oops! Algo deu errado
              </Typography>
              
              <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                Ocorreu um erro inesperado. Tente recarregar a página ou entre em contato 
                conosco se o problema persistir.
              </Typography>
              
              <Button
                variant="contained"
                startIcon={<Refresh />}
                onClick={this.handleReload}
                size="large"
              >
                Recarregar Página
              </Button>
              
              {process.env.NODE_ENV === 'development' && this.state.error && (
                <Box sx={{ mt: 3, textAlign: 'left' }}>
                  <Typography variant="body2" color="error" component="pre" sx={{ 
                    fontSize: '0.75rem',
                    backgroundColor: 'grey.100',
                    p: 2,
                    borderRadius: 1,
                    overflow: 'auto'
                  }}>
                    {this.state.error.toString()}
                  </Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Box>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary; 