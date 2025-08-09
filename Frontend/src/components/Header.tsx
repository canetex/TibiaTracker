import React from 'react'
import { Moon, Sun } from 'lucide-react'

type HeaderProps = {
  onToggleTheme: () => void
  isDarkMode: boolean
}

export default function Header({ onToggleTheme, isDarkMode }: HeaderProps): JSX.Element {
  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto flex h-16 items-center justify-between px-4">
        <div className="flex items-center space-x-4">
          <div className="relative">
            <img src={'/LogoTibiaTracker.png'} alt="Tibia Tracker" className="h-12 w-12 object-contain" />
          </div>
          <div>
            <h1 className="text-2xl font-bold gradient-text font-display">Tibia Tracker</h1>
            <p className="text-sm text-muted-foreground hidden sm:block">Monitor de personagens Tibia</p>
          </div>
        </div>
        <button onClick={onToggleTheme} aria-label="Alternar tema" className="inline-flex items-center justify-center h-10 w-10 rounded-full hover:bg-muted/50">
          {isDarkMode ? <Sun className="h-5 w-5 text-yellow-500" /> : <Moon className="h-5 w-5" />}
        </button>
      </div>
    </header>
  )
} 