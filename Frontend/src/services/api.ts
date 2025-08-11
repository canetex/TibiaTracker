import axios from 'axios';
import logger from '../lib/logger';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptors
api.interceptors.request.use(
  (config) => {
    logger.debug(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
    return config;
  },
  (error) => {
    logger.error('Erro na requisição:', error);
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => {
    logger.debug(`API Response: ${response.status} ${response.config.url}`);
    return response;
  },
  (error) => {
    logger.error('Erro na resposta:', error);
    return Promise.reject(error);
  }
);

// Error handling
const handleError = (error) => {
  if (error.response) {
    const { status, data } = error.response;
    switch (status) {
      case 400:
        logger.error('Erro de validação:', data);
        break;
      case 401:
        logger.error('Não autorizado:', data);
        break;
      case 404:
        logger.error('Recurso não encontrado:', data);
        break;
      case 422:
        logger.error('Erro de processamento:', data);
        break;
      case 500:
        logger.error('Erro interno do servidor:', data);
        break;
      default:
        logger.error('Erro desconhecido:', data);
    }
  } else if (error.request) {
    logger.error('Erro de rede - servidor não respondeu:', error.request);
  } else {
    logger.error('Erro na configuração da requisição:', error.message);
  }
  throw error;
};

// API methods
const apiService = {
  // Character methods
  async getRecentCharacters(limit = 10) {
    try {
      logger.debug(`[API] getRecentCharacters chamado com limite: ${limit}`);
      const response = await api.get(`/characters/recent?limit=${limit}`);
      logger.debug('[API] getRecentCharacters resposta:', response.data);
      return response.data;
    } catch (error) {
      logger.error('[API] Erro em getRecentCharacters:', error);
      handleError(error);
    }
  },

  async getCharacterStats(characterId, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/stats?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterHistory(characterId, days = 30) {
    try {
      const response = await api.get(`/characters/${characterId}/history?days=${days}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterDetails(characterId) {
    try {
      const response = await api.get(`/characters/${characterId}`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async updateCharacter(characterId) {
    try {
      const response = await api.post(`/characters/${characterId}/update`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async scrapeCharacter(name, server, world) {
    try {
      logger.debug(`API: Fazendo scraping com histórico para ${name} em ${server}/${world}`);
      const response = await api.post('/characters/scrape', {
        name,
        server,
        world,
        with_history: true,
      });
      logger.debug('API: Scraping com histórico concluído:', response);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharacterExperienceData(characterId, days = 30) {
    try {
      logger.debug(`API: Buscando dados de experiência para personagem ${characterId}, ${days} dias`);
      const response = await api.get(`/characters/${characterId}/charts/experience?days=${days}`);
      logger.debug('API: Dados de experiência recebidos:', response.data);
      return response.data;
    } catch (error) {
      logger.error('API: Erro ao buscar dados de experiência:', error);
      handleError(error);
    }
  },

  async getCharacterLevelData(characterId, days = 30) {
    try {
      logger.debug(`API: Buscando dados de level para personagem ${characterId}, ${days} dias`);
      const response = await api.get(`/characters/${characterId}/charts/level?days=${days}`);
      logger.debug('API: Dados de level recebidos:', response.data);
      return response.data;
    } catch (error) {
      logger.error('API: Erro ao buscar dados de level:', error);
      handleError(error);
    }
  },

  async toggleFavorite(characterId) {
    try {
      const response = await api.post(`/characters/${characterId}/favorite`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async toggleRecovery(characterId) {
    try {
      const response = await api.post(`/characters/${characterId}/recovery`);
      return response.data;
    } catch (error) {
      handleError(error);
    }
  },

  async getCharactersByIds(ids) {
    try {
      logger.debug('[API] getCharactersByIds chamado com IDs:', ids);
      const response = await api.post('/characters/batch', { ids });
      logger.debug('[API] getCharactersByIds resposta completa:', response.data);
      return response.data;
    } catch (error) {
      logger.error('[API] Erro em getCharactersByIds:', error);
      handleError(error);
    }
  },

  async getAllCharacters() {
    try {
      const response = await api.get('/characters');
      return response.data;
    } catch (error) {
      logger.error('[API] Erro em getAllCharacters:', error);
      handleError(error);
    }
  },

  async getFilteredCharacters(filters) {
    try {
      const response = await api.post('/characters/filter', filters);
      return response.data;
    } catch (error) {
      logger.error('[API] Erro em getFilteredCharacters:', error);
      handleError(error);
    }
  },

  async getTopExp(days = 30, filters = {}) {
    try {
      logger.debug(`[API] getTopExp chamado com período de ${days} dias`);
      const params = new URLSearchParams({ days: days.toString(), ...filters });
      const response = await api.get(`/characters/top-exp?${params}`);
      logger.debug('[API] getTopExp resposta:', response.data);
      return response.data;
    } catch (error) {
      logger.error('[API] Erro em getTopExp:', error);
      handleError(error);
    }
  },
};

export { api, apiService }; 