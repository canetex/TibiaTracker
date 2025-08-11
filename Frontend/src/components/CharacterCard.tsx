import React, { useState } from 'react';
import { Card, CardContent } from './ui/card';
import { Avatar, AvatarImage, AvatarFallback } from './ui/avatar';
import { Button } from './ui/button';
import { Badge } from './ui/badge';
import { Progress } from './ui/progress';
import { Heart, RefreshCw, User } from 'lucide-react';
import { formatNumber, getVocationColor, getTibiaUrl } from '../lib/utils';

interface CharacterCardProps {
  character: {
    id: number;
    name: string;
    level: number;
    vocation: string;
    world: string;
    server: string;
    guild?: string;
    isOnline: boolean;
    recoveryActive: boolean;
    isFavorite: boolean;
    deaths: number;
    lastLogin: string;
    experienceGained24h?: number;
    levelProgress: number;
    outfitImageUrl?: string;
  };
  onViewCharts: (character: any) => void;
  onRestartTracking: (character: any) => void;
  onToggleFavorite: (character: any) => void;
}

export function CharacterCard({
  character,
  onViewCharts,
  onRestartTracking,
  onToggleFavorite,
}: CharacterCardProps) {
  const [imageError, setImageError] = useState(false);
  const vocationColor = getVocationColor(character.vocation);
  const tibiaUrl = getTibiaUrl(character);

  const handleImageError = () => {
    setImageError(true);
  };

  return (
    <Card className="tibia-card group hover:scale-[1.02] transition-all duration-300">
      <CardContent className="p-4">
        <div className="flex items-start gap-4">
          <div className="relative">
            <Avatar className="h-16 w-16">
              {!imageError && character.outfitImageUrl ? (
                <AvatarImage
                  src={character.outfitImageUrl}
                  alt={character.name}
                  onError={handleImageError}
                />
              ) : (
                <AvatarFallback>
                  <User className="h-8 w-8" />
                </AvatarFallback>
              )}
            </Avatar>
            {character.isOnline && (
              <div className="absolute -top-1 -right-1 h-3 w-3 rounded-full bg-success" />
            )}
          </div>

          <div className="flex-1">
            <div className="flex items-start justify-between">
              <div>
                <a
                  href={tibiaUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-lg font-semibold hover:underline"
                >
                  {character.name}
                </a>
                <p className="text-sm text-muted-foreground">
                  Level {character.level} {character.vocation}
                </p>
                <p className="text-xs text-muted-foreground">
                  {character.server} • {character.world}
                  {character.guild && ` • ${character.guild}`}
                </p>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => onToggleFavorite(character)}
                className="opacity-0 group-hover:opacity-100 transition-opacity"
              >
                <Heart
                  className={`h-4 w-4 ${character.isFavorite ? 'fill-primary text-primary' : ''}`}
                />
              </Button>
            </div>

            <div className="mt-4 space-y-3">
              <div>
                <div className="flex items-center justify-between text-sm mb-1">
                  <span className="text-muted-foreground">Level Progress</span>
                  <span>{Math.round(character.levelProgress * 100)}%</span>
                </div>
                <Progress value={character.levelProgress * 100} className="h-2" />
              </div>

              <div className="flex flex-wrap gap-2">
                <Badge variant={character.isOnline ? 'default' : 'secondary'}>
                  {character.isOnline ? 'Online' : 'Offline'}
                </Badge>
                {character.recoveryActive && (
                  <Badge variant="destructive">Em Recuperação</Badge>
                )}
                {character.experienceGained24h !== undefined && (
                  <Badge variant={vocationColor}>
                    +{formatNumber(character.experienceGained24h)} exp
                  </Badge>
                )}
              </div>
            </div>

            <div className="mt-4 flex items-center justify-between gap-2">
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => onViewCharts(character)}
              >
                Ver Gráficos
              </Button>
              <Button
                variant="outline"
                size="icon"
                onClick={() => onRestartTracking(character)}
              >
                <RefreshCw className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
} 