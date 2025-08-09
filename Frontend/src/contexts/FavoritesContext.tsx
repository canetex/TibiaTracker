import React, { createContext, useContext, useEffect, useMemo, useState } from 'react'

type FavoritesContextValue = {
  favorites: number[]
  isFavorite: (id: number) => boolean
  toggleFavorite: (id: number) => void
}

const FavoritesContext = createContext<FavoritesContextValue | undefined>(undefined)

export const useFavorites = (): FavoritesContextValue => {
  const ctx = useContext(FavoritesContext)
  if (!ctx) throw new Error('useFavorites deve ser usado dentro de um FavoritesProvider')
  return ctx
}

export const FavoritesProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const [favorites, setFavorites] = useState<number[]>([])

  useEffect(() => {
    try {
      const raw = localStorage.getItem('tibiaTracker_favorites')
      if (raw) setFavorites(JSON.parse(raw))
    } catch {}
  }, [])

  useEffect(() => {
    try {
      localStorage.setItem('tibiaTracker_favorites', JSON.stringify(favorites))
    } catch {}
  }, [favorites])

  const toggleFavorite = (id: number) => {
    setFavorites(prev => (prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]))
  }

  const value = useMemo<FavoritesContextValue>(() => ({
    favorites,
    isFavorite: (id: number) => favorites.includes(id),
    toggleFavorite,
  }), [favorites])

  return <FavoritesContext.Provider value={value}>{children}</FavoritesContext.Provider>
} 