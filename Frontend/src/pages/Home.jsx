import React, { useEffect, useState } from 'react';
import { apiService } from '../services/api';
import logger from '../lib/logger';

export default function Home() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [characters, setCharacters] = useState([]);

  useEffect(() => {
    const loadInitialData = async () => {
      try {
        setLoading(true);
        setError(null);
        const data = await apiService.getRecentCharacters();
        setCharacters(data);
      } catch (err) {
        logger.error('Erro ao carregar dados iniciais:', err);
        setError('Erro ao carregar dados iniciais');
      } finally {
        setLoading(false);
      }
    };

    loadInitialData();
  }, []);

  const loadAllCharacters = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getAllCharacters();
      setCharacters(data);
    } catch (err) {
      logger.error('Erro ao carregar todos os personagens:', err);
      setError('Erro ao carregar todos os personagens');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (searchTerm) => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getFilteredCharacters({ search: searchTerm });
      setCharacters(data);
    } catch (err) {
      logger.error('Erro na busca:', err);
      setError('Erro ao realizar busca');
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async (characterId) => {
    try {
      setLoading(true);
      setError(null);
      await apiService.updateCharacter(characterId);
      const data = await apiService.getRecentCharacters();
      setCharacters(data);
    } catch (err) {
      logger.error('Erro ao atualizar personagem:', err);
      setError('Erro ao atualizar personagem');
    } finally {
      setLoading(false);
    }
  };

  const handleFilter = async (filters) => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getFilteredCharacters(filters);
      setCharacters(data);
    } catch (err) {
      logger.error('Erro ao aplicar filtros:', err);
      setError('Erro ao aplicar filtros');
    } finally {
      setLoading(false);
    }
  };

  const handleRecoveryToggle = async (characterId) => {
    try {
      await apiService.toggleRecovery(characterId);
      const data = await apiService.getRecentCharacters();
      setCharacters(data);
    } catch (err) {
      logger.error('Erro ao alterar status de recuperação:', err);
      setError('Erro ao alterar status de recuperação');
    }
  };

  if (loading) {
    return <div>Carregando...</div>;
  }

  if (error) {
    return <div>{error}</div>;
  }

  return (
    <div>
      <h1>Personagens</h1>
      <div>
        {characters.map((char) => (
          <div key={char.id}>
            <h2>{char.name}</h2>
            <p>Level: {char.level}</p>
            <p>Vocation: {char.vocation}</p>
            <p>World: {char.world}</p>
            <button onClick={() => handleRefresh(char.id)}>Atualizar</button>
            <button onClick={() => handleRecoveryToggle(char.id)}>
              {char.recovery_active ? 'Desativar Recuperação' : 'Ativar Recuperação'}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}