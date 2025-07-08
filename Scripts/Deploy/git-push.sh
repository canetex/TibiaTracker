#!/bin/bash

# =============================================================================
# TIBIA TRACKER - GIT PUSH AUTOMATIZADO
# =============================================================================
# Script para automatizar commits e push para o GitHub
# Autor: Tibia Tracker Team
# =============================================================================

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# =============================================================================
# VERIFICAÇÕES PRÉ-COMMIT
# =============================================================================

check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se estamos em um repositório Git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Não está em um repositório Git!"
    fi
    
    # Verificar se há um remote origin configurado
    if ! git remote get-url origin > /dev/null 2>&1; then
        error "Remote 'origin' não configurado!"
    fi
    
    # Verificar se há mudanças para commit
    if git diff --quiet && git diff --cached --quiet; then
        warning "Não há mudanças para commit!"
        exit 0
    fi
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# VALIDAÇÕES DE CÓDIGO
# =============================================================================

validate_code() {
    log "Executando validações de código..."
    
    # Verificar se há arquivos .env no staged
    if git diff --cached --name-only | grep -q "\.env$"; then
        error "Arquivo .env detectado no staged! Use 'git reset HEAD .env' para remover."
    fi
    
    # Verificar se há arquivos sensíveis
    local sensitive_files=(
        "*.key"
        "*.pem"
        "*.p12"
        "*.pfx"
        "id_rsa"
        "id_dsa"
        "passwords.txt"
        "secrets.json"
    )
    
    for pattern in "${sensitive_files[@]}"; do
        if git diff --cached --name-only | grep -q "$pattern"; then
            error "Arquivo sensível detectado: $pattern"
        fi
    done
    
    # Verificar se há console.log ou print não removidos (apenas warning)
    if git diff --cached | grep -E "^\+.*console\.log|^\+.*print\(" | head -5; then
        warning "Console.log ou print() detectados. Considere remover antes do commit."
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Validações concluídas!"
}

# =============================================================================
# GERAR MENSAGEM DE COMMIT
# =============================================================================

generate_commit_message() {
    local commit_msg=""
    
    # Se foi passado como parâmetro
    if [[ $# -gt 0 ]]; then
        commit_msg="$*"
    else
        # Detectar tipo de mudanças automaticamente
        local added_files=$(git diff --cached --name-only --diff-filter=A | wc -l)
        local modified_files=$(git diff --cached --name-only --diff-filter=M | wc -l)
        local deleted_files=$(git diff --cached --name-only --diff-filter=D | wc -l)
        
        # Detectar categoria das mudanças
        local changes=$(git diff --cached --name-only)
        local category=""
        
        if echo "$changes" | grep -q "Backend/"; then
            category="backend"
        elif echo "$changes" | grep -q "Frontend/"; then
            category="frontend"
        elif echo "$changes" | grep -q "Scripts/"; then
            category="scripts"
        elif echo "$changes" | grep -q -E "(README|\.md|docs)"; then
            category="docs"
        elif echo "$changes" | grep -q -E "(docker|\.yml|\.yaml)"; then
            category="config"
        else
            category="misc"
        fi
        
        # Gerar mensagem baseada nas mudanças
        if [[ $added_files -gt 0 && $modified_files -eq 0 && $deleted_files -eq 0 ]]; then
            commit_msg="feat($category): adicionar novos arquivos"
        elif [[ $added_files -eq 0 && $modified_files -gt 0 && $deleted_files -eq 0 ]]; then
            commit_msg="fix($category): atualizar arquivos existentes"
        elif [[ $deleted_files -gt 0 ]]; then
            commit_msg="refactor($category): remover arquivos obsoletos"
        else
            commit_msg="chore($category): atualizações diversas"
        fi
        
        # Perguntar se quer personalizar
        info "Mensagem gerada: $commit_msg"
        read -p "Personalizar mensagem? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Digite a mensagem do commit: " commit_msg
        fi
    fi
    
    echo "$commit_msg"
}

# =============================================================================
# MOSTRAR RESUMO DAS MUDANÇAS
# =============================================================================

show_changes_summary() {
    log "Resumo das mudanças:"
    
    echo -e "\n${BLUE}Arquivos modificados:${NC}"
    git diff --cached --name-status
    
    echo -e "\n${BLUE}Estatísticas:${NC}"
    git diff --cached --stat
    
    echo -e "\n${BLUE}Branch atual:${NC} $(git branch --show-current)"
    echo -e "${BLUE}Remote:${NC} $(git remote get-url origin)"
}

# =============================================================================
# EXECUTAR PUSH
# =============================================================================

execute_push() {
    local commit_msg="$1"
    local branch=$(git branch --show-current)
    
    log "Executando commit e push..."
    
    # Fazer commit
    git commit -m "$commit_msg"
    log "Commit realizado: $commit_msg"
    
    # Verificar se branch existe no remote
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        # Branch existe, fazer push normal
        git push origin "$branch"
    else
        # Branch nova, fazer push com -u
        warning "Branch '$branch' não existe no remote. Criando..."
        git push -u origin "$branch"
    fi
    
    log "Push concluído com sucesso!"
    
    # Mostrar informações finais
    local last_commit=$(git log -1 --pretty=format:"%h - %s (%cr)")
    info "Último commit: $last_commit"
    info "Branch: $branch"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log "=== TIBIA TRACKER - GIT PUSH ==="
    
    check_prerequisites
    show_changes_summary
    
    # Confirmar antes de prosseguir
    echo
    read -p "Prosseguir com commit e push? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Operação cancelada pelo usuário."
        exit 0
    fi
    
    validate_code
    
    # Adicionar todos os arquivos modificados se nada estiver staged
    if git diff --cached --quiet; then
        log "Nenhum arquivo no stage. Adicionando arquivos modificados..."
        git add -A
    fi
    
    # Gerar mensagem do commit
    local commit_msg=$(generate_commit_message "$@")
    
    # Confirmar commit
    echo
    info "Mensagem do commit: $commit_msg"
    read -p "Confirmar commit e push? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Operação cancelada pelo usuário."
        exit 0
    fi
    
    execute_push "$commit_msg"
    
    log "=== PUSH CONCLUÍDO COM SUCESSO ==="
}

# =============================================================================
# TRATAMENTO DE ERROS
# =============================================================================

trap 'error "Script interrompido! Verifique o estado do repositório Git."' ERR

# =============================================================================
# EXECUÇÃO
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 