import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { 
  X, 
  GitCompare, 
  TrendingUp, 
  Users,
  Crown,
  Shield,
  Zap
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

const ComparisonPanel = ({ 
  characters = [], 
  onRemoveCharacter, 
  onShowComparison, 
  onClearAll,
  maxCharacters = 50 
}) => {
  const { toast } = useToast();

  if (characters.length === 0) {
    return null;
  }

  const handleShowComparison = () => {
    if (characters.length < 2) {
      toast({
        title: "Seleção insuficiente",
        description: "Selecione pelo menos 2 personagens para comparar",
        variant: "warning"
      });
      return;
    }
    onShowComparison();
  };

  const handleClearAll = () => {
    onClearAll();
    toast({
      title: "Comparação limpa",
      description: "Todos os personagens foram removidos da comparação",
      variant: "info"
    });
  };

  const handleRemoveCharacter = (characterId, characterName) => {
    onRemoveCharacter(characterId);
    toast({
      title: "Personagem removido",
      description: `${characterName} removido da comparação`,
      variant: "info"
    });
  };

  const getVocationIcon = (vocation) => {
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
    return vocationIcons[vocation] || Users;
  };

  const getVocationColor = (vocation) => {
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
    return vocationColors[vocation] || "text-foreground";
  };

  const formatExperience = (exp) => {
    if (exp >= 1000000000) return `${(exp / 1000000000).toFixed(1)}B`;
    if (exp >= 1000000) return `${(exp / 1000000).toFixed(1)}M`;
    if (exp >= 1000) return `${(exp / 1000).toFixed(1)}K`;
    return exp.toString();
  };

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 p-4 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-t border-border">
      <Card className="tibia-card max-w-7xl mx-auto">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <GitCompare className="h-5 w-5 text-primary" />
              <CardTitle className="text-lg">Comparação de Personagens</CardTitle>
              <Badge variant="secondary" className="ml-2">
                {maxCharacters ? `${characters.length}/${maxCharacters}` : `${characters.length}`}
              </Badge>
            </div>
            
            <div className="flex items-center space-x-2">
              <Button
                variant="tibia"
                size="sm"
                onClick={handleShowComparison}
                disabled={characters.length < 2}
                className="min-w-[140px]"
              >
                <TrendingUp className="mr-2 h-4 w-4" />
                Comparar ({characters.length})
              </Button>
              
              <Button
                variant="outline"
                size="sm"
                onClick={handleClearAll}
                className="min-w-[120px]"
              >
                <X className="mr-2 h-4 w-4" />
                Limpar Todos
              </Button>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-border scrollbar-track-transparent">
            {characters.map((character) => {
              const VocationIcon = getVocationIcon(character.vocation);
              const vocationColor = getVocationColor(character.vocation);
              
              return (
                <div
                  key={character.id}
                  className="flex-shrink-0 flex items-center space-x-3 p-3 bg-muted/50 rounded-lg border border-border/50 hover:border-border transition-colors"
                >
                  {/* Avatar com ícone da vocação */}
                  <Avatar className="h-10 w-10">
                    <AvatarFallback className="bg-gradient-to-br from-primary/20 to-secondary/20">
                      <VocationIcon className={`h-5 w-5 ${vocationColor}`} />
                    </AvatarFallback>
                  </Avatar>

                  {/* Informações do personagem */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <h4 className="font-semibold text-sm truncate">
                        {character.name}
                      </h4>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => handleRemoveCharacter(character.id, character.name)}
                        className="h-6 w-6 ml-2"
                      >
                        <X className="h-3 w-3" />
                      </Button>
                    </div>
                    
                    <div className="flex items-center space-x-2 mt-1">
                      <Badge variant="outline" className="text-xs">
                        {character.vocation}
                      </Badge>
                      <Badge variant="outline" className="text-xs">
                        {character.world}
                      </Badge>
                    </div>
                    
                    <div className="flex items-center justify-between mt-2 text-xs text-muted-foreground">
                      <span>Nível {character.latest_snapshot?.level || character.level || 'N/A'}</span>
                      <span className="font-medium">
                        {formatExperience(character.latest_snapshot?.experience || character.experience || 0)}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Dicas */}
          {characters.length < 2 && (
            <div className="text-center text-sm text-muted-foreground mt-3">
              Selecione pelo menos 2 personagens para iniciar a comparação
            </div>
          )}
          
          {characters.length >= maxCharacters && (
            <div className="text-center text-sm text-warning mt-3">
              Limite máximo de {maxCharacters} personagens atingido
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default ComparisonPanel; 