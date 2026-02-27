# 🏗️ État de l'Art : L'Architecture Résiliente

## 🛡️ Le Défi de l'Environnement Hostile (Le Réseau de l'X)
Le serveur (un vieux PC avec l'écran presque mort) tourne sur Proxmox, mais il vit sur **eduroam**, un réseau universitaire (l'X) imprévisible. L’IP change sans prévenir, les restrictions réseau sont nombreuses (proxy obligatoire, auth 802.1X, ports entrants bloqués), et la moindre variation du DHCP pouvait casser l’accès. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](https://kpihx-labs.github.io/presentation/#/tutos_live/1-deploiement-proxmox-8021x.md))

**La Réponse Technique (Confirmée en Prod) :**
- **Hardware de Survie :** Adaptateur USB-C Ethernet (MAC whitelistée) et SSD de 1 To pour les performances E/S.
- **Topologie Réelle :** IP Publique Ecole `129.104.234.138` avec un masque large en `/22` (segment réseau institutionnel vaste).
- **Sécurisation Initiale :** 
    - Sécurisation de l'accès SSH : port `2222` pour réduire le bruit des bots.
    - Authentification par clé SSH uniquement. (Voir [Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH)](https://kpihx-labs.github.io/presentation/#/tutos_live/security/3-bouclier-inactivite-ssh.md))
    - Désactivation du login `root` direct.
    - Création de l’utilisateur `ivann` avec droits `sudo`.
    - Ajout des clés publiques de tous les appareils dans les `authorized_keys`.
- **Le "Hack" de la Confiance :** Ajustement du `SECLEVEL=0` d'OpenSSL dans Debian 12 pour forcer la compatibilité avec les chiffrements anciens du Radius de l'X (EAP-TTLS / PAP).
- **Le Routeur Fantôme :** Proxmox ne se contente pas d'héberger, il route via `vmbr1` (NAT) avec Masquerading via `iptables` pour donner l'accès au LXC `10.10.10.10` sans exposer sa MAC.

## 🧱 Ingénierie de la Connexion (@.ssh/config)
Pour simplifier l’accès à travers cette jungle réseau, un `.ssh/config` propre a été construit (vérifié via `kpihx-labs-ui`) :
- **Host `homelab` :** Atteint Proxmox directement (`homelab.local`, User `ivann`, Port `2222`).
- **Host `docker-host` :** Passe automatiquement par Proxmox via `ProxyJump` pour atteindre le conteneur interne (`10.10.10.10`) avec `ForwardAgent yes`. (Voir [Tuto 2 : Mise sur pied du Docker-Host et Routage Intelligent](https://kpihx-labs.github.io/presentation/#/tutos_live/2-mise-en-place-docker-host.md))
- **Sur PC :** Utilisation d'**Avahi** (mDNS) pour résoudre `homelab.local` malgré les changements d’IP.
- **Sur Android (Le Hack) :** Impossible d’utiliser mDNS sans être root. Un script **Termux** a donc été écrit. (Voir [Annexe 2 : Termux SSH Homelab Toolkit](https://kpihx-labs.github.io/presentation/#/tutos_live/annexes/2-termux-ssh-toolkit.md))

## 🔧 Stabiliser l’instable : Le Network Watchdog
La connectivité réseau sautait au moindre mouvement du câble. Parfois seul le LXC tombait, parfois tout Proxmox. Toutes les manipulations manuelles ont été automatisées. (Voir [Annexe 1 : Network Watchdog (Auto-Réparation & Monitoring)](https://kpihx-labs.github.io/presentation/#/tutos_live/annexes/1-network-watchdog-v3.md))

C’est ainsi qu’est né le **network watchdog**.
- Il teste régulièrement la connectivité (ping vers 8.8.8.8).
- Il applique des réparations graduelles selon la gravité de la panne (Cycle interfaces -> DHCP -> WPA Reset -> Networking Restart).
- Il logue tout dans `/var/log/network_watchdog.log`.
- Il envoie un message Telegram dès qu’il intervient.
Depuis la version 3, il n'y a plus jamais eu besoin de réparer la connectivité manuellement. Le système s'auto-guérit.

## 💾 Hygiène du système : Sauvegardes, Maintenance, Docker
Une fois la stabilité réseau assurée, une stratégie sérieuse a été mise en place :

1.  **La règle 3‑2‑1 (Sauvegardes) :** (Voir [Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)](https://kpihx-labs.github.io/presentation/#/tutos_live/security/1-sauvegarde-maintenance-321.md))
    - Une copie locale sur Proxmox.
    - Une copie sur un SSD externe (via exfiltration automatisée sur PC Ubuntu).
    - Une copie miroir sur Google Drive via GVFS (ou `rclone`).
    - Exécution automatique tous les jours à **3h du matin**.
2.  **Maintenance du Samedi (4h du matin) :**
    - Script de maintenance hebdomadaire (`weekly_maintenance.sh`) lancé juste après les sauvegardes.
    - Nettoie intelligemment le système, évite les reboot naïfs (qui sur Linux peuvent empirer les choses), et garde le serveur fluide (`apt dist-upgrade`, `docker system prune -a`).
3.  **Purge Docker (5h du matin) :**
    - Conteneur dédié (ou script) pour le nettoyage des images, volumes orphelins et caches, exécuté vers 5h.
4.  **Mises à jour Auto (Watchtower) :** (Voir [Sécurité 2 : Mises à jour Automatiques avec Watchtower](https://kpihx-labs.github.io/presentation/#/tutos_live/security/2-automatisation-watchtower.md))
    - Conteneur configuré (API v1.44) pour scanner le Hub et mettre à jour les applications à **5h du matin**.

## 📊 Sentinel : Donner des yeux au serveur
Pour surveiller l’état du serveur, **Sentinel** a été développé. C'est une sorte de task manager graphique maison (Streamlit sur le port 8501).
- Il suit l’usage CPU, RAM, disque et la charge système.
- Il envoie des alertes Telegram en cas de surcharge.
- Sentinel est devenu le tableau de bord principal, intégré dans le réseau via Traefik.

## 🛠️ Industrialisation : GitLab CI/CD + GitHub
Avant même de s'attaquer à Tailscale ou Cloudflare, il fallait industrialiser les déploiements. Coder directement sur le serveur via VSCode SSH surchargeait inutilement la machine. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](https://kpihx-labs.github.io/presentation/#/tutos_live/3-industrialisation-devops.md))

- **Organisation :** Création d'une organisation GitHub publique et d'un groupe GitLab privé.
- **Sécurité :** Configuration de clés SSH distinctes et génération d'un token GitLab.
- **Runner Local :** Installation d'un **GitLab Runner** directement sur le `docker-host`.
- **Structure des Projets :** Définition de variables secrètes globales, structuration avec des templates Docker, `docker-compose.yml`, `.gitignore`, `.dockerignore`, et parfois un `Makefile`.
- **Pipelines (Jobs) :** Chaque pipeline GitLab comporte au moins deux jobs :
    1.  Un pour déployer sur le homelab (injection du `.env`, `docker compose up -d --build`).
    2.  Un autre pour synchroniser automatiquement le dépôt privé vers GitHub pour le portfolio.

## 🌐 L'Abstraction DNS et le Réseau Overlay (Tailscale + AdGuard)
La véritable élégance de l'infrastructure réside dans une **abstraction totale du réseau**. (Voir [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](https://kpihx-labs.github.io/presentation/#/tutos_live/4-reseau-overlay-tailscale.md))

**Le Mécanisme du Split DNS (Version Subnet Routing) :**
- **Tailscale (VPN Mesh) :** Installé directement sur l'hôte PVE agissant comme **Subnet Router**. Dans la console Tailscale, un **Split DNS** est configuré pour rediriger le domaine `kpihx-labs.com` vers notre DNS interne (`10.10.10.10`).
- **AdGuard Home (L'Annuaire Local) :** Pour les requêtes `.kpihx-labs.com` qui reviennent au serveur, c'est le conteneur AdGuard qui prend le relais. (Voir [adguard.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.2.yaml)).
- **L'Avantage Ultime :** Le serveur est accessible via un FQDN public (`vault.kpihx-labs.com`) qui résout sur une IP privée locale grâce au tunnel DNS souverain.

## 🔐 Certification "Stealth Trusted" (DNS-01 Challenge)
C'est le sommet de la sécurité du lab. Pour obtenir des certificats SSL officiels sans exposer les services sur internet, nous utilisons le **DNS-01 Challenge**. (Voir [Tuto 6 : Souveraineté des Secrets et Certification DNS-01 (Vaultwarden)](https://kpihx-labs.github.io/presentation/#/tutos_live/6-souverainete-secrets-certification-dns01.md))

**Le Flux de Certification :**
1.  **Traefik** communique avec l'**API Cloudflare** pour prouver la propriété du domaine via un record TXT temporaire. (Voir [traefik.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/traefik.2.yaml)).
2.  **Let's Encrypt** délivre un certificat Wildcard officiel (`*.kpihx-labs.com`).
3.  **Résultat :** Les services comme **Vaultwarden** ou **PolyTask** bénéficient d'un cadenas vert reconnu par les applications mobiles, tout en restant **100% invisibles** du web public. (Voir [vaultwarden.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/vaultwarden.2.yaml) et [polytask.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/polytask.2.yaml)).

## ☁️ Exposition publique : Cloudflare Tunnel et Kpihx-labs.com
Pour exposer certains services au public, Tailscale Funnel a d'abord été envisagé, mais jugé trop lourd (un port par service, modifs du docker-compose, URLs non intuitives). (Voir [Tuto 5 : Exposition Publique et Zero Trust (Cloudflare)](https://kpihx-labs.github.io/presentation/#/tutos_live/5-exposition-publique-cloudflare.md))

**Le Déploiement Cloudflare :**
- Achat du domaine **`kpihx-labs.com`**.
- Déploiement d'un conteneur **Cloudflare Tunnel** dans le `docker-host` (forçage du protocole `http2` pour traverser le proxy de l'X).
- Configuration de **Cloudflare Zero Trust** pour gérer les DNS publics et l'accès.
- **Rôle des Certificats :** Cloudflare gère les certificats publics, Traefik gère les certificats internes (ou via DNS Challenge), et tout passe proprement par le tunnel.

**Validation Finale (OAuth) :**
- Test de l'accès *on-host* (authentification par email).
- Mise en place de l'**OAuth Google** pour un service de test : `whoami.kpihx-labs.com`.
- **Le Flux :** Google renvoie un token contenant l’email ➔ Cloudflare vérifie l’autorisation ➔ Traefik route vers le conteneur `whoami`.
- Le même service existe en local (`whoami.homelab`) pour tester la cohérence interne/externe.
- Ce test a validé toute la chaîne : local, proxy de l'X, DNS interne, DNS public, tunnel, certificats, authentification.

## 🎯 Inventaire des Services (Février 2026)
L'infrastructure héberge actuellement **14 services actifs**, répartis en deux piliers d'exposition :

### 🌍 Pilier Public (Exposés via Cloudflare Tunnel)
Accessibles via `https://service.kpihx-labs.com` avec protection **Google OAuth** :
- **sentinel** : Monitoring CPU/RAM/Disque en temps réel.
- **kpihx-portal** : Page d'accueil centralisée du lab.

### 🔐 Pilier Privé (Accessibles via Tailscale uniquement)
Accessibles via `https://service.kpihx-labs.com` (Souverain) ou `.homelab` (Local) :
- **vaultwarden** : Coffre-fort de mots de passe (Certifié SSL Let's Encrypt Production).
- **polytask** : Gestionnaire de tâches IA.
- **whoami** : Service de test de headers et routage.
- **adguard** : Serveur DNS récursif et filtrage (Cœur de l'abstraction).
- **portainer** : Orchestration et gestion des stacks Docker.
- **traefik** : Routeur Edge et automate ACME (DNS-01).
- **imhotep-brain** : Instance **Ollama** locale pour l'IA générative souveraine.
- **wa-bot** : Bot d'intégration WhatsApp pour les notifications système.
- **postgres** & **adminer** : Base de données relationnelle et interface de gestion.
- **watchtower** : Automatisation des mises à jour d'images Docker.

## 🎯 Architecture Actuelle
L'infrastructure est aujourd'hui :
- **auto‑réparatrice** (Watchdog)
- **sécurisée** (Zero Trust, SSH Keys, OAuth)
- **automatisée** (Cron, Watchtower, CI/CD)
- **observable** (Sentinel, Logs)
- **accessible en privé** via Tailscale
- **exposée proprement en public** via Cloudflare
- et entièrement déployée via usine logicielle.

Une architecture cohérente, modulaire, élégante, et surtout vivante.