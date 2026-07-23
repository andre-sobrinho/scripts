#!/bin/bash

################################################################################
# Script de Instalação do auditd no Debian Linux
# Descrição: Instala e configura o auditd (Linux Audit Daemon)
# Uso: sudo bash install-auditd.sh
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script deve ser executado como root (use sudo)"
    exit 1
fi

# Atualizar lista de pacotes
print_info "Atualizando lista de pacotes..."
apt-get update

# Instalar auditd e ferramentas relacionadas
print_info "Instalando auditd e ferramentas de auditoria..."
apt-get install -y auditd audispd-plugins

# Iniciar o serviço auditd
print_info "Iniciando o serviço auditd..."
systemctl start auditd

# Habilitar auditd para iniciar automaticamente
print_info "Habilitando auditd para iniciar com o sistema..."
systemctl enable auditd

# Verificar status do serviço
print_info "Verificando status do serviço auditd..."
if systemctl is-active --quiet auditd; then
    print_info "✓ Serviço auditd está ativo e rodando"
else
    print_error "✗ Falha ao iniciar o serviço auditd"
    exit 1
fi

# Verificar se o auditd está habilitado para boot
if systemctl is-enabled auditd > /dev/null; then
    print_info "✓ auditd está habilitado para iniciar no boot"
else
    print_error "✗ Falha ao habilitar auditd para boot"
    exit 1
fi

# Exibir versão do auditd
print_info "Versão do auditd instalada:"
auditd --version

# Exibir status do auditd
print_info "Status atual do auditd:"
auditctl -l

print_info ""
print_info "================================================================"
print_info "✓ Instalação do auditd concluída com sucesso!"
print_info "================================================================"
print_info ""
print_info "Comandos úteis:"
print_info "  - Ver logs de auditoria: ausearch -m all"
print_info "  - Ver relatório de auditoria: aureport"
print_info "  - Ver regras de auditoria: auditctl -l"
print_info "  - Adicionar regra de monitoramento: auditctl -a always,exit -F arch=b64 -S execve -k exec"
print_info "  - Status do serviço: systemctl status auditd"
print_info "  - Parar serviço: systemctl stop auditd"
print_info "  - Reiniciar serviço: systemctl restart auditd"
print_info ""
print_info "Arquivos de configuração importantes:"
print_info "  - /etc/audit/audit.rules (regras de auditoria)"
print_info "  - /etc/audit/auditd.conf (configuração do auditd)"
print_info "  - /var/log/audit/audit.log (arquivo de log)"
print_info ""
