import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Toaster } from '@/hooks/use-toast';
import { ThemeProvider } from '@/contexts/ThemeContext';
import { FavoritesProvider } from '@/contexts/FavoritesContext';
import ErrorBoundary from '@/components/ErrorBoundary';
import Home from '@/pages/Home';

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider>
        <FavoritesProvider>
          <div className="min-h-screen bg-background text-foreground">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/character/:id" element={<div>Character Details (Coming Soon)</div>} />
            </Routes>
            <Toaster />
          </div>
        </FavoritesProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App; 