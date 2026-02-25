# 🚀 Tuto Live 5 : Exposition Publique et Zero Trust (Cloudflare)

**Contexte :** Vos services tournent en privé via Tailscale. Mais parfois, vous voulez qu'un service soit accessible publiquement (ex: portfolio, bot), ou par des amis, sans les forcer à installer un VPN. On veut exposer `sentinel.kpihx-labs.com` sur le web mondial, en toute sécurité.

**Objectifs :**
1. Créer un tunnel sécurisé (**Cloudflare Tunnel**) qui traverse le firewall de l'école.
2. Forcer l'authentification (**Google OAuth**) avant d'accéder au serveur.
3. Configurer le routage public sans ouvrir de port sur votre box ou à l'école.

**IMPORTANT :** Il faudra avoir acheté le nom de domaine chez Cloudflare (`kpihx-labs.com` dans notre cas).

---

## ☁️ PHASE 1 : L'INFRASTRUCTURE (LE TUNNEL)

Le "Tunnel" est un câble virtuel qui relie votre serveur à Cloudflare. Il traverse le pare-feu de l'X comme si de rien n'était.

### 1. Création du Tunnel (Interface Cloudflare)
1.  Va sur [one.dash.cloudflare.com](https://one.dash.cloudflare.com/).
2.  Menu de gauche : **Networks** > **Tunnels**.
3.  Clique sur **Create a Tunnel**.
4.  Choisis **Cloudflared**.
5.  Nomme-le : `kpihx-labs`.
6.  **Sauvegarde le Token** (C'est la longue chaîne de caractères qui commence par `ey...` après `tunnel run --token`). **Ne lance pas la commande**, on va utiliser Docker.

### 2. Déploiement du Conteneur
On crée une stack dédiée dans Portainer nommée **`ingress`**.

⚠️ **Points Critiques :**
*   **Proxy :** Indispensable pour que le tunnel sorte vers Cloudflare.
*   **NO_PROXY :** Indispensable pour que le tunnel puisse parler à Traefik en local.

*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/cloudflared.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/cloudflared.yaml)

*Déploie la stack. Si le statut passe à "Healthy" sur le site Cloudflare, la route est ouverte.*

---

## 🔑 PHASE 2 : L'IDENTITÉ (GOOGLE OAUTH)

On veut que tu puisses te connecter avec ton compte Google. C'est l'étape la plus "bureaucratique" entre Google et Cloudflare.

### 1. Préparer Cloudflare
1.  Dans **Zero Trust**, va dans **Integrations/Identity providers**.
2.  Dans la carte "Login methods", clique sur **Add new**.
3.  Choisis **Google**.
4.  Suis la procédure donnée par Cloudflare (création d'un projet Google Cloud et d'un ID Client OAuth).

*Test : Cliquez sur le bouton "Test" à côté de la ligne Google dans Cloudflare. Si ça vous dit "Success", c'est bon.*

---

## 🛡️ PHASE 3 : LA SÉCURITÉ (POLICIES)

On définit qui a le droit d'entrer.

1.  Dans **Zero Trust**, va dans **Access** > **Applications**.
2.  Clique sur **Add an application** > **Self-hosted**.
3.  **Application Configuration :**
    *   **Application name :** `Sentinel`
    *   **Session Duration :** `1 Month` (Pour ne pas se reconnecter tous les jours).
    *   **Subdomain :** `sentinel`
    *   **Domain :** `kpihx-labs.com`.
4.  Clique sur **Next**.
5.  **Policy Configuration :**
    *   **Policy Name :** `Admin Access`.
    *   **Action :** `Allow`.
    *   Configure rules :
        *   Selector : **Email**.
        *   Value : `ton.email@gmail.com`.
6.  Clique sur **Next** > **Add application**.

---

## 🚦 PHASE 4 : LE ROUTEUR PUBLIC (PUBLIC HOSTNAMES)

Maintenant, on dit au Tunnel où envoyer le trafic.

1.  Va dans **Networks** > **Tunnels**.
2.  Clique sur ton tunnel > **Configure**.
3.  Onglet **Public Hostname** > **Add a public hostname**.

**Configuration :**
*   **Subdomain :** `sentinel`
*   **Domain :** `kpihx-labs.com`
*   **Service :**
    *   Type : **`HTTPS`** (Car ton Traefik force le HTTPS en interne).
    *   URL : **`traefik:443`**

**⚠️ Le Détail Vital (TLS Verify) :**
Traefik utilise un certificat "maison" (auto-signé). Cloudflare va le rejeter par défaut. Il faut désactiver cette vérification.
1.  Clique sur **Additional application settings**.
2.  Clique sur **TLS**.
3.  Active **No TLS Verify**.
4.  Clique sur **Save hostname**.

---

## 🏗️ PHASE 5 : AJUSTEMENT FINAL (DOCKER)

Il faut dire à Traefik (sur ton serveur) d'accepter ce nouveau nom de domaine public.

1.  Va dans Portainer > Stack **`sentinel`**.
2.  Modifie les Labels :

```yaml
    labels:
      - "traefik.enable=true"
      
      # --- ROUTAGE HYBRIDE ---
      # On accepte soit le nom local (homelab), soit le nom public (kpihx-labs.com)
      - "traefik.http.routers.sentinel.rule=Host(`sentinel.homelab`) || Host(`sentinel.kpihx-labs.com`)"
      
      - "traefik.http.routers.sentinel.entrypoints=websecure"
      - "traefik.http.routers.sentinel.tls=true"
      
      # --- SÉCURITÉ OPTIMISÉE ---
      # Pour l'interne (.homelab), on garde le mot de passe Traefik (car pas de Cloudflare Access)
      # Pour l'externe (.com), Cloudflare Access protège déjà.
      # Solution simple : On garde le mot de passe partout (Double Sécu)
      # Solution confort : On enlève le mot de passe Traefik (On fait confiance au VPN et à Cloudflare)
      
      # Je te conseille d'enlever le middleware 'auth' si tu utilises Cloudflare Access + VPN.
      # - "traefik.http.routers.sentinel.middlewares=auth" 
```
3.  **Update the stack**.

---

## 🧪 TEST FINAL

1.  Désactivez le Wifi de votre téléphone (4G).
2.  Désactivez Tailscale (pour être sûr d'être "Public").
3.  Allez sur **`https://sentinel.kpihx-labs.com`**.
4.  **Écran Cloudflare :** Cliquez sur "Sign in with Google".
5.  Connectez-vous.
6.  **Succès :** Vous voyez votre Dashboard Sentinel.

Tu as maintenant une exposition publique de niveau entreprise, protégée par Google, sans aucun port ouvert chez toi. 🛡️✨⚓

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
