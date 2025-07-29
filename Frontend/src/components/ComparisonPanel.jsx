import React from 'react';
import { X, GitCompare, TrendingUp, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';

const ComparisonPanel = ({ 
  characters = [], 
  onRemoveCharacter, 
  onShowComparison, 
  onClearAll,
  maxCharacters = 50 
}) => {
  if (characters.length === 0) {
    return null;
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-background border-t-2 border-primary p-4 shadow-lg">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <GitCompare className="h-5 w-5 text-primary" />
          <h3 className="text-lg font-semibold">
            Comparação de Personagens
          </h3>
          <Badge 
            variant={maxCharacters && characters.length >= maxCharacters ? "destructive" : "secondary"}
          >
            {maxCharacters ? `${characters.length}/${maxCharacters}` : `${characters.length}`}
          </Badge>
        </div>
        
        <div className="flex gap-2">
          <Button
            onClick={onShowComparison}
            disabled={characters.length < 2}
            size="sm"
          >
            <TrendingUp className="mr-2 h-4 w-4" />
            Comparar ({characters.length})
          </Button>
          
          <Button
            variant="outline"
            onClick={onClearAll}
            size="sm"
          >
            Limpar Todos
          </Button>
        </div>
      </div>

      {/* Character Mini Cards */}
      <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100">
        {characters.map((character) => (
          <Card
            key={character.id}
            className="min-w-[200px] border-primary bg-primary/5"
          >
            <CardContent className="p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-1">
                  <User className="h-4 w-4 text-primary" />
                  <span className="text-sm font-semibold">
                    {character.name}
                  </span>
                </div>
                
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => onRemoveCharacter(character.id)}
                  className="h-6 w-6 p-0 text-destructive hover:bg-destructive/10"
                  title="Remover da comparação"
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>

              <div className="flex gap-1 flex-wrap mb-2">
                <Badge variant="outline" className="text-xs h-5">
                  {character.server}/{character.world}
                </Badge>
                {character.vocation && (
                  <Badge variant="outline" className="text-xs h-5">
                    {character.vocation}
                  </Badge>
                )}
              </div>

              <div className="flex justify-between items-center">
                <span className="text-xs text-muted-foreground">Level:</span>
                <span className="text-sm font-semibold">
                  {character.level || 0}
                </span>
              </div>

              {character.guild && (
                <div className="flex justify-between items-center mt-1">
                  <span className="text-xs text-muted-foreground">Guild:</span>
                  <span className="text-xs font-medium">
                    {character.guild}
                  </span>
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Warning when max characters reached */}
      {maxCharacters && characters.length >= maxCharacters && (
        <Alert className="mt-2">
          <AlertDescription className="font-medium">
            ⚠️ Limite máximo de {maxCharacters} personagens atingido. 
            Remova um personagem para adicionar outro.
          </AlertDescription>
        </Alert>
      )}
    </div>
  );
};

export default ComparisonPanel; 