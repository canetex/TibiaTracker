import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 10000,
});

const handleError = (error: any) => {
  if (error.response) {
    throw new Error(error.response.data.detail || 'Erro na requisição');
  }
  throw error;
};

export const apiService = {
  async getRecentCharacters(limit = 10) {
    try {
      const response = await api.get(`/characters/recent?limit=${limit}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterStats(characterId: number, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/stats?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterHistory(characterId: number, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/history?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterExperienceData(characterId: number, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/charts/experience?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterLevelData(characterId: number, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/charts/level?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getGlobalStats() {
    try {
      const response = await api.get('/characters/stats/global');
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async searchCharacters(query: string) {
    try {
      const response = await api.get(`/characters/search?q=${encodeURIComponent(query)}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getTopExp(days = 30, filters = {}) {
    try {
      const params = new URLSearchParams({ days: days.toString(), ...filters });
      const response = await api.get(`/characters/top-exp?${params}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getLinearity(days = 30, filters = {}) {
    try {
      const params = new URLSearchParams({ days: days.toString(), ...filters });
      const response = await api.get(`/characters/linearity?${params}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getVocations() {
    try {
      const response = await api.get('/characters/vocations');
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getServers() {
    try {
      const response = await api.get('/characters/servers');
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getAllCharacters() {
    try {
      const response = await api.get('/characters/');
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getFilteredCharacters(filters = {}) {
    try {
      // Converter chaves camelCase para snake_case e remover valores vazios/undefined/null
      const params = new URLSearchParams();
      Object.entries(filters as Record<string, any>).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          // Converter camelCase para snake_case
          const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
          params.append(snakeKey, String(value));
        }
      });
      
      // Usar o endpoint filter-ids para obter IDs primeiro
      const response = await api.get(`/characters/filter-ids?${params}`);
      
      // Se não há IDs, retornar array vazio
      if (!response.data || !response.data.ids || !Array.isArray(response.data.ids)) {
        return [];
      }
      
      // Agora buscar os personagens pelos IDs
      const characterResponse = await api.post('/characters/by-ids', {
        ids: response.data.ids
      });
      
      return characterResponse.data || [];
    } catch (error) {
      handleError(error);
    }
  }
};

export { api }; 