
**Contexte :** Serveur Proxmox "Headless" sur réseau complexe \(Authentification 802\.1X, DHCP dynamique, adaptateur USB\-Ethernet\)\.

***

## 1\. Problématique et Objectifs

Dans un environnement réseau sécurisé \(type École Polytechnique\) utilisant un adaptateur USB\-Ethernet, trois problèmes critiques surviennent fréquemment :

1.  **Race Condition au démarrage :** Le serveur sollicite un bail DHCP avant la fin de l'authentification WPA \(802\.1X\), entraînant une IP de quarantaine \(`192.168.x.x`\) au lieu de l'IP publique\.
2.  **Instabilité USB :** Déconnexions intermittentes de l'adaptateur nécessitant une réinitialisation de l'interface\.
3.  **Isolation du Conteneur :** Perte de connectivité du pont NAT \(`vmbr1`\) empêchant le conteneur Docker d'accéder à Internet, même si l'hôte est en ligne\.

**La solution :** Un script "Watchdog" automatisé qui vérifie l'état du réseau toutes les 5 minutes et applique des mesures correctives graduelles\.

***

## 2\. Implémentation du Script

Le script doit être placé dans le répertoire `/root/` pour garantir les privilèges nécessaires à la manipulation des interfaces réseaux et des conteneurs Proxmox\.

### A\. Préparation du fichier
Connectez\-vous en SSH et exécutez les commandes suivantes :

```warp-runnable-command
sudo touch /root/network_watchdog.sh
sudo chmod +x /root/network_watchdog.sh
sudo nano /root/network_watchdog.sh

```
### B\. Code Source
Copiez et collez le script ci\-dessous :

```warp-runnable-command
#!/bin/bash

# ==============================================================================
# 1. CONFIGURATION
# ==============================================================================
TELEGRAM_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"

# Interfaces & Cibles
IF_WAN="vmbr0"
IF_PHY="nic1"
TARGET="8.8.8.8"
CT_ID="100"

# Chemins Absolus (VITAL POUR CRON)
PCT_CMD="/usr/sbin/pct"
PING_CMD="/usr/bin/ping"

# Fichiers
STATE_DIR="/var/lib/homelab_watchdog"
LAST_IP_FILE="$STATE_DIR/last_ip"
LOG_FILE="/var/log/network_watchdog.log"
LOCK_FILE="/tmp/network_fixing.lock"

mkdir -p "$STATE_DIR"

# ==============================================================================
# 2. FONCTIONS
# ==============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

send_telegram() {
    ICON="$1"
    TITLE="$2"
    MESSAGE="$3"
    # On force le texte vide si pas de message pour éviter erreur curl
    if [ -z "$MESSAGE" ]; then MESSAGE="Notification système"; fi
    
    TEXT="$ICON **$TITLE** $ICON%0A%0A$MESSAGE"
    
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$TEXT" > /dev/null
}

get_current_ip() {
    ip -4 addr show "$IF_WAN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1
}

# ==============================================================================
# 3. VERROU ANTI-DOUBLON
# ==============================================================================
if [ -f "$LOCK_FILE" ]; then
    if [ $(find "$LOCK_FILE" -mmin +15) ]; then
        log "⚠️ Verrou expiré supprimé."
        rm "$LOCK_FILE"
    else
        exit 0
    fi
fi

# ==============================================================================
# 4. HÔTE : VÉRIFICATION INTERNET
# ==============================================================================

HOST_OK=false

if ping -c 3 -W 5 "$TARGET" > /dev/null 2>&1; then
    HOST_OK=true
else
    # --- RÉPARATION HÔTE ---
    touch "$LOCK_FILE"
    log "- Hôte déconnecté. Début du protocole de réparation..."

    if [ -f /etc/apparmor.d/sbin.dhclient ]; then
    	ln -sf /etc/apparmor.d/sbin.dhclient /etc/apparmor.d/disable/
    	apparmor_parser -R /etc/apparmor.d.sbin.dhclient 2>/dev/null || true
    fi

    killall dhclient 2>/dev/null || true
    killall wpa_supplicant 2>/dev/null || true

    log "Action 0: Cycle interfaces..."
    # Action 0 : Simple réveil
    ip link set "$IF_WAN" down
    ip link set "$IF_PHY" down
    sleep 2
    ip link set "$IF_PHY" up
    sleep 2
    ip link set "$IF_WAN" up
    sleep 5

    if ping -c 1 "$TARGET" > /dev/null 2>&1; then
        log "+ Hôte réparé (simple réveil d'interfaces)"
        send_telegram "✅" "HÔTE RÉPARÉ" "Simple réveil d'interface."
        HOST_OK=true
    else
        log "Action 1: DHCP...."
        # Action 1 : DHCP
        dhclient -r -v "$IF_WAN" > /dev/null 2>&1
        dhclient -v "$IF_WAN" > /dev/null 2>&1
        sleep 5

        if ping -c 1 "$TARGET" > /dev/null 2>&1; then
            HOST_OK=true
            log "+ Hôte réparé (via Network DHCP)"
            send_telegram "✅" "HÔTE RÉPARÉ" "Via DHCP."
        else
            log "Action 2: WPA Reset..."
            # Action 2 : WPA Reset
            killall dhclient 2>/dev/null || true
            ip link set "$IF_PHY" down
            sleep 2
            ip link set "$IF_PHY" up
            wpa_supplicant -B -i "$IF_PHY" -c /etc/wpa_supplicant/polytechnique.conf -D wired
            sleep 15
            dhclient -v "$IF_WAN" > /dev/null 2>&1

            if ping -c 1 "$TARGET" > /dev/null 2>&1; then
                HOST_OK=true
                log "+ Hôte réparé (via Network reset WPA)"
                send_telegram "🛡️" "HÔTE RÉPARÉ" "Via Reset WPA."
            else
                log "Action 3: Restart system networking..."
                killall wpa_supplicant 2>/dev/null || true
                killall dhclient 2>/dev/null || true

                systemctl restart networking
                sleep 20

                if ping -c 1 "$TARGET" > /dev/null 2>&1; then
                    log "+ Hôte réparé (via Network reset)"
                    send_telegram "✅" "HÔTE RÉPARÉ" "Network reset"
                    HOST_OK=true
                fi

            fi
        fi
    fi
    rm "$LOCK_FILE"
fi

if [ "$HOST_OK" = false ]; then
    log "- Échec Hôte."
    exit 1
fi

# --- Suivi IP ---
CURRENT_IP=$(get_current_ip)
if [ -f "$LAST_IP_FILE" ]; then LAST_IP=$(cat "$LAST_IP_FILE"); else LAST_IP="Inconnue"; fi
if [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "$LAST_IP" ]; then
    echo "$CURRENT_IP" > "$LAST_IP_FILE"
    if [[ "$CURRENT_IP" != 192.168* ]]; then
        send_telegram "🔄" "INFO IP" "Nouvelle IP : \`$CURRENT_IP\`"
    fi
fi

# ==============================================================================
# 5. CONTENEUR : VÉRIFICATION PROFONDE (PCT)
# ==============================================================================
# Utilisation de chemins absolus pour éviter "command not found"

# A. Le conteneur tourne-t-il ?
CT_STATUS=$($PCT_CMD status $CT_ID)

if [[ $CT_STATUS != *"running"* ]]; then
    log "⚠️ Conteneur $CT_ID éteint."
    send_telegram "⚠️" "CONTENEUR ÉTEINT" "Démarrage en cours..."
    
    $PCT_CMD start $CT_ID
    sleep 15 # On laisse le temps au réseau de monter
fi

# B. Le conteneur a-t-il internet ?
# On utilise le ping simple (sans option w/W) pour compatibilité maximale
if ! $PCT_CMD exec $CT_ID -- ping -c 1 "$TARGET" > /dev/null 2>&1; then
    touch "$LOCK_FILE"
    log "🟠 Hôte OK mais Conteneur déconnecté."
    send_telegram "🛠️" "PANNE CONTENEUR" "Le serveur a internet, mais le Docker-Host ne ping pas google.%0ADébut de la réparation..."

    # --- RÉPARATION ---
    
    # 1. Vérification pont interne
    ip link set vmbr1 up
    
    # 2. Redémarrage violent du conteneur (seule façon de re-clipser le réseau)
    log "Reboot conteneur $CT_ID..."
    $PCT_CMD stop $CT_ID
    sleep 5
    $PCT_CMD start $CT_ID
    
    # Attente longue (pour que Docker et le réseau s'initialisent)
    sleep 20
    
    # --- VÉRIFICATION FINALE ---
    if $PCT_CMD exec $CT_ID -- ping -c 1 "$TARGET" > /dev/null 2>&1; then
        log "✅ Conteneur reconnecté."
        send_telegram "🐳" "CONTENEUR RÉTABLI" "Redémarrage effectué avec succès.%0AAccès internet OK."
    else
        log "❌ Échec réparation Conteneur."
        send_telegram "💀" "ÉCHEC CONTENEUR" "Malgré le redémarrage, le conteneur n'a pas internet.%0AVérifie le pont vmbr1 manuellement."
    fi
    
    rm "$LOCK_FILE"
fi

exit 0
```
***

## 3\. Automatisation avec Cron

Pour que la surveillance soit constante, nous programmons le script pour s'exécuter toutes les 5 minutes\.

1.  Ouvrez le crontab de **root** :
```warp-runnable-command
sudo crontab -e
```
2.  Ajoutez la ligne suivante à la fin du fichier :
```text
*/5 * * * * /root/network_watchdog.sh >> /var/log/cron_watchdog_debug.log 2>&1
```
    *Note : La redirection vers le fichier `.log` permet de capturer d'éventuelles erreurs de syntaxe\.*

***

## 4\. Surveillance et Diagnostics

### A\. Vérifier l'activité du script
Pour voir si Cron lance bien la tâche :
```warp-runnable-command
sudo journalctl -u cron -n 20 --no-pager | grep watchdog

```
### B\. Consulter les logs métier
Ce fichier recense uniquement les pannes et les actions de réparation :
```warp-runnable-command
sudo tail -f /var/log/network_watchdog.log

```
### C\. Vérifier la persistance
Vérifiez que le script mémorise correctement votre adresse IP :
```warp-runnable-command
cat /var/lib/homelab_watchdog/last_ip

```
***

## 5\. Crash Test \(Validation\)

Il est recommandé de tester le watchdog pour valider son bon fonctionnement :

1.  **Simuler une panne conteneur :** 
```warp-runnable-command
sudo ip link set vmbr1 down
```
2.  **Observer la réaction :**
    *   Suivez les logs : `tail -f /var/log/network_watchdog.log`\.
    *   Attendez maximum 5 minutes\.
3.  **Résultat attendu :**
    *   Le script détecte la coupure\.
    *   Une notification Telegram est envoyée\.
    *   L'interface `vmbr1` repasse en `UP` et le conteneur est redémarré\.
