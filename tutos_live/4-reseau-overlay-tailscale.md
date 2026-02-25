# 🚀 Tuto Live 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)

**Contexte :** Vous avez des services qui tournent (Sentinel, Adminer), mais pour y accéder, vous devez soit faire des tunnels SSH compliqués, soit être physiquement à l'X. Nous voulons un accès "Transparent" : taper `sentinel.homelab` dans le navigateur de votre téléphone, n'importe où dans le monde, et que ça fonctionne.

**Objectifs :**
1. Créer un annuaire DNS privé (**AdGuard Home**) pour gérer les domaines `.homelab`.
2. Monter un tunnel VPN sécurisé (**Tailscale**) qui traverse tous les firewalls.
3. Configurer le **Split DNS** pour ne pas ralentir votre connexion internet classique.

---

## 📖 PHASE 1 : L'ABSTRACTION DNS MAGIQUE (ADGUARD HOME)

### 🤔 Pourquoi faire cela ?
Le domaine `.homelab` n'existe pas sur internet. Il nous faut un annuaire local. Mais le véritable coup de génie réside dans l'**abstraction du réseau**. 
Dans le conteneur Docker, le résolveur principal est **Tailscale** (présent au niveau de Proxmox). Dans Tailscale, il y a un **Split DNS** qui attrape tout ce qui finit en `.homelab` et l'envoie vers notre serveur interne. Pour tout le reste (ex: google.com), il le renvoie vers les DNS de l'X (`129.104.30.41`).

Pour ce qui revient au serveur (`.homelab`), c'est le conteneur **AdGuard** (notre DNS local) qui prend le relais. Il gère aussi l'**Upstream DNS**. Résultat : Le jour où le serveur quitte l'X pour une box internet standard, la seule chose à modifier, ce sont les IP des serveurs Upstream DNS dans AdGuard et le Nameserver Global de Tailscale. Le conteneur Docker, lui, n'a jamais su qu'il était à l'X.

**✅ La Solution :**
1. **Déploiement :** Récupérez le **Template :** [adguard.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.yaml) et déployez-le via Portainer.
2. **DNS Rewrite :** Dans l'interface AdGuard (port 3000), allez dans *Filtres > Réécritures DNS*. Ajoutez une règle : `*.homelab` ➔ IP Tailscale de votre serveur.
3. **Upstream DNS (Le Pivot) :** Configurez AdGuard pour qu'il demande aux serveurs de l'école (`129.104.30.41`) quand il ne connaît pas une adresse.

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
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
