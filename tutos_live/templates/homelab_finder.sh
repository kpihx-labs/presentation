#!/data/data/com.termux/files/usr/bin/bash
# homelab_finder.sh — Scan IP, match fingerprint, update SSH config, notify Telegram
# Description: This script compensates for the lack of mDNS/Avahi support on Android.
# It scans a range of IPs around the last known address and matches the SSH fingerprint.

#######################################
#           CONFIG UTILISATEUR        #
#######################################

TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"

LOGFILE="$HOME/homelab/homelab_finder.log"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_PORT=2222

# Replace with your actual server fingerprint (get it via: ssh-keyscan -t ed25519 -p 2222 IP | ssh-keygen -lf -)
SSH_EXPECTED_FINGERPRINT="SHA256:rTRwyaqaUtvOW0oEdv8HPYbZ1fS8Ckl2ui+FRZK23og"
HOST_ALIASES=("homelab" "homelab-ui")
REFERENCE_ALIAS="homelab"
SCAN_DELTA=5

#######################################
#               LOGGING               #
#######################################
log() {
  local level="$1"
  shift
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [$level] $msg" | tee -a "$LOGFILE"
}

#######################################
#     NOTIFICATION TELEGRAM STYLÉE    #
#######################################
send_telegram() {
  local emoji="$1"
  local title="$2"
  local message="$3"
  local full="${emoji} ${title} ${emoji}%0A% ${message}"

  if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    log "WARN" "Telegram non configuré → notification ignorée."
    return
  fi

  curl -s -X POST 
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" 
    -d chat_id="${CHAT_ID}" 
    -d text="${full}" 
    > /dev/null 2>&1

  [[ $? -eq 0 ]] && log "INFO" "Notification Telegram envoyée."
}

#######################################
#     EXTRAIRE L’ANCIENNE IP SSH      #
#######################################
get_old_ip() {
  local alias="$1"
  if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
    log "ERROR" "Fichier SSH inexistant : $SSH_CONFIG_FILE"
    return 1
  fi
  local old_ip
  old_ip=$(awk -v host="$alias" '
    $1 == "Host" && $2 == host {found=1; next}
    found && $1 == "HostName" {print $2; exit}
  ' "$SSH_CONFIG_FILE")
  [[ -z "$old_ip" ]] && return 1
  echo "$old_ip"
}

#######################################
#     DÉCOMPOSER UNE IP EN A.B.C.D    #
#######################################
extract_ip_components() {
  local ip="$1"
  IFS='.' read -r A B C D <<< "$ip"
  [[ -z "$A" || -z "$B" || -z "$C" || -z "$D" ]] && return 1
  export IP_A="$A" IP_B="$B" IP_C="$C" IP_D="$D"
}

#######################################
#   CALCULER LE FINGERPRINT SSH       #
#######################################
compute_fingerprint() {
  local ip="$1"
  local key
  key=$(ssh-keyscan -t ed25519 -p "$SSH_PORT" -T 3 "$ip" 2>/dev/null)
  [[ -z "$key" ]] && return 1
  local fp
  fp=$(echo "$key" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
  [[ -n "$fp" ]] && echo "$fp"
}

#######################################
#     METTRE À JOUR ~/.ssh/config     #
#######################################
update_ssh_config() {
  local alias="$1"
  local new_ip="$2"
  [[ ! -f "$SSH_CONFIG_FILE" ]] && mkdir -p "$(dirname "$SSH_CONFIG_FILE")" && touch "$SSH_CONFIG_FILE"
  if ! grep -q "Host $alias" "$SSH_CONFIG_FILE"; then
    log "INFO" "Bloc Host $alias absent → création."
    cat >> "$SSH_CONFIG_FILE" <<EOF

Host $alias
    HostName $new_ip
    Port $SSH_PORT
    User ivann
    IdentityFile ~/.ssh/id_ed25519
EOF
    return
  fi
  local tmp
  tmp="$(mktemp)"
  awk -v host="$alias" -v newip="$new_ip" -v port="$SSH_PORT" '
    $1 == "Host" && $2 == host {inblock=1; print; next}
    $1 == "Host" && $2 != host {inblock=0; print; next}
    inblock && $1 == "HostName" {print "    HostName " newip; next}
    inblock && $1 == "Port"     {print "    Port " port; next}
    {print}
  ' "$SSH_CONFIG_FILE" > "$tmp"
  mv "$tmp" "$SSH_CONFIG_FILE"
}

#######################################
#               MAIN                  #
#######################################
main() {
  log "INFO" "=== Démarrage de homelab_finder ==="

  old_ip=$(get_old_ip "$REFERENCE_ALIAS")
  if [[ $? -ne 0 ]]; then
    log "ERROR" "Impossible de récupérer l’ancienne IP"
    send_telegram "⚠️" "homelab_finder" "Impossible de récupérer l’ancienne IP via $REFERENCE_ALIAS"
    return
  fi

  log "INFO" "Ancienne IP détectée : $old_ip"
  extract_ip_components "$old_ip" || {
    log "ERROR" "IP invalide : $old_ip"
    send_telegram "⚠️" "homelab_finder" "IP invalide : $old_ip"
    return
  }

  found_ip=""
  for ((i = IP_C - SCAN_DELTA; i <= IP_C + SCAN_DELTA; i++)); do
    ip="$IP_A.$IP_B.$i.$IP_D"
    log "INFO" "Scan de $ip..."
    fp=$(compute_fingerprint "$ip")
    if [[ -z "$fp" ]]; then
      log "WARN" "Aucun fingerprint sur $ip"
      continue
    fi
    log "INFO" "Fingerprint obtenu : $fp"
    if [[ "$fp" == "$SSH_EXPECTED_FINGERPRINT" ]]; then
      log "INFO" "MATCH fingerprint → $ip"
      found_ip="$ip"
      break
    fi
  done

  if [[ -z "$found_ip" ]]; then
    log "ERROR" "Aucune IP trouvée"
    send_telegram "❌" "homelab_finder" "Aucune IP trouvée dans la plage autour de $old_ip"
    return
  fi

  for alias in "${HOST_ALIASES[@]}"; do
    log "INFO" "Mise à jour de $alias → $found_ip"
    update_ssh_config "$alias" "$found_ip"
    send_telegram "🔧" "$alias" "✅ $alias trouvé à $found_ip"
  done

  log "INFO" "=== Fin de homelab_finder ==="
}

main
