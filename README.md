# 🚀 Torrent to Google Drive - Instalador Automático

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

Script completo e interativo para instalar e configurar sistema automatizado de downloads via torrent com upload para Google Drive.

## ✨ Características

- ✅ **qBittorrent Web Interface** - Controle via navegador
- ✅ **rclone** - Sincronização com Google Drive
- ✅ **Upload automático** - Via cron job (a cada 1 hora)
- ✅ **Scripts de monitoramento** - Acompanhe seus downloads
- ✅ **Instalação interativa** - Tutorial passo a passo
- ✅ **Verificação completa** - Checagem de todos os componentes
- ✅ **OAuth ou Service Account** - Escolha seu método de autenticação

## 🚀 Instalação Rápida
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/i9team/torrent-gdrive-installer/main/setup-torrent-gdrive.sh)
```

Ou faça download primeiro:
```bash
wget https://raw.githubusercontent.com/i9team/torrent-gdrive-installer/main/setup-torrent-gdrive.sh
chmod +x setup-torrent-gdrive.sh
./setup-torrent-gdrive.sh
```

## 📋 Pré-requisitos

- **SO:** Ubuntu 20.04+ ou Debian 11+
- **Acesso:** Root ou sudo
- **Conta:** Google Drive ativa
- **Espaço:** Mínimo 10GB livres

## 🎬 Como Funciona
```
┌─────────────────┐
│  Adiciona       │
│  Torrent        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  qBittorrent    │
│  baixa arquivo  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Script rclone  │
│  envia p/ GDrive│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Arquivo no     │
│  Google Drive   │
└─────────────────┘
```

## 📦 O que será instalado

| Componente | Descrição |
|------------|-----------|
| qBittorrent-nox | Cliente torrent sem interface gráfica |
| rclone | Ferramenta de sincronização com cloud |
| screen | Gerenciador de sessões |
| speedtest-cli | Teste de velocidade |
| nload / iftop | Monitores de rede |

## 🔧 Configuração

Durante a instalação você escolherá:

1. **Senha do qBittorrent** (padrão: admin123)
2. **Método de autenticação:**
   - OAuth (recomendado - mais fácil)
   - Service Account (avançado)
3. **Nome da pasta no Google Drive** (padrão: VPS-DOWNLOADS)

## 🎯 Após a Instalação

### Acessar qBittorrent Web:
```
http://SEU_IP:8080
Usuário: admin
Senha: (a que você escolheu)
```

### Comandos úteis:
```bash
# Forçar upload manual
/root/force-upload.sh

# Monitorar downloads
/root/monitor.sh

# Ver logs de upload
tail -f /var/log/gdrive-upload.log

# Testar velocidade
speedtest-cli

# Reiniciar qBittorrent
pkill qbittorrent-nox
screen -dmS qbittorrent qbittorrent-nox
```

## 📖 Tutorial Completo

O script inclui tutorial passo a passo para:

### OAuth (Método Recomendado):
1. Criar projeto no Google Cloud Console
2. Ativar Google Drive API
3. Configurar tela de consentimento
4. Criar credenciais OAuth
5. Autorizar acesso

### Service Account (Método Avançado):
1. Criar Service Account
2. Baixar chave JSON
3. Compartilhar pasta do Drive

## 🐛 Solução de Problemas

### Não consigo acessar a porta 8080
```bash
# Liberar no firewall
ufw allow 8080/tcp
ufw reload

# Ou use túnel SSH
ssh -L 8080:localhost:8080 root@SEU_IP
# Depois acesse: http://localhost:8080
```

### qBittorrent não inicia
```bash
# Verificar se está rodando
ps aux | grep qbittorrent

# Reiniciar
pkill qbittorrent-nox
screen -dmS qbittorrent qbittorrent-nox
```

### Erro na conexão com Google Drive
```bash
# Testar conexão
rclone lsd gdrive:

# Reconfigurar
rclone config
```

## 🔐 Segurança

- ✅ Senha customizável para qBittorrent
- ✅ OAuth com tokens seguros
- ✅ Service Account com chaves criptografadas
- ✅ Upload limitado para economizar banda

## 📊 Desempenho

Em uma VPS com 1Gbps:

| Operação | Tempo (100GB) |
|----------|---------------|
| Download torrent | 15-30 min |
| Upload Google Drive | 15-25 min |
| **Total** | **30-55 min** |

Comparado com torrent direto (5-8 horas), você economiza ~4-7 horas! 🚀

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se livre para:

1. Fazer fork do projeto
2. Criar uma branch (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abrir um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 👤 Autor

**i9team**

- GitHub: [@i9team](https://github.com/i9team)

## ⭐ Mostre seu apoio

Se este projeto te ajudou, dê uma ⭐️!

---

**Desenvolvido com ❤️ para facilitar downloads em VPS**
