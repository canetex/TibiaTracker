import React, { createContext, useContext, useEffect, useState } from 'react'

type ThemeContextValue = {
  isDarkMode: boolean
  toggleTheme: () => void
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined)

export const useTheme = (): ThemeContextValue => {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme deve ser usado dentro de um ThemeProvider')
  return ctx
}

export const ThemeProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const [isDarkMode, setIsDarkMode] = useState(false)

  useEffect(() => {
    const saved = localStorage.getItem('tibiaTracker_theme')
    if (saved) {
      setIsDarkMode(saved === 'dark')
    } else {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      setIsDarkMode(prefersDark)
    }
  }, [])

  useEffect(() => {
    localStorage.setItem('tibiaTracker_theme', isDarkMode ? 'dark' : 'light')
    // Sincroniza a classe `dark` no elemento <html> sempre que o tema mudar
    if (typeof window !== 'undefined') {
      document.documentElement.classList.toggle('dark', isDarkMode)
    }
  }, [isDarkMode])

  const toggleTheme = () => setIsDarkMode(prev => !prev)

  return (
    <ThemeContext.Provider value={{ isDarkMode, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  )
} 