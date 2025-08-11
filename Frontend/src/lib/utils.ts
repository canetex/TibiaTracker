import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"
import { format } from "date-fns"
import { ptBR } from "date-fns/locale"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatNumber(value: number): string {
  if (!value || isNaN(value)) return '0';
  if (value >= 1000000000) return `${(value / 1000000000).toFixed(1)}B`;
  if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M`;
  if (value >= 1000) return `${(value / 1000).toFixed(1)}K`;
  return value.toString();
}

export function formatDate(date?: string | Date): string {
  if (!date) return '-';
  const parsedDate = typeof date === 'string' ? new Date(date) : date;
  return format(parsedDate, "dd/MM/yyyy HH:mm", { locale: ptBR });
}

export function getVocationColor(vocation: string): "default" | "secondary" | "destructive" | "success" {
  switch (vocation) {
    case 'Elite Knight':
      return 'destructive';
    case 'Royal Paladin':
      return 'success';
    case 'Master Sorcerer':
      return 'secondary';
    case 'Elder Druid':
      return 'default';
    default:
      return 'default';
  }
}

export function getTibiaUrl(character: { name: string; world: string }): string {
  const encodedName = encodeURIComponent(character.name);
  const encodedWorld = encodeURIComponent(character.world);
  return `https://www.tibia.com/community/?name=${encodedName}&world=${encodedWorld}`;
} 