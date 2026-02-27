# 🕒 Évolution : Chronologie de l'Ingénierie

## [Février 2026] : L'Ère de l'Auto-Validation et de l'Expérience Web
- **Certification DNS-01 & "Stealth Trusted" :** Succès du challenge DNS-01 via l'API Cloudflare. Obtention d'un certificat Wildcard officiel pour `*.kpihx-labs.com` sans exposition publique. (Voir [Tuto 6](https://kpihx-labs.github.io/presentation/#/tutos_live/6-souverainete-secrets-certification-dns01.md)).
- **Coffre-fort Souverain :** Déploiement de **Vaultwarden** avec SSL reconnu par les applications mobiles Bitwarden.
- **Pivot Architectural (Réseau) :** Post-mortem sur le conflit DNS circulaire causé par la conteneurisation de Tailscale. Transition vers le **Subnet Routing** exclusif sur l'hôte PVE pour une robustesse absolue. (Voir le Post-Mortem dans le [Tuto 4](https://kpihx-labs.github.io/presentation/#/tutos_live/4-reseau-overlay-tailscale.md)).
- **Standardisation du Versioning :** Adoption de la règle d'immutabilité des templates (`xxxx.yaml` ➔ `xxxx.2.yaml`) pour préserver l'historique narratif.
- **Usine de Validation :** Mise en place de scripts de tests full-verbose ([check_links.sh](https://github.com/kpihx-labs/presentation/blob/main/scripts/check_links.sh), [check_templates.sh](https://github.com/kpihx-labs/presentation/blob/main/scripts/check_templates.sh), [check_tutos.sh](https://github.com/kpihx-labs/presentation/blob/main/scripts/check_tutos.sh)) pour garantir l'intégrité du maillage technique.
- **Intelligence Documentaire :** Intégration d'un moteur de recherche full-text et d'un thème sombre dynamique.
- **Consolidation du Mandat Agent :** Inscription de la philosophie de reproductibilité par scripts et de proactivité dans [AGENT.md](https://kpihx-labs.github.io/presentation/#/AGENT.md).

## [Décembre 2025] : Transparence et Accès Public
- Achat du domaine `kpihx-labs.com`.
- Déploiement du **Cloudflare Tunnel (HTTP2)**. (Voir [Tuto 5 : Exposition Publique et Zero Trust (Cloudflare)](https://kpihx-labs.github.io/presentation/#/tutos_live/5-exposition-publique-cloudflare.md))
- Intégration de **Google OAuth** pour la validation d'identité. (Voir [Tuto 5](https://kpihx-labs.github.io/presentation/#/tutos_live/5-exposition-publique-cloudflare.md))
- Déploiement de **PolyTask Pro** (Voir [Template PolyTask](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/polytask.yaml)) et **WA-Bot** (Voir [Template WA-Bot](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/wa_bot.yaml)).
- Initialisation de **Vaultwarden** pour la souveraineté des secrets. (Voir [Template Vaultwarden](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/vaultwarden.yaml))
- Structuration de la "Boîte Noire" documentaire dans `presentation/` avec un mandat strict de **100% transparence et exhaustivité**.
- Mise sur pied du conteneur "Usine" (**Docker-Host**) et déploiement de **Traefik**. (Voir [Tuto 2 : Mise sur pied du Docker-Host et Routage Intelligent](https://kpihx-labs.github.io/presentation/#/tutos_live/2-mise-en-place-docker-host.md))
- Rédaction de tutoriels "Live" axés "Problème ➔ Solution" dans le sous-dossier [tutos_live/](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md).
- Externalisation et standardisation de toutes les configurations (Docker Compose, Scripts, SSH) dans `tutos_live/templates/` avec documentation approfondie en anglais.

## [Décembre 2025] : L'Usine Logicielle
- Déploiement du **GitLab Runner** local. (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](https://kpihx-labs.github.io/presentation/#/tutos_live/3-industrialisation-devops.md))
- Automatisation des pipelines CI/CD vers Docker Compose. (Voir [Tuto 3](https://kpihx-labs.github.io/presentation/#/tutos_live/3-industrialisation-devops.md))
- Mise en place de la synchronisation automatique vers l'organisation GitHub. (Voir [Tuto 3](https://kpihx-labs.github.io/presentation/#/tutos_live/3-industrialisation-devops.md))

## [Décembre 2025] : Le Réseau Invisible
- Installation de **Tailscale** et **AdGuard Home**. (Voir [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](https://kpihx-labs.github.io/presentation/#/tutos_live/4-reseau-overlay-tailscale.md))
- Création du Split DNS pour le domaine `*.homelab`. (Voir [Tuto 4](https://kpihx-labs.github.io/presentation/#/tutos_live/4-reseau-overlay-tailscale.md))
- Script Android/Termux pour le scan d'IP dynamique et mise à jour `.ssh/config`. (Voir [Annexe 2 : Termux SSH Homelab Toolkit](https://kpihx-labs.github.io/presentation/#/tutos_live/annexes/2-termux-ssh-toolkit.md))

## [Décembre 2025] : Stabilisation & Hardware
- Montage du SSD 1 To.
- Développement du **Network Watchdog V3**. (Voir [Annexe 1 : Network Watchdog (Auto-Réparation & Monitoring)](https://kpihx-labs.github.io/presentation/#/tutos_live/annexes/1-network-watchdog-v3.md))
- Configuration du Masquerading (NAT) sur `vmbr1` for l'isolation des LXC. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](https://kpihx-labs.github.io/presentation/#/tutos_live/1-deploiement-proxmox-8021x.md))
- Mise en place de la règle de sauvegarde 3-2-1 (Local, SSD, Cloud). (Voir [Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)](https://kpihx-labs.github.io/presentation/#/tutos_live/security/1-sauvegarde-maintenance-321.md))
- Automatisation des mises à jour applicatives via Watchtower. (Voir [Sécurité 2 : Mises à jour Automatiques avec Watchtower](https://kpihx-labs.github.io/presentation/#/tutos_live/security/2-automatisation-watchtower.md))

## [Décembre 2025] : Fondation & Survie
- Récupération d'un laptop AMD (écran brisé).
- Installation de **Proxmox VE 8**. (Voir [Tuto 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)](https://kpihx-labs.github.io/presentation/#/tutos_live/1-deploiement-proxmox-8021x.md))
- Hack de l'auth 802.1X via `wpa_supplicant` et OpenSSL `SECLEVEL=0`. (Voir [Tuto 1](https://kpihx-labs.github.io/presentation/#/tutos_live/1-deploiement-proxmox-8021x.md))
- Première sécurisation SSH (Port 2222, clés uniquement). (Voir [Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH Timeout)](https://kpihx-labs.github.io/presentation/#/tutos_live/security/3-bouclier-inactivite-ssh.md))


