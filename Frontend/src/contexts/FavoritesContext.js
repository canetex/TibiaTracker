import React, { createContext, useContext, useState, useEffect } from 'react';

// Nome do cookie para favoritos
const FAVORITES_COOKIE = 'tibia_favorites';

// Funções utilitárias para cookies
const getFavoritesFromCookie = () => {
  try {
    const cookie = document.cookie
      .split('; ')
      .find(row => row.startsWith(FAVORITES_COOKIE + '='));
    
    if (!cookie) return [];
    
    const cookieValue = cookie.split('=')[1];
    if (!cookieValue) return [];
    
    return cookieValue.split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id));
  } catch (error) {
    console.error('Erro ao ler favoritos do cookie:', error);
    return [];
  }
};

const saveFavoritesToCookie = (favoriteIds) => {
  try {
    const cookieValue = favoriteIds.join(',');
    // Cookie válido por 1 ano
    document.cookie = `${FAVORITES_COOKIE}=${cookieValue}; path=/; max-age=31536000`;
  } catch (error) {
    console.error('Erro ao salvar favoritos no cookie:', error);
  }
};

// Contexto de Favoritos
const FavoritesContext = createContext();

export const useFavorites = () => {
  const context = useContext(FavoritesContext);
  if (!context) {
    throw new Error('useFavorites deve ser usado dentro de um FavoritesProvider');
  }
  return context;
};

export const FavoritesProvider = ({ children }) => {
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(true);

  // Carregar favoritos do cookie na inicialização
  useEffect(() => {
    const loadFavorites = () => {
      try {
        const favoriteIds = getFavoritesFromCookie();
        setFavorites(favoriteIds);
        console.log('[FAVORITES] Favoritos carregados:', favoriteIds);
      } catch (error) {
        console.error('[FAVORITES] Erro ao carregar favoritos:', error);
        setFavorites([]);
      } finally {
        setLoading(false);
      }
    };

    loadFavorites();
  }, []);

  // Adicionar personagem aos favoritos
  const addFavorite = (characterId) => {
    if (!favorites.includes(characterId)) {
      const newFavorites = [...favorites, characterId];
      setFavorites(newFavorites);
      saveFavoritesToCookie(newFavorites);
      console.log('[FAVORITES] Adicionado favorito:', characterId);
    }
  };

  // Remover personagem dos favoritos
  const removeFavorite = (characterId) => {
    const newFavorites = favorites.filter(id => id !== characterId);
    setFavorites(newFavorites);
    saveFavoritesToCookie(newFavorites);
    console.log('[FAVORITES] Removido favorito:', characterId);
  };

  // Alternar favorito (adicionar/remover)
  const toggleFavorite = (characterId) => {
    if (favorites.includes(characterId)) {
      removeFavorite(characterId);
    } else {
      addFavorite(characterId);
    }
  };

  // Verificar se um personagem é favorito
  const isFavorite = (characterId) => {
    return favorites.includes(characterId);
  };

  // Limpar todos os favoritos
  const clearFavorites = () => {
    setFavorites([]);
    saveFavoritesToCookie([]);
    console.log('[FAVORITES] Todos os favoritos removidos');
  };

  // Obter quantidade de favoritos
  const getFavoritesCount = () => {
    return favorites.length;
  };

  const value = {
    favorites,
    loading,
    addFavorite,
    removeFavorite,
    toggleFavorite,
    isFavorite,
    clearFavorites,
    getFavoritesCount,
  };

  return (
    <FavoritesContext.Provider value={value}>
      {children}
    </FavoritesContext.Provider>
  );
};

export default FavoritesContext; 