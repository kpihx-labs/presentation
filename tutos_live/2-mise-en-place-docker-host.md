# 🚀 Tuto Live 2 : Mise sur pied du Docker-Host et Routage Intelligent

**Contexte :** Le serveur Proxmox dispose désormais d'un accès Internet stable (via l'adaptateur USB et le NAT). L'étape suivante consiste à transformer cette machine en une véritable usine à services (PaaS) capable d'héberger des applications et de les rendre accessibles de manière élégante.

**Objectifs :**
1. Configurer le **DNAT (Port Forwarding)** pour que le monde extérieur puisse "voir" nos services.
2. Monter le Conteneur "Usine" (**LXC Docker Host**) avec les options de virtualisation imbriquée.
3. Configurer l'accès SSH avancé (**Tunnels & ProxyJump**) pour le confort de l'administrateur.
4. Déployer la Gateway **Traefik** (Reverse Proxy, HTTPS forcé, Authentification).
5. Déployer un service test (**Whoami**) pour valider toute la chaîne.

---

## 🚪 PHASE 1 : OUVERTURE DES PORTES (DNAT SUR PROXMOX)

**🤔 Pourquoi faire cela ?**
Le serveur Proxmox (IP publique `129.104...`) agit comme un routeur/pare-feu. Par défaut, il bloque tout le trafic entrant. Il faut lui indiquer explicitement : *"Si quelqu'un frappe au port 80 ou 443 de mon IP publique, envoie-le au conteneur Docker interne (IP `10.10.10.10`) qui saura quoi en faire"*.

**✅ La Solution :**
Éditez le fichier `/etc/network/interfaces` sur l'hôte Proxmox. Ajoutez ces règles de redirection dans la section de votre pont privé `vmbr1` (après les règles de Masquerading créées au Tuto 1) :

```text
# ... (Configuration IP et Masquerading déjà présents) ...

# --- REGLES DE REDIRECTION (DNAT) ---
# 1. Port 80 (HTTP) -> Vers Conteneur Docker (Pour la redirection auto vers HTTPS)
post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 10.10.10.10:80
post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 10.10.10.10:80

# 2. Port 443 (HTTPS) -> Vers Conteneur Docker (Le trafic principal sécurisé)
post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 10.10.10.10:443
post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 10.10.10.10:443

# 3. Port 9443 (Portainer) -> Accès direct à l'interface de gestion graphique
post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 9443 -j DNAT --to 10.10.10.10:9443
post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 9443 -j DNAT --to 10.10.10.10:9443
```

**🚀 Application :** Appliquez les modifications sans redémarrer (pour ne pas couper le SSH) avec : `ifreload -a`.

---

## 🏗️ PHASE 2 : CRÉATION DE L'USINE (DOCKER HOST)

**🤔 Pourquoi faire cela ?**
Par mesure de sécurité et d'hygiène système, on n'installe **jamais** Docker ou des services directement sur l'hyperviseur Proxmox. On crée une bulle isolée : un conteneur LXC.

### 1. Création du LXC (Interface Web Proxmox)
- **Template :** `debian-12-standard`
- **Disque :** 20 Go minimum (prévoyez large pour les images Docker).
- **Mémoire :** 4 Go minimum.
- **Réseau :** Bridge `vmbr1` | IPv4 statique : `10.10.10.10/24` | Gateway : `10.10.10.1`.

### 2. Options CRITIQUES (Le "Nesting")
Sans ces options, Docker ne pourra pas démarrer à l'intérieur de LXC. Dans l'onglet **Options > Features**, cochez :
- **[x] Nesting :** Permet la virtualisation imbriquée (Docker dans LXC).
- **[x] Keyctl :** Nécessaire pour la gestion des clés sécurisées dans les images Docker modernes.

### 3. Installation de Docker et du Proxy
**⚠️ ATTENTION :** Comme le conteneur est sur le réseau privé `10.10.10.x`, il doit passer par le proxy de l'école pour télécharger des paquets.

**a. Configuration du Proxy Shell (Immédiat) :**
```bash
export http_proxy=http://129.104.201.11:8080
export https_proxy=http://129.104.201.11:8080
```

**b. Installation :**
```bash
apt update && apt install curl git -y
curl -fsSL https://get.docker.com | sh
```

**c. Proxy pour le Démon Docker (INDISPENSABLE pour faire des `docker pull`) :**
Si vous oubliez cela, Docker sera incapable de télécharger des images depuis le Hub.
```bash
mkdir -p /etc/systemd/system/docker.service.d
echo '[Service]
Environment="HTTP_PROXY=http://129.104.201.11:8080"
Environment="HTTPS_PROXY=http://129.104.201.11:8080"
Environment="NO_PROXY=localhost,127.0.0.1,10.10.10.10"' > /etc/systemd/system/docker.service.d/http-proxy.conf

systemctl daemon-reload
systemctl restart docker
```

---

## 🛰️ PHASE 3 : RÉSOLUTION MDNS (AVAHI) & TUNNELS SSH

### A. Configuration mDNS (Accès par Nom)
Pour ne plus jamais avoir à retenir l'IP (qui peut changer), on installe Avahi sur l'hôte Proxmox :
1. `apt update && apt install avahi-daemon avahi-utils -y`
2. Modifiez `/etc/avahi/avahi-daemon.conf` pour définir `host-name=homelab`.
3. Désormais, depuis votre PC, vous pouvez faire `ping homelab.local`.

### B. Ingénierie SSH (~/.ssh/config)
C'est le "tableau de bord" de votre PC administrateur.

*   **Template complet :** `https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ssh_config`

Ce fichier magique vous permet de définir :
- `homelab` : l'accès physique.
- `docker-host` : l'accès au conteneur interne en rebondissant (`ProxyJump`) sur le homelab.
- `homelab-ui` : l'ouverture simultanée de tunnels locaux (`LocalForward`) pour afficher Proxmox, Portainer et Traefik directement sur le `localhost` de votre PC.

---

## 🚦 PHASE 4 : LE ROUTEUR INTELLIGENT (TRAEFIK)

**🤔 Pourquoi faire cela ?**
Traefik est le cerveau de l'usine. Il reçoit tout le trafic Web, gère les certificats (même auto-signés en local) et aiguille les requêtes vers le bon conteneur selon le nom de domaine demandé (ex: `whoami.homelab`).

**✅ Déploiement via Portainer (Stack "traefik") :**
1. Générez un hash pour protéger l'interface : `htpasswd -nb user password`. *(Note : Doublez les `$` dans le yaml : `$$apr1$$...`)*
2. Récupérez le fichier **Template :** `https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/traefik.yaml`.
3. Déployez-le. Traefik commencera immédiatement à écouter les événements Docker.

---

## 🧪 PHASE 5 : VALIDATION FINALE (DNS LOCAL & TEST)

Pour que votre PC puisse résoudre `traefik.homelab`, vous devez modifier votre fichier `/etc/hosts` (ou Windows `hosts`) :
```text
127.0.0.1 traefik.homelab
127.0.0.1 whoami.homelab
```

**✅ Test :**
1. Lancez le tunnel : `ssh -N homelab-ui`.
2. Ouvrez : `https://traefik.homelab:8443`.
3. Si le dashboard Traefik s'affiche, votre usine logicielle est prête !

---
## 🗺️ Navigation
- [🏠 Accueil](../README.md)
- [🔭 Vision](../VISION.md)
- [🏗️ État de l'Art](../STATE_OF_THE_ART.md)
- [🕒 Évolution](../EVOLUTION.md)
- [🤖 Agent Mandate](../AGENT.md)
