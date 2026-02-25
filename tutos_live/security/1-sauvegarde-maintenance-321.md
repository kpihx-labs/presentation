# 🛡️ Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)

**Contexte :** Infrastructure de production.
**Objectif :** Garantir la pérennité des données et la stabilité à long terme (Règle du 3‑2‑1).

---

## 1. 📐 Philosophie : La Règle du 3‑2‑1

En auto‑hébergement (Homelab), la panne matérielle ou l’erreur humaine n’est pas une question de *si*, mais de *quand*. Nous appliquons la stratégie industrielle **3‑2‑1**, adaptée à nos contraintes (HDD instable sur le serveur) :

### 🔢 Rappel de la règle
1. **3 copies de vos données**
    *   Copie A : Production (SSD du serveur)
    *   Copie B : Locale (HDD externe)
    *   Copie C : Distante (Google Drive)
2. **2 supports différents**  
    *   SSD vs disque mécanique (HDD)
3. **1 copie hors‑site**  
    *   Cloud (protection contre le vol ou l'incendie)

---

## 2. 🛠️ Maintenance Préventive (Sur le Serveur)

### 🤔 Pourquoi faire cela ?
Un serveur Linux accumule :
*   mises à jour de sécurité,
*   images Docker obsolètes,
*   caches divers.
Sans nettoyage ➔ disque saturé.
Sans redémarrage ➔ instabilités (fuites mémoire, USB, etc.).

### ✅ La Solution
Un **script hebdomadaire** qui automatise tout.

**A. 📜 Script de Maintenance**
*   **Source réelle :** [scripts/maintenance.sh](https://github.com/kpihx-labs/scripts/blob/main/maintenance.sh)
*   **Emplacement recommandé :** `/root/weekly_maintenance.sh`
*   **Droits :** `chmod +x /root/weekly_maintenance.sh`

Ce script réalise :
1. Mise à jour APT (`update`, `upgrade`, `autoremove`)
2. Nettoyage Docker (`docker system prune -a -f --volumes`)
3. Notifications Telegram pour vous tenir informé.
4. Reboot propre pour rafraîchir le noyau.

**B. ⏱️ Automatisation (Cron Root)**
Planification : **Samedi à 04h00**, période de faible activité.
```bash
# sudo crontab -e
0 4 * * 6 /root/weekly_maintenance.sh
```

---

## 🧩 3. Sauvegarde Niveau 1 : Snapshot Local (Proxmox)

### 🤔 Pourquoi faire cela ?
C’est la **première ligne de défense**. Proxmox crée une image compressée (`.tar.zst`) du conteneur **sans interruption de service**.

### ✅ Configuration (Interface Web)
*   **Datacenter ➔ Backup ➔ Add**
*   **Node :** `pve`
*   **Schedule :** `03:00` le samedi (1h avant la maintenance)
*   **Sélection :** Conteneur `100` (docker‑host)
*   **Mode :** Snapshot
*   **Compression :** ZSTD
*   **Rétention :** Keep Last 2

---

## 🛰️ 4. Sauvegarde Niveau 2 & 3 : Exfiltration (PC Client)

### 🤔 Pourquoi sur le PC ?
Brancher le HDD directement sur le serveur provoque des **instabilités réseau (USB)**. Le PC Ubuntu sert donc de **hub de sauvegarde** :
1. Récupère le backup depuis le serveur (pull via `rsync`).
2. Le copie sur le HDD externe.
3. Envoie la dernière version sur Google Drive (via GVFS ou `rclone`).

### A. 🧱 Pré‑requis Matériel
*   **HDD externe :** formaté en Ext4.
*   **Google Drive :** Monté via GVFS (Comptes en ligne) ou configuré via `rclone`.

### B. 📜 Script d’Exfiltration
*   **Source réelle :** [scripts/backup_homelab.sh](https://github.com/kpihx-labs/scripts/blob/main/backup_homelab.sh)
*   **Emplacement :** `~/backup_home_pro.sh`

**Important :** 
*   Créez un dossier `Backup_Homelab` à la racine de votre Drive Google.
*   Lancez ce script via `tmux` pour éviter les interruptions si votre terminal se ferme.

---

## 🚨 5. Plan de Reprise d’Activité (PRA)

Sauvegarder ne sert à rien si l’on ne sait pas restaurer.

### 🟦 Scénario A — *Erreur logicielle*
**“J’ai cassé la config Docker”** (Gravité : **Faible**)
1.  Ne touchez pas aux backups.
2.  Corrigez le code sur votre PC.
3.  `git push` GitLab.
4.  Le pipeline CI/CD reconstruit le conteneur proprement.

### 🟧 Scénario B — *Erreur système*
**“La maintenance a planté le conteneur”** (Gravité : **Moyenne**)
1.  Accédez à Proxmox : `https://homelab:8006`
2.  **Stockage local ➔ Backups**
3.  Sélectionnez le fichier de **03:00**.
4.  Cliquez sur **Restore**.
⏱️ *Rétablissement : ~5 minutes*

### 🟥 Scénario C — *Catastrophe totale*
**“Le SSD du serveur est mort”** (Gravité : **Critique**)
1.  Remplacez le SSD.
2.  Réinstallez Proxmox (ISO USB).
3.  Reconfigurez le réseau (voir [Tuto 1](https://kpihx-labs.github.io/presentation/#/tutos_live/1-deploiement-proxmox-8021x.md)).
4.  Branchez le HDD sur votre PC.
5.  Envoyez le backup vers le nouveau serveur :
    ```bash
    scp -P 2222 /media/ivann/MonHDD/Backups/vzdump-....tar.zst ivann@homelab:/var/lib/vz/dump/
    ```
6.  Dans Proxmox ➔ **Restore**.
⏱️ *Rétablissement complet : ~1 heure*

---

## 📅 6. Planning des Opérations

| Quand ? | Qui ? | Quoi ? |
| :--- | :--- | :--- |
| **Samedi 03:00** | Proxmox (Auto) | Snapshot local du conteneur docker‑host |
| **Samedi 04:00** | Script (Auto) | Maintenance système + nettoyage Docker + reboot |
| **Samedi matin** | Vous (Manuel) | Lancement du script `backup_home_pro.sh` (avec café) |
| **Temps réel** | Watchdog (Auto) | Surveillance réseau + réparation automatique |

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
