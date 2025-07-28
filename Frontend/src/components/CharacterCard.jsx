import React, { useState } from 'react';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { 
  Heart, 
  TrendingUp, 
  BarChart3, 
  RefreshCw, 
  Users, 
  Crown, 
  Sword, 
  Shield, 
  Zap, 
  Skull,
  ExternalLink,
  GitCompare
} from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
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

  const vocationIcons = {
    "Knight": Shield,
    "Elite Knight": Shield,
    "Paladin": Users,
    "Royal Paladin": Users,
    "Sorcerer": Zap,
    "Master Sorcerer": Zap,
    "Druid": Crown,
    "Elder Druid": Crown,
  };

  const vocationColors = {
    "Knight": "text-blue-600 dark:text-blue-400",
    "Elite Knight": "text-blue-700 dark:text-blue-300",
    "Paladin": "text-green-600 dark:text-green-400",
    "Royal Paladin": "text-green-700 dark:text-green-300",
    "Sorcerer": "text-purple-600 dark:text-purple-400",
    "Master Sorcerer": "text-purple-700 dark:text-purple-300",
    "Druid": "text-orange-600 dark:text-orange-400",
    "Elder Druid": "text-orange-700 dark:text-orange-300",
  };

  const handleRefresh = async () => {
    if (onRefresh && !refreshing) {
      setRefreshing(true);
      try {
        await onRefresh(character.id);
        toast({
          title: "Atualizado!",
          description: "Dados do personagem atualizados com sucesso",
          variant: "success"
        });
      } catch (error) {
        toast({
          title: "Erro",
          description: "Erro ao atualizar dados do personagem",
          variant: "destructive"
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
      description: `${character.name} ${isFavorite(character.id) ? 'removido' : 'adicionado'} aos favoritos`,
      variant: "success"
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
        description: `${character.name} removido da comparação`,
        variant: "info"
      });
    } else {
      onAddToComparison?.(character);
      toast({
        title: "Adicionado à comparação",
        description: `${character.name} adicionado à comparação`,
        variant: "success"
      });
    }
  };

  const handleToggleRecovery = async () => {
    if (onToggleRecovery && !recoveryLoading) {
      setRecoveryLoading(true);
      try {
        await onToggleRecovery(character.id);
        toast({
          title: "Recovery atualizado",
          description: "Status de recovery alterado",
          variant: "success"
        });
      } catch (error) {
        toast({
          title: "Erro",
          description: "Erro ao alterar status de recovery",
          variant: "destructive"
        });
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
        toast({
          title: "Scraping realizado",
          description: "Dados atualizados via scraping manual",
          variant: "success"
        });
      } catch (error) {
        toast({
          title: "Erro no scraping",
          description: "Erro ao realizar scraping manual",
          variant: "destructive"
        });
      } finally {
        setScrapingLoading(false);
      }
    }
  };

  const formatExperience = (exp) => {
    if (exp >= 1000000000) return `${(exp / 1000000000).toFixed(1)}B`;
    if (exp >= 1000000) return `${(exp / 1000000).toFixed(1)}M`;
    if (exp >= 1000) return `${(exp / 1000).toFixed(1)}K`;
    return exp.toString();
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    try {
      return format(new Date(dateString), 'dd/MM/yyyy HH:mm', { locale: ptBR });
    } catch {
      return 'Data inválida';
    }
  };

  const getVocationIcon = (vocation) => {
    return vocationIcons[vocation] || Sword;
  };

  const getVocationColor = (vocation) => {
    return vocationColors[vocation] || "text-foreground";
  };

  const getTibiaUrl = (character) => {
    return `https://www.tibia.com/community/?name=${encodeURIComponent(character.name)}`;
  };

  const VocationIcon = getVocationIcon(character.vocation);
  const vocationColor = getVocationColor(character.vocation);

  return (
    <Card className="tibia-card group hover:shadow-[var(--shadow-hover)] transition-all duration-300">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex items-center space-x-3">
            <div className="relative">
              <div className="w-12 h-12 bg-gradient-to-br from-primary/20 to-secondary/20 rounded-lg flex items-center justify-center">
                <VocationIcon className={`w-6 h-6 ${vocationColor}`} />
              </div>
              {character.is_online && (
                <div className="absolute -top-1 -right-1 w-4 h-4 bg-success rounded-full border-2 border-background"></div>
              )}
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="text-lg font-semibold text-foreground truncate">
                {character.name}
              </h3>
              <div className="flex items-center space-x-2 mt-1">
                <Badge variant="outline" className="text-xs">
                  {character.vocation}
                </Badge>
                <Badge variant="outline" className="text-xs">
                  {character.world}
                </Badge>
              </div>
            </div>
          </div>
          
          <div className="flex items-center space-x-1">
            <Button
              variant="ghost"
              size="icon"
              onClick={handleToggleFavorite}
              className="h-8 w-8"
            >
              {isFavorite(character.id) ? (
                <Heart className="h-4 w-4 fill-current text-destructive" />
              ) : (
                <Heart className="h-4 w-4" />
              )}
            </Button>
            
            <Button
              variant="ghost"
              size="icon"
              onClick={handleToggleComparison}
              className={`h-8 w-8 ${isInComparison ? 'bg-primary/10' : ''}`}
            >
              <GitCompare className={`h-4 w-4 ${isInComparison ? 'text-primary' : ''}`} />
            </Button>
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Level and Experience */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Nível</span>
            <span className="text-lg font-bold text-primary">
              {character.latest_snapshot?.level || character.level || 'N/A'}
            </span>
          </div>
          
          <div className="space-y-1">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground">Experiência</span>
              <span className="font-medium">
                {formatExperience(character.latest_snapshot?.experience || character.experience || 0)}
              </span>
            </div>
            
            {character.exp_gained && (
              <div className="flex items-center justify-between text-xs">
                <span className="text-muted-foreground">Ganho 24h</span>
                <span className="text-success font-medium">
                  +{formatExperience(character.exp_gained)}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Status Badges */}
        <div className="flex flex-wrap gap-2">
          {character.is_online ? (
            <Badge variant="online">Online</Badge>
          ) : (
            <Badge variant="offline">Offline</Badge>
          )}
          
          {character.recovery_active && (
            <Badge variant="recovery">Recovery Ativo</Badge>
          )}
          
          {character.guild && (
            <Badge variant="outline" className="text-xs">
              {character.guild}
            </Badge>
          )}
        </div>

        {/* Last Update */}
        {character.last_experience_date && (
          <div className="text-xs text-muted-foreground">
            Última atualização: {formatDate(character.last_experience_date)}
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center justify-between pt-2">
          <div className="flex items-center space-x-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={handleRefresh}
              disabled={refreshing}
              className="h-8 px-2"
            >
              <RefreshCw className={`h-3 w-3 ${refreshing ? 'animate-spin' : ''}`} />
            </Button>
            
            <Button
              variant="ghost"
              size="sm"
              onClick={handleViewCharts}
              className="h-8 px-2"
            >
              <BarChart3 className="h-3 w-3" />
            </Button>
            
            <Button
              variant="ghost"
              size="sm"
              onClick={() => window.open(getTibiaUrl(character), '_blank')}
              className="h-8 px-2"
            >
              <ExternalLink className="h-3 w-3" />
            </Button>
          </div>
          
          {onToggleRecovery && (
            <Button
              variant="outline"
              size="sm"
              onClick={handleToggleRecovery}
              disabled={recoveryLoading}
              className="h-8"
            >
              {character.recovery_active ? 'Desativar Recovery' : 'Ativar Recovery'}
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

export default CharacterCard; 