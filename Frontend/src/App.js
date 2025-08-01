import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Button } from './components/ui/button';
import { Toaster } from 'sonner';

import Home from './pages/Home';
import { useTheme } from './contexts/ThemeContext';
import { FavoritesProvider } from './contexts/FavoritesContext';
import ErrorBoundary from './components/ErrorBoundary';
import Header from './components/Header';

function App() {
  const { isDarkMode, toggleTheme } = useTheme();

  React.useEffect(() => {
    // Apply theme class to document
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDarkMode]);

  return (
    <ErrorBoundary>
      <FavoritesProvider>
        <div className="min-h-screen bg-background text-foreground">
          {/* Header */}
          <Header onToggleTheme={toggleTheme} isDarkMode={isDarkMode} />

          {/* Main Content */}
          <main className="container mx-auto px-4 py-6">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route 
                path="/character/:id" 
                element={
                  <div className="text-center py-12">
                    <h2 className="text-2xl font-bold mb-4">Character Details</h2>
                    <p className="text-muted-foreground">Em breve...</p>
                  </div>
                } 
              />
            </Routes>
          </main>

          {/* Footer */}
          <footer className="border-t bg-card/50 backdrop-blur-sm">
            <div className="container mx-auto px-4 py-6 text-center">
              <p className="text-sm text-muted-foreground">
                © 2025 Tibia Tracker - Desenvolvido com ❤️ para a comunidade Tibia
              </p>
            </div>
          </footer>

          {/* Toast notifications */}
          <Toaster 
            theme={isDarkMode ? 'dark' : 'light'}
            position="bottom-right"
            richColors
          />
        </div>
      </FavoritesProvider>
    </ErrorBoundary>
  );
}

export default App;