#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# 🤖 RVCArise Bot CLI v2.0
# Script interativo para controlar o bot pelo terminal (Arch Linux)
#
# Funcionalidades:
#   - Entrar em grupos via ID ou @username
#   - Enviar/ler mensagens em tempo real
#   - Enviar comandos do bot (!d, !youtube, etc.) via Worker
#   - Broadcast para todos os grupos
#   - Modo live (polling) para ver mensagens em tempo real
#   - Gerenciar webhook automaticamente
#
# Uso:
#   ./rvcbot-cli.sh              # modo interativo
#   ./rvcbot-cli.sh scan         # listar chats
#   ./rvcbot-cli.sh send ID msg  # enviar mensagem
#   ./rvcbot-cli.sh live         # modo tempo real
# ═══════════════════════════════════════════════════════════════════

# Sem set -e para não crashar em erros de API
# Sem set -u para permitir variáveis vazias

# ─── CONFIG ───────────────────────────────────────────────────────
# NEVER hardcode secrets — use environment variables or .env file
# Copy .env.example to .env and fill in your values
if [[ -f "$(dirname "$0")/.env" ]]; then
    source "$(dirname "$0")/.env"
fi
BOT_TOKEN="${BOT_TOKEN:?BOT_TOKEN not set — create bot/.env with your token}"
ADMIN_ID="${ADMIN_ID:?ADMIN_ID not set — create bot/.env with your admin ID}"
WORKER_URL="${WORKER_URL:-https://kinera-tg-bot.christovaopereirasilvaa.workers.dev}"
API="https://api.telegram.org/bot${BOT_TOKEN}"
POLL_TIMEOUT=30

# ─── CORES ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── ESTADO ───────────────────────────────────────────────────────
WEBHOOK_URL_SAVED=""
POLLING=false
CURRENT_CHAT_ID=""
CURRENT_CHAT_NAME=""
CURRENT_CHAT_TYPE=""
LAST_UPDATE_ID=0

# ─── TELEGRAM API ─────────────────────────────────────────────────

tg_get() {
    curl -s --max-time 10 "${API}/${1}"
}

tg_post() {
    local endpoint="$1"
    local data="$2"
    curl -s --max-time 15 -X POST "${API}/${endpoint}" \
        -H "Content-Type: application/json" \
        -d "$data"
}

# ─── WEBHOOK ──────────────────────────────────────────────────────

save_webhook() {
    local info=$(tg_get "getWebhookInfo")
    WEBHOOK_URL_SAVED=$(echo "$info" | jq -r '.result.url // empty' 2>/dev/null)
    if [[ -n "$WEBHOOK_URL_SAVED" ]]; then
        echo -e "${YELLOW}📡 Webhook salvo: ${DIM}${WEBHOOK_URL_SAVED:0:50}...${RESET}"
    else
        echo -e "${GRAY}📡 Nenhum webhook ativo${RESET}"
    fi
}

pause_webhook() {
    save_webhook
    if [[ -n "$WEBHOOK_URL_SAVED" ]]; then
        echo -e "${YELLOW}⏸️  Pausando webhook para polling...${RESET}"
        tg_post "deleteWebhook" '{}' > /dev/null
        sleep 1
        # Consumir updates pendentes
        local updates=$(tg_post "getUpdates" '{"limit":1,"timeout":0}')
        LAST_UPDATE_ID=$(echo "$updates" | jq -r '.result[-1].update_id // 0' 2>/dev/null)
        if [[ "$LAST_UPDATE_ID" -gt 0 ]]; then
            tg_post "getUpdates" "{\"offset\":$((LAST_UPDATE_ID + 1)),\"limit\":1,\"timeout\":0}" > /dev/null
        fi
    fi
    POLLING=true
}

restore_webhook() {
    if [[ -n "$WEBHOOK_URL_SAVED" ]] && [[ "$POLLING" == true ]]; then
        echo -e "${YELLOW}▶️  Restaurando webhook...${RESET}"
        tg_post "setWebhook" "{\"url\":\"${WEBHOOK_URL_SAVED}\"}" > /dev/null
        POLLING=false
        echo -e "${GREEN}✅ Webhook restaurado${RESET}"
    fi
}

# ─── BOT INFO ────────────────────────────────────────────────────

get_bot_info() {
    local info=$(tg_get "getMe")
    local ok=$(echo "$info" | jq -r '.ok' 2>/dev/null)
    if [[ "$ok" != "true" ]]; then
        echo -e "${RED}❌ Bot não encontrado! Verifique o token.${RESET}"
        return 1
    fi
    local username=$(echo "$info" | jq -r '.result.username')
    local name=$(echo "$info" | jq -r '.result.first_name')
    local id=$(echo "$info" | jq -r '.result.id')
    echo -e "${GREEN}🤖 ${BOLD}${name}${RESET}${GREEN} (@${username}) [${id}]${RESET}"
}

check_worker() {
    local status=$(curl -s --max-time 5 "$WORKER_URL" 2>/dev/null || echo '{"error":"unreachable"}')
    local bot_status=$(echo "$status" | jq -r '.bot // "offline"' 2>/dev/null)
    if [[ "$bot_status" == *"Online"* ]]; then
        echo -e "${GREEN}☁️  Worker: Online${RESET}"
    else
        echo -e "${RED}☁️  Worker: Offline${RESET}"
    fi
}

# ─── SCAN / LISTAR CHATS ─────────────────────────────────────────

scan_updates() {
    echo -e "${CYAN}🔍 Escaneando updates para encontrar chats...${RESET}"
    
    local was_polling="$POLLING"
    if [[ "$POLLING" == false ]]; then
        pause_webhook
    fi
    
    local updates=$(tg_post "getUpdates" '{"limit":100,"timeout":0}')
    local count=$(echo "$updates" | jq -r '.result | length' 2>/dev/null)
    
    # Extrair chats únicos
    local chats=$(echo "$updates" | jq -r '
        .result[] |
        .message.chat // .my_chat_member.chat // empty |
        {id, type, title: (.title // .first_name // "DM")} |
        "\(.id)|\(.type)|\(.title)"
    ' 2>/dev/null | sort -u -t'|' -k1,1)
    
    if [[ -z "$chats" ]]; then
        echo -e "${YELLOW}  Nenhum chat encontrado.${RESET}"
        echo -e "${GRAY}  Dica: mande uma mensagem pro bot ou adicione ele a um grupo${RESET}"
    else
        echo ""
        echo -e "  ${BOLD}ID               Tipo        Nome${RESET}"
        echo -e "  ${DIM}──────────────── ─────────── ──────────────────${RESET}"
        while IFS='|' read -r id type name; do
            [[ -z "$id" ]] && continue
            local icon="💬"
            [[ "$type" == "group" ]] && icon="👥"
            [[ "$type" == "supergroup" ]] && icon="🏛️"
            [[ "$type" == "channel" ]] && icon="📢"
            [[ "$type" == "private" ]] && icon="👤"
            printf "  ${icon} %-15s %-11s %s\n" "$id" "$type" "$name"
        done <<< "$chats"
        echo ""
        echo -e "  ${GREEN}${count} updates processados${RESET}"
    fi
    
    # Atualizar offset
    LAST_UPDATE_ID=$(echo "$updates" | jq -r '.result[-1].update_id // 0' 2>/dev/null)
    if [[ "${LAST_UPDATE_ID:-0}" -gt 0 ]]; then
        tg_post "getUpdates" "{\"offset\":$((LAST_UPDATE_ID + 1)),\"limit\":1,\"timeout\":0}" > /dev/null
    fi
}

# ─── ENTER CHAT ───────────────────────────────────────────────────

enter_chat() {
    local target="$1"
    
    # Link de convite
    if [[ "$target" == https://t.me/* ]] || [[ "$target" == http://t.me/* ]]; then
        echo -e "${YELLOW}🔗 Link do Telegram detectado${RESET}"
        
        # Tentar como @username (t.me/username)
        local username=$(echo "$target" | sed 's|https\?://t.me/||' | sed 's|^[+]||')
        
        # Se é link de convite (tem + ou joinchat)
        if [[ "$target" == *"/+/"* ]] || [[ "$target" == *"/joinchat/"* ]] || [[ "$target" == *"?start="* ]] || [[ "$username" == +* ]]; then
            echo -e "${GRAY}  Bots não podem aceitar convites automaticamente.${RESET}"
            echo -e "${GRAY}  Adicione o bot manualmente ao grupo e use: enter <chat_id>${RESET}"
            echo ""
            echo -e "  ${BOLD}Como adicionar o bot ao grupo:${RESET}"
            echo -e "  1. Abra o grupo no Telegram"
            echo -e "  2. Toque no nome do grupo → Adicionar Membros"
            echo -e "  3. Busque pelo bot e adicione"
            echo -e "  4. Use ${GREEN}scan${RESET} para descobrir o ID"
            echo -e "  5. Use ${GREEN}enter <id>${RESET} para entrar"
            return
        fi
        
        # É um username público — tentar acessar como @username
        target="@${username}"
    fi
    
    # @username
    if [[ "$target" == @* ]]; then
        echo -e "${CYAN}🔍 Buscando @${target#@}...${RESET}"
    fi
    
    # Tentar acessar o chat
    local chat_info=$(tg_post "getChat" "{\"chat_id\":\"${target}\"}")
    local ok=$(echo "$chat_info" | jq -r '.ok' 2>/dev/null)
    
    if [[ "$ok" == "true" ]]; then
        local chat_id=$(echo "$chat_info" | jq -r '.result.id')
        local chat_type=$(echo "$chat_info" | jq -r '.result.type')
        local chat_title=$(echo "$chat_info" | jq -r '.result.title // .result.first_name // "Chat"')
        local members=$(echo "$chat_info" | jq -r '.result.member_count // "?"')
        local desc=$(echo "$chat_info" | jq -r '.result.description // ""')
        local username=$(echo "$chat_info" | jq -r '.result.username // ""')
        
        CURRENT_CHAT_ID="$chat_id"
        CURRENT_CHAT_NAME="$chat_title"
        CURRENT_CHAT_TYPE="$chat_type"
        
        local icon="💬"
        [[ "$chat_type" == "group" ]] && icon="👥"
        [[ "$chat_type" == "supergroup" ]] && icon="🏛️"
        [[ "$chat_type" == "channel" ]] && icon="📢"
        [[ "$chat_type" == "private" ]] && icon="👤"
        
        echo -e "${GREEN}✅ Chat ativo: ${icon} ${BOLD}${chat_title}${RESET} [${chat_id}]"
        echo -e "   Tipo: ${chat_type} | Membros: ${members}"
        [[ -n "$username" ]] && echo -e "   Username: @${username}"
        [[ -n "$desc" ]] && echo -e "   ${DIM}Descrição: ${desc:0:80}${RESET}"
        echo ""
    else
        local desc=$(echo "$chat_info" | jq -r '.description // "Erro desconhecido"' 2>/dev/null)
        echo -e "${RED}❌ Não consegui acessar: ${desc}${RESET}"
        echo ""
        echo -e "${GRAY}O bot precisa estar no grupo para acessá-lo.${RESET}"
        echo -e "${GRAY}Adicione o bot ao grupo primeiro, depois use o ID.${RESET}"
    fi
}

leave_chat() {
    if [[ -z "$CURRENT_CHAT_ID" ]]; then
        echo -e "${YELLOW}⚠️  Nenhum chat ativo${RESET}"
        return
    fi
    echo -e "${YELLOW}Saindo do chat: ${CURRENT_CHAT_NAME}${RESET}"
    CURRENT_CHAT_ID=""
    CURRENT_CHAT_NAME=""
    CURRENT_CHAT_TYPE=""
}

show_chat_info() {
    if [[ -z "$CURRENT_CHAT_ID" ]]; then
        echo -e "${RED}❌ Nenhum chat ativo. Use: enter <chat_id>${RESET}"
        return
    fi
    local info=$(tg_post "getChat" "{\"chat_id\":\"${CURRENT_CHAT_ID}\"}")
    echo "$info" | jq -r '
        "📋 Chat Info:",
        "  ID: \(.result.id)",
        "  Tipo: \(.result.type)",
        "  Nome: \(.result.title // .result.first_name)",
        "  Username: \(.result.username // "nenhum")",
        "  Membros: \(.result.member_count // "?")",
        "  Descrição: \(.result.description // "nenhuma")",
        "  Criado: \(.result.date // "?")"
    ' 2>/dev/null
}

# ─── MENSAGENS ────────────────────────────────────────────────────

send_message() {
    local text="$1"
    
    if [[ -z "$CURRENT_CHAT_ID" ]]; then
        echo -e "${RED}❌ Nenhum chat ativo. Use: enter <chat_id>${RESET}"
        return 1
    fi
    
    local result=$(tg_post "sendMessage" "{\"chat_id\":\"${CURRENT_CHAT_ID}\",\"text\":$(echo "$text" | jq -Rs .)}")
    local ok=$(echo "$result" | jq -r '.ok' 2>/dev/null)
    
    if [[ "$ok" == "true" ]]; then
        local msg_id=$(echo "$result" | jq -r '.result.message_id')
        echo -e "${GREEN}✅ Enviado [${msg_id}]${RESET}"
    else
        local desc=$(echo "$result" | jq -r '.description // "Erro desconhecido"' 2>/dev/null)
        echo -e "${RED}❌ ${desc}${RESET}"
        return 1
    fi
}

send_to_chat() {
    local chat_id="$1"
    shift
    local text="$*"
    
    if [[ -z "$chat_id" ]] || [[ -z "$text" ]]; then
        echo -e "${YELLOW}Uso: msg <chat_id> <texto>${RESET}"
        return 1
    fi
    
    local result=$(tg_post "sendMessage" "{\"chat_id\":\"${chat_id}\",\"text\":$(echo "$text" | jq -Rs .)}")
    local ok=$(echo "$result" | jq -r '.ok' 2>/dev/null)
    
    if [[ "$ok" == "true" ]]; then
        echo -e "${GREEN}✅ Mensagem enviada para ${chat_id}${RESET}"
    else
        local desc=$(echo "$result" | jq -r '.description // "Erro"' 2>/dev/null)
        echo -e "${RED}❌ ${desc}${RESET}"
        return 1
    fi
}

broadcast_message() {
    local text="$*"
    
    if [[ -z "$text" ]]; then
        echo -e "${YELLOW}Uso: broadcast <texto>${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}📢 Coletando grupos...${RESET}"
    
    if [[ "$POLLING" == false ]]; then
        pause_webhook
    fi
    
    local updates=$(tg_post "getUpdates" '{"limit":100,"timeout":0}')
    local chat_ids=$(echo "$updates" | jq -r '
        .result[] |
        .message.chat |
        select(.type == "group" or .type == "supergroup") |
        .id
    ' 2>/dev/null | sort -u)
    
    if [[ -z "$chat_ids" ]]; then
        echo -e "${YELLOW}⚠️  Nenhum grupo encontrado nos updates.${RESET}"
        echo -e "${GRAY}  Dica: mande alguma mensagem nos grupos primeiro, depois use scan${RESET}"
        return 1
    fi
    
    local count=0
    echo ""
    while read -r chat_id; do
        [[ -z "$chat_id" ]] && continue
        local chat_info=$(tg_post "getChat" "{\"chat_id\":\"${chat_id}\"}")
        local name=$(echo "$chat_info" | jq -r '.result.title // "Grupo"' 2>/dev/null)
        
        local result=$(tg_post "sendMessage" "{\"chat_id\":\"${chat_id}\",\"text\":$(echo "$text" | jq -Rs .)}")
        local ok=$(echo "$result" | jq -r '.ok' 2>/dev/null)
        
        if [[ "$ok" == "true" ]]; then
            echo -e "  ${GREEN}✅ ${name}${RESET}"
            count=$((count + 1))
        else
            echo -e "  ${RED}❌ ${name}${RESET}"
        fi
        sleep 0.3
    done <<< "$chat_ids"
    
    echo ""
    echo -e "${GREEN}📢 Broadcast: ${count} grupo(s) receberam a mensagem${RESET}"
}

# ─── LIVE / POLLING ───────────────────────────────────────────────

live_poll() {
    if [[ "$POLLING" == false ]]; then
        pause_webhook
    fi
    
    echo ""
    echo -e "${BOLD}🔴 MODO LIVE — Mensagens em tempo real${RESET}"
    echo -e "${DIM}────────────────────────────────────────${RESET}"
    if [[ -n "$CURRENT_CHAT_ID" ]]; then
        echo -e "${CYAN}📡 Monitorando: ${BOLD}${CURRENT_CHAT_NAME}${RESET} [${CURRENT_CHAT_ID}]"
    else
        echo -e "${CYAN}📡 Monitorando: ${BOLD}TODOS os chats${RESET}"
    fi
    echo -e "${YELLOW}Ctrl+C para parar${RESET}"
    echo -e "${DIM}────────────────────────────────────────${RESET}"
    echo ""
    
    local offset=$((LAST_UPDATE_ID + 1))
    
    while true; do
        local updates=$(tg_post "getUpdates" "{\"offset\":${offset},\"limit\":10,\"timeout\":${POLL_TIMEOUT}}")
        
        if [[ -z "$updates" ]]; then
            continue
        fi
        
        local items=$(echo "$updates" | jq -c '.result[]' 2>/dev/null)
        
        if [[ -n "$items" ]]; then
            while IFS= read -r update; do
                local uid=$(echo "$update" | jq -r '.update_id')
                offset=$((uid + 1))
                LAST_UPDATE_ID=$uid
                
                # Mensagem de texto
                local msg=$(echo "$update" | jq -r '.message // empty' 2>/dev/null)
                if [[ -n "$msg" ]]; then
                    local chat_id=$(echo "$msg" | jq -r '.chat.id')
                    local chat_name=$(echo "$msg" | jq -r '.chat.title // .chat.first_name // "DM"')
                    local chat_type=$(echo "$msg" | jq -r '.chat.type')
                    local sender=$(echo "$msg" | jq -r '.from.first_name // "Unknown"')
                    local text=$(echo "$msg" | jq -r '.text // "[midia]"')
                    local ts=$(echo "$msg" | jq -r '.date')
                    
                    # Filtrar por chat ativo
                    if [[ -n "$CURRENT_CHAT_ID" ]] && [[ "$chat_id" != "$CURRENT_CHAT_ID" ]]; then
                        continue
                    fi
                    
                    local icon="💬"
                    [[ "$chat_type" == "group" ]] && icon="👥"
                    [[ "$chat_type" == "supergroup" ]] && icon="🏛️"
                    [[ "$chat_type" == "private" ]] && icon="👤"
                    
                    # Time format
                    local time=$(date -d "@${ts}" "+%H:%M:%S" 2>/dev/null || echo "?")
                    
                    if [[ -z "$CURRENT_CHAT_ID" ]]; then
                        echo -e "  ${DIM}${time}${RESET} ${icon} ${DIM}[${chat_name}]${RESET} ${BOLD}${sender}:${RESET} ${text}"
                    else
                        echo -e "  ${DIM}${time}${RESET} ${BOLD}${sender}:${RESET} ${text}"
                    fi
                fi
            done <<< "$items"
        fi
    done
}

# ─── WORKER PROXY ─────────────────────────────────────────────────

worker_send() {
    local chat_id="$1"
    local text="$2"
    curl -s --max-time 30 -X POST "$WORKER_URL" \
        -H "Content-Type: application/json" \
        -d "{\"message\":{\"chat\":{\"id\":${chat_id}},\"from\":{\"id\":${ADMIN_ID},\"first_name\":\"Admin\"},\"text\":\"${text}\"}}"
}

bot_cmd() {
    local cmd="$1"
    if [[ -z "$CURRENT_CHAT_ID" ]]; then
        echo -e "${RED}❌ Nenhum chat ativo. Use: enter <chat_id>${RESET}"
        return
    fi
    
    echo -e "${CYAN}📤 ${cmd}${RESET}"
    local result=$(worker_send "$CURRENT_CHAT_ID" "$cmd")
    if [[ "$result" == "OK" ]]; then
        echo -e "${GREEN}✅ Comando processado pelo Worker${RESET}"
    else
        echo -e "${YELLOW}⚠️  Worker: ${result}${RESET}"
    fi
}

# ─── STATUS & HELP ────────────────────────────────────────────────

show_status() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║      🤖 RVCArise Bot CLI v2.0        ║${RESET}"
    echo -e "${BOLD}╚═══════════════════════════════════════╝${RESET}"
    echo ""
    get_bot_info
    check_worker
    echo ""
    
    if [[ -n "$CURRENT_CHAT_ID" ]]; then
        local icon="💬"
        [[ "$CURRENT_CHAT_TYPE" == "group" ]] && icon="👥"
        [[ "$CURRENT_CHAT_TYPE" == "supergroup" ]] && icon="🏛️"
        [[ "$CURRENT_CHAT_TYPE" == "private" ]] && icon="👤"
        echo -e "📍 Chat ativo: ${icon} ${GREEN}${BOLD}${CURRENT_CHAT_NAME}${RESET} [${CURRENT_CHAT_ID}]"
    else
        echo -e "📍 Chat ativo: ${YELLOW}nenhum — use enter <id>${RESET}"
    fi
    
    echo -e "📡 Polling: ${POLLING}"
    echo ""
}

show_help() {
    echo ""
    echo -e "${BOLD}═══ 🤖 RVCArise Bot CLI ═══${RESET}"
    echo ""
    echo -e "${CYAN}📡 GRUPOS & CHATS:${RESET}"
    echo -e "  ${GREEN}scan${RESET}                Listar todos os chats do bot"
    echo -e "  ${GREEN}enter${RESET} <id|@user>    Entrar em um chat/grupo"
    echo -e "  ${GREEN}enter${RESET} <link>        Info sobre como entrar via link"
    echo -e "  ${GREEN}leave${RESET}               Sair do chat atual"
    echo -e "  ${GREEN}info${RESET}                Info do chat atual"
    echo ""
    echo -e "${CYAN}💬 MENSAGENS:${RESET}"
    echo -e "  ${GREEN}say${RESET} <texto>         Enviar mensagem no chat ativo"
    echo -e "  ${GREEN}msg${RESET} <id> <texto>    Enviar para um chat específico"
    echo -e "  ${GREEN}broadcast${RESET} <txt>     Enviar para todos os grupos"
    echo -e "  ${GREEN}live${RESET}                Modo tempo real (Ctrl+C para parar)"
    echo ""
    echo -e "${CYAN}🤖 COMANDOS DO BOT (via Worker):${RESET}"
    echo -e "  ${GREEN}!ping${RESET}               Ping no bot"
    echo -e "  ${GREEN}!help${RESET}               Menu de ajuda do bot"
    echo -e "  ${GREEN}!d${RESET} <celular>        Buscar especificações"
    echo -e "  ${GREEN}!youtube${RESET}            Última release"
    echo -e "  ${GREEN}!resetcache${RESET}         Limpar cache"
    echo ""
    echo -e "${CYAN}⚙️  SISTEMA:${RESET}"
    echo -e "  ${GREEN}poll${RESET} on|off         Ativar/desativar polling"
    echo -e "  ${GREEN}webhook${RESET}             Ver status do webhook"
    echo -e "  ${GREEN}worker${RESET}              Status do Cloudflare Worker"
    echo -e "  ${GREEN}status${RESET}              Status geral"
    echo -e "  ${GREEN}help${RESET}                Este menu"
    echo -e "  ${GREEN}quit${RESET}                Sair (restaura webhook)"
    echo ""
    echo -e "${GRAY}💡 Texto sem comando = mensagem no chat ativo${RESET}"
    echo -e "${GRAY}💡 Comandos ! são enviados via Worker (bot processa)${RESET}"
    echo -e "${GRAY}💡 Exemplo rápido:${RESET}"
    echo -e "${GRAY}   scan → enter -1001234567890 → Oi pessoal! → live${RESET}"
    echo ""
}

# ─── INTERACTIVE MODE ─────────────────────────────────────────────

interactive_mode() {
    show_status
    
    while true; do
        # Prompt dinâmico
        local prompt=""
        if [[ -n "$CURRENT_CHAT_ID" ]]; then
            prompt="${CURRENT_CHAT_NAME:0:18}> "
        else
            prompt="rvcbot> "
        fi
        
        echo -ne "${GREEN}${BOLD}${prompt}${RESET}"
        read -r input || break
        
        # Vazio = continuar
        [[ -z "$input" ]] && continue
        
        # Parsear
        local cmd=""
        local args=""
        cmd=$(echo "$input" | awk '{print $1}')
        args=$(echo "$input" | awk '{for(i=2;i<=NF;i++) printf $i" "; print ""}' | sed 's/ $//')
        
        # Comando em lowercase (exceto !comandos)
        local cmd_lower=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')
        
        case "$cmd_lower" in
            # ─── GRUPOS ───
            scan)
                scan_updates
                ;;
            enter|join|group|e)
                if [[ -z "$args" ]]; then
                    echo -e "${YELLOW}Uso: enter <chat_id|@username|link>${RESET}"
                    echo -e "${GRAY}Ex: enter -1001234567890${RESET}"
                    echo -e "${GRAY}Ex: enter @meugrupo${RESET}"
                    echo -e "${GRAY}Ex: enter https://t.me/meugrupo${RESET}"
                else
                    enter_chat "$args"
                fi
                ;;
            leave|l)
                leave_chat
                ;;
            info|i)
                show_chat_info
                ;;
            
            # ─── MENSAGENS ───
            say|send|s)
                if [[ -z "$args" ]]; then
                    echo -e "${YELLOW}Uso: say <texto>${RESET}"
                else
                    send_message "$args"
                fi
                ;;
            msg|m)
                local target=$(echo "$args" | awk '{print $1}')
                local text=$(echo "$args" | awk '{for(i=2;i<=NF;i++) printf $i" "; print ""}' | sed 's/ $//')
                send_to_chat "$target" "$text"
                ;;
            broadcast|bc)
                broadcast_message "$args"
                ;;
            live|watch|w)
                live_poll
                ;;
            
            # ─── BOT COMMANDS via WORKER ───
            !*)
                bot_cmd "$cmd $args"
                ;;
            
            # ─── SISTEMA ───
            poll)
                if [[ "$args" == "on" ]]; then
                    pause_webhook
                    echo -e "${GREEN}✅ Polling ativado${RESET}"
                elif [[ "$args" == "off" ]]; then
                    restore_webhook
                    echo -e "${GREEN}✅ Webhook restaurado${RESET}"
                else
                    echo -e "${YELLOW}Uso: poll on|off${RESET}"
                fi
                ;;
            webhook|wh)
                local info=$(tg_get "getWebhookInfo")
                echo "$info" | jq -r '
                    "📡 Webhook:",
                    "  URL: \(.result.url // "nenhuma")",
                    "  Pendentes: \(.result.pending_update_count)",
                    "  Último erro: \(.result.last_error_message // "nenhum")",
                    "  Última data: \(.result.last_error_date // "n/a")"
                ' 2>/dev/null
                ;;
            worker)
                worker_status
                ;;
            status|st)
                show_status
                ;;
            help|h|\?)
                show_help
                ;;
            quit|q|exit)
                echo -e "${YELLOW}👋 Saindo...${RESET}"
                restore_webhook
                echo -e "${GREEN}✅ Até mais!${RESET}"
                break
                ;;
            clear)
                clear
                ;;
            
            # ─── DEFAULT: enviar como mensagem ───
            *)
                if [[ -n "$CURRENT_CHAT_ID" ]]; then
                    # Se começa com !, mandar via Worker
                    if [[ "$cmd" == !* ]]; then
                        bot_cmd "$input"
                    else
                        send_message "$input"
                    fi
                else
                    echo -e "${YELLOW}❓ Comando desconhecido: ${cmd}${RESET}"
                    echo -e "${GRAY}   Digite ${BOLD}help${RESET} para ver os comandos${RESET}"
                fi
                ;;
        esac
    done
}

# ─── ONE-SHOT MODE ────────────────────────────────────────────────

one_shot() {
    local cmd="$1"
    shift || true
    
    case "$cmd" in
        scan)
            scan_updates
            ;;
        send)
            local chat_id="${1:-}"
            shift || true
            local text="$*"
            if [[ -z "$chat_id" ]] || [[ -z "$text" ]]; then
                echo "Uso: $0 send <chat_id> <mensagem>"
                exit 1
            fi
            send_to_chat "$chat_id" "$text"
            ;;
        broadcast|bc)
            broadcast_message "$*"
            ;;
        info)
            get_bot_info
            check_worker
            ;;
        live)
            trap restore_webhook EXIT INT TERM
            live_poll
            ;;
        enter)
            if [[ -z "${1:-}" ]]; then
                echo "Uso: $0 enter <chat_id|@username|link>"
                exit 1
            fi
            enter_chat "$1"
            ;;
        *)
            echo "Uso: $0 [comando] [args]"
            echo ""
            echo "Comandos:"
            echo "  scan              Listar chats"
            echo "  enter <id>        Entrar em um chat"
            echo "  send <id> <msg>   Enviar mensagem"
            echo "  broadcast <msg>   Enviar para todos"
            echo "  live              Modo tempo real"
            echo "  info              Info do bot"
            echo ""
            echo "  $0                Modo interativo"
            exit 1
            ;;
    esac
}

# ─── CLEANUP ─────────────────────────────────────────────────────

cleanup() {
    if [[ "$POLLING" == true ]]; then
        echo ""
        echo -e "${YELLOW}🧹 Restaurando webhook...${RESET}"
        restore_webhook
    fi
}
trap cleanup EXIT INT TERM

# ─── MAIN ─────────────────────────────────────────────────────────

main() {
    # Verificar dependências
    for dep in curl jq; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${RED}❌ ${dep} não encontrado. Instale: sudo pacman -S ${dep}${RESET}"
            exit 1
        fi
    done
    
    if [[ $# -gt 0 ]]; then
        one_shot "$@"
    else
        interactive_mode
    fi
}

main "$@"
