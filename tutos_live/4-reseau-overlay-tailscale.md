# 🚀 Tuto Live 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)

**Contexte :** Vous avez des services qui tournent (Sentinel, Adminer), mais pour y accéder, vous devez soit faire des tunnels SSH compliqués, soit être physiquement à l'X. Nous voulons un accès "Transparent" : taper `sentinel.homelab` dans le navigateur de votre téléphone, n'importe où dans le monde, et que ça fonctionne.

**Objectifs :**
1. Installer **Tailscale** sur l'hôte physique (PVE) pour le routage et la stabilité.
2. Créer un annuaire DNS privé (**AdGuard Home**) dans Docker pour gérer les domaines `.homelab`.
3. Monter un tunnel VPN sécurisé (**Tailscale Container**) pour isoler les services.
4. Configurer le **Split DNS** pour ne pas ralentir votre connexion internet classique.

---

## 🏗️ PHASE 0 : INSTALLATION SUR L'HÔTE (PROXMOX PVE)

### 🤔 Pourquoi faire cela ?
Avant de mettre Tailscale dans Docker, il est vital de l'avoir sur l'hôte physique. 
*   **Stabilité :** Si Docker crash, vous gardez l'accès SSH à votre serveur via le VPN.
*   **Gateway :** C'est l'hôte qui servira de "Subnet Router" pour exposer tout votre réseau local (10.10.10.0/24) au reste du VPN.

### ✅ La Solution
Connectez-vous en SSH à votre **PVE** et lancez l'installation classique :
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```
Activez Tailscale en annonçant votre réseau interne :
```bash
sudo tailscale up --advertise-routes=10.10.10.0/24
```

---

## 📖 PHASE 1 : L'ABSTRACTION DNS MAGIQUE (ADGUARD HOME)

### 🤔 Pourquoi faire cela ?
Le domaine `.homelab` n'existe pas sur internet. Il nous faut un annuaire local. Mais le véritable coup de génie réside dans l'**abstraction du réseau**. 
Dans le conteneur Docker, le résolveur principal est **Tailscale** (présent au niveau de Proxmox). Dans Tailscale, il y a un **Split DNS** qui attrape tout ce qui finit en `.homelab` et l'envoie vers notre serveur interne. Pour tout le reste (ex: google.com), il le renvoie vers les DNS de l'X (`129.104.30.41`).

Pour ce qui revient au serveur (`.homelab`), c'est le conteneur **AdGuard** (notre DNS local) qui prend le relais. Il gère aussi l'**Upstream DNS**. Résultat : Le jour où le serveur quitte l'X pour une box internet standard, la seule chose à modifier, ce sont les IP des serveurs Upstream DNS dans AdGuard et le Nameserver Global de Tailscale. Le conteneur Docker, lui, n'a jamais su qu'il était à l'X.

**✅ La Solution :**

1. **Préparation des dossiers (Sur le serveur)**
Connectez-vous en SSH à votre conteneur `docker-host` :
```bash
ssh docker-host
mkdir -p /root/dns/work
mkdir -p /root/dns/conf
cd /root/dns
```

2. **Déploiement :** Récupérez le **Template :** [adguard.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.yaml) et déployez-le via Portainer.

3. **Configuration Initiale (Via Tunnel SSH)**
Pour configurer AdGuard la première fois, on ne peut pas utiliser de nom de domaine. On doit y accéder via un tunnel.
*Sur votre PC :*
```bash
ssh -L 3000:10.10.10.10:3000 homelab
```
*Dans votre navigateur :*
Ouvrez `http://localhost:3000`.
*   **Interface Admin :** Choisissez le port **3000** (Important, sinon conflit avec Traefik).
*   **Serveur DNS :** Laissez le port **53**.

4. **Configuration des "Upstream DNS" (Pour avoir Internet)**
AdGuard doit savoir à qui demander quand il ne connaît pas la réponse (ex: google.com). À l'X, on ne peut pas sortir sur le port 53 vers Google (8.8.8.8). On doit utiliser les DNS de l'école.
*   Dans AdGuard > **Paramètres** > **Paramètres DNS**.
*   Section **Serveurs DNS amont** : Supprimez tout et mettez les IP de l'X (trouvées dans `/etc/resolv.conf` sur le serveur) :
    `129.104.30.41`
    `129.104.32.41`

5. **La Règle Magique : DNS Rewrite**
C'est ici qu'on crée le domaine `.homelab`.
*   Dans AdGuard > **Filtres** > **Réécritures DNS**.
*   Ajoutez une règle : `*.homelab` ➔ **IP Tailscale de votre serveur**.

---

## 🛡️ PHASE 2 : LE TUNNEL INVISIBLE (TAILSCALE)

**🤔 Pourquoi faire cela ?**
Tailscale crée un réseau privé virtuel (Overlay) entre vos appareils. Même si votre serveur change d'IP à l'école, son IP Tailscale (`100.x.y.z`) reste **fixe** et accessible de partout.

**✅ La Solution :**
1. **Déploiement :** Utilisez le **Template :** [tailscale.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/tailscale.yaml).
2. **Mode Userspace :** Vital dans un conteneur LXC pour éviter de casser le kernel Proxmox (`TS_USERSPACE=true`).
3. **Subnet Router :** Dans la console Tailscale (Web), activez la route `10.10.10.0/24`. Cela permet à votre téléphone de "voir" tous vos conteneurs Docker comme s'ils étaient à côté de lui.

---

## 🚦 PHASE 3 : LA PLOMBERIE (TAILSCALE SERVE)

**🤔 Pourquoi faire cela ?**
Par défaut, Tailscale arrive sur votre serveur mais ne sait pas qu'il doit envoyer le trafic web vers Traefik.

**✅ La Solution :**
Connectez-vous au conteneur Tailscale et redirigez les flux :
```bash
docker exec -it tailscale sh
tailscale serve --bg --tcp 80 tcp://traefik:80
tailscale serve --bg --tcp 443 tcp://traefik:443
```

---

## 🛰️ PHASE 4 : LE SPLIT DNS (LA TOUCHE FINALE SUR TAILSCALE)

**🤔 Pourquoi faire cela ?**
On ne veut pas que TOUT votre trafic (YouTube, Instagram) passe par votre petit serveur à l'école. On veut juste que les requêtes `.homelab` y aillent, et déléguer le reste aux DNS de l'X (l'abstraction finale).

**✅ La Solution (Console Tailscale Web) :**
1. Allez dans l'onglet **DNS**.
2. **Global Nameservers :** Ajoutez l'IP interne d'AdGuard (`10.10.10.10`).
3. **Restrict to domain (Split DNS) :** Cochez cette case et écrivez `homelab`.
4. **Namespace par défaut :** Laissez les autres requêtes pointer vers les DNS natifs de l'école.
5. **Résultat :** Votre téléphone demandera à AdGuard uniquement pour les sites en `.homelab`. Le reste passera par votre 4G/Wifi normalement.

**Verdict :** Ouvrez votre navigateur sur votre iPhone, tapez `https://sentinel.homelab`. Si ça s'affiche, vous avez réussi le chef-d'œuvre de l'abstraction réseau et du Split DNS ! 🌐✨

---

## 📱 PHASE 5 : CONFIGURATION DES CLIENTS

**1. Sur votre Téléphone (Android/iOS)**
Installez l'app Tailscale, activez le VPN. Accédez à `https://sentinel.homelab`.

**2. Sur votre PC Linux**
```bash
sudo tailscale up --accept-routes --accept-dns
```

---

### 🔄 RÉSUMÉ DE LA MÉCANIQUE
1.  **Vous :** `https://sentinel.homelab`
2.  **Votre PC/Tel :** Demande au DNS Tailscale pour `.homelab`.
3.  **Tailscale :** Oriente vers `10.10.10.10` via le tunnel.
4.  **AdGuard (10.10.10.10) :** Répond avec l'IP Tailscale `100.x.y.z`.
5.  **Conteneur Tailscale (`100.x.y.z`) :** Reçoit le HTTPS et l'envoie à `traefik:443`.
6.  **Traefik :** Sert le site Sentinel.

C'est propre, logique, et ça marche partout.

---

## ⚠️ POST-MORTEM : L'Échec du "Double Tailscale" (Pourquoi nous avons changé de méthode)

Dans notre approche initiale, nous avions déployé un conteneur Docker Tailscale (Voir l'archive : [tailscale.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/tailscale.yaml)) à l'intérieur du `docker-host` pour utiliser son MagicDNS, tout en gardant une installation Tailscale sur le PVE hôte.

### 💥 Le problème rencontré : Le Cercle Vicieux du DNS
Cette architecture a causé un effondrement fatal du DNS (`servefail`) sur le PVE après un redémarrage de Traefik :
1.  Le PVE avait `accept-dns=true` et pointait vers `100.100.100.100`.
2.  Le trafic TCP était lié à Traefik via `tailscale serve`.
3.  Lorsque Traefik redémarrait, le réseau Docker coupait.
4.  Les deux instances Tailscale (Hôte et Conteneur) se battaient pour les mêmes ports UDP de sortie.
5.  **Résultat :** Le PVE perdait son DNS. Sans DNS, impossible de résoudre les registres Docker, empêchant les conteneurs de redémarrer. L'infrastructure était totalement bloquée.

### 🛠️ La nouvelle philosophie (Subnet Routing)
Nous avons abandonné le conteneur Docker. Le PVE (Hôte physique) est redevenu le seul chef d'orchestre :
- Il fait du **Subnet Routing** (`--advertise-routes=10.10.10.0/24`) pour donner accès à tout le sous-réseau Docker sans avoir besoin d'être "dans" Docker.
- Il a `accept-dns=false` pour utiliser exclusivement les serveurs DNS infaillibles de l'école (pas de boucle locale).
- Le Split DNS d'AdGuard fonctionne de manière transparente pour le reste des appareils du mesh.

**Leçon apprise :** L'abstraction est puissante, mais elle ne doit jamais créer de dépendances circulaires entre l'hôte et ses propres conteneurs.

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
