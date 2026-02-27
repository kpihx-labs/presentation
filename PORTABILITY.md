# 🚜 Portabilité : Adaptation à un Nouvel Environnement

**Vision :** Ce document est le guide de survie pour déplacer le Homelab. Que vous changiez de ville, de réseau Wi-Fi ou que vous passiez de l'X à une box internet standard, voici les étapes pour reconnecter votre "Boîte Noire" au monde.

---

### 🔍 1. Les Dépendances Implicites (Le Piège)
L'architecture actuelle est optimisée pour l'X. Plusieurs réglages sont "codés en dur" ou dépendent de l'infrastructure de l'école :
- **Authentification 802.1X :** Nécessite `wpa_supplicant`.
- **Serveurs DNS de l'X :** Utilisés comme Fallback et Upstream.
- **Proxy HTTP :** Nécessaire pour sortir de l'X sur certains ports.

---

### 🏗️ 2. Check-list d'Adaptation Réseau

#### A. Niveau Proxmox (L'Hôte)
Si vous quittez l'X pour une box standard (DHCP classique) :
1.  **Interface Réseau :** Modifiez `/etc/network/interfaces` pour retirer la configuration bridge complexe si nécessaire, ou passez simplement en DHCP sur `vmbr0`.
2.  **Désactivation 802.1X :** Stoppez le service `wpa_supplicant` qui n'a plus lieu d'être.
3.  **DNS Système :** Modifiez `/etc/resolv.conf` pour pointer vers votre nouvelle box (ex: `192.168.1.1`) ou des DNS publics (`1.1.1.1`).

#### B. Niveau Tailscale (Le Tunnel)
Tailscale est le composant le plus résilient, mais son DNS doit être mis à jour :
1.  **Global Nameservers :** Si l'IP de votre serveur change, assurez-vous que Tailscale pointe toujours vers l'IP correcte d'AdGuard.
2.  **Split DNS :** Si vous changez de domaine de recherche, ajustez-le dans la console Tailscale.

#### C. Niveau AdGuard Home (L'Annuaire)
C'est ici que bat le cœur de votre résolution DNS :
1.  **Upstream DNS :** Dans AdGuard > Paramètres DNS, **supprimez les IPs de l'X** (`129.104.x.x`) et remplacez-les par celles de votre nouveau fournisseur ou par des DNS neutres (Cloudflare/Quad9).
2.  **DNS Rewrites :** Si l'IP locale de votre serveur change, vous devez mettre à jour la règle `*.kpihx-labs.com` pour qu'elle pointe vers la nouvelle IP.

#### D. Niveau Traefik (Le Certificat)
Le DNS-01 challenge est agnostique du réseau, **MAIS** il a besoin d'internet pour parler à Cloudflare :
1.  **Resolvers ACME :** Dans le `docker-compose.yml` de Traefik, vérifiez que les resolvers fournis (`10.10.10.10`, `1.1.1.1`) sont toujours joignables.
2.  **Délai de propagation :** Vous pourrez probablement réduire le `delaybeforecheck` de 60s à 10s si le nouveau réseau est plus rapide.

---

### 🛠️ 3. Procédure de Migration Pas-à-Pas

1.  **Avant le départ :** Notez l'IP Tailscale de votre serveur (elle ne changera jamais).
2.  **Arrivée sur le nouveau réseau :**
    *   Branchez l'Ethernet.
    *   Si Proxmox ne prend pas d'IP, connectez-vous physiquement et forcez un `dhclient`.
3.  **Rétablir AdGuard :** C'est la priorité n°1 pour que Docker retrouve internet. Changez les Upstreams DNS vers `1.1.1.1`.
4.  **Vérifier Cloudflare :** Le conteneur `cloudflared` devrait se reconnecter automatiquement dès qu'internet est présent.
5.  **Test de Certification :** Si vos certificats expirent pendant le trajet, Traefik les renouvellera dès qu'AdGuard sera fonctionnel.

---

### 🧐 4. Résumé des Variables à Surveiller
| Composant | Variable à modifier | Emplacement |
| :--- | :--- | :--- |
| **OS (Host)** | Nameservers | `/etc/resolv.conf` |
| **Docker** | HTTP Proxy | `.env` ou `/etc/docker/daemon.json` |
| **AdGuard** | Upstream DNS | Interface Web (Port 3000) |
| **Tailscale** | DNS Servers | Console Tailscale Web |
| **Traefik** | ACME Resolvers | `docker-compose.yml` |


