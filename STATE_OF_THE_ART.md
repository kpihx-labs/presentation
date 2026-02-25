# 🏗️ État de l'Art : L'Architecture Résiliente

## 🛡️ Le Défi de l'Environnement Hostile (Le Réseau de l'X)
Le serveur (un vieux PC avec l'écran presque mort) tourne sur Proxmox, mais il vit sur **eduroam**, un réseau universitaire (l'X) imprévisible. L’IP change sans prévenir, les restrictions réseau sont nombreuses (proxy obligatoire, auth 802.1X, ports entrants bloqués), et la moindre variation du DHCP pouvait casser l’accès. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](tutos_live/1-deploiement-proxmox-8021x.md))

**La Réponse Technique (Confirmée en Prod) :**
- **Hardware de Survie :** Adaptateur USB-C Ethernet (MAC whitelistée) et SSD de 1 To pour les performances E/S.
- **Topologie Réelle :** IP Publique Ecole `129.104.234.138` avec un masque large en `/22` (segment réseau institutionnel vaste).
- **Sécurisation Initiale :** 
    - Sécurisation de l'accès SSH : port `2222` pour réduire le bruit des bots.
    - Authentification par clé SSH uniquement. (Voir [Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH)](tutos_live/security/3-bouclier-inactivite-ssh.md))
    - Désactivation du login `root` direct.
    - Création de l’utilisateur `ivann` avec droits `sudo`.
    - Ajout des clés publiques de tous les appareils dans les `authorized_keys`.
- **Le "Hack" de la Confiance :** Ajustement du `SECLEVEL=0` d'OpenSSL dans Debian 12 pour forcer la compatibilité avec les chiffrements anciens du Radius de l'X (EAP-TTLS / PAP).
- **Le Routeur Fantôme :** Proxmox ne se contente pas d'héberger, il route via `vmbr1` (NAT) avec Masquerading via `iptables` pour donner l'accès au LXC `10.10.10.10` sans exposer sa MAC.

## 🧱 Ingénierie de la Connexion (@.ssh/config)
Pour simplifier l’accès à travers cette jungle réseau, un `.ssh/config` propre a été construit (vérifié via `kpihx-labs-ui`) :
- **Host `homelab` :** Atteint Proxmox directement (`homelab.local`, User `ivann`, Port `2222`).
- **Host `docker-host` :** Passe automatiquement par Proxmox via `ProxyJump` pour atteindre le conteneur LXC (IP `10.10.10.10`) avec `ForwardAgent yes`. (Voir [Tuto 2 : Mise sur pied du Docker-Host et Routage Intelligent](tutos_live/2-mise-en-place-docker-host.md))
- **Sur PC :** Utilisation d'**Avahi** (mDNS) pour résoudre `homelab.local` malgré les changements d’IP.
- **Sur Android (Le Hack) :** Impossible d’utiliser mDNS sans être root. Un script **Termux** a donc été écrit. (Voir [Annexe 2 : Termux SSH Homelab Toolkit](tutos_live/annexes/2-termux-ssh-toolkit.md))

## 🔧 Stabiliser l’instable : Le Network Watchdog
La connectivité réseau sautait au moindre mouvement du câble. Parfois seul le LXC tombait, parfois tout Proxmox. Toutes les manipulations manuelles ont été automatisées. (Voir [Annexe 1 : Network Watchdog (Auto-Réparation)](tutos_live/annexes/1-network-watchdog-v3.md))

C’est ainsi qu’est né le **network watchdog**.
- Il teste régulièrement la connectivité (ping vers 8.8.8.8).
- Il applique des réparations graduelles selon la gravité de la panne.
- Il logue tout dans `/var/log/network_watchdog.log`.
- Il envoie un message Telegram dès qu’il intervient.
Depuis la version 3, il n'y a plus jamais eu besoin de réparer la connectivité manuellement. Le système s'auto-guérit.

## 💾 Hygiène du système : Sauvegardes, Maintenance, Docker
Une fois la stabilité réseau assurée, une stratégie sérieuse a été mise en place :

1.  **La règle 3‑2‑1 (Sauvegardes) :** (Voir [Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)](tutos_live/security/1-sauvegarde-maintenance-321.md))
    - Une copie locale sur Proxmox.
    - Une copie sur un SSD externe (via exfiltration automatisée sur PC Ubuntu).
    - Une copie miroir sur Google Drive via GVFS.
    - Exécution automatique tous les jours à **3h du matin**.
2.  **Maintenance du Samedi (4h du matin) :**
    - Script de maintenance hebdomadaire (`weekly_maintenance.sh`) lancé juste après les sauvegardes.
    - Nettoie intelligemment le système, évite les reboot naïfs, et garde le serveur fluide (`apt dist-upgrade`, `docker system prune -a`).
3.  **Purge Docker (5h du matin) :**
    - Conteneur dédié (ou script) pour le nettoyage des images, volumes orphelins et caches, exécuté vers 5h.
4.  **Mises à jour Auto (Watchtower) :** (Voir [Sécurité 2 : Mises à jour Automatiques avec Watchtower](tutos_live/security/2-automatisation-watchtower.md))
    - Conteneur configuré (API v1.44) pour scanner le Hub et mettre à jour les applications à **5h du matin**.

## 📊 Sentinel : Donner des yeux au serveur
Pour surveiller l’état du serveur, **Sentinel** a été développé. C'est une sorte de task manager graphique maison (Streamlit sur le port 8501).
- Il suit l’usage CPU, RAM, disque et la charge système.
- Il envoie des alertes Telegram en cas de surcharge.
- Sentinel est devenu le tableau de bord principal, intégré dans le réseau via Traefik.

## 🛠️ Industrialisation : GitLab CI/CD + GitHub
Avant même de s'attaquer à Tailscale ou Cloudflare, il fallait industrialiser les déploiements. Coder directement sur le serveur via VSCode SSH surchargeait inutilement la machine. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](tutos_live/3-industrialisation-devops.md))

- **Organisation :** Création d'une organisation GitHub publique et d'un groupe GitLab privé.
- **Sécurité :** Configuration de clés SSH distinctes et génération d'un token GitLab.
- **Runner Local :** Installation d'un **GitLab Runner** directement sur le `docker-host`.
- **Structure des Projets :** Définition de variables secrètes globales, structuration avec des templates Docker, `docker-compose.yml`, `.gitignore`, `.dockerignore`, et parfois un `Makefile`.
- **Pipelines (Jobs) :** Chaque pipeline GitLab comporte au moins deux jobs :
    1.  Un pour déployer sur le homelab (injection du `.env`, `docker compose up -d --build`).
    2.  Un autre pour synchroniser automatiquement le dépôt privé vers GitHub pour le portfolio.

## 🌐 L'Abstraction DNS et le Réseau Overlay (Tailscale + AdGuard)
La véritable élégance de l'infrastructure réside dans une **abstraction totale du réseau**. (Voir [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](tutos_live/4-reseau-overlay-tailscale.md))

**Preuve de l'Abstraction (Vérifiée sur Docker-Host) :**
Dans le conteneur `docker-host`, le fichier `/etc/resolv.conf` ne connaît pas l'X. Il pointe uniquement vers :
`nameserver 100.100.100.100` (MagicDNS de Tailscale).

**Le Mécanisme du Split DNS :**
- **Tailscale (VPN Mesh) :** Installé dans le `docker-host` (Conteneur ID 100), en mode Bridge sur le réseau `proxy`. Il agit comme un routeur. Dans Tailscale, un **Split DNS** est configuré : il attrape toutes les requêtes finissant par `.homelab` et les renvoie vers notre serveur interne. Pour toutes les autres requêtes (un namespace global), il les renvoie vers les DNS de l'X (`129.104.30.41`).
- **AdGuard Home (L'Annuaire Local) :** Pour les requêtes `.homelab` qui reviennent au serveur, c'est le conteneur AdGuard qui prend le relais. Il gère également l'**Upstream DNS** pointant vers les DNS de l'école.
- **L'Avantage Ultime :** Si le serveur déménage sur une box internet standard, la seule chose à ajuster sera l'IP des serveurs DNS dans le namespace Tailscale. Le conteneur Docker restera sur son MagicDNS `100.100.100.100` sans jamais savoir que son environnement physique a changé.
- **Routage :** Tailscale redirige les ports 80 et 443 directement vers Traefik. Accéder aux services internes est devenu trivial : `sentinel.homelab`, `traefik.homelab`… sans port, depuis n’importe quel réseau.

## ☁️ Exposition publique : Cloudflare Tunnel et Kpihx-labs.com
Pour exposer certains services au public, Tailscale Funnel a d'abord été envisagé, mais jugé trop lourd (un port par service, modifs du docker-compose, URLs non intuitives). (Voir [Tuto 5 : Exposition Publique et Zero Trust (Cloudflare)](tutos_live/5-exposition-publique-cloudflare.md))

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

---
## 🗺️ Navigation
- [🏠 Accueil](README.md)
- [🔭 Vision](VISION.md)
- [🕒 Évolution](EVOLUTION.md)
- [🤖 Agent Mandate](AGENT.md)
