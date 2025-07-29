import React, { useState } from 'react';
import { Search, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

const CharacterSearch = ({ onSearch, loading = false }) => {
  const [formData, setFormData] = useState({
    name: '',
    server: 'taleon',
    world: 'san',
  });

  const [errors, setErrors] = useState({});

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
    // Adicionar outros servidores no futuro
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

  const handleInputChange = (field) => (event) => {
    const value = event.target.value;
    
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

  const handleSelectChange = (field, value) => {
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
    
    if (validateForm() && !loading) {
      onSearch({
        name: formData.name.trim(),
        server: formData.server,
        world: formData.world,
      });
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
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
        {/* Nome do Personagem */}
        <div className="space-y-2">
          <Label htmlFor="name">Nome do Personagem</Label>
          <Input
            id="name"
            value={formData.name}
            onChange={handleInputChange('name')}
            onKeyPress={handleKeyPress}
            placeholder="Ex: Gates, Galado, Wild Warior"
            disabled={loading}
            autoComplete="off"
            className={errors.name ? 'border-red-500' : ''}
          />
          {errors.name && (
            <p className="text-sm text-red-500">{errors.name}</p>
          )}
        </div>

        {/* Servidor */}
        <div className="space-y-2">
          <Label htmlFor="server">Servidor</Label>
          <Select
            value={formData.server}
            onValueChange={(value) => handleSelectChange('server', value)}
            disabled={loading}
          >
            <SelectTrigger className={errors.server ? 'border-red-500' : ''}>
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
                  {config.disabled && ' (Em breve)'}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {errors.server && (
            <p className="text-sm text-red-500">{errors.server}</p>
          )}
        </div>

        {/* Mundo */}
        <div className="space-y-2">
          <Label htmlFor="world">Mundo</Label>
          <Select
            value={formData.world}
            onValueChange={(value) => handleSelectChange('world', value)}
            disabled={loading || availableWorlds.length === 0}
          >
            <SelectTrigger className={errors.world ? 'border-red-500' : ''}>
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
            <p className="text-sm text-red-500">{errors.world}</p>
          )}
        </div>

        {/* Botão de Busca */}
        <div>
          <Button
            type="submit"
            className="w-full h-10"
            disabled={loading}
          >
            {loading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Verificando...
              </>
            ) : (
              <>
                <Search className="mr-2 h-4 w-4" />
                Buscar Personagem
              </>
            )}
          </Button>
        </div>
      </div>

      {/* Dica para o usuário */}
      <div className="text-sm text-muted-foreground">
        💡 <strong>Dica:</strong> O botão "Buscar Personagem" primeiro verifica se o personagem já existe. 
        Se existir, mostra os dados. Se não existir, adiciona automaticamente!
      </div>
    </form>
  );
};

export default CharacterSearch; 