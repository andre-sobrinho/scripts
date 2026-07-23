#!/bin/bash

################################################################################
# Script de Desinstalação e Limpeza do auditd e rsyslog
# Descrição: Remove auditd, rsyslog e todas as configurações/arquivos relacionados
# Uso: sudo bash uninstall-auditd.sh
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
AUDIT_RULES_FILE="/etc/audit/rules.d/security-rules.rules"
AUDIT_RULES_BACKUP="/etc/audit/rules.d/security-rules.rules.backup"
RSYSLOG_AUDIT_CONFIG="/etc/rsyslog.d/31-auditd.conf"
AUDIT_LOG="/var/log/audit/audit.log"
AUDIT_DIR="/var/log/audit"

# Funções auxiliares
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

print_section() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# Confirmar desinstalação
confirm_uninstall() {
    echo ""
    print_warn "⚠ AVISO: Esta ação irá:"
    echo -e "  ${YELLOW}- Parar e desabilitar o serviço auditd${NC}"
    echo -e "  ${YELLOW}- Parar e desabilitar o serviço rsyslog${NC}"
    echo -e "  ${YELLOW}- Desinstalar os pacotes auditd e rsyslog${NC}"
    echo -e "  ${YELLOW}- Remover arquivo de regras: $AUDIT_RULES_FILE${NC}"
    echo -e "  ${YELLOW}- Remover configuração rsyslog: $RSYSLOG_AUDIT_CONFIG${NC}"
    echo -e "  ${YELLOW}- Limpar diretório de logs: $AUDIT_DIR${NC}"
    echo ""
    
    read -p "Tem certeza que deseja prosseguir? (sim/não): " confirm
    if [[ ! "$confirm" =~ ^[Ss][Ii][Mm]$ ]]; then
        print_error "Desinstalação cancelada"
        exit 1
    fi
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script deve ser executado como root (use sudo)"
    exit 1
fi

print_section "DESINSTALAÇÃO DO AUDITD E RSYSLOG"

# Confirmar desinstalação
confirm_uninstall

# Parar o serviço auditd
print_info "Parando o serviço auditd..."
if systemctl is-active --quiet auditd; then
    systemctl stop auditd
    print_info "✓ Serviço auditd parado"
else
    print_warn "Serviço auditd já não estava ativo"
fi

# Desabilitar auditd do boot
print_info "Desabilitando auditd do boot..."
if systemctl is-enabled auditd > /dev/null 2>&1; then
    systemctl disable auditd
    print_info "✓ auditd desabilitado do boot"
else
    print_warn "auditd já não estava habilitado para boot"
fi

# Parar o serviço rsyslog
print_info "Parando o serviço rsyslog..."
if systemctl is-active --quiet rsyslog; then
    systemctl stop rsyslog
    print_info "✓ Serviço rsyslog parado"
else
    print_warn "Serviço rsyslog já não estava ativo"
fi

# Desabilitar rsyslog do boot
print_info "Desabilitando rsyslog do boot..."
if systemctl is-enabled rsyslog > /dev/null 2>&1; then
    systemctl disable rsyslog
    print_info "✓ rsyslog desabilitado do boot"
else
    print_warn "rsyslog já não estava habilitado para boot"
fi

# Remover arquivo de configuração do rsyslog
print_info "Removendo configuração do rsyslog..."
if [ -f "$RSYSLOG_AUDIT_CONFIG" ]; then
    rm -f "$RSYSLOG_AUDIT_CONFIG"
    print_info "✓ Arquivo removido: $RSYSLOG_AUDIT_CONFIG"
else
    print_warn "Arquivo de configuração não encontrado: $RSYSLOG_AUDIT_CONFIG"
fi

# Remover arquivo de regras de auditoria
print_info "Removendo regras de auditoria..."
if [ -f "$AUDIT_RULES_FILE" ]; then
    rm -f "$AUDIT_RULES_FILE"
    print_info "✓ Arquivo removido: $AUDIT_RULES_FILE"
else
    print_warn "Arquivo de regras não encontrado: $AUDIT_RULES_FILE"
fi

# Remover backup de regras
if [ -f "$AUDIT_RULES_BACKUP" ]; then
    rm -f "$AUDIT_RULES_BACKUP"
    print_info "✓ Backup removido: $AUDIT_RULES_BACKUP"
fi

# Limpar logs de auditoria
print_info "Limpando logs de auditoria..."
if [ -d "$AUDIT_DIR" ]; then
    # Remover logs mas manter o diretório
    rm -f "$AUDIT_DIR"/*.log* 2>/dev/null || true
    print_info "✓ Logs removidos de: $AUDIT_DIR"
else
    print_warn "Diretório não encontrado: $AUDIT_DIR"
fi

# Desinstalar pacotes
print_section "DESINSTALAÇÃO DE PACOTES"

print_info "Desinstalando pacotes..."
apt-get remove -y auditd audispd-plugins 2>/dev/null || true

print_info "Limpando pacotes não utilizados..."
apt-get autoremove -y 2>/dev/null || true

# Limpar configurações residuais
print_section "LIMPEZA DE CONFIGURAÇÕES RESIDUAIS"

print_info "Removendo diretórios de configuração residuais..."

# Remover configurações do auditd se existirem
if [ -d "/etc/audit" ]; then
    # Fazer backup antes de remover
    if [ -d "/etc/audit" ] && [ "$(ls -A /etc/audit)" ]; then
        print_warn "Diretório /etc/audit contém arquivos. Mantendo para segurança."
        print_info "Se desejar remover completamente, execute: sudo rm -rf /etc/audit"
    fi
else
    print_info "Diretório /etc/audit não encontrado"
fi

# Remover cache de apt
print_info "Limpando cache de pacotes..."
apt-get clean

# Resumo final
print_section "DESINSTALAÇÃO CONCLUÍDA!"

cat << EOF

${GREEN}✓ Ações concluídas:${NC}
  - Serviço auditd parado e desabilitado
  - Serviço rsyslog parado e desabilitado
  - Pacotes auditd e audispd-plugins desinstalados
  - Arquivo de regras removido: $AUDIT_RULES_FILE
  - Configuração rsyslog removida: $RSYSLOG_AUDIT_CONFIG
  - Logs de auditoria removidos de: $AUDIT_DIR
  - Cache de pacotes limpo

${YELLOW}Informações importantes:${NC}
  - Arquivos de configuração do auditd em /etc/audit podem ainda existir
  - Se desejar remover completamente: sudo rm -rf /etc/audit
  - Verifique se rsyslog está funcionando corretamente: systemctl status rsyslog

${YELLOW}Para reinstalar, execute:${NC}
  sudo bash install-auditd.sh

${YELLOW}Verificações finais:${NC}
  - Confirmar que auditd não está rodando: systemctl status auditd
  - Confirmar que rsyslog está funcionando: systemctl status rsyslog
  - Listar regras remanescentes: auditctl -l (deve estar vazio)

EOF

print_info "Script de desinstalação finalizado em $(date)"
