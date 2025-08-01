import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs) {
  return twMerge(clsx(inputs))
}

export function formatNumber(number) {
  if (!number) return "0"
  
  if (number >= 1000000000) {
    return `${(number / 1000000000).toFixed(1)}B`
  }
  if (number >= 1000000) {
    return `${(number / 1000000).toFixed(1)}M`
  }
  if (number >= 1000) {
    return `${(number / 1000).toFixed(1)}K`
  }
  
  return number.toLocaleString('pt-BR')
}

export function formatDate(dateString) {
  if (!dateString) return 'Nunca'
  
  try {
    const date = new Date(dateString)
    const now = new Date()
    const diffInMinutes = Math.floor((now - date) / (1000 * 60))
    
    if (diffInMinutes < 1) return 'Agora'
    if (diffInMinutes < 60) return `${diffInMinutes}m atrás`
    
    const diffInHours = Math.floor(diffInMinutes / 60)
    if (diffInHours < 24) return `${diffInHours}h atrás`
    
    const diffInDays = Math.floor(diffInHours / 24)
    if (diffInDays < 30) return `${diffInDays}d atrás`
    
    return date.toLocaleDateString('pt-BR')
  } catch {
    return 'Data inválida'
  }
}

export function getVocationColor(vocation) {
  const colors = {
    'Sorcerer': 'sorcerer',
    'Master Sorcerer': 'sorcerer',
    'Druid': 'druid',
    'Elder Druid': 'druid',
    'Paladin': 'paladin',
    'Royal Paladin': 'paladin',
    'Knight': 'knight',
    'Elite Knight': 'knight',
  }
  return colors[vocation] || 'default'
}

export function getVocationIcon(vocation) {
  // Map vocations to appropriate icons
  const icons = {
    'Sorcerer': '🔮',
    'Master Sorcerer': '🔮',
    'Druid': '🌿',
    'Elder Druid': '🌿',
    'Paladin': '🏹',
    'Royal Paladin': '🏹',
    'Knight': '⚔️',
    'Elite Knight': '⚔️',
  }
  return icons[vocation] || '👤'
}

export function getTibiaUrl(character) {
  const serverUrls = {
    'taleon': `https://${character.world}.taleon.online`,
    'rubini': 'https://rubini.com.br',
  }
  
  const baseUrl = serverUrls[character.server] || 'https://tibia.com'
  return `${baseUrl}/characterprofile.php?name=${encodeURIComponent(character.name)}`
}