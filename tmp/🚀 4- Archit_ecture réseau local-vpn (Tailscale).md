

Avant de connecter le VPN, il nous faut un annuaire capable de dire "sentinel\.homelab, c'est ici"\. On installe AdGuard Home\.

**1\. Préparation des dossiers \(Sur le serveur\)**
Connecte\-toi en SSH à ton conteneur `docker-host` :
`ssh docker-host`

Crée un dossier propre pour ranger la configuration :
`mkdir -p /root/dns/work`
`mkdir -p /root/dns/conf`
`cd /root/dns`

**2\. Le Fichier `docker-compose.yml`**
Crée le fichier : `nano docker-compose.yml`

*Pourquoi cette config ?*
*   On expose le port **53** \(UDP/TCP\) pour que les appareils puissent poser des questions DNS\.
*   On définit les variables de **Proxy** \(`http_proxy`\) pour qu'AdGuard puisse télécharger ses listes de blocage de pubs\.
*   On définit **NO\_PROXY** pour qu'il puisse parler aux machines locales sans passer par le proxy de l'X\.

Colle ceci :

```yaml
services:
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    
    # --- RÉSEAU ---
    # On connecte au réseau proxy pour que Traefik puisse router l'interface admin
    networks:
      - proxy
    
    # --- PORTS ---
    # Le DNS doit être exposé en direct (TCP/UDP)
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      # Port d'installation/Admin initial (sera routé par Traefik ensuite)
      - "3000:3000/tcp"

    environment:
      - http_proxy=http://129.104.201.11:8080
      - https_proxy=http://129.104.201.11:8080
      - no_proxy=localhost,127.0.0.1,10.10.10.0/24
    
    # --- PERSISTANCE ---
    # Vital pour ne pas perdre tes règles DNS au reboot
    volumes:
      - ./work:/opt/adguardhome/work
      - ./conf:/opt/adguardhome/conf
    
    # --- INTÉGRATION TRAEFIK (ACCÈS ADMIN) ---
    labels:
      - "traefik.enable=true"
      
      # 1. Définition de l'URL d'administration
      - "traefik.http.routers.adguard.rule=Host(`dns.homelab`)"
      
      # 2. Sécurité HTTPS stricte
      - "traefik.http.routers.adguard.entrypoints=websecure"
      - "traefik.http.routers.adguard.tls=true"
      
      # 3. Double Authentification (Celle de Traefik + Celle d'AdGuard)
      # Ajoute une couche de sécurité vitale pour une infra DNS
      - "traefik.http.routers.adguard.middlewares=auth"
      
      # 4. CIBLAGE DU SERVICE
      # IMPORTANT : On dit à Traefik de taper sur le port 3000 du conteneur (pas le 80)
      # Car le port 80 d'AdGuard est souvent réservé pour les pages de blocage
      - "traefik.http.services.adguard.loadbalancer.server.port=3000"

networks:
  proxy:
    external: true

```
Lance le conteneur :
`docker compose up -d`

**3\. Configuration Initiale \(Via Tunnel SSH\)**
Pour configurer AdGuard la première fois, on ne peut pas utiliser de nom de domaine\. On doit y accéder via un tunnel\.

*Sur ton PC :*
`ssh -L 3000:10.10.10.10:3000 homelab`

*Dans ton navigateur :*
Ouvre `http://localhost:3000`\.

*   Clique sur "C'est parti"\.
*   **Interface Admin :** Choisis le port **3000** \(Important, sinon conflit avec Traefik\)\.
*   **Serveur DNS :** Laisse le port **53**\.
*   Crée ton compte utilisateur\.

**4\. Configuration des "Upstream DNS" \(Pour avoir Internet\)**
AdGuard doit savoir à qui demander quand il ne connaît pas la réponse \(ex: google\.com\)\. À l'X, on ne peut pas sortir sur le port 53 vers Google \(8\.8\.8\.8\)\. On doit utiliser les DNS de l'école\.

*   Dans AdGuard > **Paramètres** > **Paramètres DNS**\.
*   Section **Serveurs DNS amont** : Supprime tout et mets les IP de l'X \(trouvées dans `/etc/resolv.conf` sur le serveur\) :
    `129.104.30.41`
    `129.104.32.41`
*   Clique sur "Tester"\. Si c'est OK, clique sur "Appliquer"\.

**5\. La Règle Magique : DNS Rewrite**
C'est ici qu'on crée le domaine `.homelab`\.
*   Dans AdGuard > **Filtres** > **Réécritures DNS**\.
*   Clique sur **Ajouter**\.
*   Domaine : `*.homelab`
*   IP : **L'IP Tailscale de ton serveur** \(ex: `100.x.y.z`\)\.
    *   *Pourquoi l'IP Tailscale ?* Parce que c'est la seule IP qui sera accessible de partout \(Wifi, 4G, PC, Tel\) une fois le VPN monté\.
    *   *Note :* Tu peux trouver cette IP en tapant `tailscale ip -4` dans le conteneur Tailscale plus tard, ou dans la console admin\. Pour l'instant, mets une fausse IP et reviens la corriger après avoir installé Tailscale\.

Une fois cela fait par mesuré de sécurté, il faut comment le port 3000:3000 dansle docker\-compose et rebuild ; l'idée est de ne pas bypasser Traefik, qui est supposer être le proxy et donc de rester en protocole TLS

***

### PHASE 2 : LE TUYAU VPN \(TAILSCALE CONTAINER\)

Maintenant, on installe le VPN qui va relier ton téléphone à ton AdGuard et tes sites\.

**1\. Préparation**
Dans ton Portainer, on crée une nouvelle stack de nom vpn et on va définir le docker\-compose comme expliqué plus bas

**2\. Le `docker-compose.yml`**

*Points Clés :*
*   **`TS_USERSPACE=true`** : Mode compatible Docker/LXC \(évite les erreurs kernel\)\.
*   **`TS_ACCEPT_DNS=false`** : Empêche le conteneur de s'utiliser lui\-même comme DNS \(évite la boucle infinie\)\.
*   **`TS_ROUTES=10.10.10.0/24`** : Active le "Subnet Router"\. Cela permet aux appareils du VPN d'accéder à tout ton réseau Docker \(10\.10\.10\.x\) directement\.

```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    restart: unless-stopped
    # Network Host n'est PAS recommandé pour Funnel si on veut router vers d'autres conteneurs proprement.
    # MAIS pour un Homelab simple, on peut le laisser en mode host pour la facilité de gestion réseau,
    # OU mieux : on le met dans le réseau "proxy" pour qu'il parle à Traefik par son nom DNS interne.
    
    # --- STRATÉGIE PRO : MODE BRIDGE DANS LE RÉSEAU PROXY ---
    # On enlève network_mode: host et on le met dans le réseau proxy
    # network_mode: "host"  <-- ENLEVER ÇA
    networks:
      - proxy
      
    # 2. PRIVILEGED : Vital. Pour créer l'interface /dev/net/tun
    environment:
      - TS_AUTHKEY=tskey-auth-kWZ2RXmEqZ11CNTRL-CucPZ5zi1u2pGeXPFbMGu2qpeYSxQ1eK
      - TS_HOSTNAME=kpihx-labs # Le nom qu'il aura sur le réseau
      
      # Stockage état
      - TS_STATE_DIR=/var/lib/tailscale
      
      # On reste en mode userspace et non pas server car le mode serveur peut être instable lorsque tailscale est enfermé dans son conteneur et n'a pas accès au réseau host
      - TS_USERSPACE=true
      # Proxy de l'X (toujours lui !)
      # - http_proxy=http://129.104.201.11:8080
      # - https_proxy=http://129.104.201.11:8080

      # Empêche le conteneur d'utiliser le DNS MagicDNS (AdGuard) pour lui-même
      # Cela évite la boucle infinie sur 127.0.0.1:53
      - TS_ACCEPT_DNS=false

      # On annonce le réseau interne du LXC au VPN
      - TS_ROUTES=10.10.10.0/24
    volumes:
      # 3. PERSISTANCE : On garde l'identité pour ne pas changer d'IP Tailscale
      - ./tailscale-data:/var/lib/tailscale
      # Accès au périphérique Tun du noyau Linux
      # - /dev/net/tun:/dev/net/tun
    # On force le DNS de Google pour que ce conteneur puisse toujours sortir
    # dns:
      # - 8.8.8.8
      # - 1.1.1.1
    # Capabilities pour le tunnel VPN (cas du mode server)
    # cap_add:
      # - NET_ADMIN # Capcité à configurer le réseau (se créer une interface ...)
      # - NET_RAW # Capacité à envoyer des paquets bruts (ping ...)
    # Donne tous les privilèges mais peut être une faille de sécurité
    # privileged: true 

networks:
  proxy:
    external: true
```
Ensuite il  faut juste valider la création avec portainer
**3\. Vérification des Logs**
`docker logs -f tailscale` \(depuis docker\-host\) ou alors aller dans l'onglet containers de Portainer, choisir tailscale et cliquer sur logs\.
Tu dois voir "Success" et "Log in at\.\.\."\. Si tu as utilisé une clé AuthKey, il se connecte tout seul\.

**4\. Récupérer l'IP Tailscale**
`docker exec tailscale tailscale ip -4`
Prends cette IP \(ex: `100.123.191.40`\) et va la mettre dans la règle **DNS Rewrite d'AdGuard** \(Phase 1, Étape 5\)\. C'est vital\.

***

### PHASE 3 : LA CONNEXION INTERNE \(ROUTAGE\)

Maintenant, on configure la "Plomberie" pour que quand on tape sur l'IP Tailscale, ça arrive sur Traefik\.

**1\. Configuration "Tailscale Serve"**
Le conteneur Tailscale reçoit le trafic, mais il ne sait pas qu'il doit l'envoyer à Traefik\. On va lui dire\.

Connecte\-toi dans le conteneur :
`docker exec -it tailscale sh`

Tape ces commandes :

```warp-runnable-command
# Rediriger le port 80 (HTTP) vers le conteneur Traefik
tailscale serve --bg --tcp 80 tcp://traefik:80

# Rediriger le port 443 (HTTPS) vers le conteneur Traefik
tailscale serve --bg --tcp 443 tcp://traefik:443

```
Vérifie avec : `tailscale serve status`\. Tu dois voir les redirections\.

***

### PHASE 4 : LA CONSOLE D'ADMINISTRATION TAILSCALE \(WEB\)

C'est ici qu'on configure le comportement global de tes appareils\.

Va sur [login\.tailscale\.com/admin/machines](https://login.tailscale.com/admin/machines)\.

**1\. Valider le Subnet Router**
*   Trouve ta machine `kpihx-labs`\.
*   Clique sur les `...` > **Edit route settings**\.
*   Coche la case **`10.10.10.0/24`**\. \(Cela autorise le trafic vers ton réseau Docker\)\.

**2\. Configurer le DNS Global \(Split DNS\)**
*   Va dans l'onglet **DNS**\.
*   Dans "Global Nameservers", clique sur **Add nameserver** > **Custom**\.
*   Entre l'adresse IP interne d'AdGuard : **`10.10.10.10`**\.
    *   *Pourquoi cette IP ?* Grâce au Subnet Router activé juste avant, tes appareils peuvent joindre cette IP locale à travers le VPN\. C'est plus direct\.
*   Coche **"Restrict to domain"**\.
*   Entre le domaine : **`homelab`**\.
*   Sauvegarde\.

**3\. Désactiver l'Override**
Assure\-toi que l'option **"Override local DNS"** est **DÉSACTIVÉE**\.
*   *Résultat :*
    *   Si tu vas sur `google.com` \-> Ça utilise la 4G/Wifi \(Pas de ralentissement\)\.
    *   Si tu vas sur `sentinel.homelab` \-> Ça utilise le DNS `10.10.10.10` via le VPN\.

***

### PHASE 5 : CONFIGURATION DES CLIENTS

**1\. Sur ton Téléphone \(Android/iOS\)**
*   Installe l'app Tailscale\.
*   Connecte\-toi\.
*   Active le VPN\.
*   Ouvre Chrome, tape : `https://sentinel.homelab`\.
*   Ça marche \! \(Avec alerte de sécurité SSL, c'est normal\)\.

**2\. Sur ton PC Linux \(Le cas particulier\)**
Linux est strict\. Même si Tailscale propose des routes, Linux les ignore par défaut\.

*   Installe Tailscale : `curl -fsSL https://tailscale.com/install.sh | sh`
*   Connecte\-toi en acceptant les routes et le DNS :
```warp-runnable-command
sudo tailscale up --accept-routes --accept-dns

```
*   **Vérification :**
```warp-runnable-command
ping sentinel.homelab
```
    Si ça répond, tu peux supprimer tes bidouilles dans `/etc/hosts` \!

***

### RÉSUMÉ DE LA MÉCANIQUE

1.  **Toi :** `https://sentinel.homelab`
2.  **Ton PC/Tel :** "C'est un domaine `.homelab`, je demande au DNS Tailscale"\.
3.  **Tailscale :** "Le DNS pour `.homelab` est à `10.10.10.10`"\.
4.  **Ton PC/Tel :** Envoie la requête DNS à `10.10.10.10` via le tunnel \(Subnet Route\)\.
5.  **AdGuard \(10\.10\.10\.10\) :** "Ah, `sentinel.homelab` ? C'est l'IP `100.x.y.z`"\.
6.  **Ton PC/Tel :** Envoie la requête HTTPS à `100.x.y.z`\.
7.  **Conteneur Tailscale \(`100.x.y.z`\) :** Reçoit sur le port 443\. Règle `serve` \-> Envoie à `traefik:443`\.
8.  **Traefik :** Reçoit, voit le Host `sentinel.homelab`, et sert le site\.

C'est propre, logique, et ça marche partout\.