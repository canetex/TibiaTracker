#!/bin/bash

# =============================================================================
# TIBIA TRACKER - GIT PULL AUTOMATIZADO
# =============================================================================
# Script para automatizar pull do GitHub com backup e validações
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
# VERIFICAÇÕES PRÉ-PULL
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
    
    # Verificar conectividade com o remote
    if ! git ls-remote origin HEAD > /dev/null 2>&1; then
        error "Não foi possível conectar ao repositório remoto!"
    fi
    
    log "Pré-requisitos verificados!"
}

# =============================================================================
# VERIFICAR MUDANÇAS LOCAIS
# =============================================================================

check_local_changes() {
    log "Verificando mudanças locais..."
    
    local has_changes=false
    
    # Verificar arquivos não commitados
    if ! git diff --quiet || ! git diff --cached --quiet; then
        warning "Há mudanças não commitadas!"
        git status --porcelain
        has_changes=true
    fi
    
    # Verificar arquivos não rastreados
    if [[ -n $(git ls-files --others --exclude-standard) ]]; then
        warning "Há arquivos não rastreados:"
        git ls-files --others --exclude-standard
        has_changes=true
    fi
    
    if [[ "$has_changes" == true ]]; then
        echo
        warning "ATENÇÃO: Há mudanças locais que podem ser perdidas!"
        info "Opções:"
        info "1. (S)tash - Salvar mudanças temporariamente"
        info "2. (C)ommit - Fazer commit das mudanças"
        info "3. (F)orce - Forçar pull e descartar mudanças locais"
        info "4. (A)bort - Cancelar operação"
        
        read -p "Escolha uma opção (S/C/F/A): " -n 1 -r
        echo
        
        case $REPLY in
            [Ss])
                log "Salvando mudanças no stash..."
                git stash push -m "Auto-stash antes do pull $(date)"
                info "Mudanças salvas no stash. Use 'git stash pop' para recuperar."
                ;;
            [Cc])
                log "Fazendo commit das mudanças..."
                git add -A
                local commit_msg="WIP: auto-commit antes do pull $(date +'%Y-%m-%d %H:%M')"
                git commit -m "$commit_msg"
                info "Commit criado: $commit_msg"
                ;;
            [Ff])
                warning "CUIDADO: Descartando mudanças locais!"
                read -p "Tem certeza? Esta ação não pode ser desfeita! (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Operação cancelada."
                    exit 0
                fi
                git reset --hard HEAD
                git clean -fd
                info "Mudanças locais descartadas."
                ;;
            *)
                info "Operação cancelada pelo usuário."
                exit 0
                ;;
        esac
    else
        log "Nenhuma mudança local detectada."
    fi
}

# =============================================================================
# CRIAR BACKUP DA BRANCH ATUAL
# =============================================================================

create_backup() {
    local current_branch=$(git branch --show-current)
    local backup_branch="backup-${current_branch}-$(date +'%Y%m%d-%H%M%S')"
    
    log "Criando backup da branch atual..."
    
    # Criar branch de backup
    git branch "$backup_branch"
    
    info "Backup criado: $backup_branch"
    echo "Para restaurar: git checkout $backup_branch"
    
    # Limpar backups antigos (manter últimos 5)
    local old_backups=$(git branch | grep "backup-${current_branch}-" | head -n -5)
    if [[ -n "$old_backups" ]]; then
        warning "Removendo backups antigos..."
        echo "$old_backups" | xargs -r git branch -D
    fi
}

# =============================================================================
# VERIFICAR ATUALIZAÇÕES DISPONÍVEIS
# =============================================================================

check_updates() {
    local current_branch=$(git branch --show-current)
    
    log "Verificando atualizações disponíveis..."
    
    # Fetch das atualizações
    git fetch origin
    
    # Verificar se há commits novos
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "origin/$current_branch" 2>/dev/null || echo "")
    
    if [[ -z "$remote_commit" ]]; then
        warning "Branch '$current_branch' não existe no remote!"
        return 1
    fi
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        info "Repositório já está atualizado!"
        exit 0
    fi
    
    # Mostrar diferenças
    local commits_behind=$(git rev-list HEAD..origin/$current_branch --count)
    local commits_ahead=$(git rev-list origin/$current_branch..HEAD --count)
    
    info "Status da branch '$current_branch':"
    info "  - Commits atrás do remote: $commits_behind"
    info "  - Commits à frente do remote: $commits_ahead"
    
    if [[ $commits_ahead -gt 0 ]]; then
        warning "Há commits locais que não estão no remote!"
        info "Últimos commits locais:"
        git log --oneline origin/$current_branch..HEAD
    fi
    
    if [[ $commits_behind -gt 0 ]]; then
        info "Novos commits no remote:"
        git log --oneline HEAD..origin/$current_branch
    fi
    
    return 0
}

# =============================================================================
# EXECUTAR PULL
# =============================================================================

execute_pull() {
    local current_branch=$(git branch --show-current)
    local pull_strategy="$1"
    
    log "Executando pull da branch '$current_branch'..."
    
    case $pull_strategy in
        "merge")
            git pull origin "$current_branch"
            ;;
        "rebase")
            git pull --rebase origin "$current_branch"
            ;;
        "fast-forward")
            git pull --ff-only origin "$current_branch"
            ;;
        *)
            # Estratégia padrão - tentar fast-forward, senão merge
            if ! git pull --ff-only origin "$current_branch" 2>/dev/null; then
                warning "Fast-forward não possível. Usando merge..."
                git pull origin "$current_branch"
            fi
            ;;
    esac
    
    log "Pull concluído com sucesso!"
}

# =============================================================================
# VERIFICAÇÕES PÓS-PULL
# =============================================================================

post_pull_checks() {
    log "Executando verificações pós-pull..."
    
    # Verificar se há conflitos não resolvidos
    if git ls-files --unmerged | grep -q .; then
        error "Há conflitos não resolvidos! Resolva os conflitos e execute 'git add' nos arquivos."
    fi
    
    # Verificar se houve mudanças em arquivos críticos
    local critical_files=(
        "package.json"
        "requirements.txt"
        "docker-compose.yml"
        "Dockerfile"
        "env.template"
    )
    
    local changed_critical=false
    for file in "${critical_files[@]}"; do
        if git diff --name-only HEAD~1..HEAD | grep -q "^$file$"; then
            if [[ "$changed_critical" == false ]]; then
                warning "Arquivos críticos foram modificados:"
                changed_critical=true
            fi
            echo "  - $file"
        fi
    done
    
    if [[ "$changed_critical" == true ]]; then
        warning "Considere executar rebuild dos containers:"
        info "  docker-compose down && docker-compose up -d --build"
    fi
    
    # Mostrar resumo das mudanças
    local commits_pulled=$(git rev-list HEAD~1..HEAD --count)
    if [[ $commits_pulled -gt 0 ]]; then
        info "Resumo das mudanças:"
        git log --oneline HEAD~$commits_pulled..HEAD
        
        info "Arquivos modificados:"
        git diff --name-status HEAD~$commits_pulled..HEAD
    fi
    
    log "Verificações pós-pull concluídas!"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    local pull_strategy="${1:-auto}"
    
    log "=== TIBIA TRACKER - GIT PULL ==="
    
    check_prerequisites
    check_local_changes
    create_backup
    
    if ! check_updates; then
        # Se check_updates retornar erro, significa que a branch não existe no remote
        read -p "Criar branch no remote? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local current_branch=$(git branch --show-current)
            git push -u origin "$current_branch"
            info "Branch '$current_branch' criada no remote."
        fi
        exit 0
    fi
    
    # Confirmar antes do pull
    echo
    read -p "Prosseguir com o pull? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Operação cancelada pelo usuário."
        exit 0
    fi
    
    execute_pull "$pull_strategy"
    post_pull_checks
    
    log "=== PULL CONCLUÍDO COM SUCESSO ==="
    
    local current_commit=$(git log -1 --pretty=format:"%h - %s (%cr)")
    info "Commit atual: $current_commit"
    info "Branch: $(git branch --show-current)"
}

# =============================================================================
# AJUDA
# =============================================================================

show_help() {
    echo "Uso: $0 [ESTRATÉGIA]"
    echo
    echo "Estratégias de pull:"
    echo "  auto      - Automática (fast-forward ou merge)"
    echo "  merge     - Sempre criar merge commit"
    echo "  rebase    - Rebase dos commits locais"
    echo "  ff        - Apenas fast-forward"
    echo
    echo "Exemplos:"
    echo "  $0              # Pull automático"
    echo "  $0 rebase       # Pull com rebase"
    echo "  $0 ff           # Pull apenas fast-forward"
}

# =============================================================================
# TRATAMENTO DE ARGUMENTOS
# =============================================================================

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    merge|rebase|ff|auto|"")
        # Argumentos válidos, continuar
        ;;
    *)
        error "Estratégia inválida: $1. Use -h para ver opções disponíveis."
        ;;
esac

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