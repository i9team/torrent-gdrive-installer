#!/bin/bash

# Cores para output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Função para printar colorido
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_step() { echo -e "${MAGENTA}▶ $1${NC}"; }
print_header() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Spinner melhorado
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\b${BLUE}%c${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\b"
}

# Função de menu interativo com setas
menu_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local key

    # Esconder cursor
    tput civis

    while true; do
        # Limpar área do menu
        for i in "${!options[@]}"; do
            tput cuu1 2>/dev/null
            tput el
        done
        tput cuu1 2>/dev/null
        tput el

        # Mostrar prompt
        echo -e "${WHITE}$prompt${NC}"
        
        # Mostrar opções
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${GREEN}▶ ${options[$i]}${NC}"
            else
                echo -e "    ${GRAY}${options[$i]}${NC}"
            fi
        done

        # Ler tecla
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A') # Seta para cima
                        ((selected--))
                        [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                        ;;
                    '[B') # Seta para baixo
                        ((selected++))
                        [ $selected -ge ${#options[@]} ] && selected=0
                        ;;
                esac
                ;;
            '') # Enter
                # Mostrar cursor
                tput cnorm
                echo ""
                return $selected
                ;;
        esac
    done
}

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Execute este script como root: sudo bash $0"
    exit 1
fi

clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           🚀 INSTALADOR AUTOMÁTICO - TORRENT + GDRIVE 🚀          ║
║                                                                   ║
║   ✓ qBittorrent Web Interface                                    ║
║   ✓ rclone (Google Drive Sync)                                   ║
║   ✓ Upload automático via Cron                                   ║
║   ✓ Scripts de monitoramento                                     ║
║   ✓ Configuração automática de firewall                          ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF

echo ""
read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."

# ============================================
# ETAPA 1: Atualização do sistema
# ============================================
print_header "ETAPA 1/6: Atualizando Sistema"
print_step "Atualizando pacotes do sistema..."
apt update > /dev/null 2>&1 &
spinner
print_success "Sistema atualizado!"

# ============================================
# ETAPA 2: Instalação de dependências
# ============================================
print_header "ETAPA 2/6: Instalando Dependências"
print_step "Instalando pacotes necessários (pode levar alguns minutos)..."
apt install -y qbittorrent-nox rclone curl screen python3 python3-pip speedtest-cli nload iftop wget net-tools jq ufw > /dev/null 2>&1 &
spinner
print_success "Dependências instaladas!"

# ============================================
# ETAPA 3: Configuração de pastas
# ============================================
print_header "ETAPA 3/6: Criando Estrutura de Diretórios"
mkdir -p /root/torrents/{completed,incomplete,watched}
mkdir -p /root/.config/qBittorrent
mkdir -p /var/log
print_success "Estrutura de pastas criada"

# ============================================
# ETAPA 4: Configuração do qBittorrent
# ============================================
print_header "ETAPA 4/6: Configurando qBittorrent Web UI"

echo ""
print_step "Configure a senha de acesso ao qBittorrent:"
read -p "Escolha uma senha (padrão: admin123): " QB_PASSWORD
QB_PASSWORD=${QB_PASSWORD:-admin123}

# Gerar hash da senha usando Python
print_step "Gerando hash da senha..."
QB_PASSWORD_HASH=$(python3 << EOF
import hashlib
import base64

password = "$QB_PASSWORD"
salt = b'\x00' * 16  # Salt vazio para simplicidade

# PBKDF2 com SHA512
iterations = 100000
dk = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, iterations, dklen=64)

# Formato: @ByteArray(SALT_BASE64:HASH_BASE64)
salt_b64 = base64.b64encode(salt).decode()
hash_b64 = base64.b64encode(dk).decode()

print(f'@ByteArray({salt_b64}:{hash_b64})')
EOF
)

if [ -z "$QB_PASSWORD_HASH" ]; then
    print_error "Erro ao gerar hash da senha"
    exit 1
fi

print_success "Hash gerado com sucesso"

# Criar configuração completa do qBittorrent
print_step "Criando configuração do qBittorrent..."
cat > /root/.config/qBittorrent/qBittorrent.conf << EOF
[LegalNotice]
Accepted=true

[Application]
FileLogger\Enabled=true
FileLogger\Path=/var/log
FileLogger\Backup=true
FileLogger\MaxSizeBytes=66560
FileLogger\DeleteOld=true
FileLogger\Age=6
FileLogger\AgeType=1

[BitTorrent]
Session\Categories=@Variant(\0\0\0\b\0\0\0\0)
Session\DefaultSavePath=/root/torrents/completed
Session\TempPath=/root/torrents/incomplete
Session\TempPathEnabled=true

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=6

[Network]
Cookies=@Invalid()

[Preferences]
Advanced\RecheckOnCompletion=false
Advanced\trackerPort=9000
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxRatioAction=0
Bittorrent\DHT=true
Bittorrent\PeX=true
Bittorrent\LSD=true
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=50
Connection\PortRangeMin=6881
Connection\PortRangeMax=6889
Connection\UPnP=false
Downloads\SavePath=/root/torrents/completed
Downloads\TempPath=/root/torrents/incomplete
Downloads\TempPathEnabled=true
Downloads\FinishedTorrentExportDir=/root/torrents/watched
General\Locale=pt_BR
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\CertificatePath=
WebUI\HTTPS\Enabled=false
WebUI\HTTPS\KeyPath=
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=8080
WebUI\ReverseProxySupportEnabled=false
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=admin
WebUI\Password_PBKDF2="$QB_PASSWORD_HASH"

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
EOF

print_step "Iniciando qBittorrent..."
pkill qbittorrent-nox > /dev/null 2>&1
screen -dmS qbittorrent bash -c "echo y | qbittorrent-nox"
sleep 5

if pgrep -x "qbittorrent-nox" > /dev/null && netstat -tulpn 2>/dev/null | grep -q ":8080"; then
    print_success "qBittorrent iniciado e porta 8080 ativa!"
else
    print_error "Erro ao iniciar qBittorrent ou porta não está escutando"
    exit 1
fi

# ============================================
# ETAPA 5: Configuração do rclone (Google Drive)
# ============================================
print_header "ETAPA 5/6: Configurando Google Drive (rclone)"

echo ""
print_step "Escolha o método de autenticação:"
echo ""

# Menu interativo para método de autenticação
menu_select "Use as setas ↑↓ para selecionar e ENTER para confirmar:" \
    "OAuth (Recomendado - mais fácil)" \
    "Service Account (Avançado - melhor para produção)"

AUTH_METHOD=$?
AUTH_METHOD=$((AUTH_METHOD + 1))

if [ "$AUTH_METHOD" == "1" ]; then
    # ===== OAUTH =====
    print_header "Configuração OAuth - Google Drive"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════╗
║  📋 TUTORIAL: Criando Credenciais OAuth                           ║
╚════════════════════════════════════════════════════════════════════╝

1️⃣  https://console.cloud.google.com/
2️⃣  Criar projeto: "rclone-drive"
3️⃣  Ativar: Google Drive API
4️⃣  OAuth consent screen → External → Preencher dados
5️⃣  Credentials → Create OAuth Client ID → Desktop app
6️⃣  Copiar Client ID e Client Secret

EOF

    read -p "Pressione ENTER quando tiver as credenciais..."
    
    echo ""
    read -p "Client ID: " CLIENT_ID
    read -p "Client Secret: " CLIENT_SECRET
    
    echo ""
    print_warning "No seu PC, execute:"
    echo ""
    echo -e "${GREEN}rclone authorize \"drive\" \"$CLIENT_ID\" \"$CLIENT_SECRET\"${NC}"
    echo ""
    read -p "Pressione ENTER quando estiver pronto para colar o token..."
    
    echo ""
    print_step "Cole o TOKEN JSON completo:"
    read -r TOKEN
    
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf << EOF
[gdrive]
type = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
scope = drive
token = $TOKEN
EOF
    
else
    # ===== SERVICE ACCOUNT =====
    print_header "Configuração Service Account"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════╗
║  📋 TUTORIAL: Service Account                                     ║
╚════════════════════════════════════════════════════════════════════╝

1️⃣  https://console.cloud.google.com/
2️⃣  IAM & Admin → Service Accounts → Create
3️⃣  Keys → Add Key → Create New Key → JSON
4️⃣  Compartilhar pasta Drive com email da service account

EOF

    read -p "Pressione ENTER quando tiver o JSON..."
    
    echo ""
    print_step "Cole o conteúdo do arquivo JSON:"
    
    JSON_CONTENT=""
    while IFS= read -r line; do
        JSON_CONTENT+="$line"
        [[ "$line" == *"}"* ]] && break
    done
    
    echo "$JSON_CONTENT" > /root/gdrive-service-account.json
    
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf << EOF
[gdrive]
type = drive
scope = drive
service_account_file = /root/gdrive-service-account.json
EOF
fi

# Testar conexão
echo ""
print_step "Testando conexão com Google Drive..."
if rclone lsd gdrive: > /dev/null 2>&1; then
    print_success "Conexão estabelecida!"
else
    print_error "Erro na conexão com Google Drive"
    exit 1
fi

# Listar pastas do Google Drive e escolher
echo ""
print_step "Buscando pastas no Google Drive..."
sleep 1

# Obter lista de pastas
mapfile -t GDRIVE_FOLDERS < <(rclone lsd gdrive: 2>/dev/null | awk '{for(i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')

if [ ${#GDRIVE_FOLDERS[@]} -eq 0 ]; then
    print_warning "Nenhuma pasta encontrada no Google Drive"
    read -p "Digite o nome da nova pasta: " GDRIVE_FOLDER
    GDRIVE_FOLDER=${GDRIVE_FOLDER:-VPS-DOWNLOADS}
else
    print_success "Pastas encontradas:"
    echo ""
    
    # Adicionar opções
    FOLDER_OPTIONS=("${GDRIVE_FOLDERS[@]}")
    FOLDER_OPTIONS+=("📁 Criar nova pasta")
    
    # Menu para selecionar pasta
    menu_select "Escolha a pasta de destino:" "${FOLDER_OPTIONS[@]}"
    FOLDER_INDEX=$?
    
    if [ $FOLDER_INDEX -eq ${#GDRIVE_FOLDERS[@]} ]; then
        # Criar nova pasta
        echo ""
        read -p "Digite o nome da nova pasta: " GDRIVE_FOLDER
        GDRIVE_FOLDER=${GDRIVE_FOLDER:-VPS-DOWNLOADS}
    else
        # Usar pasta existente
        GDRIVE_FOLDER="${GDRIVE_FOLDERS[$FOLDER_INDEX]}"
    fi
fi

# Criar pasta no Google Drive (se não existir)
rclone mkdir "gdrive:$GDRIVE_FOLDER" 2>/dev/null
print_success "Pasta configurada: gdrive:$GDRIVE_FOLDER"

# ============================================
# ETAPA 6: Criar scripts e configurar cron
# ============================================
print_header "ETAPA 6/6: Criando Scripts e Configurando Automação"

# Script de upload
cat > /root/upload-to-gdrive.sh << 'EOFSCRIPT'
#!/bin/bash
COMPLETED_DIR="/root/torrents/completed"
GDRIVE_PATH="gdrive:GDRIVE_FOLDER_PLACEHOLDER"
LOG_FILE="/var/log/gdrive-upload.log"
LOCK_FILE="/tmp/gdrive-upload.lock"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

if [ -f "$LOCK_FILE" ]; then
    log "Script já em execução. Saindo..."
    exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

if [ ! "$(ls -A $COMPLETED_DIR 2>/dev/null)" ]; then
    log "Nenhum arquivo para enviar."
    exit 0
fi

log "=== Iniciando upload ==="
ls -lh "$COMPLETED_DIR" | tee -a "$LOG_FILE"

rclone move "$COMPLETED_DIR/" "$GDRIVE_PATH/" \
    --progress \
    --transfers=2 \
    --checkers=4 \
    --buffer-size=128M \
    --drive-chunk-size=128M \
    --use-mmap \
    --no-traverse \
    --delete-empty-src-dirs \
    --log-file="$LOG_FILE" \
    --log-level INFO \
    --stats=30s

if [ $? -eq 0 ]; then
    log "=== Upload concluído! ==="
else
    log "!!! ERRO no upload !!!"
    exit 1
fi

find "$COMPLETED_DIR" -type d -empty -delete
log "=== Processo finalizado ==="
EOFSCRIPT

sed -i "s/GDRIVE_FOLDER_PLACEHOLDER/$GDRIVE_FOLDER/g" /root/upload-to-gdrive.sh
chmod +x /root/upload-to-gdrive.sh

# Script de upload forçado
cat > /root/force-upload.sh << 'EOFSCRIPT'
#!/bin/bash
echo "🚀 Forçando upload para Google Drive..."
pkill -f upload-to-gdrive.sh 2>/dev/null
/root/upload-to-gdrive.sh
echo "✅ Concluído!"
EOFSCRIPT
chmod +x /root/force-upload.sh

# Script de monitoramento
cat > /root/monitor.sh << 'EOFSCRIPT'
#!/bin/bash
GREEN='\033[1;32m'
BLUE='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

while true; do
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}        📊 MONITORAMENTO DE DOWNLOADS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    date
    echo ""
    
    if pgrep -x "qbittorrent-nox" > /dev/null; then
        echo -e "${GREEN}✓ qBittorrent: Rodando${NC}"
    else
        echo -e "${YELLOW}⚠ qBittorrent: Parado${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📁 Arquivos na pasta de download:${NC}"
    if [ "$(ls -A /root/torrents/completed 2>/dev/null)" ]; then
        du -sh /root/torrents/completed/* 2>/dev/null | while read size file; do
            echo -e "   ${GRAY}• $size - $(basename "$file")${NC}"
        done
    else
        echo -e "   ${GRAY}(nenhum arquivo)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}💾 Espaço em disco:${NC}"
    df -h /root | tail -1 | awk '{print "   "$4" livres de "$2" ("$5" usado)"}'
    
    echo ""
    echo -e "${GRAY}🔄 Atualiza a cada 5 segundos | Ctrl+C para sair${NC}"
    sleep 5
done
EOFSCRIPT
chmod +x /root/monitor.sh

print_success "Scripts criados"

# Configurar horário do cron com menu
echo ""
print_step "Configurar horário do upload automático:"
echo ""

menu_select "Use as setas ↑↓ para selecionar o intervalo:" \
    "A cada 30 minutos" \
    "A cada 1 hora (Recomendado)" \
    "A cada 2 horas" \
    "A cada 6 horas" \
    "Personalizado (avançado)"

CRON_CHOICE=$?

case $CRON_CHOICE in
    0) CRON_TIME="*/30 * * * *"; CRON_DESC="a cada 30 minutos" ;;
    1) CRON_TIME="0 * * * *"; CRON_DESC="a cada 1 hora" ;;
    2) CRON_TIME="0 */2 * * *"; CRON_DESC="a cada 2 horas" ;;
    3) CRON_TIME="0 */6 * * *"; CRON_DESC="a cada 6 horas" ;;
    4) 
        echo ""
        print_step "Formato: minuto hora dia mês dia_semana"
        print_info "Exemplos:"
        echo -e "  ${GRAY}0 */3 * * * (a cada 3 horas)${NC}"
        echo -e "  ${GRAY}0 2,14 * * * (às 2h e 14h)${NC}"
        read -p "Digite o horário: " CRON_TIME
        CRON_DESC="personalizado: $CRON_TIME"
        ;;
esac

(crontab -l 2>/dev/null | grep -v upload-to-gdrive.sh; echo "$CRON_TIME /root/upload-to-gdrive.sh") | crontab -
print_success "Cron configurado: $CRON_DESC"

# ============================================
# CONFIGURAÇÃO DO FIREWALL (UFW)
# ============================================
print_header "Configurando Firewall (UFW)"

print_step "Configurando regras do firewall..."

# Desabilitar UFW temporariamente
ufw --force disable > /dev/null 2>&1

# Resetar regras
ufw --force reset > /dev/null 2>&1

# Regras padrão
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

# Permitir SSH
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1

# Permitir qBittorrent Web UI
ufw allow 8080/tcp comment 'qBittorrent Web UI' > /dev/null 2>&1

# Permitir portas de torrent
ufw allow 6881:6889/tcp comment 'qBittorrent Torrents TCP' > /dev/null 2>&1
ufw allow 6881:6889/udp comment 'qBittorrent Torrents UDP' > /dev/null 2>&1

# Habilitar UFW
echo "y" | ufw enable > /dev/null 2>&1

print_success "Firewall configurado!"

# ============================================
# VERIFICAÇÃO FINAL
# ============================================
print_header "Verificação Final do Sistema"

declare -A CHECKS

# Verificar componentes
if pgrep -x "qbittorrent-nox" > /dev/null; then
    CHECKS[qbittorrent]="OK"
    print_success "qBittorrent rodando"
else
    CHECKS[qbittorrent]="ERRO"
    print_error "qBittorrent não está rodando"
fi

if netstat -tulpn 2>/dev/null | grep -q ":8080"; then
    CHECKS[porta]="OK"
    print_success "Porta 8080 ativa"
else
    CHECKS[porta]="ERRO"
    print_error "Porta 8080 não está escutando"
fi

if rclone lsd gdrive: > /dev/null 2>&1; then
    CHECKS[gdrive]="OK"
    print_success "Google Drive conectado"
else
    CHECKS[gdrive]="ERRO"
    print_error "Erro no Google Drive"
fi

if crontab -l 2>/dev/null | grep -q "upload-to-gdrive.sh"; then
    CHECKS[cron]="OK"
    print_success "Cron job configurado"
else
    CHECKS[cron]="ERRO"
    print_error "Cron job não configurado"
fi

if ufw status | grep -q "Status: active"; then
    CHECKS[firewall]="OK"
    print_success "Firewall UFW ativo"
else
    CHECKS[firewall]="AVISO"
    print_warning "Firewall UFW não ativo"
fi

# ============================================
# EXIBIR INFORMAÇÕES FINAIS
# ============================================
sleep 1
clear

# Pegar IP
IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                   ║${NC}"
echo -e "${GREEN}║              ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✅               ║${NC}"
echo -e "${GREEN}║                                                                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}📋 INFORMAÇÕES DE ACESSO${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🌐 qBittorrent Web Interface:${NC}"
echo -e "   ${WHITE}URL:${NC} ${YELLOW}http://$IP:8080${NC}"
echo -e "   ${WHITE}Usuário:${NC} ${YELLOW}admin${NC}"
echo -e "   ${WHITE}Senha:${NC} ${YELLOW}$QB_PASSWORD${NC}"
echo ""
echo -e "${GREEN}📁 Google Drive:${NC}"
echo -e "   ${WHITE}Pasta:${NC} ${YELLOW}gdrive:$GDRIVE_FOLDER${NC}"
echo -e "   ${WHITE}Upload automático:${NC} ${YELLOW}$CRON_DESC${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}🚀 COMANDOS ÚTEIS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Forçar upload manual:${NC}"
echo -e "   ${GRAY}\$${NC} ${YELLOW}/root/force-upload.sh${NC}"
echo ""
echo -e "${GREEN}Monitorar downloads:${NC}"
echo -e "   ${GRAY}\$${NC} ${YELLOW}/root/monitor.sh${NC}"
echo ""
echo -e "${GREEN}Ver velocidade:${NC}"
echo -e "   ${GRAY}\$${NC} ${YELLOW}speedtest-cli${NC}"
echo ""
echo -e "${GREEN}Ver logs:${NC}"
echo -e "   ${GRAY}\$${NC} ${YELLOW}tail -f /var/log/gdrive-upload.log${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}⚙️  STATUS DO SISTEMA${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Status
[ "${CHECKS[qbittorrent]}" == "OK" ] && echo -e "${GREEN}✓${NC} qBittorrent: ${GREEN}Rodando${NC}" || echo -e "${RED}✗${NC} qBittorrent: ${RED}Erro${NC}"
[ "${CHECKS[porta]}" == "OK" ] && echo -e "${GREEN}✓${NC} Porta 8080: ${GREEN}Ativa${NC}" || echo -e "${RED}✗${NC} Porta 8080: ${RED}Inativa${NC}"
[ "${CHECKS[gdrive]}" == "OK" ] && echo -e "${GREEN}✓${NC} Google Drive: ${GREEN}Conectado${NC}" || echo -e "${RED}✗${NC} Google Drive: ${RED}Erro${NC}"
[ "${CHECKS[cron]}" == "OK" ] && echo -e "${GREEN}✓${NC} Upload automático: ${GREEN}Configurado${NC}" || echo -e "${RED}✗${NC} Upload automático: ${RED}Erro${NC}"
[ "${CHECKS[firewall]}" == "OK" ] && echo -e "${GREEN}✓${NC} Firewall UFW: ${GREEN}Ativo${NC}" || echo -e "${YELLOW}⚠${NC} Firewall UFW: ${YELLOW}Inativo${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

print_success "Tudo pronto! Acesse: http://$IP:8080"
echo ""
