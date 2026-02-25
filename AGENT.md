# 🤖 Agent Mandate : 100% Transparence et Exhaustivité

## 🎯 Rôle du Dossier `presentation/`
Ce dossier est la mémoire atomique et pédagogique de KpihX Labs. Il ne doit subir **aucune compression, aucune synthèse, ni aucun oubli**. Chaque détail technique (hacks, scripts, choix de ports) et chaque nuance narrative (vision, émotions, dimension humaine) sont essentiels.
Ce dossier est la "Boîte Noire" et le Manuel d'Instruction de KpihX Labs.

### 🏛️ Hiérarchie de Consultation
1.  **[VISION.md](https://kpihx-labs.github.io/presentation/#/VISION.md) :** L'âme du projet et la stratégie long terme. À lire pour comprendre le "Pourquoi" profond, de façon narrative et intuitive (le passage de l'île du local à la presqu'île du cloud, la place de l'IA, l'équipe).
2.  **[STATE_OF_THE_ART.md](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md) :** La carte technique actuelle. À lire pour comprendre "Comment" tout est relié (l'infrastructure, les contraintes, les choix techniques comme le Split DNS, le réseau overlay).
3.  **[EVOLUTION.md](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md) :** Le journal de bord. À lire pour la chronologie et l'historique des changements, de façon rigoureuse et ordonnée.
4.  **[tutos_live/](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md) :** Le manuel d'instruction. À lire pour reproduire, dépanner ou faire évoluer techniquement un service.
    - `security/` : Dossier dédié à la forteresse numérique (sauvegardes, mises à jour, timeout).
    - `annexes/` : Scripts de survie et outils mobiles (Watchdog, Termux).
    - `templates/` : Fichiers de configuration bruts, externalisés des tutoriels. Ils doivent toujours être des environnements ouverts, bien commentés en anglais sur toutes les options possibles (commentables, décommentables) et les prérequis. Les exemples utilisent `homelab`, `kpihx-labs`, `kpihx`, `ivann`.

## ✍️ Style des "Tutos Live" (Règles Sacrées)
Chaque fichier dans `tutos_live/` doit respecter ce format unifié :
1.  **Contexte & Problème First :** On commence par décrire le mur technique auquel on a fait face. Jamais de listing de commandes à froid.
2.  **Narratif Intuitif :** Le lecteur doit comprendre *pourquoi* on choisit telle option de commande plutôt qu'une autre.
3.  **100% Exhaustivité :** On doit pouvoir réinitialiser tout le lab à partir de zéro sans connaissance préalable. Aucune étape n'est "trop évidente".
4.  **Hacks Documentés :** Les solutions "sales" mais vitales (ex: SECLEVEL=0) doivent être mises en avant car elles sont la clé de la réussite. Documentez-les avec leur "Pourquoi".
5.  **Débogage Intégré :** Chaque tuto doit inclure une section "Cas de débogage" pour anticiper les erreurs classiques.
6.  **Liens vers Templates :** Les fichiers de configuration volumineux ou scripts doivent être externalisés dans `templates/` et simplement référencés dans le fichier MD.

## ⚙️ Règles de Mise à Jour (CRITIQUE)
- **Lecture Systématique :** Toujours lire ce `AGENT.md` avant toute action dans `presentation/`.
- **Append & Merge (Zéro Compression) :** Les mises à jour fusionnent les nouvelles données avec les anciennes. On ne supprime rien, on ajoute les nouvelles étapes. La transparence est la priorité sur la brièveté. L'édition doit se faire progressivement.
- **Zéro Suppression :** Sauf demande explicite de l'utilisateur, aucune donnée ne doit disparaître. Jamais de compression, jamais de synthèse. On augmente toujours l'information.
- **Vérification Réelle :** L'agent a carte blanche pour scanner le serveur (via `ssh kpihx-labs`) ou le conteneur (via `ssh docker-host`) pour confirmer les noms de conteneurs, voir les logs, inspecter les états Docker (images, volumes), et vérifier que les tutos correspondent parfaitement à la réalité. C'est le moyen ultime de lever toute zone d'ombre.
- **Synchronisation Globale :** Tout changement validé dans l'infrastructure doit être répercuté dans le `CHANGELOG` (`EVOLUTION.md`), puis dans `STATE_OF_THE_ART.md`, et enfin dans le tutoriel correspondant. Inversement, toute modification d'un tutoriel dans `tutos_live/` DOIT entraîner une mise à jour des sections correspondantes dans `STATE_OF_THE_ART.md`, `EVOLUTION.md` et potentiellement `VISION.md` pour garantir une cohérence arborescente totale.
- **Web Showcase (Docsify) :** Ce dossier est configuré pour être servi via Docsify. Chaque nouveau fichier `.md` créé, renommé ou déplacé DOIT être immédiatement répercuté dans la barre latérale `_sidebar.md` pour apparaître sur le site web public. De plus, tout nouveau tutoriel ou annexe doit être ajouté avec son titre complet dans l'index [tutos_live/README.md](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md).
- **Navigation Unifiée :** Chaque fichier Markdown créé ou modifié DOIT comporter le bloc de navigation standard à la fin pour permettre un retour fluide vers les piliers de la documentation.
- **Transparence des Liens :** Dans les fichiers de synthèse (`VISION`, `STATE_OF_THE_ART`, `EVOLUTION`), les liens vers les tutoriels ne doivent jamais être génériques (ex: "Tuto 1"). Ils doivent impérativement utiliser le titre complet et riche du fichier cible pour une clarté maximale.
- **CI/CD Deployment :** Le push vers GitLab déclenche un pipeline qui synchronise la branche `gh-pages` de GitHub. Les scripts de production sont liés directement au dépôt `scripts` de l'organisation GitHub pour éviter les duplications.
- **Évolution Continue :** Si un nouveau service est déployé, il doit faire l'objet d'un nouveau fichier dans `tutos_live/` suivant ce même standard, et ses configurations doivent enrichir `templates/`.
- **Reproductibilité & Scripts de Validation :** Pour toute tâche impliquant une commande complexe (ex: vérifier les références des templates) ou une série de commandes Bash/Python (plus de 5 lignes), **ne pas exécuter de boucles dans le terminal**. Il faut :
    1. Créer le dossier `scripts/` s'il n'existe pas.
    2. Y placer un script dédié (`.sh` ou `.py`).
    3. **Full Verbose :** Tous les scripts créés doivent être **full verbose** par défaut. Ils doivent imprimer chaque étape franchie, les fichiers scannés, et le détail des succès/échecs pour une transparence totale.
    4. Exécuter ce script.
    5. Ces scripts font office de tests. **Avant chaque commit majeur, il faut impérativement relancer ces scripts de validation** pour s'assurer que l'intégrité de la documentation n'est pas compromise (liens brisés, templates non référencés, tutos orphelins).
---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)