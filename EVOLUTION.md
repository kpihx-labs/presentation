# 🕒 Évolution : Chronologie de l'Ingénierie

## [Décembre 2025] : Fondation & Survie
- Récupération d'un laptop AMD (écran brisé).
- Installation de **Proxmox VE 8**. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](tutos_live/1-deploiement-proxmox-8021x.md))
- Hack de l'auth 802.1X via `wpa_supplicant` et OpenSSL `SECLEVEL=0`. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](tutos_live/1-deploiement-proxmox-8021x.md))
- Première sécurisation SSH (Port 2222, clés uniquement). (Voir [Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH)](tutos_live/security/3-bouclier-inactivite-ssh.md))

## [Décembre 2025] : Stabilisation & Hardware
- Montage du SSD 1 To.
- Développement du **Network Watchdog V3**. (Voir [Annexe 1 : Network Watchdog (Auto-Réparation)](tutos_live/annexes/1-network-watchdog-v3.md))
- Configuration du Masquerading (NAT) sur `vmbr1` pour l'isolation des LXC. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](tutos_live/1-deploiement-proxmox-8021x.md))
- Mise en place de la règle de sauvegarde 3-2-1 (Local, SSD, Cloud). (Voir [Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)](tutos_live/security/1-sauvegarde-maintenance-321.md))

## [Décembre 2025] : Le Réseau Invisible
- Installation de **Tailscale** et **AdGuard Home**. (Voir [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](tutos_live/4-reseau-overlay-tailscale.md))
- Création du Split DNS pour le domaine `*.homelab`. (Voir [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](tutos_live/4-reseau-overlay-tailscale.md))
- Script Android/Termux pour le scan d'IP dynamique et mise à jour `.ssh/config`. (Voir [Annexe 2 : Termux SSH Homelab Toolkit](tutos_live/annexes/2-termux-ssh-toolkit.md))

## [Décembre 2025] : L'Usine Logicielle
- Déploiement du **GitLab Runner** local. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](tutos_live/3-industrialisation-devops.md))
- Automatisation des pipelines CI/CD vers Docker Compose. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](tutos_live/3-industrialisation-devops.md))
- Mise en place de la synchronisation automatique vers l'organisation GitHub. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](tutos_live/3-industrialisation-devops.md))

## [Décembre 2025] : Transparence et Accès Public
- Achat du domaine `kpihx-labs.com`.
- Déploiement du **Cloudflare Tunnel (HTTP2)**. (Voir [Tuto 5 : Exposition Publique et Zero Trust (Cloudflare)](tutos_live/5-exposition-publique-cloudflare.md))
- Intégration de **Google OAuth** pour la validation d'identité. (Voir [Tuto 5 : Exposition Publique et Zero Trust (Cloudflare)](tutos_live/5-exposition-publique-cloudflare.md))
- Déploiement de **PolyTask Pro** et **WA-Bot**.
- Initialisation de **Vaultwarden** pour la souveraineté des secrets.
- Structuration de la "Boîte Noire" documentaire dans `presentation/` avec un mandat strict de **100% transparence et exhaustivité**.
- Rédaction de tutoriels "Live" axés "Problème ➔ Solution" dans le sous-dossier `tutos_live/`.
- Externalisation et standardisation de toutes les configurations (Docker Compose, Scripts, SSH) dans `tutos_live/templates/` avec documentation approfondie en anglais.


---
## 🗺️ Navigation
- [🏠 Accueil](README.md)
- [🔭 Vision](VISION.md)
- [🏗️ État de l'Art](STATE_OF_THE_ART.md)
- [🕒 Évolution](EVOLUTION.md)
- [🚀 Live Tutorials](tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](AGENT.md)
