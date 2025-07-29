import React, { useState } from 'react';
import { 
  Star, 
  RefreshCw, 
  User, 
  Clock, 
  BarChart3, 
  ExternalLink, 
  GitCompare, 
  Play,
  Pause
} from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { useFavorites } from '@/contexts/FavoritesContext';
import { useToast } from '@/hooks/use-toast';

const CharacterCard = ({ 
  character, 
  onRefresh, 
  onViewCharts, 
  onAddToComparison, 
  onRemoveFromComparison, 
  isInComparison = false,
  onQuickFilter,
  onToggleRecovery,
  onManualScrape
}) => {
  const [refreshing, setRefreshing] = useState(false);
  const [recoveryLoading, setRecoveryLoading] = useState(false);
  const [scrapingLoading, setScrapingLoading] = useState(false);
  const { toggleFavorite, isFavorite } = useFavorites();
  const { toast } = useToast();

  // Log dos dados do personagem para debug
  console.log(`[CHARACTER_CARD] Renderizando card para ${character.name}:`, {
    id: character.id,
    name: character.name,
    last_experience: character.last_experience,
    last_experience_date: character.last_experience_date,
    previous_experience: character.previous_experience,
    latest_snapshot: character.latest_snapshot ? {
      experience: character.latest_snapshot.experience,
      level: character.latest_snapshot.level
    } : null,
    total_exp_gained: character.total_exp_gained,
    exp_gained: character.exp_gained
  });

  const handleRefresh = async () => {
    if (onRefresh && !refreshing) {
      setRefreshing(true);
      try {
        await onRefresh(character.id);
        toast({
          title: "Personagem atualizado",
          description: "Os dados foram atualizados com sucesso.",
        });
      } catch (error) {
        toast({
          title: "Erro ao atualizar",
          description: "Não foi possível atualizar os dados do personagem.",
          variant: "destructive",
        });
      } finally {
        setRefreshing(false);
      }
    }
  };

  const handleToggleFavorite = () => {
    toggleFavorite(character.id);
    toast({
      title: isFavorite(character.id) ? "Removido dos favoritos" : "Adicionado aos favoritos",
      description: `${character.name} foi ${isFavorite(character.id) ? 'removido' : 'adicionado'} aos favoritos.`,
    });
  };

  const handleViewCharts = () => {
    if (onViewCharts) {
      onViewCharts(character);
    }
  };

  const handleToggleComparison = () => {
    if (isInComparison) {
      onRemoveFromComparison?.(character.id);
      toast({
        title: "Removido da comparação",
        description: `${character.name} foi removido do painel de comparação.`,
      });
    } else {
      onAddToComparison?.(character);
    }
  };

  const handleToggleRecovery = async () => {
    if (onToggleRecovery && !recoveryLoading) {
      setRecoveryLoading(true);
      try {
        await onToggleRecovery(character.id);
      } finally {
        setRecoveryLoading(false);
      }
    }
  };

  const handleManualScrape = async () => {
    if (onManualScrape && !scrapingLoading) {
      setScrapingLoading(true);
      try {
        await onManualScrape(character.id);
      } finally {
        setScrapingLoading(false);
      }
    }
  };

  // Função para filtros rápidos via tags
  const handleQuickFilter = (filterType, value) => {
    console.log(`[CHARACTER_CARD] handleQuickFilter chamado: ${filterType} = ${value}`);
    if (onQuickFilter) {
      console.log(`[CHARACTER_CARD] Chamando onQuickFilter...`);
      onQuickFilter(filterType, value);
    } else {
      console.log(`[CHARACTER_CARD] onQuickFilter não está definido`);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'Nunca';
    try {
      return format(new Date(dateString), 'dd/MM/yyyy HH:mm', { locale: ptBR });
    } catch {
      return 'Data inválida';
    }
  };

  const getVocationColor = (vocation) => {
    const colors = {
      'Sorcerer': 'bg-blue-100 text-blue-800',
      'Master Sorcerer': 'bg-blue-100 text-blue-800',
      'Druid': 'bg-green-100 text-green-800',
      'Elder Druid': 'bg-green-100 text-green-800',
      'Paladin': 'bg-yellow-100 text-yellow-800',
      'Royal Paladin': 'bg-yellow-100 text-yellow-800',
      'Knight': 'bg-red-100 text-red-800',
      'Elite Knight': 'bg-red-100 text-red-800',
    };
    return colors[vocation] || 'bg-gray-100 text-gray-800';
  };

  const getTibiaUrl = (character) => {
    // Mapear servidores para URLs corretas
    const serverUrls = {
      'taleon': `https://${character.world}.taleon.online`,
      'rubini': 'https://rubini.com.br',
      // Adicionar outros servidores conforme necessário
    };
    
    const baseUrl = serverUrls[character.server] || 'https://tibia.com';
    return `${baseUrl}/characterprofile.php?name=${encodeURIComponent(character.name)}`;
  };

  const latest = character.latest_snapshot;

  return (
    <Card className={`h-full flex flex-col transition-all duration-200 hover:shadow-lg hover:-translate-y-1 ${
      isInComparison ? 'ring-2 ring-primary' : ''
    }`}>
      <CardContent className="flex-1 p-4">
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center flex-1">
            {/* Outfit Image or Fallback Icon */}
            {character.outfit_image_url ? (
              <img
                src={character.outfit_image_url}
                alt={`Outfit de ${character.name}`}
                className="w-8 h-8 mr-2 rounded"
                onError={(e) => { e.target.style.display = 'none'; }}
              />
            ) : (
              <User className="w-5 h-5 mr-2 text-primary" />
            )}
            <CardTitle className="text-lg font-semibold truncate">
              {character.name}
            </CardTitle>
            <Button
              variant="ghost"
              size="sm"
              asChild
              className="ml-2 h-6 w-6 p-0"
            >
              <a
                href={getTibiaUrl(character)}
                target="_blank"
                rel="noopener noreferrer"
                title="Ver no Tibia"
              >
                <ExternalLink className="h-4 w-4" />
              </a>
            </Button>
          </div>
          
          <div className="flex gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={handleToggleFavorite}
              className="h-8 w-8 p-0"
            >
              {isFavorite(character.id) ? (
                <Star className="h-4 w-4 text-yellow-500 fill-current" />
              ) : (
                <Star className="h-4 w-4" />
              )}
            </Button>
            
            {onAddToComparison && (
              <Button
                variant="ghost"
                size="sm"
                onClick={handleToggleComparison}
                className={`h-8 w-8 p-0 ${
                  isInComparison ? 'bg-primary/10 text-primary' : ''
                }`}
                title={isInComparison ? "Remover da Comparação" : "Adicionar à Comparação"}
              >
                {isInComparison ? (
                  <GitCompare className="h-4 w-4" />
                ) : (
                  <GitCompare className="h-4 w-4" />
                )}
              </Button>
            )}
          </div>
        </div>

        {/* Server/World Info - Tags clicáveis para filtros rápidos */}
        <div className="flex gap-2 mb-4 flex-wrap">
          <Badge 
            variant="outline"
            className="cursor-pointer hover:bg-primary/10"
            onClick={() => handleQuickFilter('server', character.server)}
          >
            {character.server}/{character.world}
          </Badge>
          {character.vocation && (
            <Badge 
              variant="outline"
              className={`cursor-pointer hover:bg-primary/10 ${getVocationColor(character.vocation)}`}
              onClick={() => handleQuickFilter('vocation', character.vocation)}
            >
              {character.vocation}
            </Badge>
          )}
          {character.guild && (
            <Badge 
              variant="outline"
              className="cursor-pointer hover:bg-secondary/10"
              onClick={() => handleQuickFilter('guild', character.guild)}
            >
              {character.guild}
            </Badge>
          )}
          
          {/* Recovery Status Badge */}
          <Badge 
            variant="outline"
            className={`cursor-pointer ${
              character.recovery_active 
                ? 'border-green-200 text-green-700 hover:bg-green-50' 
                : 'border-yellow-200 text-yellow-700 hover:bg-yellow-50'
            }`}
            onClick={handleToggleRecovery}
            disabled={recoveryLoading}
            title={
              character.recovery_active 
                ? "Recuperação Ativa - Clique para desativar scraping automático"
                : "Recuperação Inativa - Clique para ativar scraping automático"
            }
          >
            {character.recovery_active ? (
              <Play className="w-3 h-3 mr-1" />
            ) : (
              <Pause className="w-3 h-3 mr-1" />
            )}
            {character.recovery_active ? "Recuperação Ativa" : "Recuperação Inativa"}
          </Badge>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-sm text-muted-foreground">Level</p>
            <p className="text-lg font-semibold">
              {(latest?.level || character.level || 0).toLocaleString('pt-BR')}
            </p>
          </div>
          
          <div>
            <p className="text-sm text-muted-foreground">
              {character.last_experience_date 
                ? `Exp. Total (último dia - ${character.last_experience_date})`
                : 'Exp. Total (último dia)'
              }
            </p>
            <p className="text-base font-medium">
              {character.last_experience 
                ? character.last_experience.toLocaleString('pt-BR')
                : 'N/A'
              }
            </p>
          </div>
          
          <div>
            <p className="text-sm text-muted-foreground">Mortes</p>
            <p className="text-base font-medium">
              {(latest?.deaths || character.deaths || 0).toLocaleString('pt-BR')}
            </p>
          </div>
        </div>

        {/* Experience Progress */}
        {(() => {
          const exp = latest?.experience || character.experience;
          const totalGained = character.total_exp_gained || character.exp_gained || 0;
          return exp ? (
            <div className="mb-4">
              <div className="flex justify-between mb-2">
                <p className="text-sm text-muted-foreground">Exp. Ganha (30 dias)</p>
                <p className="text-sm text-muted-foreground">
                  +{totalGained.toLocaleString('pt-BR')}
                </p>
              </div>
              <Progress 
                value={Math.min(totalGained / 1000000 * 100, 100)}
                className="h-2"
              />
            </div>
          ) : null;
        })()}

        {/* Last Update */}
        <div className="flex items-center text-muted-foreground text-sm">
          <Clock className="w-4 h-4 mr-1" />
          <span>Atualizado: {formatDate(character.last_scraped_at)}</span>
        </div>
      </CardContent>

      {/* Actions */}
      <div className="flex justify-between p-4 pt-0">
        <Button
          size="sm"
          variant="outline"
          onClick={handleViewCharts}
        >
          <BarChart3 className="w-4 h-4 mr-2" />
          Gráficos
        </Button>
        
        {onRefresh && (
          <Button
            size="sm"
            variant="outline"
            onClick={handleRefresh}
            disabled={refreshing}
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            {refreshing ? 'Atualizando...' : 'Atualizar'}
          </Button>
        )}
      </div>
    </Card>
  );
};

export default CharacterCard; 