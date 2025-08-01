import React from 'react';
import { Button } from './ui/button';
import { Moon, Sun } from 'lucide-react';

const Header = ({ onToggleTheme, isDarkMode }) => {
  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto flex h-16 items-center justify-between px-4">
        {/* Logo and Title */}
        <div className="flex items-center space-x-4">
          <div className="relative">
            <img 
              src={process.env.PUBLIC_URL + '/LogoTibiaTracker.png'}
              alt="Tibia Tracker" 
              className="h-12 w-12 object-contain"
            />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gradient font-display">
              Tibia Tracker
            </h1>
            <p className="text-sm text-muted-foreground hidden sm:block">
              Monitor de personagens Tibia
            </p>
          </div>
        </div>

        {/* Theme Toggle */}
        <Button
          variant="ghost"
          size="icon"
          onClick={onToggleTheme}
          aria-label="Alternar tema"
          className="rounded-full"
        >
          {isDarkMode ? (
            <Sun className="h-5 w-5 text-yellow-500" />
          ) : (
            <Moon className="h-5 w-5" />
          )}
        </Button>
      </div>
    </header>
  );
};

export default Header;