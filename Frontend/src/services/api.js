import axios from 'axios';

// Configuração base do Axios
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || 'http://localhost:8000',
  timeout: 30000, // 30 segundos
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptador de requisições
api.interceptors.request.use(
  (config) => {
    // Adicionar timestamp para evitar cache
    config.params = {
      ...config.params,
      _t: Date.now(),
    };
    
    console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
    return config;
  },
  (error) => {
    console.error('Erro na requisição:', error);
    return Promise.reject(error);
  }
);

// Interceptador de respostas
api.interceptors.response.use(
  (response) => {
    console.log(`API Response: ${response.status} ${response.config.url}`);
    return response;
  },
  (error) => {
    console.error('Erro na resposta:', error);
    
    // Tratar diferentes tipos de erro
    if (error.response) {
      // Erro de resposta do servidor
      const { status, data } = error.response;
      
      switch (status) {
        case 400:
          console.error('Erro de validação:', data);
          break;
        case 401:
          console.error('Não autorizado:', data);
          break;
        case 404:
          console.error('Recurso não encontrado:', data);
          break;
        case 422:
          console.error('Erro de processamento:', data);
          break;
        case 500:
          console.error('Erro interno do servidor:', data);
          break;
        default:
          console.error('Erro desconhecido:', data);
      }
    } else if (error.request) {
      // Erro de rede
      console.error('Erro de rede - servidor não respondeu:', error.request);
    } else {
      // Outro tipo de erro
      console.error('Erro na configuração da requisição:', error.message);
    }
    
    return Promise.reject(error);
  }
);

// Serviços da API
export const apiService = {
  // ============================================================================
  // HEALTH CHECK
  // ============================================================================
  
  async healthCheck() {
    try {
      const response = await api.get('/health');
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  // ============================================================================
  // CHARACTERS
  // ============================================================================

  /**
   * Buscar personagem específico
   */
  async searchCharacter(name, server, world) {
    try {
      const response = await api.get('/api/v1/characters/search', {
        params: { name, server, world }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Criar/adicionar novo personagem
   */
  async createCharacter(characterData) {
    try {
      const response = await api.post('/api/v1/characters/', characterData);
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter personagem por ID
   */
  async getCharacter(characterId) {
    try {
      const response = await api.get(`/api/v1/characters/${characterId}`);
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Listar personagens com filtros
   */
  async listCharacters(params = {}) {
    try {
      const response = await api.get('/api/v1/characters/', { params });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter personagens recentes
   */
  async getRecentCharacters(limit = 10) {
    try {
      const response = await api.get('/api/v1/characters/recent', {
        params: { limit }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Atualizar configurações do personagem
   */
  async updateCharacter(characterId, updateData) {
    try {
      const response = await api.put(`/api/v1/characters/${characterId}`, updateData);
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Favoritar/desfavoritar personagem
   */
  async toggleFavorite(characterId, isFavorited) {
    try {
      const response = await api.post(`/api/v1/characters/${characterId}/favorite`, {
        is_favorited: isFavorited
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Atualizar dados do personagem manualmente
   */
  async refreshCharacter(characterId) {
    try {
      const response = await api.post(`/api/v1/characters/${characterId}/refresh`);
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter estatísticas detalhadas do personagem
   */
  async getCharacterStats(characterId, days = 30) {
    try {
      const response = await api.get(`/api/v1/characters/${characterId}/stats`, {
        params: { days }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Deletar personagem
   */
  async deleteCharacter(characterId) {
    try {
      const response = await api.delete(`/api/v1/characters/${characterId}`);
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter estatísticas globais da plataforma
   */
  async getGlobalStats() {
    try {
      const response = await api.get('/api/v1/characters/stats/global');
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Fazer scraping com histórico completo de experiência
   */
  async scrapeWithHistory(server, world, characterName) {
    try {
      const response = await api.post('/api/v1/characters/scrape-with-history', null, {
        params: { server, world, character_name: characterName }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter dados de experiência para gráfico
   */
  async getCharacterExperienceChart(characterId, days = 30) {
    try {
      const response = await api.get(`/api/v1/characters/${characterId}/charts/experience`, {
        params: { days }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter dados de level para gráfico
   */
  async getCharacterLevelChart(characterId, days = 30) {
    try {
      const response = await api.get(`/api/v1/characters/${characterId}/charts/level`, {
        params: { days }
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  // ============================================================================
  // UTILS
  // ============================================================================

  /**
   * Verificar se o servidor está online
   */
  async ping() {
    try {
      const response = await api.get('/');
      return response.data;
    } catch (error) {
      throw error;
    }
  },

  /**
   * Obter informações da API
   */
  async getApiInfo() {
    try {
      const response = await api.get('/info');
      return response.data;
    } catch (error) {
      throw error;
    }
  },
};

// Função utilitária para formatar erros
export const formatApiError = (error) => {
  if (error.response?.data?.detail) {
    // Erro estruturado da API
    const detail = error.response.data.detail;
    if (typeof detail === 'string') {
      return detail;
    } else if (detail.message) {
      return detail.message;
    }
  }
  
  if (error.response?.data?.message) {
    return error.response.data.message;
  }
  
  if (error.message) {
    return error.message;
  }
  
  return 'Erro desconhecido na comunicação com o servidor';
};

// Função utilitária para verificar se é erro de rede
export const isNetworkError = (error) => {
  return error.code === 'NETWORK_ERROR' || 
         error.code === 'ECONNABORTED' ||
         !error.response;
};

export default api; 