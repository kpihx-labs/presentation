
*Contexte : Infrastructure de production\.*  
*Objectif : Garantir la pérennité des données et la stabilité à long terme \(Règle du 3‑2‑1\)\.*
## 1\. 📐 Philosophie : La Règle du 3‑2‑1
En auto‑hébergement \(Homelab\), la panne matérielle ou l’erreur humaine n’est pas une question de *si*, mais de *quand*\.
Nous appliquons la stratégie industrielle **3‑2‑1**, adaptée à nos contraintes \(HDD instable sur le serveur\) :
### 🔢 Rappel de la règle
1. **3 copies de vos données**
    * Copie A : Production \(SSD du serveur\)
    * Copie B : Locale \(HDD externe\)
    * Copie C : Distante \(Google Drive\)
1. **2 supports différents**  
SSD vs disque mécanique
2. **1 copie hors‑site**  
Cloud \(protection contre vol/incendie\)
## 2\. 🛠️ Maintenance Préventive \(Sur le Serveur\)
### Pourquoi ?
Un serveur Linux accumule :
* mises à jour de sécurité,
* images Docker obsolètes,
* caches divers\.
Sans nettoyage → disque saturé\.
Sans redémarrage → instabilités \(fuites mémoire, USB, etc\.\)\.
### La solution
Un **script hebdomadaire** qui :
* met à jour le système,
* nettoie Docker,
* envoie des notifications Telegram,
* redémarre proprement\.
### A\. 📜 Script de Maintenance
**Emplacement :** `/root/weekly_maintenance.sh`  **Droits :** `chmod +x /root/weekly_maintenance.sh`
Ce script réalise :
1. Mise à jour APT
2. Nettoyage Docker \(`docker system prune`\)
3. Notifications Telegram
4. Reboot propre
bash

```warp-runnable-command
#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
TELEGRAM_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"
LOG_FILE="/var/log/maintenance.log"

# Proxy (Indispensable pour apt à l'X)
# export http_proxy=http://129.104.201.11:8080
# export https_proxy=http://129.104.201.11:8080

# ==============================================================================
# FONCTIONS
# ==============================================================================
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

send_telegram() {
    MSG="$1"
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🧹 **MAINTENANCE HEBDOMADAIRE** 🧹%0A%0A$MSG" > /dev/null
}

# ==============================================================================
# DÉBUT DU TRAITEMENT
# ==============================================================================
log "Démarrage de la maintenance..."
send_telegram "Début de la maintenance automatique (Mises à jour + Nettoyage)..."

# 1. MISE À JOUR SYSTÈME (Debian/Proxmox)
log "Update & Upgrade APT..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get dist-upgrade -y >> "$LOG_FILE" 2>&1
apt-get autoremove -y >> "$LOG_FILE" 2>&1
apt-get autoclean >> "$LOG_FILE" 2>&1

# 2. NETTOYAGE DOCKER (Dans le conteneur 100)
# On commande au conteneur docker-host de faire son ménage
log "Nettoyage Docker sur le conteneur 100..."
/usr/sbin/pct exec 100 -- docker system prune -a -f --volumes >> "$LOG_FILE" 2>&1

# 3. NOTIFICATION FINALE ET REBOOT
log "Maintenance terminée. Redémarrage..."
send_telegram "✅ Maintenance terminée.%0A🔄 Le serveur va redémarrer dans 1 minute."

# On attend un peu pour que le message Telegram parte
sleep 5

# Reboot
/sbin/reboot
```
*\(Voir le code complet généré précédemment pour le copier‑coller\.\)*
### B\. ⏱️ Automatisation \(Cron Root\)
Planification : **Samedi à 04h00**, période de faible activité\.
bash

```warp-runnable-command
# sudo crontab -e
0 4 * * 6 /root/weekly_maintenance.sh
```
## 3\. 🧩 Sauvegarde Niveau 1 : Snapshot Local \(Proxmox\)
### Pourquoi ?
C’est la **première ligne de défense**\.
Proxmox crée une image compressée \(`.tar.zst`\) du conteneur **sans interruption de service**\.
### Configuration \(Interface Web\)
* **Datacenter → Backup → Add**
* Node : `pve`
* Schedule : `03:00` le samedi \(1h avant la maintenance\)
* Sélection : Conteneur `100` \(docker‑host\)
* Mode : **Snapshot**
* Compression : **ZSTD**
* Rétention : **Keep Last 2**
### Résultat
Chaque samedi à 03h00, un fichier :
Code

```warp-runnable-command
/var/lib/vz/dump/vzdump-lxc-100-....tar.zst
```
est généré automatiquement\.
## 4\. 🛰️ Sauvegarde Niveau 2 & 3 : Exfiltration \(PC Client\)
### Pourquoi sur le PC ?
Brancher le HDD sur le serveur provoque des **instabilités réseau \(USB\)**\.
Le PC Ubuntu sert donc de **hub de sauvegarde** :
1. Récupère le backup depuis le serveur \(pull\)
2. Le copie sur le HDD
3. Envoie la dernière version sur Google Drive
### A\. 🧱 Pré‑requis Matériel
* **HDD externe** : formaté en Ext4
* bash

```warp-runnable-command
sudo mkfs.ext4 -L "MonHDD" /dev/sdx1
sudo chown -R user:user /media/user/MonHDD
```
* **Google Drive** : monté via *Comptes en ligne* \(GVFS\)
### B\. 📜 Script d’Exfiltration \(`backup_homelab.sh`\)
**Emplacement :** `~/backup_home_pro.sh`
Fonctionnalités :
* Vérifie la disponibilité du serveur
* Monte automatiquement HDD \+ Google Drive
* `rsync` → miroir complet sur HDD
* Copie uniquement le **dernier fichier** vers Google Drive
* Notifications \(bureau \+ Telegram\)

**Important:** 
* Il faudra créer un dossier `Backup_Homelab` à la racine du drive Google
* Pour eviter les interruptions \(cas où le terminal plante par exple\) il est conseillé de lancer ce script via tmux, bien penser pour gérer les tâches batch

```warp-runnable-command
#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# --- TELEGRAM ---
TELEGRAM_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"

# --- SERVEUR (SOURCE) ---
SERVER_ALIAS="homelab"
REMOTE_DIR="/var/lib/vz/dump"

# --- HDD EXTERNE (DESTINATION 1) ---
HDD_MOUNT_POINT="/media/kpihx/KpihX-Backup"
HDD_DEST_DIR="$HDD_MOUNT_POINT/Backups_Homelab"

# --- GOOGLE DRIVE (DESTINATION 2) ---
GDRIVE_URI="google-drive:host=polytechnique.org,user=ivann.kamdem-pouokam.2024"
GDRIVE_MOUNT_POINT="/run/user/$(id -u)/gvfs/$GDRIVE_URI"
GDRIVE_DEST_DIR="$GDRIVE_MOUNT_POINT/Backups_Homelab"

NOW=$(date +"%Y-%m-%d %H:%M:%S")

# ==============================================================================
# FONCTIONS
# ==============================================================================

alert() {
    TYPE="$1"
    MESSAGE="$2"
    
    # Notification Bureau
    notify-send "Backup Homelab [$TYPE]" "$MESSAGE"
    
    case $TYPE in
        "SUCCESS") ICON="✅" ;;
        "ERROR")   ICON="❌" ;;
        "WARN")    ICON="⚠️" ;;
        *)         ICON="ℹ️" ;;
    esac
    
    # Notification Telegram
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$ICON **BACKUP** $ICON%0A%0A$MESSAGE" \
        -d parse_mode="Markdown" > /dev/null
}

check_ssh() {
    if ! ssh -q -o ConnectTimeout=5 $SERVER_ALIAS exit; then
        alert "ERROR" "Serveur injoignable via SSH."
        exit 1
    fi
}

mount_hdd_if_needed() {
    if [ ! -d "$HDD_MOUNT_POINT" ]; then
        alert "ERROR" "HDD non monté à : $HDD_MOUNT_POINT"
        exit 1
    fi
    mkdir -p "$HDD_DEST_DIR"
}

mount_gdrive_if_needed() {
    if [ ! -d "$GDRIVE_MOUNT_POINT" ]; then
        echo "🔄 Montage GDrive..."
        gio mount "$GDRIVE_URI" 2>/dev/null
        sleep 5
        if [ ! -d "$GDRIVE_MOUNT_POINT" ]; then
            alert "WARN" "Impossible de monter le Google Drive."
            return 1
        fi
    fi
    mkdir -p "$GDRIVE_DEST_DIR"
    return 0
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

echo "[$NOW] 🚀 Démarrage Backup..."
check_ssh
mount_hdd_if_needed

# ---------------------------------------------------------
# PHASE 1 : HDD (MIROIR ARCHIVES SEULEMENT)
# ---------------------------------------------------------
echo -e "\n--- 1. Synchronisation HDD ---"

rsync -av --progress --partial --size-only \
    -e "ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=10 -o ConnectTimeout=10" \
    --exclude '*.log' \
    --exclude '*.notes' \
    $SERVER_ALIAS:$REMOTE_DIR/ "$HDD_DEST_DIR/"

if [ $? -ne 0 ]; then
    alert "ERROR" "Échec du téléchargement rsync vers HDD."
    exit 1
fi

echo -e "\n--- 2. Rotation HDD (Garder les 2 récents) ---"
cd "$HDD_DEST_DIR" || exit 1

ARCHIVES=$(ls -1t *.zst *.vma *.tar.gz 2>/dev/null)
COUNT=0
KEEP=2

echo "$ARCHIVES" | while read -r ARCHIVE_FILE; do
    [ -z "$ARCHIVE_FILE" ] && continue
    COUNT=$((COUNT+1))

    if [ "$COUNT" -gt "$KEEP" ]; then
        echo "🗑️ Suppression vieux backup : $ARCHIVE_FILE"
        rm -f "$ARCHIVE_FILE"
    fi
done

# ---------------------------------------------------------
# PHASE 2 : CLOUD (DERNIÈRE ARCHIVE UNIQUEMENT)
# ---------------------------------------------------------
if mount_gdrive_if_needed; then
    echo -e "\n--- 3. Sync Google Drive ---"
    
    LATEST_ARCHIVE=$(ls -t *.zst *.vma *.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "$LATEST_ARCHIVE" ]; then
        alert "WARN" "Aucune archive trouvée pour le Cloud."
    else
        ARCHIVE_NAME=$(basename "$LATEST_ARCHIVE")

        # Vérification existence sur le Drive
        if [ -f "$GDRIVE_DEST_DIR/$ARCHIVE_NAME" ]; then
            echo "✅ Fichier déjà sur le Drive : $ARCHIVE_NAME"
            alert "SUCCESS" "Backup terminé (Déjà à jour) !"
        else
            echo "📤 Upload vers le Cloud en cours..."
            
            # --- MODIFICATION IMPORTANTE ICI ---
            # Ajout de --no-times pour éviter l'erreur "Operation not supported"
            # Ajout de --size-only pour être cohérent
            rsync -ah --progress --size-only --no-perms --no-owner --no-group --no-times --inplace "$LATEST_ARCHIVE" "$GDRIVE_DEST_DIR/"
            
            if [ $? -eq 0 ]; then
                echo "🧹 Nettoyage Cloud..."
                find "$GDRIVE_DEST_DIR" -type f ! -name "$ARCHIVE_NAME" -delete
                
                SIZE=$(du -sh "$LATEST_ARCHIVE" | cut -f1)
                alert "SUCCESS" "Backup terminé !%0AHDD : OK%0ACloud : Uploadé ($SIZE)"
            else
                alert "ERROR" "Erreur upload Google Drive."
            fi
        fi
    fi
fi

echo -e "\n🏁 Terminé."



```
## 5\. 🚨 Plan de Reprise d’Activité \(PRA\)
Sauvegarder ne sert à rien si l’on ne sait pas restaurer\.
Voici les scénarios possibles\.
### 🟦 Scénario A — *Erreur logicielle*
**“J’ai cassé la config Docker”**  
Gravité : **Faible**
* Ne touchez pas aux backups
* Corrigez le code sur votre PC
* Push GitLab
* Le pipeline CI/CD reconstruit le conteneur proprement
### 🟧 Scénario B — *Erreur système*
**“La maintenance a planté le conteneur”**  
Gravité : **Moyenne**
1. Accédez à Proxmox : `https://homelab:8006`
2. Stockage local → Backups
3. Sélectionnez le fichier de **03:00**
4. Cliquez sur **Restore**
⏱️ *Rétablissement : ~5 minutes*
### 🟥 Scénario C — *Catastrophe totale*
**“Le SSD du serveur est mort”**  
Gravité : **Critique**
1. Remplacez le SSD
2. Réinstallez Proxmox \(ISO USB\)
3. Reconfigurez le réseau \(scripts Partie 1 & 4\)
4. Branchez le HDD sur votre PC
5. Envoyez le backup vers le nouveau serveur :
bash

```warp-runnable-command
scp -P 2222 /media/ivann/MonHDD/Backups/vzdump-....tar.zst ivann@homelab:/var/lib/vz/dump/
```
6. Dans Proxmox → **Restore**
⏱️ *Rétablissement complet : ~1 heure*
## 6\. 📅 Planning des Opérations
Quand ?Qui ?Quoi ?
Samedi 03:00Proxmox \(Auto\)Snapshot local du conteneur docker‑hostSamedi 04:00Script \(Auto\)Maintenance système \+ nettoyage Docker \+ rebootSamedi matinVous \(Manuel\)Lancement du script `backup_home_pro.sh` \(avec café\)Temps réelWatchdog \(Auto\)Surveillance réseau \+ réparation automatique