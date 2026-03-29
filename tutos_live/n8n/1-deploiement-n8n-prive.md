# 🚀 Tuto Live n8n 1 : Déploiement du Cerveau n8n Privé sur le Homelab

**Contexte :** Nous voulons faire de `n8n` le cerveau orchestral du Personal OS, mais sans transformer le lab en cockpit public. L'objectif est d'avoir un `n8n` stable, persistant, certifié, et accessible seulement par les chemins privés de confiance.

**Le Mur Technique :**
1.  Il existe déjà un PostgreSQL de production sur le serveur. On ne veut pas déployer une base supplémentaire juste pour `n8n`.
2.  On veut un double accès cohérent avec la philosophie du lab :
    *   **principal privé certifié** : `n8n.kpihx-labs.com`
    *   **fallback privé** : `n8n.homelab`
3.  Il faut garder l'éditeur `n8n` privé tout en préparant plus tard des webhooks publics séparés.

---

## 🏗️ PHASE 1 : LE CHOIX D'ARCHITECTURE

On ne déploie pas `n8n` comme un mini-service isolé. On le déploie comme un **cerveau privé**.

```text
n8n.kpihx-labs.com
-> route privée principale

n8n.homelab
-> route de secours

```

**Pourquoi ?**
*   `n8n` contient les workflows, les credentials, les logs, l'éditeur. C'est la salle des machines.
*   Les services externes (Telegram, WhatsApp, demain Gmail ou LinkedIn) ont seulement besoin de routes webhook précises.
*   On sépare donc très tôt :
    *   **le cockpit privé**
    *   **les points d'entrée publics**

---

## 🧱 PHASE 2 : RÉUTILISER LE POSTGRES EXISTANT

Le bon choix n'était pas un deuxième PostgreSQL. Le bon choix était :

```text
Postgres existant
    |
    +-- base dédiée n8n
    +-- user dédié n8n
```

**Pourquoi ?**
*   moins de conteneurs,
*   moins de maintenance,
*   moins de sauvegardes éclatées,
*   cohérent avec la prod déjà en place.

**La règle absolue :**
Ne jamais partager le schéma ou l'utilisateur SQL avec une autre application.

---

## 🔐 PHASE 3 : LA VARIABLE CRITIQUE `N8N_ENCRYPTION_KEY`

`n8n` chiffre une partie de ses secrets avec une clé propre. Il fallait donc poser un vrai `.env`.

**Template à utiliser :**
[n8n.env.example](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/n8n.env.example)

**Point critique :**
`N8N_ENCRYPTION_KEY` doit être générée une fois, sauvegardée proprement, et **ne doit jamais changer** sans plan de migration.

---

## 🐳 PHASE 4 : LE COMPOSE DE PRODUCTION

Le stack `n8n` doit être très petit :
*   un service `n8n`
*   aucun PostgreSQL embarqué
*   labels Traefik pour :
    *   `n8n.kpihx-labs.com`
    *   `n8n.homelab`

**Template à utiliser :**
[n8n.docker-compose.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/n8n.docker-compose.yaml)

**Idée générale :**

```text
Traefik
  |
  +--> n8n.kpihx-labs.com  (private trusted)
  |
  +--> n8n.homelab         (private fallback)
```

---

## 🌐 PHASE 5 : LE RÔLE DE `WEBHOOK_URL`

Le détail le plus important est celui-ci :

*   L'éditeur `n8n` reste privé.
*   Mais les webhooks doivent plus tard être annoncés au monde extérieur sous une autre URL.

Donc on configure :

```text
N8N_HOST=n8n.kpihx-labs.com
WEBHOOK_URL=https://n8n.kpihx-labs.com/
```

**Pourquoi cette dissociation est magnifique ?**
Parce qu'elle permet :
*   un cockpit privé,
*   des webhooks publics,
*   une seule instance `n8n`,
*   aucune confusion pour les services externes.

---

## 🧪 PHASE 6 : VALIDATION DE LA MISE EN LIGNE

Les validations minimales après déploiement sont :

1.  ouvrir `https://n8n.kpihx-labs.com`
2.  vérifier que `https://n8n.homelab` répond aussi
3.  confirmer que l'owner setup s'affiche
4.  générer une API key
5.  vérifier que l'API `https://n8n.kpihx-labs.com/api/v1` répond

**Verdict :** Une fois cette phase réussie, le lab possède enfin un **cerveau d'orchestration privé**, prêt à recevoir une arête webhook publique indépendante. 🧠🛡️
