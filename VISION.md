# 🔭 Vision : L'ADN de KpihX Labs

## 🌊 De l’île du local à la presqu’île du cloud : naissance du homelab

J’ai toujours été très à l’aise en local. J’ai testé presque tous les Windows, une bonne partie des distributions Linux, je me suis senti chez moi aussi bien en GUI qu’en ligne de commande. Je comprenais le système, je savais comment il respirait, comment il réagissait. Mais malgré cette aisance, je sentais qu’il me manquait quelque chose. Une partie entière du monde informatique m’échappait : le réseau, le cloud, le déploiement. Tout cela me semblait mystérieux, opaque, presque magique.

Le mieux que je faisais, c’était de déployer des frontends statiques sur GitHub Pages ou Vercel, mais sans jamais comprendre ce qui se passait derrière. Et surtout, je n’avais aucun contrôle : Vercel ne permettait pas de backends, GitHub Pages encore moins. Résultat : la plupart de mes projets restaient à l’état statique, jamais déployés en fullstack, jamais dockerisés, jamais réellement vivants. Pour faire un projet complet gratuitement, il fallait jongler entre trop de plateformes : Google Studio pour la base de données, Vercel pour le front, un autre service pour le back… et tout pouvait disparaître du jour au lendemain. Pire encore : tout était opaque. On cliquait sur des boutons, on obtenait un résultat, mais on ne comprenait rien de ce qui se passait en arrière‑plan.

J’ai fini par comprendre que je vivais sur une île, celle du local. Et que si je voulais devenir complet, il fallait que je quitte cette île, que je plonge dans l’océan du réseau, que je traverse ses courants, ses pièges, ses zones d’ombre. J’ai donc pris mon vieux PC, celui avec l’écran presque mort, et j’ai décidé d’en faire mon premier vrai serveur. Je l’ai branché derrière le réseau de l’X, j’ai bricolé des tunnels, j’ai commencé à toucher Docker, GitLab CI, la gestion d’IP, les noms de domaine… Je devais m’aventurer hors de mon confort, quitter mon île, traverser la mer, et atteindre — si tout se passait bien — la presqu’île qu’est le cloud.

C’est comme ça que tout a commencé.

---

## 🏗️ Premiers fondements : un homelab sur un terrain instable

Le serveur tournait sur Proxmox, mais il vivait sur eduroam, un réseau universitaire imprévisible. L’IP changeait sans prévenir, les restrictions réseau étaient nombreuses, et la moindre variation du DHCP pouvait casser l’accès. J’ai donc commencé par sécuriser l’accès SSH : port 2222 pour réduire le bruit des bots, authentification par clé uniquement, désactivation du login root, création de l’utilisateur ivann avec sudo, et ajout des clés publiques de mes appareils dans les authorized_keys.

Pour simplifier l’accès, j’ai construit un `.ssh/config` propre : un Host `homelab` pour atteindre Proxmox directement, et un Host `docker-host` qui passe automatiquement par Proxmox via `ProxyJump`. Sur PC, Avahi m’a permis d’utiliser `homelab.local` malgré les changements d’IP. Sur Android, impossible d’utiliser mDNS sans root, alors j’ai écrit un script Termux qui scanne les IP autour de l’ancienne, détecte la nouvelle grâce à la hostkey SSH, et met automatiquement à jour mon `.ssh/config`.

---

## 🔧 Stabiliser l’instable : création du watchdog réseau

Très vite, un autre problème est apparu : la connectivité réseau sautait au moindre mouvement du câble. Parfois seul le LXC tombait, parfois tout Proxmox. J’ai fini par automatiser toutes les manipulations que je faisais à la main : ifdown/ifup, relancer wpa_supplicant, renouveler le DHCP, redémarrer le service réseau…

C’est ainsi qu’est né mon network watchdog. Il teste régulièrement la connectivité, applique des réparations graduelles, logue tout dans `/var/...`, et m’envoie un message Telegram dès qu’il intervient. Depuis la version 3, je n’ai plus jamais eu à réparer la connectivité manuellement.

---

## 💾 Hygiène du système : sauvegardes, maintenance, Docker

Une fois la stabilité réseau assurée, j’ai mis en place une stratégie de sauvegarde sérieuse : la règle 3‑2‑1. Une copie locale sur Proxmox, une sur un SSD externe, et une sur Google Drive, tous les jours à 3h du matin.

Ensuite, j’ai créé un script de maintenance hebdomadaire, lancé le samedi à 4h, juste après les sauvegardes. Ce script nettoie intelligemment le système, évite les reboot naïfs (qui sur Linux peuvent empirer les choses), et garde le serveur fluide. Pour Docker, j’ai ajouté un conteneur dédié au nettoyage des images, volumes et caches, exécuté vers 5h.

---

## 📊 Sentinel : donner des yeux au serveur

Pour surveiller l’état du serveur, j’ai développé Sentinel, une sorte de task manager graphique maison. Il suit l’usage CPU, RAM, disque, charge, et m’envoie des alertes Telegram en cas de surcharge. Sentinel est devenu mon tableau de bord, intégré dans mon réseau Traefik.

---

## 🛠️ Industrialisation : GitLab CI/CD + GitHub

Avant même de m’attaquer à Tailscale ou Cloudflare, j’ai voulu industrialiser mes déploiements. Coder directement sur le serveur via VSCode SSH surchargeait inutilement la machine.

J’ai donc créé une organisation GitHub et un groupe GitLab, configuré des clés SSH distinctes, généré un token GitLab, et installé un GitLab Runner local sur Docker-host. J’ai défini des variables secrètes globales, structuré mes projets avec des templates Docker, docker-compose, gitignore, dockerignore, et parfois un Makefile. Chaque pipeline GitLab comporte au moins deux jobs : un pour déployer sur mon homelab, et un autre pour synchroniser automatiquement le dépôt vers GitHub.

---

## 🌐 Simplifier l’accès interne : Tailscale et le réseau privé overlay

Avant Tailscale, j’utilisais des tunnels SSH (LocalForward) pour accéder à Proxmox, Portainer, Traefik, Adminer… C’était fonctionnel mais lourd.

J’ai donc installé Tailscale dans Docker-host, dans le même réseau que Traefik. J’ai configuré un DNS local via AdGuard, avec une wildcard `*.homelab` pointant vers l’IP Tailscale du serveur. J’ai mis en place du split DNS dans Tailscale pour que tout ce qui concerne homelab passe par mon DNS interne. Pour éviter les boucles VPN, j’ai déclaré le sous-réseau 10.10.10.0/24 à Tailscale. Enfin, j’ai configuré Tailscale pour rediriger les ports 80 et 443 vers Traefik.

À partir de là, accéder à mes services internes devenait trivial : `sentinel.homelab`, `portainer.homelab`, `traefik.homelab`… sans port, sans tunnel, depuis n’importe quel réseau.

---

## ☁️ Exposition publique : Cloudflare Tunnel et domaine kpihx-labs.com

Pour exposer certains services au public, j’ai d’abord envisagé Tailscale Funnel, mais c’était trop lourd : un port par service, modifications du docker-compose, URLs non intuitives. J’ai donc opté pour Cloudflare. J’ai acheté le domaine `kpihx-labs.com`, déployé un conteneur Cloudflare Tunnel dans Docker-host, et configuré Zero Trust pour gérer les DNS publics.

Cloudflare gère les certificats publics, Traefik gère les certificats internes, et tout passe proprement par le tunnel. J’ai testé l’accès on-host (authentification par email), puis j’ai mis en place OAuth Google pour un service de test : `whoami.kpihx-labs.com`. Google me renvoie un token contenant l’email, Cloudflare vérifie l’autorisation, et Traefik route vers le conteneur whoami. Le même service existe en local (`whoami.homelab`) pour tester la cohérence interne/externe.

Ce test OAuth a été la validation finale : toute la chaîne — local, proxy, DNS interne, DNS public, tunnel, certificats, authentification — fonctionnait parfaitement.

---

## 🌱 Quand la technique ne suffisait plus : naissance de la dimension humaine

À mesure que mon homelab prenait forme, quelque chose d’autre a commencé à émerger en moi. Au départ, tout était guidé par la curiosité brute, le besoin presque vital de comprendre ce qui m’avait toujours échappé : le réseau, le cloud, le déploiement. Mais plus j’avançais, plus je réalisais que ce voyage n’était pas seulement un défi intellectuel. Il y avait une autre force, plus profonde, qui se réveillait.

Je ressentais le besoin de partager. Pas partager au sens “publier un tuto”, mais partager vivant, partager transparent, partager comme on raconte une aventure, avec les erreurs, les hésitations, les pivots, les moments de doute et les moments de victoire. Je voulais que quelqu’un d’autre puisse revivre ce chemin, pas seulement le résultat final. Je voulais que ce que j’apprenais ne reste pas enfermé dans ma tête ou dans mon serveur, mais devienne une matière transmissible, une histoire technique mais humaine.

C’est là que l’idée de kpihx‑labs a commencé à prendre forme.

## 📘 kpihx‑labs : une plateforme née d’un besoin de transmettre

La première vision qui s’est imposée, naturellement, cétait la **Vision 0 : une documentation vivante**, narrative, transparente, qui raconte le processus avant de montrer la solution. Une documentation qui ne cache rien, qui montre les problèmes avant les réponses, les pourquoi avant les comment. Une documentation qui donne envie de refaire le chemin, pas juste de copier-coller des commandes.

Puis, en prolongeant cette logique, la **Vision 1** s’est dessinée : si j’ai réussi à industrialiser mes déploiements, pourquoi ne pas offrir à d’autres un moyen simple, propre, transparent de déployer leurs propres services ? (Voir [Tuto 3 : Industrialisation, Sécurité et DevOps](tutos_live/3-industrialisation-devops.md)). Un PaaS artisanal mais robuste, où l’utilisateur n’a pas besoin de comprendre Docker, Traefik ou GitLab CI pour déployer quelque chose. Une plateforme où la complexité est assumée, mais encapsulée.

Et naturellement, la **Vision 2** a suivi : un Cloud OS, un espace de travail complet dans le cloud — drive, codespace, cloudspace — où quelqu’un peut coder, stocker, exécuter, expérimenter, sans dépendre de services opaques ou fragiles. (Voir [Tuto 2 : Mise sur pied du Docker-Host et Routage Intelligent](tutos_live/2-mise-en-place-docker-host.md) et [Tuto 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)](tutos_live/4-reseau-overlay-tailscale.md)). Un environnement cohérent, contrôlé, extensible, mais toujours transparent.

Ces trois visions formaient déjà un tout : transmettre, simplifier, outiller.

## 🤖 Le réveil de la simplification : l’IA comme prolongement naturel

Mais il y avait encore quelque chose qui bouillonnait en moi. Depuis toujours, j’ai cette obsession de simplifier sans sacrifier la robustesse, de rendre les choses accessibles sans les rendre opaques. Et plus j’avançais dans mon homelab, plus je sentais que cette obsession trouvait un écho dans un domaine particulier : l’intelligence artificielle.

L’IA, dans ma vision, n’est pas un gadget. C’est un moyen de rendre la complexité lisible, navigable, humaine.

C’est là que l’idée du copilot pour mon homelab est née. Un assistant proactif, fusionné avec mon infrastructure, capable de :
- comprendre l’architecture,
- lire les logs,
- détecter les anomalies,
- me prévenir sur Telegram,
- me proposer des actions,
- attendre mon feu vert,
- exécuter proprement,
- documenter ce qu’il fait.

Un assistant qui ne remplace pas l’humain, mais qui augmente l’humain. Un assistant qui me libère de la charge mentale des chemins de logs, des commandes, des vérifications. Un assistant qui me parle en langage naturel, comme un collègue.

Et naturellement, si ce copilot existe pour mon homelab, il doit aussi exister dans la vitrine kpihx‑labs, sous la forme d’un assistant transversal, capable d’aider l’utilisateur à naviguer, comprendre, agir, sans jamais cacher la logique.

C’est dans cette dynamique que la **Vision 3** de kpihx‑labs s’est imposée : un Lab IA, un espace où l’on peut manipuler des modèles, configurer des paramètres, créer des branches de conversation, utiliser une API, expérimenter comme dans Google AI Studio mais en auto‑hébergé, transparent, contrôlé. (Voir [Template Ollama](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ollama.yaml)).

## 🤝 Quand la technique rencontre l’humain : l’idée d’une équipe

À ce stade, quelque chose s’est éclairci. Je me suis rendu compte que ce projet n’était pas seulement un défi personnel. Il avait une dimension humaine beaucoup plus large.

Je me suis souvenu de ce que c’est que d’être passionné dans un monde qui ne comprend pas toujours cette passion. Je me suis souvenu de ce que c’est que de chercher quelqu’un qui partage la même intensité, la même curiosité, la même envie de comprendre. Et j’ai compris que kpihx‑labs ne pouvait pas rester un projet solitaire.

Il devait devenir un espace d’équipe, un lieu où d’autres passionnés pourraient rejoindre l’aventure, apporter leur vision, leur énergie, leur sensibilité. Un espace où la technique et l’humain avancent ensemble.

Et au-delà de l’équipe, il y a le reste du monde : ceux qui ne feront pas partie du projet, mais qui pourront en bénéficier, apprendre, s’inspirer, suivre le processus, lire les récits, regarder les vidéos, comprendre les choix.

## 🌐 La vision méta : trois forces qui guident tout

En prenant du recul, j’ai réalisé que tout ce projet — homelab, copilot, kpihx‑labs — repose sur trois forces fondamentales :

1.  **La vision méta “stimuli” : la curiosité.** C’est la force originelle, celle qui m’a poussé à quitter l’île du local pour plonger dans l’océan du réseau.
2.  **La vision méta “simplification/transparence” : l’IA.** L’IA comme moyen de rendre la complexité lisible, de guider, d’expliquer, de proposer.
3.  **La vision méta “humain/partage” : l’équipe et le monde.** La volonté de transmettre, de raconter, de partager, de créer un espace où d’autres peuvent vivre la même aventure.

## 🧭 Les visions pragmatiques qui en découlent

De ces trois visions méta naissent deux grands axes pragmatiques :

### A. Les visions techniques
- **Homelab + Copilot :** l’infrastructure vivante, auto‑réparatrice, augmentée par l’IA.
- **kpihx‑labs :**
    - **Vision 0 :** documentation vivante
    - **Vision 1 :** déploiement transparent
    - **Vision 2 :** Cloud OS
    - **Vision 3 :** Lab IA
    - l’assistant transversal

### B. Les visions humaines
- **L’équipe :** un groupe de passionnés qui rejoindront l’aventure une fois la Vision 1 stabilisée.
- **Le reste du monde :** partage vivant via LinkedIn, Medium, X, YouTube, vidéos, récits, tutoriels narratifs, ouverture progressive de la plateforme.

Tout cela se fera progressivement, naturellement, sans précipitation, mais avec une direction claire dès que l’équipe sera formée.

## 🎯 État actuel : un projet qui a trouvé son identité

Aujourd’hui, ce qui avait commencé comme un simple besoin de comprendre le réseau est devenu :
- un laboratoire d’ingénierie,
- une plateforme en construction,
- un futur copilot,
- une vision IA,
- un projet humain,
- une aventure collective en devenir.

Et tout cela repose sur une idée simple : rendre visible ce qui est caché, rendre simple ce qui est complexe, rendre humain ce qui est technique.

---
## 🗺️ Navigation
- [🏠 Accueil](README.md)
- [🔭 Vision](VISION.md)
- [🏗️ État de l'Art](STATE_OF_THE_ART.md)
- [🕒 Évolution](EVOLUTION.md)
- [🚀 Live Tutorials](tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](AGENT.md)
