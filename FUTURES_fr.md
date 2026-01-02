# EmComm-Tools OS - Édition Debian

## Vision et Philosophie

Ce document décrit l'orientation future d'EmComm-Tools OS Édition Debian, un fork du projet original EmComm-Tools OS Community par Gaston Gonzalez (KT7RUN / TheTechPrepper).

**Mainteneur :** Sylvain Deguire (VA2OPS)

### L'Esprit Radioamateur

La radio amateur a toujours été une affaire de communauté, de partage des connaissances, et d'entraide. La plupart d'entre nous font partie d'un club ou d'une communauté où nous partageons nos expériences, apprenons les uns des autres, et construisons ensemble.

Ce projet est né de cet esprit.

L'objectif de cette édition « Vanilla » EmComm-Tools Debian est de créer une **fondation réutilisable et personnalisable** par :
- **Les clubs radio** voulant leur propre solution EmComm personnalisée
- **Les groupes régionaux** nécessitant des adaptations linguistiques ou réglementaires spécifiques
- **Les organisations d'urgence** requérant des configurations de déploiement personnalisées
- **Les opérateurs individuels** qui veulent construire sur une base solide et testée

Ceci n'est pas destiné à être un produit fermé et fini. C'est un point de départ - une base vanilla que vous pouvez adapter à vos besoins. Forkez-le, personnalisez-le, faites-en le vôtre. C'est ça, l'esprit radioamateur.

*Partagez les connaissances. Bâtissez la communauté. 73.*

---

## Pourquoi Debian plutôt qu'Ubuntu ?

### Support Bilingue : Une Nécessité Québécoise

Ce fork inclut un **support bilingue français/anglais complet** - une fonctionnalité non offerte dans l'EmComm-Tools OS original.

**Pourquoi c'est important :**

Au Québec, les lois linguistiques (*Loi 101*) exigent la disponibilité du français. En tant que radioamateur individuel, utiliser un logiciel uniquement en anglais est un choix personnel. Cependant, pour les **clubs radio et entités légales** au Québec, promouvoir ou adopter officiellement une solution uniquement anglophone peut créer des problèmes de conformité.

Cette édition Debian répond à ce besoin en offrant :
- Assistants d'installation et de premier démarrage bilingues (FR/EN)
- Traductions françaises des scripts de gestion et des menus
- Documentation dans les deux langues
- Sélection de la langue au démarrage - le système demande, plutôt que de présumer

**Implémentation Technique :**

Les scripts overlay du projet EmComm-Tools original ont été modifiés pour supporter le fonctionnement bilingue. Ces modifications respectent la licence Ms-PL originale tout en étendant les fonctionnalités pour les utilisateurs francophones.

Ceci n'est pas une critique du projet original - TheTechPrepper a créé une excellente solution pour sa communauté. Ce fork étend simplement ce travail pour servir la communauté radioamateur francophone au Québec et dans d'autres régions francophones.

---

### Le Débat « Appliance »

Le projet EmComm-Tools original a été construit sur Ubuntu avec la philosophie de créer une « appliance » autonome - un système figé dans le temps où tout fonctionne parfaitement ensemble. Bien que cette approche ait du mérite pour certains cas d'utilisation, le paysage des logiciels de radioamateur et de communications d'urgence évolue rapidement.

**Le problème avec l'approche appliance :**

- **La stabilité dépend des mises à jour** - Quand JS8Call, fldigi, ou pat-winlink publient des correctifs, vous devez pouvoir les appliquer. Un OS figé rend cela difficile ou impossible.
- **Les logiciels radioamateurs évoluent rapidement** - Nouveaux modes numériques, améliorations de protocoles, et support matériel arrivent régulièrement. Rester sur d'anciennes versions signifie manquer ces avancées.
- **La sécurité est moins préoccupante pour plusieurs utilisateurs** - Soyons honnêtes : plusieurs opérateurs EmComm ne connecteront jamais leur PC de station à internet. Pas de fichiers personnels, pas de documents de travail, juste la radio. Pour ces utilisateurs, les correctifs de sécurité importent moins.
- **Mais qu'en est-il de la stabilité ?** - C'est le vrai problème. Quand votre OS de base atteint sa fin de vie, vous perdez la capacité de mettre à jour *quoi que ce soit*. Votre gestionnaire de paquets cesse de fonctionner. Les dépendances brisent. Vous êtes coincé.
- **Alors que gagnez-vous en figeant l'OS ?** - Un faux sentiment de « ça fonctionne, n'y touchez pas » qui devient éventuellement « ça ne fonctionne plus, et je ne peux pas le réparer. »

### L'Avantage Debian

**Un Bref Historique :**

Debian est l'une des plus anciennes et des plus respectées distributions Linux, fondée en 1993 par Ian Murdock. Le nom combine celui de sa petite amie de l'époque (plus tard son épouse) Debra avec son propre prénom Ian - « Deb-Ian ».

**La Relation d'Ubuntu avec Debian :**

Ce que plusieurs utilisateurs ne réalisent pas, c'est qu'**Ubuntu est construit par-dessus Debian**. Quand Mark Shuttleworth a créé Ubuntu en 2004, il n'a pas parti de zéro - il a pris Debian comme fondation et a ajouté :
- Un cycle de publication plus fréquent (aux 6 mois)
- Une installation simplifiée et expérience de bureau
- Un soutien commercial via Canonical Ltd.
- Une image de marque et des politiques spécifiques à Ubuntu (incluant les restrictions de marque de commerce)

En termes pratiques, Ubuntu prend les dépôts de paquets Debian, modifie certains paquets, ajoute les leurs, et publie le tout avec l'image de marque Ubuntu. Le système sous-jacent - le gestionnaire de paquets (apt/dpkg), la structure du système de fichiers, les utilitaires de base - tout provient de Debian.

**Ce que ça signifie pour EmComm-Tools :**

Passer d'Ubuntu à Debian n'est pas un changement radical - c'est retourner à la source. La plupart de ce qui fonctionnait sur Ubuntu fonctionne identiquement sur Debian parce qu'Ubuntu l'a hérité de Debian au départ. Les principales différences sont :
- Aucune restriction de marque de commerce sur la redistribution
- Des cycles de publication plus longs et plus stables
- Accès direct aux vastes dépôts de paquets Debian
- Un projet communautaire sans frais généraux corporatifs

**Stabilité à Long Terme avec Maintenance Active :**
Debian Stable offre un cycle de support de 3-5 ans avec des mises à jour de sécurité continues. Contrairement au cycle de publication de 6 mois d'Ubuntu qui peut briser des choses, Debian priorise la stabilité tout en restant activement maintenu.

**Aucune Restriction de Marque de Commerce :**
Le projet EmComm-Tools original est licencié sous la **Microsoft Public License (Ms-PL)** - une licence open-source permissive qui permet explicitement les œuvres dérivées et la distribution. Cependant, le *système d'exploitation de base* crée un problème.

La politique de marque de commerce d'Ubuntu restreint la redistribution d'ISOs Ubuntu modifiés. C'est pourquoi le projet original indique « You must build your own distribution » et « Please do not distribute pre-built images. » Ce n'est pas le code EmComm-Tools qui est restreint - c'est l'image de marque Ubuntu en dessous.

**Debian n'a pas de telles restrictions.** En construisant sur Debian plutôt qu'Ubuntu, nous pouvons librement distribuer des ISOs pré-construits tout en honorant les termes de la licence Ms-PL. Les utilisateurs obtiennent une image prête à démarrer sans complications légales.

**Disponibilité des Logiciels Radioamateurs :**
Les dépôts Debian contiennent la plupart des applications radioamateurs qui nécessitaient une compilation manuelle sur Ubuntu. Le Debian Ham Radio Pure Blend inclut js8call, wsjtx, fldigi, direwolf, et plusieurs autres - tous correctement empaquetés et maintenus.

**Mon Engagement :**
Je ne resterai pas les bras croisés. Ce projet fournira toujours le meilleur système d'exploitation LTS (Long-Term Support) à jour, assurant que votre station EmComm reste sécurisée et fonctionnelle.

---

## Démarrage avec les ISOs Pré-Construits

### Pour les Nouveaux Utilisateurs Linux

L'une des plus grandes barrières aux modes numériques radioamateurs est la complexité de configurer un environnement Linux. Nos fichiers ISO pré-construits éliminent entièrement cette barrière.

**Avantages des ISOs Pré-Construits :**

- **Aucune installation Linux requise** - Démarrez directement depuis USB et commencez à opérer
- **Wine pré-configuré** - Environnement Wine32 prêt pour les applications Windows radioamateurs
- **Applications natives incluses** - JS8Call, WSJTX, fldigi, pat-winlink, direwolf, et plus
- **Interface bilingue (FR/EN)** - Sélection de la langue au premier démarrage
- **Compatibilité matérielle testée** - Optimisé pour le déploiement terrain sur des appareils comme les Panasonic Toughpads
- **Prêt pour le hors-ligne** - Tous les outils fonctionnent sans connectivité internet (scénarios SHTF)

### Installation de VARA HF/FM et VarAC

**Important :** VARA HF, VARA FM, et VarAC ne sont **pas pré-installés** dans l'ISO. Ces applications ont des termes de licence spécifiques qui ne permettent pas la redistribution.

**Option d'Installation au Premier Démarrage :**

Au premier démarrage, le système vous offrira de télécharger et installer VARA et VarAC :

1. **Installation Fraîche :** Si vous sélectionnez « Oui », un script d'installation va :
   - Télécharger les installateurs VARA HF/FM et VarAC via `wget`
   - Lancer chaque installateur via Wine
   - **Vous devez compléter l'assistant d'installation manuellement** pour chaque application
   - Ce processus respecte les politiques de distribution et accords de licence des développeurs

2. **Restaurer depuis une Sauvegarde :** Si vous avez précédemment utilisé l'EmComm-Tools OS original (version Ubuntu/TTP) et créé une sauvegarde Wine avec le script `05-backup-wine-install.sh` (fichier TAR), vous pouvez la restaurer directement. Cette méthode préserve votre configuration VARA existante et votre enregistrement.

**Note :** Une connexion internet est requise pour l'option d'installation fraîche. Planifiez en conséquence si vous préparez un déploiement terrain.

### Versions ISO : Petite vs Complète

Deux versions ISO sont disponibles au téléchargement :

| Version | Taille | Cartes Incluses | Idéal Pour |
|---------|--------|-----------------|------------|
| **Petite** | ~3 Go | Non | Utilisateurs avec bon internet, appareils à stockage limité |
| **Complète** | ~8 Go | Oui (US, Canada, Monde) | Préparation déploiement terrain, configurations hors-ligne |

**Petite ISO - Options de Cartes au Premier Démarrage :**

Si vous téléchargez la petite ISO, l'assistant de premier démarrage vous offrira de :
1. **Télécharger les cartes** - Récupérer et installer les jeux de tuiles cartographiques (requiert internet)
2. **Passer** - Utiliser sans cartes (peut ajouter plus tard)

**Disque Externe / Stockage USB :**

Pour les appareils avec stockage interne limité (comme les Panasonic Toughpads), les cartes peuvent être hébergées sur un disque externe ou une clé USB plutôt que sur le disque interne. Ceci garde votre partition système légère tout en ayant la pleine capacité cartographique hors-ligne.

Cette flexibilité vous permet de choisir le bon équilibre entre taille ISO, temps de téléchargement, et utilisation du stockage pour votre scénario de déploiement spécifique.

### Outils de Création USB Démarrable

Le seul logiciel dont vous avez besoin est un créateur USB démarrable. Voici les options les plus fiables par plateforme :

#### Windows

| Outil | Description | Téléchargement |
|-------|-------------|----------------|
| **Rufus** | Rapide, fiable, open-source. Le standard de référence pour Windows. | [rufus.ie](https://rufus.ie) |
| **balenaEtcher** | Processus simple en 3 étapes, valide les écritures, multiplateforme. | [etcher.balena.io](https://etcher.balena.io) |
| **Ventoy** | Multi-boot capable - mettez plusieurs ISOs sur une USB. | [ventoy.net](https://ventoy.net) |

#### macOS

| Outil | Description | Téléchargement |
|-------|-------------|----------------|
| **balenaEtcher** | Meilleur choix pour Mac - simple, fiable, application native. | [etcher.balena.io](https://etcher.balena.io) |
| **UNetbootin** | Multiplateforme, fonctionne bien pour les ISOs Linux. | [unetbootin.github.io](https://unetbootin.github.io) |
| **dd (Terminal)** | Intégré, puissant mais requiert de la prudence. | `sudo dd if=image.iso of=/dev/diskN bs=4M` |

#### Linux

| Outil | Description | Installation |
|-------|-------------|--------------|
| **balenaEtcher** | Même interface simple que les autres plateformes. | AppImage disponible |
| **Ventoy** | Installez une fois, puis copiez simplement les fichiers ISO sur USB. | [ventoy.net](https://ventoy.net) |
| **GNOME Disques** | Intégré à la plupart des bureaux GNOME, fonction « Restaurer l'image disque ». | Pré-installé |
| **dd** | Outil Unix classique, rapide et fiable. | `sudo dd if=image.iso of=/dev/sdX bs=4M status=progress` |

#### Recommandation

Pour débutants : **balenaEtcher** - Fonctionne sur toutes les plateformes, impossible d'écraser accidentellement votre disque dur, valide l'écriture.

Pour utilisateurs avancés : **Ventoy** - Installez-le une fois sur votre clé USB, puis copiez simplement les fichiers ISO dessus. Vous pouvez avoir EmComm-Tools, un installateur Windows, et des outils de récupération système tous sur une même USB.

---

## Contribuer

Ceci est un projet open-source. Les contributions, rapports de bogues, et demandes de fonctionnalités sont les bienvenus.

**Dépôt :** [github.com/emcomm-tools/debian](https://github.com/emcomm-tools/debian)

**Téléchargements ISO :** [sourceforge.net/p/emcomm-tools](https://sourceforge.net/p/emcomm-tools/)

**Site Web :** [emcomm-tools.ca](https://emcomm-tools.ca) | [emcomm-tools.com](https://emcomm-tools.com)

**Contact :** info@emcomm-tools.ca

---

## Licence

Ce projet est une œuvre dérivée d'EmComm-Tools OS Community, licencié sous la **Microsoft Public License (Ms-PL)**.

En conformité avec la Section 3(C) de Ms-PL, nous conservons tous les avis de droits d'auteur, brevets, marques de commerce, et attribution du logiciel original.

**Ce que la Ms-PL permet :**
- Créer des œuvres dérivées (cette édition Debian)
- Distribuer des images ISO pré-construites
- Modification et redistribution

**Ce que nous honorons :**
- Attribution originale à Gaston Gonzalez (KT7RUN) alias *The Tech Prepper* et contributeurs
- Distribution sous la même licence Ms-PL
- Aucune utilisation des marques de commerce ou image de marque du projet original

Le passage d'Ubuntu à Debian élimine les restrictions de marque de commerce d'Ubuntu qui empêchaient précédemment la distribution d'images pré-construites, tout en respectant pleinement les termes Ms-PL du projet EmComm-Tools original.

---

## Remerciements

- **Gaston Gonzalez (KT7RUN)** alias *The Tech Prepper* - Projet original EmComm-Tools OS Community
- **L'Équipe Debian Ham Radio** - Maintien d'excellents paquets radioamateurs
- **EA5HVK** - Développement du modem VARA HF/FM
- **Équipe de Développement VarAC** - Application de chat VarAC pour VARA

---

*73 de VA2OPS*
