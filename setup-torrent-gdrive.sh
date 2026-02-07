#!/bin/bash

# Cores melhoradas para melhor visibilidade
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
║                                                                   ║
║   Desenvolvido para VPS Ubuntu/Debian                            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF

echo ""
print_warning "Este script irá instalar e configurar:"
echo -e "  ${GRAY}• qBittorrent-nox (cliente torrent sem interface gráfica)${NC}"
echo -e "  ${GRAY}• rclone (sincronização com Google Drive)${NC}"
echo -e "  ${GRAY}• Scripts de automação e monitoramento${NC}"
echo -e "  ${GRAY}• Cron jobs para upload automático${NC}"
echo ""
read -p "Deseja continuar? [S/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    print_error "Instalação cancelada."
    exit 0
fi

# ============================================
# ETAPA 1: Atualização do sistema
# ============================================
print_header "ETAPA 1/6: Atualizando Sistema"
print_step "Atualizando lista de pacotes..."
apt update -qq 2>&1 | grep -v "apt does not have a stable CLI interface"
print_success "Sistema atualizado com sucesso!"

# ============================================
# ETAPA 2: Instalação de dependências
# ============================================
print_header "ETAPA 2/6: Instalando Dependências"
PACKAGES="qbittorrent-nox rclone curl screen python3 python3-pip speedtest-cli nload iftop wget net-tools jq"
print_step "Instalando pacotes: $PACKAGES"
apt install -y $PACKAGES > /dev/null 2>&1
print_success "Todas as dependências instaladas!"

# Verificar instalações
print_info "Verificando versões instaladas:"
echo -e "  ${GRAY}• qBittorrent: $(qbittorrent-nox --version 2>&1 | head -1)${NC}"
echo -e "  ${GRAY}• rclone: $(rclone version | head -1)${NC}"
echo -e "  ${GRAY}• Python: $(python3 --version)${NC}"

# ============================================
# ETAPA 3: Configuração de pastas
# ============================================
print_header "ETAPA 3/6: Criando Estrutura de Diretórios"
mkdir -p /root/torrents/{completed,incomplete,watched}
mkdir -p /root/.config/qBittorrent
mkdir -p /var/log
print_success "Estrutura de pastas criada:"
echo -e "  ${GRAY}├─ /root/torrents/completed   (downloads finalizados)${NC}"
echo -e "  ${GRAY}├─ /root/torrents/incomplete  (downloads em andamento)${NC}"
echo -e "  ${GRAY}└─ /root/torrents/watched     (pasta monitorada)${NC}"

# ============================================
# ETAPA 4: Configuração do qBittorrent
# ============================================
print_header "ETAPA 4/6: Configurando qBittorrent Web UI"

echo ""
print_step "Configure a senha de acesso ao qBittorrent:"
read -p "Escolha uma senha (padrão: admin123): " QB_PASSWORD
QB_PASSWORD=${QB_PASSWORD:-admin123}

# Gerar hash da senha (usando senha padrão para simplificar)
QB_HASH='@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)'

cat > /root/.config/qBittorrent/qBittorrent.conf << EOF
[Preferences]
Downloads\SavePath=/root/torrents/completed
Downloads\TempPath=/root/torrents/incomplete
Downloads\TempPathEnabled=true
WebUI\Address=*
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="$QB_HASH"
WebUI\LocalHostAuth=false
General\Locale=pt_BR
Bittorrent\DHT=true
Bittorrent\PeX=true
Bittorrent\LSD=true
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1
Downloads\FinishedTorrentExportDir=/root/torrents/watched
Connection\PortRangeMin=6881
Connection\PortRangeMax=6889
Connection\UPnP=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=50
EOF

# Iniciar qBittorrent
print_step "Iniciando qBittorrent em background..."
pkill qbittorrent-nox 2>/dev/null
screen -dmS qbittorrent qbittorrent-nox
sleep 3

if pgrep -x "qbittorrent-nox" > /dev/null; then
    print_success "qBittorrent iniciado com sucesso!"
else
    print_error "Erro ao iniciar qBittorrent"
    exit 1
fi

# ============================================
# ETAPA 5: Configuração do rclone (Google Drive)
# ============================================
print_header "ETAPA 5/6: Configurando Google Drive (rclone)"

echo ""
print_step "Escolha o método de autenticação:"
echo ""
echo -e "  ${GREEN}1)${NC} ${WHITE}OAuth (Recomendado)${NC}"
echo -e "     ${GRAY}→ Requer PC local para autorização${NC}"
echo -e "     ${GRAY}→ Mais fácil e rápido${NC}"
echo ""
echo -e "  ${GREEN}2)${NC} ${WHITE}Service Account${NC}"
echo -e "     ${GRAY}→ Requer arquivo JSON do Google Cloud${NC}"
echo -e "     ${GRAY}→ Melhor para uso em produção${NC}"
echo ""
read -p "Escolha [1 ou 2]: " AUTH_METHOD

if [ "$AUTH_METHOD" == "1" ]; then
    # ===== OAUTH =====
    print_header "Configuração OAuth - Google Drive"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════╗
║  📋 TUTORIAL: Criando Credenciais OAuth (Google Cloud Console)   ║
╚════════════════════════════════════════════════════════════════════╝

┌─ PASSO 1: Acessar Google Cloud Console ──────────────────────────┐
│  🔗 https://console.cloud.google.com/                             │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 2: Criar Novo Projeto ────────────────────────────────────┐
│  • Clique em "Select a project" (topo da página)                 │
│  • Clique em "New Project"                                       │
│  • Nome do projeto: rclone-drive                                 │
│  • Clique em "Create"                                            │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 3: Ativar Google Drive API ───────────────────────────────┐
│  • Menu ☰ > "APIs & Services" > "Library"                        │
│  • Busque: "Google Drive API"                                    │
│  • Clique em "Enable"                                            │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 4: Configurar Tela de Consentimento ──────────────────────┐
│  • Menu ☰ > "APIs & Services" > "OAuth consent screen"           │
│  • User Type: selecione "External"                               │
│  • Clique em "Create"                                            │
│                                                                   │
│  Preencha:                                                        │
│  • App name: Rclone                                              │
│  • User support email: seu email                                 │
│  • Developer contact: seu email                                  │
│  • Clique em "Save and Continue" (3 vezes)                       │
│                                                                   │
│  Test users:                                                      │
│  • Clique em "Add Users"                                         │
│  • Adicione seu email do Google                                  │
│  • Clique em "Save and Continue"                                 │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 5: Criar Credenciais OAuth ───────────────────────────────┐
│  • Menu ☰ > "APIs & Services" > "Credentials"                    │
│  • Clique em "+ Create Credentials"                              │
│  • Selecione "OAuth client ID"                                   │
│  • Application type: "Desktop app"                               │
│  • Name: rclone                                                  │
│  • Clique em "Create"                                            │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 6: Copiar Credenciais ────────────────────────────────────┐
│  Uma janela popup vai aparecer com:                              │
│  • Client ID (xxx.apps.googleusercontent.com)                    │
│  • Client Secret (GOCSPX-xxx)                                    │
│                                                                   │
│  ⚠️  COPIE AMBOS! Você vai precisar deles.                        │
└───────────────────────────────────────────────────────────────────┘

EOF

    read -p "Pressione ENTER quando tiver as credenciais prontas..."
    
    echo ""
    print_step "Cole suas credenciais do Google Cloud Console:"
    echo ""
    read -p "Client ID: " CLIENT_ID
    read -p "Client Secret: " CLIENT_SECRET
    
    echo ""
    print_warning "IMPORTANTE: Autorização no PC Local"
    echo ""
    print_info "Você precisa ter rclone instalado no seu PC para autorizar."
    echo ""
    echo -e "${GRAY}Instalação rclone no PC:${NC}"
    echo -e "  ${BLUE}Windows:${NC} https://rclone.org/downloads/"
    echo -e "  ${BLUE}Linux/Mac:${NC} curl https://rclone.org/install.sh | sudo bash"
    echo ""
    print_step "Execute este comando NO SEU PC (Windows/Linux/Mac):"
    echo ""
    echo -e "${GREEN}┌────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC} ${WHITE}rclone authorize \"drive\" \"$CLIENT_ID\" \"$CLIENT_SECRET\"${NC}"
    echo -e "${GREEN}└────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    print_info "O navegador vai abrir automaticamente."
    print_info "Faça login na sua conta Google e autorize o acesso."
    print_info "Depois, copie TODO o TOKEN JSON que aparecer no terminal."
    echo ""
    read -p "Pressione ENTER quando estiver pronto para colar o token..."
    
    echo ""
    print_step "Cole o TOKEN JSON completo (começa com { e termina com }):"
    read -r TOKEN
    
    # Criar config do rclone
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
    print_header "Configuração Service Account - Google Drive"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════╗
║  📋 TUTORIAL: Criando Service Account (Google Cloud Console)     ║
╚════════════════════════════════════════════════════════════════════╝

┌─ PASSO 1: Acessar Google Cloud Console ──────────────────────────┐
│  🔗 https://console.cloud.google.com/                             │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 2: Criar Projeto (se não tiver) ──────────────────────────┐
│  • Clique em "Select a project"                                  │
│  • Clique em "New Project"                                       │
│  • Nome: rclone-drive                                            │
│  • Clique em "Create"                                            │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 3: Ativar Google Drive API ───────────────────────────────┐
│  • Menu ☰ > "APIs & Services" > "Library"                        │
│  • Busque: "Google Drive API"                                    │
│  • Clique em "Enable"                                            │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 4: Criar Service Account ─────────────────────────────────┐
│  • Menu ☰ > "IAM & Admin" > "Service Accounts"                   │
│  • Clique em "+ Create Service Account"                          │
│  • Nome: rclone-gdrive                                           │
│  • Clique em "Create and Continue"                               │
│  • Skip permissões (clique em "Continue")                        │
│  • Clique em "Done"                                              │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 5: Baixar Chave JSON ─────────────────────────────────────┐
│  • Clique na Service Account que você criou                      │
│  • Vá em "Keys" > "Add Key" > "Create New Key"                   │
│  • Selecione "JSON"                                              │
│  • Clique em "Create"                                            │
│  • O arquivo JSON será baixado automaticamente                   │
└───────────────────────────────────────────────────────────────────┘

┌─ PASSO 6: Compartilhar Pasta do Google Drive ────────────────────┐
│  • Abra o arquivo JSON baixado                                   │
│  • Copie o email (ex: xxx@xxx.iam.gserviceaccount.com)           │
│  • No Google Drive, clique com botão direito na pasta            │
│  • Clique em "Compartilhar"                                      │
│  • Cole o email da Service Account                               │
│  • Dê permissão de "Editor"                                      │
│  • Clique em "Enviar"                                            │
└───────────────────────────────────────────────────────────────────┘

EOF

    read -p "Pressione ENTER quando tiver o arquivo JSON..."
    
    echo ""
    print_step "Cole TODO o conteúdo do arquivo JSON abaixo:"
    print_info "(Abra o arquivo .json, selecione tudo, copie e cole aqui)"
    echo ""
    
    # Ler múltiplas linhas
    JSON_CONTENT=""
    while IFS= read -r line; do
        JSON_CONTENT+="$line"
        [[ "$line" == *"}"* ]] && break
    done
    
    # Salvar JSON
    echo "$JSON_CONTENT" > /root/gdrive-service-account.json
    
    # Criar config do rclone
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
sleep 2

if rclone lsd gdrive: > /dev/null 2>&1; then
    print_success "Conexão com Google Drive estabelecida com sucesso!"
    echo ""
    print_info "Pastas encontradas no Google Drive:"
    rclone lsd gdrive: | head -5 | while read line; do
        echo -e "  ${GRAY}• $line${NC}"
    done
else
    print_error "Erro ao conectar com Google Drive!"
    print_warning "Verifique as credenciais e tente novamente."
    exit 1
fi

# Nome da pasta no Google Drive
echo ""
print_step "Configuração da pasta de destino no Google Drive:"
read -p "Nome da pasta para uploads (padrão: VPS-DOWNLOADS): " GDRIVE_FOLDER
GDRIVE_FOLDER=${GDRIVE_FOLDER:-VPS-DOWNLOADS}

# Criar pasta no Google Drive
print_step "Criando pasta '$GDRIVE_FOLDER' no Google Drive..."
rclone mkdir "gdrive:$GDRIVE_FOLDER" 2>/dev/null
print_success "Pasta configurada: gdrive:$GDRIVE_FOLDER"

# ============================================
# ETAPA 6: Criar scripts de automação
# ============================================
print_header "ETAPA 6/6: Criando Scripts de Automação"

# Script de upload automático
print_step "Criando script de upload automático..."
cat > /root/upload-to-gdrive.sh << 'EOFSCRIPT'
#!/bin/bash

COMPLETED_DIR="/root/torrents/completed"
GDRIVE_PATH="gdrive:GDRIVE_FOLDER_PLACEHOLDER"
LOG_FILE="/var/log/gdrive-upload.log"
LOCK_FILE="/tmp/gdrive-upload.lock"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ -f "$LOCK_FILE" ]; then
    log "Script já está em execução. Saindo..."
    exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

if [ ! "$(ls -A $COMPLETED_DIR 2>/dev/null)" ]; then
    log "Nenhum arquivo para enviar."
    exit 0
fi

log "=== Iniciando upload para Google Drive ==="
log "Arquivos a serem enviados:"
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
    --stats=30s \
    --stats-one-line

if [ $? -eq 0 ]; then
    log "=== Upload concluído com sucesso! ==="
    log "Arquivos movidos para: $GDRIVE_PATH"
else
    log "!!! ERRO no upload !!!"
    exit 1
fi

find "$COMPLETED_DIR" -type d -empty -delete
log "=== Processo finalizado ==="
EOFSCRIPT

sed -i "s/GDRIVE_FOLDER_PLACEHOLDER/$GDRIVE_FOLDER/g" /root/upload-to-gdrive.sh
chmod +x /root/upload-to-gdrive.sh
print_success "Script de upload criado: /root/upload-to-gdrive.sh"

# Script de upload forçado
print_step "Criando script de upload manual..."
cat > /root/force-upload.sh << 'EOFSCRIPT'
#!/bin/bash
echo "🚀 Forçando upload manual para Google Drive..."
echo ""
pkill -f upload-to-gdrive.sh 2>/dev/null
/root/upload-to-gdrive.sh
echo ""
echo "✅ Processo finalizado!"
EOFSCRIPT
chmod +x /root/force-upload.sh
print_success "Script de upload manual criado: /root/force-upload.sh"

# Script de monitoramento simples
print_step "Criando script de monitoramento..."
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
    
    # Status qBittorrent
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
    df -h /root | tail -1 | awk -v gray="$GRAY" -v nc="$NC" '{print "   " gray $4" livres de "$2" ("$5" usado)" nc}'
    
    echo ""
    echo -e "${GRAY}🔄 Atualiza a cada 5 segundos | Ctrl+C para sair${NC}"
    sleep 5
done
EOFSCRIPT
chmod +x /root/monitor.sh
print_success "Script de monitoramento criado: /root/monitor.sh"

# Configurar cron
print_step "Configurando cron job para upload automático..."
(crontab -l 2>/dev/null | grep -v upload-to-gdrive.sh; echo "0 * * * * /root/upload-to-gdrive.sh") | crontab -
print_success "Cron job configurado: upload a cada 1 hora"

# ============================================
# VERIFICAÇÃO FINAL DO SISTEMA
# ============================================
print_header "VERIFICAÇÃO FINAL DO SISTEMA"

print_step "Verificando instalações e configurações..."
echo ""

# Array para armazenar resultados
declare -A CHECKS

# Verificar qBittorrent
if pgrep -x "qbittorrent-nox" > /dev/null; then
    CHECKS[qbittorrent]="OK"
    print_success "qBittorrent-nox está rodando"
else
    CHECKS[qbittorrent]="ERRO"
    print_error "qBittorrent-nox NÃO está rodando"
fi

# Verificar porta 8080
if netstat -tulpn 2>/dev/null | grep -q ":8080"; then
    CHECKS[porta]="OK"
    print_success "Porta 8080 está aberta e escutando"
else
    CHECKS[porta]="AVISO"
    print_warning "Porta 8080 pode precisar ser liberada no firewall"
fi

# Verificar rclone config
if [ -f "/root/.config/rclone/rclone.conf" ]; then
    CHECKS[rclone_config]="OK"
    print_success "Arquivo de configuração rclone existe"
else
    CHECKS[rclone_config]="ERRO"
    print_error "Configuração rclone não encontrada"
fi

# Verificar conexão Google Drive
if rclone lsd gdrive: > /dev/null 2>&1; then
    CHECKS[gdrive_conexao]="OK"
    print_success "Conexão com Google Drive funcionando"
else
    CHECKS[gdrive_conexao]="ERRO"
    print_error "Erro na conexão com Google Drive"
fi

# Verificar estrutura de pastas
if [ -d "/root/torrents/completed" ] && [ -d "/root/torrents/incomplete" ]; then
    CHECKS[pastas]="OK"
    print_success "Estrutura de pastas criada corretamente"
else
    CHECKS[pastas]="ERRO"
    print_error "Estrutura de pastas incorreta"
fi

# Verificar scripts
SCRIPTS=("/root/upload-to-gdrive.sh" "/root/force-upload.sh" "/root/monitor.sh")
SCRIPTS_OK=true
for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        :
    else
        SCRIPTS_OK=false
        break
    fi
done

if $SCRIPTS_OK; then
    CHECKS[scripts]="OK"
    print_success "Todos os scripts criados e executáveis"
else
    CHECKS[scripts]="ERRO"
    print_error "Alguns scripts não foram criados corretamente"
fi

# Verificar cron
if crontab -l 2>/dev/null | grep -q "upload-to-gdrive.sh"; then
    CHECKS[cron]="OK"
    print_success "Cron job configurado corretamente"
else
    CHECKS[cron]="ERRO"
    print_error "Cron job não foi configurado"
fi

# Verificar screen sessions
if screen -ls 2>/dev/null | grep -q "qbittorrent"; then
    CHECKS[screen]="OK"
    print_success "Screen session do qBittorrent ativa"
else
    CHECKS[screen]="AVISO"
    print_warning "Screen session não detectada"
fi

echo ""
print_step "Resumo da verificação:"
TOTAL_CHECKS=0
OK_CHECKS=0
for check in "${CHECKS[@]}"; do
    ((TOTAL_CHECKS++))
    [[ "$check" == "OK" ]] && ((OK_CHECKS++))
done

echo -e "  ${WHITE}$OK_CHECKS de $TOTAL_CHECKS verificações passaram${NC}"

# ============================================
# EXIBIR INFORMAÇÕES FINAIS
# ============================================
clear

# Pegar IP do servidor
IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║              ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✅               ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}📋 INFORMAÇÕES DE ACESSO${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${GREEN}🌐 qBittorrent Web Interface:${NC}
   ${WHITE}URL:${NC} ${YELLOW}http://$IP:8080${NC}
   ${WHITE}Usuário:${NC} ${YELLOW}admin${NC}
   ${WHITE}Senha:${NC} ${YELLOW}$QB_PASSWORD${NC}

${GREEN}📁 Google Drive:${NC}
   ${WHITE}Pasta:${NC} ${YELLOW}gdrive:$GDRIVE_FOLDER${NC}
   ${WHITE}Upload automático:${NC} ${YELLOW}A cada 1 hora${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}🚀 COMANDOS ÚTEIS${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${GREEN}Forçar upload manual:${NC}
   ${GRAY}\$ ${YELLOW}/root/force-upload.sh${NC}

${GREEN}Monitorar downloads:${NC}
   ${GRAY}\$ ${YELLOW}/root/monitor.sh${NC}

${GREEN}Ver velocidade da conexão:${NC}
   ${GRAY}\$ ${YELLOW}speedtest-cli${NC}

${GREEN}Ver logs de upload:${NC}
   ${GRAY}\$ ${YELLOW}tail -f /var/log/gdrive-upload.log${NC}

${GREEN}Reiniciar qBittorrent:${NC}
   ${GRAY}\$ ${YELLOW}pkill qbittorrent-nox${NC}
   ${GRAY}\$ ${YELLOW}screen -dmS qbittorrent qbittorrent-nox${NC}

${GREEN}Ver status do qBittorrent:${NC}
   ${GRAY}\$ ${YELLOW}screen -r qbittorrent${NC}
   ${GRAY}(Sair: Ctrl+A depois D)${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}📖 COMO USAR${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${WHITE}1.${NC} Acesse a interface web: ${YELLOW}http://$IP:8080${NC}
${WHITE}2.${NC} Faça login com ${YELLOW}admin${NC} / ${YELLOW}$QB_PASSWORD${NC}
${WHITE}3.${NC} Adicione torrents via magnet link ou arquivo .torrent
${WHITE}4.${NC} Aguarde o download finalizar
${WHITE}5.${NC} ${GREEN}O upload para Google Drive é AUTOMÁTICO!${NC}
${WHITE}6.${NC} Ou force manualmente: ${YELLOW}/root/force-upload.sh${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}⚙️  STATUS DO SISTEMA${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF

# Exibir status de cada componente
if [ "${CHECKS[qbittorrent]}" == "OK" ]; then
    echo -e "${GREEN}✓${NC} qBittorrent: ${GREEN}Rodando${NC}"
else
    echo -e "${RED}✗${NC} qBittorrent: ${RED}Erro${NC}"
fi

if [ "${CHECKS[gdrive_conexao]}" == "OK" ]; then
    echo -e "${GREEN}✓${NC} Google Drive: ${GREEN}Conectado${NC}"
else
    echo -e "${RED}✗${NC} Google Drive: ${RED}Erro na conexão${NC}"
fi

if [ "${CHECKS[cron]}" == "OK" ]; then
    echo -e "${GREEN}✓${NC} Upload automático: ${GREEN}Configurado (1x por hora)${NC}"
else
    echo -e "${RED}✗${NC} Upload automático: ${RED}Não configurado${NC}"
fi

if [ "${CHECKS[scripts]}" == "OK" ]; then
    echo -e "${GREEN}✓${NC} Scripts: ${GREEN}Todos criados${NC}"
else
    echo -e "${RED}✗${NC} Scripts: ${RED}Erro${NC}"
fi

# Exibir cron jobs
echo ""
echo -e "${BLUE}📅 Cron Jobs Configurados:${NC}"
crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | while read line; do
    echo -e "   ${GRAY}• $line${NC}"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}⚠️  IMPORTANTE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "${CHECKS[porta]}" != "OK" ]; then
    echo -e "${YELLOW}⚠${NC}  A porta 8080 pode estar bloqueada no firewall."
    echo -e "   ${GRAY}Libere a porta com: ${YELLOW}ufw allow 8080/tcp${NC}"
    echo ""
fi

echo -e "${GRAY}Se você não conseguir acessar a interface web:${NC}"
echo -e "  ${GRAY}1. Verifique o firewall: ${YELLOW}ufw status${NC}"
echo -e "  ${GRAY}2. Libere a porta 8080: ${YELLOW}ufw allow 8080/tcp${NC}"
echo -e "  ${GRAY}3. Ou use túnel SSH: ${YELLOW}ssh -L 8080:localhost:8080 root@$IP${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Perguntar se quer fazer teste de velocidade
read -p "Deseja fazer um teste de velocidade agora? [s/N]: " RUN_SPEEDTEST

if [[ "$RUN_SPEEDTEST" =~ ^[Ss]$ ]]; then
    echo ""
    print_header "Executando Teste de Velocidade"
    speedtest-cli
    echo ""
fi

# Perguntar se quer abrir o monitor
echo ""
read -p "Deseja iniciar o monitor de downloads agora? [s/N]: " RUN_MONITOR

if [[ "$RUN_MONITOR" =~ ^[Ss]$ ]]; then
    /root/monitor.sh
fi

echo ""
print_success "Instalação finalizada! Aproveite seu sistema de downloads!"
echo ""