# 🚀 Tuto Live 2 : Mise sur pied du Docker-Host et Routage Intelligent

**Contexte :** Le serveur Proxmox dispose désormais d'un accès Internet stable (via l'adaptateur USB et le NAT). L'étape suivante consiste à transformer cette machine en une véritable usine à services (PaaS) capable d'héberger des applications et de les rendre accessibles de manière élégante.

**Objectifs :**
1. Configurer le **DNAT (Port Forwarding)** pour que le monde extérieur puisse "voir" nos services.
2. Monter le Conteneur "Usine" (**LXC Docker Host**) avec les options de virtualisation imbriquée.
3. Configurer l'accès SSH avancé (**Tunnels & ProxyJump**) pour le confort de l'administrateur.
4. Déployer la Gateway **Traefik** (Reverse Proxy, HTTPS forcé, Authentification).
5. Déployer un service test (**Whoami**) pour valider toute la chaîne.


---
## 🗺️ Navigation
- [🏠 Accueil](../README.md)
- [🔭 Vision](../VISION.md)
- [🏗️ État de l'Art](../STATE_OF_THE_ART.md)
- [🕒 Évolution](../EVOLUTION.md)
- [🚀 Live Tutorials](README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../AGENT.md)
