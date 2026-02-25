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

### ✅ La Solution
1. **Préparation des dossiers (Sur le serveur)**
Connectez-vous en SSH à votre conteneur `docker-host` :
```bash
ssh docker-host
mkdir -p /root/dns/work
mkdir -p /root/dns/conf
cd /root/dns
```

2. **Le Fichier docker-compose.yml**
*Pourquoi cette config ?*
*   On expose le port **53** (UDP/TCP) pour que les appareils puissent poser des questions DNS.
*   On définit les variables de **Proxy** (`http_proxy`) pour qu'AdGuard puisse télécharger ses listes de blocage de pubs.
*   On définit **NO_PROXY** pour qu'il puisse parler aux machines locales sans passer par le proxy de l'X.

*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.yaml)

3. **Configuration Initiale (Via Tunnel SSH)**
Pour configurer AdGuard la première fois, on ne peut pas utiliser de nom de domaine. On doit y accéder via un tunnel.

*Sur votre PC :*
```bash
ssh -L 3000:10.10.10.10:3000 homelab
```
*Dans votre navigateur :*
Ouvrez `http://localhost:3000`.
*   Cliquez sur "C'est parti".
*   **Interface Admin :** Choisissez le port **3000** (Important, sinon conflit avec Traefik).
*   **Serveur DNS :** Laissez le port **53**.
*   Créez votre compte utilisateur.

4. **Configuration des "Upstream DNS" (Pour avoir Internet)**
AdGuard doit savoir à qui demander quand il ne connaît pas la réponse (ex: google.com). À l'X, on ne peut pas sortir sur le port 53 vers Google (8.8.8.8). On doit utiliser les DNS de l'école.
*   Dans AdGuard > **Paramètres** > **Paramètres DNS**.
*   Section **Serveurs DNS amont** : Supprimez tout et mettez les IP de l'X (trouvées dans `/etc/resolv.conf` sur le serveur) :
    `129.104.30.41`
    `129.104.32.41`
*   Cliquez sur "Tester". Si c'est OK, cliquez sur "Appliquer".

5. **La Règle Magique : DNS Rewrite**
C'est ici qu'on crée le domaine `.homelab`.
*   Dans AdGuard > **Filtres** > **Réécritures DNS**.
*   Cliquez sur **Ajouter**.
*   Domaine : `*.homelab`
*   IP : **L'IP Tailscale de votre serveur** (ex: `100.x.y.z`).
    *   *Pourquoi l'IP Tailscale ?* Parce que c'est la seule IP qui sera accessible de partout une fois le VPN monté.

---

## 🛡️ PHASE 2 : LE TUYAU VPN (TAILSCALE CONTAINER)

Maintenant, on installe le VPN qui va relier votre téléphone à votre AdGuard et vos sites.

### ✅ La Solution
1. **Préparation**
Dans Portainer, créez une nouvelle stack nommée `vpn`.

2. **Le docker-compose.yml**
*Points Clés :*
*   **`TS_USERSPACE=true`** : Mode compatible Docker/LXC (évite les erreurs kernel).
*   **`TS_ACCEPT_DNS=false`** : Empêche le conteneur de s'utiliser lui-même comme DNS (évite la boucle infinie).
*   **`TS_ROUTES=10.10.10.0/24`** : Active le "Subnet Router". Cela permet aux appareils du VPN d'accéder à tout votre réseau Docker (10.10.10.x) directement.

*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/tailscale.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/tailscale.yaml)

3. **Vérification des Logs**
Vérifiez les logs du conteneur. Vous devez voir "Success" et "Log in at...". Si vous avez utilisé une AuthKey, il se connecte tout seul.

4. **Récupérer l'IP Tailscale**
```bash
docker exec tailscale tailscale ip -4
```
Prenez cette IP (ex: `100.123.191.40`) et allez la mettre dans la règle **DNS Rewrite d'AdGuard** (Phase 1, Étape 5). C'est vital.

---

## 🚦 PHASE 3 : LA CONNEXION INTERNE (ROUTAGE)

Maintenant, on configure la "Plomberie" pour que quand on tape sur l'IP Tailscale, ça arrive sur Traefik.

**1. Configuration "Tailscale Serve"**
Le conteneur Tailscale reçoit le trafic, mais il ne sait pas qu'il doit l'envoyer à Traefik. On va lui dire.

Connectez-vous dans le conteneur :
```bash
docker exec -it tailscale sh
```
Tapez ces commandes :
```bash
# Rediriger le port 80 (HTTP) vers le conteneur Traefik
tailscale serve --bg --tcp 80 tcp://traefik:80

# Rediriger le port 443 (HTTPS) vers le conteneur Traefik
tailscale serve --bg --tcp 443 tcp://traefik:443
```
Vérifiez avec : `tailscale serve status`.

---

## 🛰️ PHASE 4 : LA CONSOLE D'ADMINISTRATION TAILSCALE (WEB)

C'est ici qu'on configure le comportement global de vos appareils sur [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines).

**1. Validez le Subnet Router**
*   Trouvez votre machine `kpihx-labs`.
*   Cliquez sur les `...` > **Edit route settings**.
*   Cochez la case **`10.10.10.0/24`**.

**2. Configurez le DNS Global (Split DNS)**
*   Allez dans l'onglet **DNS**.
*   Dans "Global Nameservers", cliquez sur **Add nameserver** > **Custom**.
*   Entrez l'adresse IP interne d'AdGuard : **`10.10.10.10`**.
*   Cochez **"Restrict to domain"**.
*   Entrez le domaine : **`homelab`**.
*   Sauvegardez.

**3. Désactiver l'Override**
Assurez-vous que l'option **"Override local DNS"** est **DÉSACTIVÉE**.
*   *Résultat :* Si vous allez sur `google.com`, ça utilise la 4G/Wifi normalement. Si vous allez sur `sentinel.homelab`, ça utilise le DNS `10.10.10.10` via le VPN.

---

## 📱 PHASE 5 : CONFIGURATION DES CLIENTS

**1. Sur votre Téléphone (Android/iOS)**
*   Installez l'app Tailscale, connectez-vous et activez le VPN.
*   Ouvrez Chrome, tapez : `https://sentinel.homelab`. Ça marche !

**2. Sur votre PC Linux (Le cas particulier)**
Linux est strict. Connectez-vous en acceptant explicitement les routes et le DNS :
```bash
sudo tailscale up --accept-routes --accept-dns
```
**Vérification :** `ping sentinel.homelab`. Si ça répond, vous pouvez supprimer vos bidouilles dans `/etc/hosts` !

---

### 🔄 RÉSUMÉ DE LA MÉCANIQUE
1.  **Vous :** `https://sentinel.homelab`
2.  **Votre PC/Tel :** "C'est un domaine `.homelab`, je demande au DNS Tailscale".
3.  **Tailscale :** "Le DNS pour `.homelab` est à `10.10.10.10`".
4.  **Votre PC/Tel :** Envoie la requête DNS à `10.10.10.10` via le tunnel.
5.  **AdGuard (10.10.10.10) :** "Ah, `sentinel.homelab` ? C'est l'IP `100.x.y.z`".
6.  **Votre PC/Tel :** Envoie la requête HTTPS à `100.x.y.z`.
7.  **Conteneur Tailscale (`100.x.y.z`) :** Reçoit sur le port 443. Règle `serve` ➔ Envoie à `traefik:443`.
8.  **Traefik :** Reçoit, voit le Host `sentinel.homelab`, et sert le site.

C'est propre, logique, et ça marche partout.

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
