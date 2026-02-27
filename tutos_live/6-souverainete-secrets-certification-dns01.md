# 🚀 Tuto Live 6 : Souveraineté des Secrets et Certification DNS-01 (Vaultwarden)

**Contexte :** Vous voulez arrêter de confier vos mots de passe à des tiers (Google, Apple, LastPass) et gérer vous-même votre coffre-fort via **Vaultwarden** (une version légère et performante de Bitwarden). 

**Le Mur Technique :** 
1.  **Exigence SSL :** L'application mobile Bitwarden refuse de se connecter à un serveur dont le certificat n'est pas reconnu par une autorité officielle (Let's Encrypt Production).
2.  **Dilemme de l'Exposition :** On veut un certificat officiel pour `vault.kpihx-labs.com`, mais on ne veut **PAS** que ce domaine soit public ou déclaré chez Cloudflare. On veut qu'il reste accessible uniquement via **Tailscale**.
3.  **Le Blocage Réseau :** L'école (l'X) bloque les challenges ACME classiques (HTTP-01) sur le port 80.

---

## 🛑 PHASE 0 : LA STRATÉGIE "DNS-01 CHALLENGE"

Pour obtenir un certificat sans ouvrir de port et sans exposer le service, on utilise le **DNS-01 Challenge**. 
*   Traefik demande à Let's Encrypt : *"Je veux un certificat pour *.kpihx-labs.com"*.
*   Let's Encrypt répond : *"Prouve-le en ajoutant un code secret dans tes DNS chez Cloudflare"*.
*   Traefik utilise l'**API Cloudflare** pour poser le code, Let's Encrypt vérifie, puis Traefik retire le code.
*   **Résultat :** Vous avez un certificat Wildcard officiel, et personne n'a vu votre serveur sur internet.

---

## 🏗️ PHASE 1 : PRÉPARATION CLOUDFLARE (API TOKEN)

Avant de toucher à Docker, Traefik a besoin des "clés de la maison" DNS.
1.  Allez sur votre tableau de bord Cloudflare.
2.  **Profil Utilisateur** > **Jetons d'API** (API Tokens).
3.  **Créer un jeton** > Modèle **"Modifier la zone DNS"**.
4.  **Autorisations :** `Zone - DNS - Modifier`.
5.  **Ressources de zone :** `Inclure - Toutes les zones` (ou votre domaine précis).
6.  **Copiez le jeton :** C'est votre variable `CF_DNS_API_TOKEN`.

---

## 🚦 PHASE 2 : ÉVOLUTION DE TRAEFIK (TEMPLATE V2)

Nous devons transformer Traefik d'un simple proxy en un **Automate de Certification**.

**✅ L'ajustement du Template :**
Nous utilisons maintenant le **Template :** [traefik.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/traefik.2.yaml).

**Les points clés ajoutés :**
*   **Variable d'env :** `- CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}`.
*   **Le Résolveur `myresolver` :** On définit Let's Encrypt Production, le stockage dans `acme.json`, et le fournisseur `cloudflare`.
*   **Le Délai de Propagation (`delaybeforecheck=60`) :** Crucial à l'X pour laisser le temps au DNS de se propager malgré les filtres réseau.
*   **Le Router Wildcard :** Un router spécifique qui génère le certificat `*.kpihx-labs.com` une fois pour toutes.

---

## 🔐 PHASE 3 : DÉPLOIEMENT DE VAULTWARDEN

Une fois Traefik prêt, on déploie le coffre-fort.

**✅ Le Template :** [vaultwarden.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/vaultwarden.2.yaml).

**La nuance des labels :**
*   On ne demande plus de certificat spécifique. On dit juste : `traefik.http.routers.vault.tls.certresolver=myresolver`.
*   Traefik verra que le domaine `vault.kpihx-labs.com` est couvert par le certificat Wildcard qu'il possède déjà.

---

## 🛰️ PHASE 4 : LE ROUTAGE SOUVERAIN (TAILSCALE & ADGUARD)

C'est ici qu'on réalise le tour de magie pour que `vault.kpihx-labs.com` ne sorte jamais sur le web.

### 1. Split DNS dans Tailscale (Console Web)
C'est l'étape la plus importante.
*   Allez dans **DNS** > **Nameservers**.
*   **Global Nameservers :** Ajoutez l'IP de votre AdGuard (`10.10.10.10`).
*   **Split DNS :** Ajoutez `kpihx-labs.com` dans la liste des domaines restreints.
*   *Pourquoi ?* Cela force votre téléphone à demander à VOTRE AdGuard pour tout ce qui finit par `.kpihx-labs.com`, même si le domaine n'existe pas publiquement.

### 2. DNS Rewrite dans AdGuard
*   Dans AdGuard Home > **Filtres** > **Réécritures DNS**.
*   Ajoutez une règle : `*.kpihx-labs.com` ➔ **IP Tailscale de votre serveur** (ou `10.10.10.10`).

---

## 🛠️ PHASE 5 : DÉBOGAGE ET VÉRIFICATION (POST-MORTEM)

### Comment savoir si c'est bon ?
Regardez les logs de Traefik juste après le démarrage :
```bash
docker logs -f traefik
```
Vous devez voir : `acme: Validations succeeded; requesting certificates`.

### Le mode "Terre Brûlée" (Reset ACME)
Si vous avez fait des tests en mode Staging, Traefik refusera de passer en Production car il "colle" à ses anciens certificats.
**Procédure de purge :**
1.  `docker stop traefik`
2.  `echo "{}" > /data/compose/1/letsencrypt/acme.json`
3.  `docker start traefik`

### Le test de sécurité (Cœur du Lab)
En mode production, Let's Encrypt est très strict. **Utilisez toujours le mode Test d'abord** en décommentant cette ligne dans le template `traefik.2.yaml` :
`- "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"`

---

---

## 🏆 LA MASTERCLASS : GÉNÉRALISATION DU "TRUSTED" (HTTPS PARTOUT)

Suite au succès de Vaultwarden, nous avons réalisé une **Masterclass d'architecture** : au lieu de subir des alertes "Unsecured" sur chaque service local (`.homelab`), nous avons profité du certificat Wildcard pour fournir un **accès souverain certifié** à l'ensemble du Homelab privé.

### 🚀 Services mis à jour en "Double Accès" :
Pour chaque service, nous avons ajouté un second router Traefik lié au domaine `.kpihx-labs.com` et au résolveur `myresolver`.

1.  **PolyTask Pro (`task.kpihx-labs.com`) :** Gestionnaire de tâches désormais certifié. (Voir [polytask.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/polytask.2.yaml)).
2.  **Base de Données Adminer (`db.kpihx-labs.com`) :** Interface de gestion SQL sécurisée. (Voir [adminer.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adminer.2.yaml)).
3.  **DNS AdGuard (`dns.kpihx-labs.com`) :** L'interface d'administration DNS est enfin passée au vert. (Voir [adguard.2.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/adguard.2.yaml)).

### 🔍 Cas Particuliers (Pourquoi ne pas tout changer ?)
*   **Sentinel :** Inutile en privé certifié car il est déjà exposé proprement au public via Cloudflare Tunnel avec OAuth.
*   **Ollama (imhotep-brain) :** C'est une API sans interface web native ; l'accès direct via IP/VPN est suffisant et plus performant.
*   **Whoami :** Conservé en mode "test initial" pour valider la plomberie brute du réseau sans surcharge de certificats.

**Conclusion :** Votre infrastructure n'est plus une collection de services isolés, mais un véritable **PaaS Souverain** où la sécurité est transparente et universelle. 🛡️✨⚓


