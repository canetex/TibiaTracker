import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Search, Loader2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

const CharacterSearch = ({ onSearch, loading = false }) => {
  const [formData, setFormData] = useState({
    name: '',
    server: 'taleon',
    world: 'san',
  });

  const [errors, setErrors] = useState({});
  const { toast } = useToast();

  // Configuração dos servidores e mundos
  const serverConfig = {
    taleon: {
      label: 'Taleon',
      worlds: [
        { value: 'san', label: 'San' },
        { value: 'aura', label: 'Aura' },
        { value: 'gaia', label: 'Gaia' },
      ],
    },
    rubini: {
      label: 'Rubini',
      worlds: [],
      disabled: true,
    },
    deus_ot: {
      label: 'DeusOT',
      worlds: [],
      disabled: true,
    },
    tibia: {
      label: 'Tibia',
      worlds: [],
      disabled: true,
    },
    pegasus_ot: {
      label: 'PegasusOT',
      worlds: [],
      disabled: true,
    },
  };

  const handleInputChange = (field, value) => {
    setFormData(prev => {
      const newData = { ...prev, [field]: value };
      
      // Se mudou o servidor, resetar o mundo para o primeiro disponível
      if (field === 'server') {
        const worlds = serverConfig[value]?.worlds || [];
        newData.world = worlds.length > 0 ? worlds[0].value : '';
      }
      
      return newData;
    });

    // Limpar erro do campo
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: null }));
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Nome do personagem é obrigatório';
    } else if (formData.name.trim().length < 2) {
      newErrors.name = 'Nome deve ter pelo menos 2 caracteres';
    }

    if (!formData.server) {
      newErrors.server = 'Selecione um servidor';
    }

    if (!formData.world) {
      newErrors.world = 'Selecione um mundo';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (event) => {
    event.preventDefault();
    
    if (!validateForm()) {
      toast({
        title: "Erro de validação",
        description: "Por favor, corrija os campos marcados",
        variant: "destructive"
      });
      return;
    }

    if (onSearch) {
      onSearch(formData);
    }
  };

  const handleKeyPress = (event) => {
    if (event.key === 'Enter') {
      handleSubmit(event);
    }
  };

  const currentServer = serverConfig[formData.server];
  const availableWorlds = currentServer?.worlds || [];

  return (
    <Card className="tibia-card">
      <CardHeader>
        <CardTitle className="flex items-center space-x-2">
          <Search className="h-5 w-5" />
          <span>Buscar Personagem</span>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Nome do Personagem */}
            <div className="space-y-2">
              <Label htmlFor="name">Nome do Personagem</Label>
              <Input
                id="name"
                type="text"
                placeholder="Digite o nome do personagem"
                value={formData.name}
                onChange={(e) => handleInputChange('name', e.target.value)}
                onKeyPress={handleKeyPress}
                className={errors.name ? 'border-destructive' : ''}
              />
              {errors.name && (
                <p className="text-sm text-destructive">{errors.name}</p>
              )}
            </div>

            {/* Servidor */}
            <div className="space-y-2">
              <Label htmlFor="server">Servidor</Label>
              <Select
                value={formData.server}
                onValueChange={(value) => handleInputChange('server', value)}
                disabled={loading}
              >
                <SelectTrigger className={errors.server ? 'border-destructive' : ''}>
                  <SelectValue placeholder="Selecione um servidor" />
                </SelectTrigger>
                <SelectContent>
                  {Object.entries(serverConfig).map(([key, config]) => (
                    <SelectItem 
                      key={key} 
                      value={key}
                      disabled={config.disabled}
                    >
                      {config.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.server && (
                <p className="text-sm text-destructive">{errors.server}</p>
              )}
            </div>

            {/* Mundo */}
            <div className="space-y-2">
              <Label htmlFor="world">Mundo</Label>
              <Select
                value={formData.world}
                onValueChange={(value) => handleInputChange('world', value)}
                disabled={loading || availableWorlds.length === 0}
              >
                <SelectTrigger className={errors.world ? 'border-destructive' : ''}>
                  <SelectValue placeholder="Selecione um mundo" />
                </SelectTrigger>
                <SelectContent>
                  {availableWorlds.map((world) => (
                    <SelectItem key={world.value} value={world.value}>
                      {world.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.world && (
                <p className="text-sm text-destructive">{errors.world}</p>
              )}
            </div>
          </div>

          {/* Botão de Busca */}
          <div className="flex justify-end">
            <Button
              type="submit"
              variant="tibia"
              disabled={loading}
              className="min-w-[120px]"
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Buscando...
                </>
              ) : (
                <>
                  <Search className="mr-2 h-4 w-4" />
                  Buscar
                </>
              )}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
};

export default CharacterSearch; 