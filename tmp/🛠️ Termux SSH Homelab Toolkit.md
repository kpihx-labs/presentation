
**Contexte : Accès SSH mobile fiable à un homelab sur réseau complexe \(DHCP dynamique, absence de DNS local, services exposés via tunnels\)\.**
## 1\. Contexte & Objectifs
L’usage de Termux sur Android permet de transformer un smartphone en **véritable terminal Linux**, capable de :
* se connecter en SSH à un homelab ou un serveur distant,
* exécuter des scripts automatisés,
* gérer des tunnels locaux \(Proxmox, Portainer, Traefik…\),
* compenser l’absence de DNS local \(mDNS/Avahi impossible sur Android\),
* maintenir une configuration SSH stable malgré les changements d’IP\.
Cependant, trois contraintes majeures apparaissent immédiatement :
### **1\. Absence de DNS local \(mDNS / Avahi impossible sur Android\)**
Android ne supporte pas Avahi/mDNS → impossible d’utiliser `homelab.local`\.
### **2\. IP dynamique \(DHCP\) sur le réseau cible**
Le serveur peut changer d’IP → les connexions SSH cassent\.
### **3\. Besoin d’un environnement Linux cohérent sur Android**
Termux n’est pas un simple terminal :
c’est un **Linux userland complet**, avec :
* `$HOME = /data/data/com.termux/files/home`
* `$PREFIX = /data/data/com.termux/files/usr`
* un système de packages \(`pkg`\) basé sur Debian
* des limitations \(pas de systemd, pas de /etc, sandbox strict\)
**Objectif final :**  
Créer un environnement Termux capable de :
* se connecter en SSH au homelab et au docker\-host,
* exposer des services via tunnels locaux,
* détecter automatiquement les changements d’IP,
* mettre à jour la configuration SSH,
* envoyer des notifications Telegram\.
## 2\. Installation & Configuration de Termux
### **A\. Installation propre \(F\-Droid recommandé\)**
Télécharger Termux depuis F\-Droid :
👉 [https://f\\\\\\\-droid\\\\\\\.org/en/packages/com\\\\\\\.termux/](https://f-droid.org/en/packages/com.termux/)
Pourquoi pas le Play Store ?
* version obsolète
* incompatibilités
* pas de mises à jour
### **B\. Mise à jour de l’environnement**
bash

```warp-runnable-command
pkg update && pkg upgrade
```
### **C\. Installation d’OpenSSH**
bash

```warp-runnable-command
pkg install openssh
```
### **D\. Génération d’une clé SSH dédiée à Termux**
bash

```warp-runnable-command
ssh-keygen -t ed25519 -C "termux-homelab" -f ~/.ssh/id_ed25519_termux
```
Cela crée :
* clé privée : `~/.ssh/id_ed25519_termux`
* clé publique : `~/.ssh/id_ed25519_termux.pub`
Afficher la clé publique :
bash

```warp-runnable-command
cat ~/.ssh/id_ed25519_termux.pub
```
### **E\. Ajouter la clé publique sur les serveurs**
#### Sur homelab :
bash

```warp-runnable-command
nano ~/.ssh/authorized_keys
```
Coller la clé publique\.
#### Sur docker\-host :
bash

```warp-runnable-command
nano ~/.ssh/authorized_keys
```
Coller la même clé\.
## 3\. Configuration SSH optimisée
Créer le fichier :
bash

```warp-runnable-command
nano ~/.ssh/config
```
Coller :
sshconfig

```warp-runnable-command
Host homelab
    HostName 129.104.232.118
    User ivann
    Port 2222
    ServerAliveInterval 60
    IdentityFile ~/.ssh/id_ed25519_termux

Host homelab-ui
    HostName 129.104.232.118
    User ivann
    Port 2222
    ServerAliveInterval 60
    LocalForward 8006 localhost:8006
    LocalForward 9443 10.10.10.10:9443
    LocalForward 8443 10.10.10.10:443
    LocalForward 8080 10.10.10.10:80
    IdentityFile ~/.ssh/id_ed25519_termux

Host docker-host
    HostName 10.10.10.10
    User root
    ProxyJump homelab
    IdentityFile ~/.ssh/id_ed25519_termux
```
### **Explications :**
* `homelab` → accès SSH direct
* `homelab-ui` → accès SSH \+ tunnels locaux \(Proxmox, Portainer…\)
* `docker-host` → accès via `ProxyJump` \(rebond via homelab\)
### **Accès aux services depuis le téléphone :**
ServiceURL locale sur le téléphone
Proxmoxhttp://localhost:8006Portainerhttp://localhost:9443Traefik❌ ne fonctionnera pas sans DNS interneApps Docker❌ idem
Pourquoi Traefik ne marche pas ?
→ Traefik route selon les **hostnames** \(`app.homelab`, `vault.homelab`, etc\.\)
→ Android n’a pas de DNS local → impossible de résoudre ces noms\.
## 4\. Problème : IP dynamique & absence de DNS
### → Solution : Script **homelab\_finder\.sh**
Comme Android ne supporte pas Avahi/mDNS, et que l’IP du homelab change régulièrement, il faut :
* scanner une plage d’IP autour de la dernière connue
* vérifier le fingerprint SSH
* mettre à jour automatiquement `~/.ssh/config`
* envoyer une notification Telegram
## 5\. Installation du Script d’Auto\-Découverte
Créer le dossier :
bash

```warp-runnable-command
mkdir ~/homelab
```
Créer le script :
bash

```warp-runnable-command
nano ~/homelab/homelab_finder.sh
```
Coller :
bash

```warp-runnable-command
data/data/com.termux/files/usr/bin/bash
#
# homelab_finder.sh — Scan IP, match fingerprint, update SSH config, notify Telegram

#######################################
#           CONFIG UTILISATEUR        #
#######################################

TELEGRAM_BOT_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"

LOGFILE="$HOME/homelab/homelab_finder.log"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_PORT=2222

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

  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${full}" \
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
```
Rendre exécutable :
bash

```warp-runnable-command
chmod +x ~/homelab/homelab_finder.sh
```
Exécuter :
bash

```warp-runnable-command
~/homelab/homelab_finder.sh
```
## 6\. Logs & Notifications
### **A\. Logs**
Les logs sont dans :
Code

```warp-runnable-command
~/homelab/homelab_finder.log
```
Afficher :
bash

```warp-runnable-command
tail -f ~/homelab/homelab_finder.log
```
### **B\. Notifications Telegram**
Chaque fois qu’une IP est trouvée :
Code

```warp-runnable-command
🔧 homelab 🔧
%0A%
✅ homelab trouvé à 129.104.232.118
```
## 7\. Pourquoi `homelab-ui` est essentiel
`homelab-ui` expose des tunnels locaux permettant d’accéder depuis le téléphone à :
* Proxmox → `localhost:8006`
* Portainer → `localhost:9443`
* Services Docker internes → `localhost:8080`, `localhost:8443`
### Limite actuelle :
Les services derrière Traefik nécessitent un **hostname** \(`app.homelab`, `vault.homelab`, etc\.\)\.
Android ne peut pas :
* résoudre `.local`
* modifier `/etc/hosts`
* utiliser Avahi
Donc Traefik ne peut pas router correctement\.
# 🎯 Conclusion
Avec Termux \+ SSH \+ tunnels \+ homelab\_finder\.sh, tu obtiens :
* un terminal Linux complet sur Android
* un accès SSH fiable au homelab
* des tunnels locaux pour Proxmox & Portainer
* une auto\-réparation en cas de changement d’IP
* des notifications Telegram
* une configuration propre, stable et portable
