import React, { useState } from 'react';
import {
  Card,
  CardContent,
  CardFooter,
} from './ui/card';
import { Button } from './ui/button';
import { Badge } from './ui/badge';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import {
  Star,
  RefreshCw,
  BarChart3,
  ExternalLink,
  User,
  Clock,
  Play,
  Pause,
  TrendingUp,
} from 'lucide-react';
import { toast } from 'sonner';
import { useFavorites } from '../contexts/FavoritesContext';
import { formatNumber, formatDate, getVocationColor, getTibiaUrl } from '../lib/utils';

interface Character {
  id: string;
  name: string;
  level: number;
  vocation: string;
  world: string;
  server: string;
  experience: number;
  guild?: string;
  isOnline: boolean;
  recoveryActive: boolean;
  isFavorite: boolean;
  deaths: number;
  lastLogin: string;
  experienceGained24h?: number;
  levelProgress: number;
  pvpType: "Optional PvP" | "Open PvP" | "Retro Open PvP" | "Hardcore PvP";
  outfitImageUrl?: string;
  lastScrapedAt?: string;
  latestSnapshot?: {
    level: number;
    experience: number;
    deaths: number;
  };
  lastExperience?: number;
  lastExperienceDate?: string;
  totalExpGained?: number;
  expGained?: number;
}

interface CharacterCardProps {
  character: Character;
  onRefresh?: (id: string) => Promise<void>;
  onViewCharts?: (character: Character) => void;
  onAddToComparison?: (character: Character) => void;
  onRemoveFromComparison?: (id: string) => void;
  isInComparison?: boolean;
  onQuickFilter?: (filterType: string, value: string) => void;
  onToggleRecovery?: (id: string) => Promise<void>;
  onManualScrape?: (id: string) => Promise<void>;
}

export function CharacterCard({
  character,
  onRefresh,
  onViewCharts,
  onAddToComparison,
  onRemoveFromComparison,
  isInComparison = false,
  onQuickFilter,
  onToggleRecovery,
  onManualScrape,
}: CharacterCardProps) {
  const [refreshing, setRefreshing] = useState(false);
  const [recoveryLoading, setRecoveryLoading] = useState(false);
  const { toggleFavorite, isFavorite } = useFavorites();

  const handleRefresh = async () => {
    if (onRefresh && !refreshing) {
      setRefreshing(true);
      try {
        await onRefresh(character.id);
        toast.success('Personagem atualizado com sucesso!');
      } catch (error) {
        toast.error('Erro ao atualizar personagem');
      } finally {
        setRefreshing(false);
      }
    }
  };

  const handleToggleFavorite = () => {
    toggleFavorite(character.id);
    const isFav = isFavorite(character.id);
    toast.success(isFav ? 'Removido dos favoritos' : 'Adicionado aos favoritos');
  };

  const handleViewCharts = () => {
    if (onViewCharts) {
      onViewCharts(character);
    }
  };

  const handleToggleRecovery = async () => {
    if (onToggleRecovery && !recoveryLoading) {
      setRecoveryLoading(true);
      try {
        await onToggleRecovery(character.id);
        toast.success(
          character.recoveryActive
            ? 'Recuperação desativada'
            : 'Recuperação ativada'
        );
      } catch (error) {
        toast.error('Erro ao alterar status de recuperação');
      } finally {
        setRecoveryLoading(false);
      }
    }
  };

  const handleQuickFilter = (filterType: string, value: string) => {
    if (onQuickFilter) {
      onQuickFilter(filterType, value);
    }
  };

  const latest = character.latestSnapshot;
  const experience = character.lastExperience || 0;
  const totalGained = character.totalExpGained || character.expGained || 0;

  return (
    <Card className={`relative overflow-hidden ${isInComparison ? 'ring-2 ring-primary' : ''}`}>
      <CardContent className="p-6">
        {/* Header with Avatar and Name */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center space-x-3">
            <Avatar>
              <AvatarImage
                src={character.outfitImageUrl}
                alt={`Outfit de ${character.name}`}
              />
              <AvatarFallback>
                <User className="h-6 w-6 text-muted-foreground" />
              </AvatarFallback>
            </Avatar>
            <div>
              <h3 className="font-semibold text-lg leading-tight mb-1">
                {character.name}
              </h3>
              <div className="flex items-center space-x-2">
                <Badge
                  variant="outline"
                  className="cursor-pointer hover:bg-muted"
                  onClick={() => handleQuickFilter('server', character.server)}
                >
                  {character.server}/{character.world}
                </Badge>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-6 w-6"
                  asChild
                >
                  <a
                    href={getTibiaUrl(character)}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </Button>
              </div>
            </div>
          </div>

          <Button
            variant="ghost"
            size="icon"
            onClick={handleToggleFavorite}
            className={`${isFavorite(character.id) ? 'text-yellow-500' : 'text-muted-foreground'}`}
          >
            <Star className={`h-5 w-5 ${isFavorite(character.id) ? 'fill-current' : ''}`} />
          </Button>
        </div>

        {/* Tags/Badges */}
        <div className="flex flex-wrap gap-2 mb-4">
          {character.vocation && (
            <Badge
              variant={getVocationColor(character.vocation)}
              className="cursor-pointer"
              onClick={() => handleQuickFilter('vocation', character.vocation)}
            >
              {character.vocation}
            </Badge>
          )}
          {character.guild && (
            <Badge
              variant="secondary"
              className="cursor-pointer"
              onClick={() => handleQuickFilter('guild', character.guild)}
            >
              {character.guild}
            </Badge>
          )}
          <Badge
            variant={character.recoveryActive ? "success" : "warning"}
            className="cursor-pointer"
            onClick={handleToggleRecovery}
          >
            {character.recoveryActive ? <Play className="h-3 w-3 mr-1" /> : <Pause className="h-3 w-3 mr-1" />}
            {character.recoveryActive ? "Ativo" : "Inativo"}
          </Badge>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-sm text-muted-foreground">Level</p>
            <p className="text-xl font-bold">
              {formatNumber(latest?.level || character.level || 0)}
            </p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Mortes</p>
            <p className="text-lg font-semibold">
              {formatNumber(latest?.deaths || character.deaths || 0)}
            </p>
          </div>
          <div className="col-span-2">
            <p className="text-sm text-muted-foreground">
              Exp. {character.lastExperienceDate ? `(${character.lastExperienceDate})` : '(último dia)'}
            </p>
            <p className="text-lg font-semibold">
              {formatNumber(experience)}
            </p>
          </div>
        </div>

        {/* Experience Progress */}
        {totalGained > 0 && (
          <div className="mb-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-muted-foreground flex items-center">
                <TrendingUp className="h-4 w-4 mr-1" />
                Progresso (30 dias)
              </span>
              <span className="text-sm font-medium text-primary">
                +{formatNumber(totalGained)}
              </span>
            </div>
            <div className="w-full bg-muted rounded-full h-2">
              <div
                className="bg-gradient-primary h-2 rounded-full transition-all duration-300"
                style={{ width: `${Math.min(totalGained / 1000000 * 100, 100)}%` }}
              />
            </div>
          </div>
        )}

        {/* Last Update */}
        <div className="flex items-center text-xs text-muted-foreground">
          <Clock className="h-3 w-3 mr-1" />
          Atualizado: {formatDate(character.lastScrapedAt)}
        </div>
      </CardContent>

      <CardFooter className="p-6 pt-0 flex justify-between">
        <Button
          variant="outline"
          size="sm"
          onClick={handleViewCharts}
          className="flex-1 mr-2"
        >
          <BarChart3 className="h-4 w-4 mr-2" />
          Gráficos
        </Button>

        <Button
          variant="outline"
          size="sm"
          onClick={handleRefresh}
          disabled={refreshing}
          className="flex-1 ml-2"
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
          {refreshing ? 'Atualizando...' : 'Atualizar'}
        </Button>
      </CardFooter>
    </Card>
  );
} 