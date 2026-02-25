# 🛡️ Sécurité 2 : Mises à jour Automatiques avec Watchtower

**Contexte :** Dans un monde de cyberattaques constantes, un logiciel qui n'est pas à jour est une faille ouverte. Mais vous n'avez pas le temps de faire des `docker pull` manuels tous les jours.

**Objectif :** Garder vos conteneurs à jour automatiquement sans casser vos services critiques (comme les bases de données).

---

## 💂‍♂️ PHASE 1 : LE GARDIEN DE NUIT (WATCHTOWER)

Watchtower est un conteneur qui scanne vos images Docker. S'il en trouve une plus récente sur le Hub, il télécharge l'image, redémarre votre service avec exactement la même config, et fait le ménage.

**✅ La Solution :**
1. **Déploiement :** Utilisez le template `https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/watchtower.yaml`.
2. **Réglage :** On le programme à 5h du matin, juste après la maintenance système.

---

## ⚠️ PHASE 2 : GESTION DES EXCLUSIONS

**🤔 Pourquoi faire cela ?**
Une mise à jour automatique de PostgreSQL (v16 ➔ v17) peut rendre votre base de données illisible si elle n'est pas migrée manuellement. On veut mettre à jour les apps (Whoami, Sentinel) mais **pas** les socles de données.

**✅ La Solution :**
Ajoutez ce label dans le `docker-compose.yml` de vos services sensibles :
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

**Verdict :** Votre infrastructure est toujours fraîche et sécurisée, sans effort manuel. 🛡️✨
