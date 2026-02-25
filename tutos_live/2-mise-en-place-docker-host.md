# 🚀 Tuto Live 2 : Mise sur pied du Docker-Host et Routage Intelligent

**Contexte :** Le serveur dispose désormais d'un accès Internet (via USB/NAT). L'étape suivante consiste à héberger des services et à les rendre accessibles de manière propre et structurée.

**Objectifs :**
1.  **Configurer le DNAT (Port Forwarding)** pour l'accessibilité des services.
2.  **Monter le Conteneur "Usine"** (LXC Docker Host).
3.  **Configurer l'accès SSH avancé** (Tunnels & ProxyJump).
4.  **Déployer la Gateway Traefik** (HTTPS Forcé & Sécurisation).
5.  **Déployer un service test.**

---

## 🚪 PHASE 1 : OUVERTURE DES PORTES (DNAT SUR PROXMOX)

### 🤔 Pourquoi faire cela ?
Le serveur Proxmox (`129.104...`) agit comme un routeur. Par défaut, il ignore le trafic entrant. Il faut lui indiquer explicitement : *"Si quelqu'un frappe au port 80, 443 ou 9443 de mon IP publique, envoie-le au conteneur Docker interne (10.10.10.10)"*.

### ✅ La Solution
Éditez le fichier `/etc/network/interfaces` sur l'hôte Proxmox. Ajoutez ces règles dans la section de votre pont privé `vmbr1` (après les règles de Masquerading existantes) :

```text
# ... (Configuration IP et Masquerading déjà présents) ...

    # --- REGLES DE REDIRECTION (DNAT) ---
    
    # 1. Port 80 (HTTP) -> Vers Conteneur Docker (Pour la redirection Traefik)
    post-up   iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 10.10.10.10:80 
    post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 10.10.10.10:80

    # 2. Port 443 (HTTPS) -> Vers Conteneur Docker (Trafic principal sécurisé)
    post-up   iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 10.10.10.10:443 
    post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 10.10.10.10:443

    # 3. Port 9443 (Portainer) -> Vers Conteneur Docker (Gestion graphique)
    post-up   iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 9443 -j DNAT --to 10.10.10.10:9443 
    post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 9443 -j DNAT --to 10.10.10.10:9443
```

**Action :** Appliquez les modifications sans redémarrer avec la commande :
```bash
ifreload -a
```

---

## 🏗️ PHASE 2 : CRÉATION DE L'USINE (DOCKER HOST)

### 🤔 Pourquoi faire cela ?
Par mesure de sécurité et de propreté, on n'installe rien directement sur l'hyperviseur Proxmox. Tout est isolé dans un conteneur LXC dédié.

### 1. Création du LXC (Interface Web Proxmox)
*   **Template :** `debian-12-standard`
*   **Disque :** 20 Go+ (pour les images et bases de données)
*   **Mémoire :** 4 Go+
*   **Réseau :** Bridge `vmbr1` | IPv4 statique : `10.10.10.10/24` | Gateway : `10.10.10.1`

### 2. Options CRITIQUES
Dans l'onglet **Options > Features**, cochez impérativement :
*   `[x] Nesting` : Permet à Docker de fonctionner à l'intérieur du conteneur.
*   `[x] Keyctl` : Nécessaire pour le fonctionnement de certaines images Docker modernes.

### 3. Installation de Docker (Dans le conteneur)
**⚠️ ATTENTION :** La configuration du Proxy est **OBLIGATOIRE** pour `apt` et `docker pull` à l'X.

**a. Proxy pour le Shell (Immédiat)**
```bash
export http_proxy=http://129.104.201.11:8080
export https_proxy=http://129.104.201.11:8080
```

**b. Script d'installation**
```bash
apt update && apt install curl git -y
curl -fsSL https://get.docker.com | sh
```

**c. Proxy pour le Démon Docker (Vital pour le téléchargement d'images)**
Si vous oubliez cette étape, `docker pull` échouera systématiquement.
```bash
mkdir -p /etc/systemd/system/docker.service.d
echo '[Service]
Environment="HTTP_PROXY=http://129.104.201.11:8080"
Environment="HTTPS_PROXY=http://129.104.201.11:8080"
Environment="NO_PROXY=localhost,127.0.0.1,10.10.10.10"' > /etc/systemd/system/docker.service.d/http-proxy.conf

systemctl daemon-reload
systemctl restart docker
```

### 4. Installation de Portainer
```bash
docker run -d -p 9443:9443 --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

---

## 🛰️ PHASE 3 : RÉSOLUTION MDNS (AVAHI) & TUNNELS SSH

### A. Configuration de mDNS avec Avahi
Pour éviter de traquer l'IP du serveur (souvent dynamique), on utilise **Avahi**. Il permet d'accéder au serveur via `homelab.local`.

**1. Installation sur Proxmox :**
```bash
apt update && apt install avahi-daemon avahi-utils -y
```
**2. Personnalisation du nom :**
Modifiez le fichier `/etc/avahi/avahi-daemon.conf` :
```ini
[server]
host-name=homelab
```
**3. Application & Test :**
```bash
systemctl restart avahi-daemon
# Depuis votre PC portable :
ping -4 homelab.local
```

### B. Comprendre les Tunnels SSH (`LocalForward`)
Un tunnel de type `LocalForward xxxx aaaaaaa:yyyy` signifie :
*   On ouvre une entrée sur le port **xxxx** de votre PC (Client).
*   Tout ce qui entre ici ressort à l'adresse **aaaaaaa** sur le port **yyyy** du côté du serveur.
*   Cela permet d'accéder à des interfaces privées (comme le port 8006 de Proxmox) comme si elles étaient locales.

### C. Fichier de configuration SSH (`~/.ssh/config`)
C'est le "tableau de bord" de votre PC administrateur.

*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ssh_config](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ssh_config)

---

## 🚦 PHASE 4 : LE ROUTEUR INTELLIGENT (TRAEFIK)

### 🤔 Pourquoi faire cela ?
Traefik reçoit tout le trafic Web (port 80/443), gère le HTTPS automatiquement (certificats) et redirige vers le bon conteneur selon le nom de domaine demandé (ex: `whoami.homelab`).

**✅ Sécurisation de l'accès :**
Pour sécuriser l'accès à Traefik, générez un hash de mot de passe :
```bash
htpasswd -nb user "password"
# résultat: user:xxxxxxx
```
*Note : Avant d'insérer le résultat dans le yaml, remplacez tous les `$` par `$$`.*

**✅ Déploiement via Portainer (Stack "traefik") :**
*   **Template :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/traefik.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/traefik.yaml)

---

## 🧪 PHASE 5 : DÉPLOIEMENT D'UN SITE TEST (WHOAMI)

**Objectif :** Vérifier que le routage de Traefik fonctionne.

Déployez via Portainer > Stacks > **"test-site"** :
```yaml
services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.homelab`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls=true"
      - "traefik.http.routers.whoami.middlewares=auth" # Optionnel

networks:
  proxy:
    external: true
```

---

## 🧪 PHASE 6 : ACCÈS DEPUIS LE PC (DNS LOCAL)

Comme nous n'utilisons pas de vrai nom de domaine réservé, nous devons modifier le fichier `hosts` de votre PC pour rediriger les noms vers votre tunnel SSH local.

*   **Fichier :** `/etc/hosts` (Linux/Mac) ou `C:\Windows\System32\drivers\etc\hosts` (Windows)

**Ajoutez ces lignes :**
```text
127.0.0.1   traefik.homelab
127.0.0.1   whoami.homelab
```

### 🚀 Utilisation finale :
1.  **Lancez le tunnel :** `ssh -N homelab-ui`
2.  **Ouvrez votre navigateur :** Accédez à `https://traefik.homelab:8443`
    *(Note : Le port 8443 correspond au LocalForward défini dans votre config SSH).*

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
