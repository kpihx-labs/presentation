
**Objectif :** Rendre accessible `sentinel.kpihx-labs.com` \(et d'autres\) depuis n'importe quel navigateur dans le monde, sans ouvrir de port sur le pare\-feu de l'école, et en sécurisant l'accès via ton compte Google\.

**IMPORTANT**: Il faudra avoir acheté le nom de domaine chez cloudflare \(kpihx\-labs dans notre cas\)

***

## PHASE 1 : L'INFRASTRUCTURE \(LE TUNNEL\)

Le "Tunnel" est un câble virtuel qui relie ton serveur à Cloudflare\. Il traverse le pare\-feu de l'X comme si de rien n'était\.

### 1\. Création du Tunnel \(Interface Cloudflare\)
1.  Va sur [one\.dash\.cloudflare\.com](https://one.dash.cloudflare.com/)\.
2.  Menu de gauche : **Networks** > **Tunnels**\.
3.  Clique sur **Create a Tunnel**\.
4.  Choisis **Cloudflared**\.
5.  Nomme\-le : `kpihx-labs`\.
6.  **Sauvegarde le Token** \(C'est la longue chaîne de caractères qui commence par `ey...` après `tunnel run --token`\)\. **Ne lance pas la commande**, on va utiliser Docker\.

### 2\. Déploiement du Conteneur \(`docker-compose.yml`\)
On crée une stack dédiée dans Portainer nommée **`ingress`**\.

⚠️ **Points Critiques :**
*   **Proxy :** Indispensable pour que le tunnel sorte vers Cloudflare\.
*   **NO\_PROXY :** Indispensable pour que le tunnel puisse parler à Traefik en local\.

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    
    # Commande de lancement
    command: tunnel run
    
    environment:
      - TUNNEL_TOKEN=TON_TOKEN_COPIÉ_ICI
      
      # --- GESTION RÉSEAU (Vital X) ---
      - http_proxy=http://129.104.201.11:8080
      - https_proxy=http://129.104.201.11:8080
      
      # IMPORTANT : On dit au tunnel "Ne passe pas par le proxy pour parler à Traefik"
      - NO_PROXY=localhost,127.0.0.1,10.10.10.10,traefik

    # Il doit être sur le même réseau que Traefik
    networks:
      - proxy

networks:
  proxy:
    external: true

```
*Déploie la stack\. Si le statut passe à "Healthy" sur le site Cloudflare, la route est ouverte\.*

***

## PHASE 2 : L'IDENTITÉ \(GOOGLE OAUTH\)

On veut que tu puisses te connecter avec ton compte Google\. C'est l'étape la plus "bureaucratique" entre Google et Cloudflare\.

### 1\. Préparer Cloudflare
1.  Dans **Zero Trust**, va dans **Integrations/Identity providers**\.
2.  Dans la carte "Login methods", clique sur **Add new**\.
3.  Choisis **Google**\.
4.  Suis la procédure donnée par Cloudflare

*Test : Clique sur le bouton "Test" à côté de la ligne Google dans Cloudflare\. Si ça te dit "Success", c'est bon\.*

***

## PHASE 3 : LA SÉCURITÉ \(POLICIES\)

On définit qui a le droit d'entrer\.

1.  Dans **Zero Trust**, va dans **Access** > **Applications**\.
2.  Clique sur **Add an application** > **Self\-hosted**\.
3.  **Application Configuration :**
    *   **Application name :** `Sentinel`
    *   **Session Duration :** `1 Month` \(Pour ne pas se reconnecter tous les jours\)\.
    *   **Subdomain :** `sentinel`
    *   **Domain :** `kpihx-labs.com` \(Ton domaine acheté\)\.
4.  Clique sur **Next**\.
5.  **Policy Configuration :**
    *   **Policy Name :** `Admin Access`\.
    *   **Action :** `Allow`\.
    *   **Configure rules :**
        *   Selector : **Email**\.
        *   Value : `ton.email@gmail.com` \(L'email de ton compte Google\)\.
6.  Clique sur **Next** > **Add application**\.

***

## PHASE 4 : LE ROUTAGE \(PUBLIC HOSTNAMES\)

Maintenant, on dit au Tunnel où envoyer le trafic\.

1.  Va dans **Networks** > **Tunnels**\.
2.  Clique sur ton tunnel \(`homelab-prod`\) > **Configure**\.
3.  Onglet **Public Hostname** > **Add a public hostname**\.

**Configuration :**
*   **Subdomain :** `sentinel`
*   **Domain :** `kpihx-labs.com`
*   **Service :**
    *   Type : **`HTTPS`** \(Car ton Traefik force le HTTPS en interne\)\.
    *   URL : **`traefik:443`**

**⚠️ Le Détail Vital \(TLS Verify\) :**
Traefik utilise un certificat "maison" \(non reconnu mondialement\)\. Cloudflare va le rejeter par défaut\. Il faut désactiver cette vérification\.
1.  Clique sur **Additional application settings**\.
2.  Clique sur **TLS**\.
3.  Active **No TLS Verify**\.
4.  Clique sur **Save hostname**\.

***

## PHASE 5 : AJUSTEMENT FINAL \(DOCKER\)

Il faut dire à Traefik \(sur ton serveur\) d'accepter ce nouveau nom de domaine public\.

1.  Va dans Portainer > Stack **`sentinel`**\.
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
      # MAIS Traefik ne sait pas distinguer la source facilement dans la même règle.
      # Solution simple : On garde le mot de passe partout (Double Sécu)
      # Solution confort : On enlève le mot de passe Traefik (On fait confiance au VPN et à Cloudflare)
      
      # Je te conseille d'enlever le middleware 'my-auth' si tu utilises Cloudflare Access + VPN.
      # - "traefik.http.routers.sentinel.middlewares=my-auth" 

```
3.  **Update the stack**\.

***

## TEST FINAL

1.  Désactive le Wifi de ton téléphone \(4G\)\.
2.  Désactive Tailscale \(pour être sûr d'être "Public"\)\.
3.  Va sur **`https://sentinel.kpihx-labs.com`**\.
4.  **Écran Cloudflare :** Clique sur "Sign in with Google"\.
5.  Connecte\-toi\.
6.  **Succès :** Tu vois ton Dashboard Sentinel\.

Tu as maintenant une exposition publique de niveau entreprise, protégée par Google, sans aucun port ouvert chez toi\.