
**Contexte :** Le serveur dispose désormais d'un accès Internet \(via USB/NAT\)\. L'étape suivante consiste à héberger des services et à les rendre accessibles\.

**Objectifs :**
1.  **Configurer le NAT \(Port Forwarding\)** pour l'accessibilité des services\.
2.  **Monter le Conteneur "Usine"** \(LXC Docker Host\)\.
3.  **Configurer l'accès SSH avancé** \(Tunnels & ProxyJump\)\.
4.  **Déployer la Gateway Traefik** \(HTTPS Forcé & Sécurisation\)\.
5.  **Déployer un service test\.**

***

## PHASE 1 : OUVERTURE DES PORTES \(DNAT SUR PROXMOX\)

### Pourquoi ?
Le serveur Proxmox \(`129.104...`\) agit comme un routeur\. Par défaut, il ignore le trafic entrant\. Il faut lui indiquer explicitement : *"Si quelqu'un frappe au port 80, 443 ou 9443, envoie\-le au conteneur Docker \(10\.10\.10\.10\)"*\.

### Configuration
Éditez le fichier `/etc/network/interfaces` sur l'hôte Proxmox\. Ajoutez ces règles dans la section de votre pont privé `vmbr1` \(après les règles de Masquerading existantes\) :

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
```warp-runnable-command
ifreload -a

```
***

## PHASE 2 : CRÉATION DE L'USINE \(DOCKER HOST\)

### Pourquoi ?
Par mesure de sécurité et de propreté, on n'installe rien directement sur l'hyperviseur Proxmox\. Tout est isolé dans un conteneur LXC dédié\.

### 1\. Création du LXC \(Interface Web Proxmox\)
*   **Template :** `debian-12-standard`
*   **Disque :** 20 Go\+ \(pour les images et bases de données\)
*   **Mémoire :** 4 Go\+
*   **Réseau :** Bridge `vmbr1` | IPv4 statique : `10.10.10.10/24` | Gateway : `10.10.10.1`

### 2\. Options CRITIQUES
Dans l'onglet **Options > Features**, cochez impérativement :
*   `[x] Nesting` : Permet à Docker de fonctionner à l'intérieur du conteneur\.
*   `[x] Keyctl` : Nécessaire pour le fonctionnement de certaines images Docker modernes\.

### 3\. Installation de Docker \(Dans le conteneur\)
**ATTENTION :** La configuration du Proxy est **OBLIGATOIRE** pour `apt` et `docker pull`\.

**a\. Proxy pour le Shell \(Immédiat\)**
```warp-runnable-command
export http_proxy=http://129.104.201.11:8080
export https_proxy=http://129.104.201.11:8080

```
**b\. Script d'installation**
```warp-runnable-command
apt update && apt install curl git -y
curl -fsSL https://get.docker.com | sh

```
**c\. Proxy pour le Démon Docker \(Vital pour le téléchargement d'images\)**
```warp-runnable-command
mkdir -p /etc/systemd/system/docker.service.d
echo '[Service]
Environment="HTTP_PROXY=http://129.104.201.11:8080"
Environment="HTTPS_PROXY=http://129.104.201.11:8080"
Environment="NO_PROXY=localhost,127.0.0.1,10.10.10.10"' > /etc/systemd/system/docker.service.d/http-proxy.conf

systemctl daemon-reload
systemctl restart docker

```
### 4\. Installation de Portainer
```warp-runnable-command
docker run -d -p 9443:9443 --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

```
***

## PHASE 3 : RÉSOLUTION MDNS \(AVAHI\) & TUNNELS SSH

### A\. Configuration de mDNS avec Avahi
Pour éviter de traquer l'IP du serveur \(souvent dynamique\), on utilise **Avahi**\. Il permet d'accéder au serveur via `homelab.local`\.

**1\. Installation sur Proxmox :**
```warp-runnable-command
apt update && apt install avahi-daemon avahi-utils -y
```
**2\. Personnalisation du nom :**
```warp-runnable-command
nano /etc/avahi/avahi-daemon.conf
```
Dans la section `[server]`, modifiez la ligne :
```ini
[server]
host-name=homelab
```
**3\. Application & Test :**
```warp-runnable-command
systemctl restart avahi-daemon
# Depuis votre PC portable :
ping -4 homelab.local
```
### B\. Comprendre les Tunnels SSH \(`LocalForward`\)
Un tunnel de type `LocalForward xxxx aaaaaaa:yyyy` signifie :
* On ouvre une entrée sur le port **xxxx** de votre PC \(Client\)\.
* Tout ce qui entre ici ressort à l'adresse **aaaaaaa** sur le port **yyyy** du côté du serveur\.
* Cela permet d'accéder à des interfaces privées \(comme le port 8006 de Proxmox\) comme si elles étaient locales\.

### C\. Fichier de configuration SSH \(`~/.ssh/config`\)
Modifiez ce fichier sur votre **PC portable** :

```text
# --- 1. ACCÈS ADMINISTRATION ---
Host homelab
    HostName homelab.local
    User root
    Port 2222
    ServerAliveInterval 60

# --- 2. ACCÈS INTERFACES WEB (Avec Tunnels) ---
# Usage : ssh -N homelab-ui
Host homelab-ui
    HostName homelab.local
    User root
    Port 2222
    # Tunnel Proxmox (Local 8006 -> distant 8006)
    LocalForward 8006 localhost:8006
    # Tunnel Portainer (Local 9443 -> LXC 9443)
    LocalForward 9443 10.10.10.10:9443
    # Tunnel Traefik Dashboard
    LocalForward 8080 10.10.10.10:8080
    # Tunnel HTTPS Global (Local 8443 -> LXC 443)
    LocalForward 8443 10.10.10.10:443
    ServerAliveInterval 60

# --- 3. REBOND DANS LE CONTENEUR ---
Host docker-host
    HostName 10.10.10.10
    User root
    ProxyJump homelab
```
***
## PHASE 4 : LE ROUTEUR INTELLIGENT \(TRAEFIK\)

### Pourquoi ?
Traefik reçoit tout le trafic Web \(port 80/443\), gère le HTTPS automatiquement \(certificats\) et redirige vers le bon conteneur selon le nom de domaine \(ex: `whoami.homelab`\)\.

Pour sécuriser l'accès à Traefik il faudra définir un user et password d'accès\.
Ainsi, il faudra générer un hash de son mot de passe pour le middleware \(authentification sécurisée à Traefik\) avec la commande
```warp-runnable-command
htpasswd -nb user "password"
# -: no to store in a file, but to display directly
# b: to pass the password as an arg

# résultat: user:xxxxxxx

```
Avant d'insérer le résultat dans l'endroit indiquer dans la config plus bas, il faudra remplacer tous les `$` par `$$`, car sinon ils seraient interprétés par docker\.

La config qui suit devra être définies et déployer via Portainer > Stacks > **"traefik"** :

```yaml
version: '3'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    
    networks:
      - proxy # Réseau pour parler aux autres conteneurs
    
    ports:
      - "80:80"      # HTTP (Sera redirigé)
      - "443:443"    # HTTPS (Principal)
      - "8080:8080"  # Dashboard (Interne)
    
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    
    command:
      - "--api.insecure=true"
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      # Redirection Forcée vers HTTPS
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      # Note: Sans config Let's Encrypt, Traefik génère son propre certificat.
      # Le navigateur affichera "Non sécurisé", c'est normal en local.
    
    labels:
      - "traefik.enable=true"
      
      # --- SÉCURISATION DU DASHBOARD (Basic Auth) ---
      # Générer le hash : htpasswd -nb user password
      # ATTENTION : Doubler les signes $ ($$apr1$$...)
      - "traefik.http.middlewares.auth.basicauth.users=ivann:$$apr1$$ExempleHash..."
      
      - "traefik.http.routers.api.rule=Host(`traefik.homelab`)"
      - "traefik.http.routers.api.service=api@internal"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.tls=true"
      - "traefik.http.routers.api.middlewares=auth"

networks:
  proxy:
    external: true # docker network create proxy (à faire avant)

```
***

## PHASE 5 : DÉPLOIEMENT D'UN SITE TEST \(WHOAMI\)

**Objectif :** Vérifier que le routage de Traefik fonctionne\.

Déployez via Portainer > Stacks > **"test\-site"** :

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
***

## PHASE 6 : ACCÈS DEPUIS LE PC \(DNS LOCAL\)

Comme nous n'utilisons pas de vrai nom de domaine réservé, nous devons modifier le fichier `hosts` de votre PC pour rediriger les noms vers votre tunnel SSH local\.

*   **Fichier :** `/etc/hosts` \(Linux/Mac\) ou `C:\Windows\System32\drivers\etc\hosts` \(Windows\)

**Ajoutez ces lignes :**
```text
127.0.0.1   traefik.homelab
127.0.0.1   whoami.homelab

```
### Utilisation finale :
1.  **Lancez le tunnel :** `ssh -N homelab-ui`
2.  **Ouvrez votre navigateur :** Accédez à `https://traefik.homelab:8443`
    *\(Note : Le port 8443 correspond au LocalForward défini dans votre config SSH\)\.*