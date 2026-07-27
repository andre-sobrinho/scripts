#!/bin/bash

################################################################################
# Script de Instalação e Configuração do auditd no Debian Linux
# Descrição: Instala auditd, rsyslog, configura regras de auditoria
#            e envia logs para SIEM
# Uso: sudo bash install-auditd.sh
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis globais
AUDIT_RULES_FILE="/etc/audit/rules.d/security-rules.rules"
RSYSLOG_AUDIT_CONFIG="/etc/rsyslog.d/31-auditd.conf"
SIEM_IP=""
SIEM_PORT=""

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

# Função para ler input do operador
read_input() {
    local prompt="$1"
    local default="$2"
    local input=""
    
    if [ -z "$default" ]; then
        read -p "$prompt: " input
    else
        read -p "$prompt [$default]: " input
        input="${input:-$default}"
    fi
    
    echo "$input"
}

# Validar IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validar Porta
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
    print_error "Este script deve ser executado como root (use sudo)"
    exit 1
fi

print_section "INSTALAÇÃO E CONFIGURAÇÃO DO AUDITD COM SIEM"

# Atualizar lista de pacotes
print_info "Atualizando lista de pacotes..."
apt-get update

# Instalar auditd, rsyslog e ferramentas relacionadas
print_info "Instalando auditd, rsyslog e ferramentas de auditoria..."
apt-get install -y auditd audispd-plugins rsyslog rsyslog-gnutls

# Coletar informações do SIEM
print_section "CONFIGURAÇÃO DO SIEM"
print_info "Por favor, forneça as informações do seu SIEM para envio de logs"

while true; do
    SIEM_IP=$(read_input "Digite o IP do SIEM")
    if validate_ip "$SIEM_IP"; then
        break
    else
        print_error "IP inválido. Tente novamente."
    fi
done

while true; do
    SIEM_PORT=$(read_input "Digite a porta do SIEM" "514")
    if validate_port "$SIEM_PORT"; then
        break
    else
        print_error "Porta inválida (1-65535). Tente novamente."
    fi
done

print_info "✓ SIEM configurado: $SIEM_IP:$SIEM_PORT"

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

# Configurar regras de auditoria
print_section "CONFIGURAÇÃO DE REGRAS DE AUDITORIA"
print_info "Configurando regras de segurança..."

# Backup da configuração original
if [ -f "$AUDIT_RULES_FILE" ]; then
    cp "$AUDIT_RULES_FILE" "$AUDIT_RULES_FILE.backup"
fi

# Criar arquivo de regras
cat > "$AUDIT_RULES_FILE" << 'EOF'
# Remover regras anteriores
-D

# Buffer Size
-b 8192

# Fail Mode
-f 1

################################################################################
# MONITORAMENTO DE SEGURANÇA - BOAS PRÁTICAS
################################################################################

# 1. MONITORAMENTO DE CHAMADAS DO SISTEMA (SYSCALLS)
# Monitorar execução de programas
-a always,exit -F arch=b64 -S execve -F uid>=1000 -F auid!=4294967295 -k exec
-a always,exit -F arch=b32 -S execve -F uid>=1000 -F auid!=4294967295 -k exec

# 2. MONITORAMENTO DE ACESSO A ARQUIVOS SENSÍVEIS
# Monitorar /etc/shadow
-w /etc/shadow -p wa -k shadow_changes
-w /etc/shadow- -p wa -k shadow_changes
-w /etc/gshadow -p wa -k shadow_changes
-w /etc/gshadow- -p wa -k shadow_changes

# Monitorar /etc/passwd
-w /etc/passwd -p wa -k passwd_changes
-w /etc/passwd- -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/group- -p wa -k group_changes

# 3. MONITORAMENTO DE SUDOERS
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# 4. MONITORAMENTO DE AUDITORIA
-w /etc/audit/ -p wa -k audit_changes
-w /etc/libaudit.conf -p wa -k audit_changes
-w /etc/audisp/ -p wa -k audit_changes

# 5. MONITORAMENTO DE SSH
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config_changes
-w /home -p wa -k home_directory_changes

# 6. MONITORAMENTO DE LOGS DO SISTEMA
-w /var/log/lastlog -p wa -k logins
-w /var/run/utmp -p wa -k logins
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# 7. MONITORAMENTO DE INSTALAÇÃO DE PACOTES
-w /usr/bin/dpkg -p x -k software_modification
-w /usr/bin/apt -p x -k software_modification
-w /usr/bin/apt-get -p x -k software_modification

# 8. MONITORAMENTO DE PERMISSÕES DE ARQUIVO
-a always,exit -F arch=b64 -S chmod -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S chown -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fchmod -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fchmodat -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fchown -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fchownat -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S lchown -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S setxattr -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S lsetxattr -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fsetxattr -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S removexattr -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S lremovexattr -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k file_permissions

# 9. MONITORAMENTO DE USUÁRIOS E GRUPOS
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_modifications
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b64 -S clock_adjtime -k time_change

# 10. MONITORAMENTO DE DESMONTAGEM DE DISPOSITIVOS
-a always,exit -F arch=b64 -S umount2 -F auid>=1000 -F auid!=4294967295 -k umount
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mount

# 11. MONITORAMENTO DE FALHAS DE ACESSO
-a always,exit -F arch=b64 -S open -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S open -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# 12. SINCRONIZAR REGRAS
-m never

# Make configuration immutable
-e 2
EOF

# Carregar regras
print_info "Carregando regras de auditoria..."
auditctl -R "$AUDIT_RULES_FILE"

if [ $? -eq 0 ]; then
    print_info "✓ Regras de auditoria carregadas com sucesso"
else
    print_warn "Aviso ao carregar regras. Verifique com 'auditctl -l'"
fi

# Configurar rsyslog para enviar logs do auditd para o SIEM
print_section "CONFIGURAÇÃO DO RSYSLOG PARA SIEM"
print_info "Configurando rsyslog para enviar eventos de auditoria para o SIEM..."

cat > "$RSYSLOG_AUDIT_CONFIG" << EOF
# Configuração de encaminhamento de logs de auditoria para SIEM
# Gerado automaticamente em $(date)

# Arquivo de entrada para logs de auditoria
\$ModLoad imfile
\$InputFileName /var/log/audit/audit.log
\$InputFileTag auditd:
\$InputFileStateFile stat-auditd
\$InputFileSeverity info
\$InputFileReadMode 0
\$InputFilePollInterval 5
\$InputRunFileMonitor

# Encaminhamento para SIEM
:programname, isequal, "auditd" @${SIEM_IP}:${SIEM_PORT}
& stop

# Backup local
:programname, isequal, "auditd" /var/log/audit/audit.log
& stop
EOF

# Reiniciar rsyslog
print_info "Reiniciando rsyslog..."
systemctl restart rsyslog

if systemctl is-active --quiet rsyslog; then
    print_info "✓ Serviço rsyslog está ativo e rodando"
else
    print_error "✗ Falha ao iniciar o serviço rsyslog"
    exit 1
fi

# Habilitar rsyslog para iniciar no boot
systemctl enable rsyslog

# Verificar conectividade com SIEM
print_section "VERIFICAÇÃO DE CONECTIVIDADE COM SIEM"
print_info "Testando conectividade com SIEM em $SIEM_IP:$SIEM_PORT..."

if nc -zv -w 3 "$SIEM_IP" "$SIEM_PORT" 2>/dev/null; then
    print_info "✓ Conexão com SIEM estabelecida com sucesso"
else
    print_warn "⚠ Não foi possível conectar ao SIEM. Verifique:"
    print_warn "  - IP: $SIEM_IP"
    print_warn "  - Porta: $SIEM_PORT"
    print_warn "  - Firewall e configurações de rede"
fi

# Exibir versão do auditd
print_info "Versão do auditd instalada:"
auditd --version

# Exibir status das regras
print_info "Regras de auditoria carregadas:"
auditctl -l | head -20
echo "..."

# Resumo final
print_section "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"

cat << EOF

${GREEN}✓ Componentes instalados:${NC}
  - auditd (daemon de auditoria)
  - audispd-plugins (plugins de dispatcher)
  - rsyslog (encaminhamento de logs)

${GREEN}✓ Configurações aplicadas:${NC}
  - Arquivo de regras: $AUDIT_RULES_FILE
  - Configuração rsyslog: $RSYSLOG_AUDIT_CONFIG
  - SIEM configurado: $SIEM_IP:$SIEM_PORT

${GREEN}✓ Serviços habilitados:${NC}
  - auditd (iniciará automaticamente no boot)
  - rsyslog (iniciará automaticamente no boot)

${YELLOW}Comandos úteis:${NC}
  - Ver logs de auditoria: ausearch -m all
  - Ver logs em tempo real: tail -f /var/log/audit/audit.log
  - Ver relatório de auditoria: aureport
  - Ver regras de auditoria: auditctl -l
  - Status do auditd: systemctl status auditd
  - Parar auditd: systemctl stop auditd
  - Reiniciar auditd: systemctl restart auditd
  - Recarregar regras: auditctl -R $AUDIT_RULES_FILE
  - Monitorar enviados para SIEM: tail -f /var/log/syslog | grep auditd

${YELLOW}Arquivos de configuração:${NC}
  - Regras de auditoria: $AUDIT_RULES_FILE
  - Configuração auditd: /etc/audit/auditd.conf
  - Configuração rsyslog: $RSYSLOG_AUDIT_CONFIG
  - Logs de auditoria: /var/log/audit/audit.log
  - Logs do sistema: /var/log/syslog

${YELLOW}Próximos passos recomendados:${NC}
  1. Verificar se os logs chegam ao SIEM
  2. Ajustar regras de auditoria conforme necessário
  3. Configurar alertas no SIEM para eventos críticos
  4. Revisar regularmente os logs de auditoria
  5. Fazer backup das configurações

EOF

print_info "Script finalizado em $(date)"
