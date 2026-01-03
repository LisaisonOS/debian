# EmComm-Tools ISO Builder

Construisez votre propre ISO Live EmComm-Tools personnalisé basé sur Debian.

## Démarrage rapide

```bash
cd emcomm-tools
./setup-emcomm-iso.sh
```

Le script vous guidera à travers la configuration et construira l'ISO automatiquement.

## Prérequis

- Debian 12+ (Trixie recommandé)
- ~10 Go d'espace disque libre
- Connexion Internet
- Accès `sudo`

## Structure des dossiers

```
emcomm-tools/
├── setup-emcomm-iso.sh      # Script principal
├── overlays/                # Fichiers overlay EmComm-Tools
│   └── et-r5-final/         # Basé sur la version R5 de TTP
│       └── overlay/
│           └── opt/emcomm-tools/bin/   # Scripts et-*
├── scripts/                 # Fichiers de configuration ISO
│   ├── package-lists/       # Paquets Debian à installer
│   ├── hooks/               # Hooks de build (0xxx-*.hook.chroot)
│   ├── autostart/           # Entrées de démarrage automatique
│   ├── panel-launchers/     # Lanceurs du panneau XFCE (.desktop)
│   ├── xfce-config/         # Fichiers de configuration XFCE (XML)
│   └── etc/                 # Fichiers de configuration système (/etc)
├── backgrounds/             # Images de fond d'écran
├── motd/                    # Bannières terminal
└── wine-sources/            # Préfixe Wine pré-configuré (depuis SourceForge)
```

## Options de configuration

Le script de configuration offre plusieurs options de personnalisation :

### 1. Sélection de l'overlay
Choisissez quelle version d'EmComm-Tools construire.

### 2. Fond d'écran
- **Générer personnalisé** - Entrez votre indicatif + slogan
- **Sélectionner existant** - Choisir dans le dossier `backgrounds/`
- **Utiliser défaut** - Depuis l'overlay

### 3. Préfixe Wine
Un préfixe Wine pré-configuré est téléchargé depuis SourceForge (~100 Mo). Ceci fournit un environnement Wine prêt à l'emploi pour VARA et VarAC.

**Note :** VARA et VarAC ne sont PAS inclus en raison des licences. Les utilisateurs doivent les installer au premier démarrage en lançant VarAC depuis le panneau - cela téléchargera et exécutera l'installateur officiel.

### 4. Bannière MOTD
Message personnalisé affiché à la connexion dans le terminal.

## Résultat du build

L'ISO est créé dans :
```
build/emcomm-debian-iso/live-image-amd64.hybrid.iso
```

Après un build réussi, le script propose de tester dans QEMU.

## Premier démarrage

Au premier démarrage, un assistant configure :
1. Paramètres utilisateur (indicatif, grille, mot de passe Winlink)
2. Sélection radio/transceiver
3. Cartes hors-ligne (optionnel)

Pour installer VARA/VarAC : Cliquez sur l'icône VarAC dans le panneau et suivez l'installateur officiel.

## Tableau de bord & Configuration

Un tableau de bord est affiché sur le bureau avec des boutons d'accès rapide :
- **OPÉRATEUR [⚙]** - Configurer indicatif, grille, mot de passe Winlink
- **INTERFACES [⚙]** - Configurer radio/transceiver
- **MODE [⚙]** - Sélectionner le mode d'opération
- **Boutons de lancement rapide** - Winlink, JS8Call, VarAC, BBS

Les utilisateurs peuvent aussi configurer en ligne de commande :
```bash
et-user        # Indicatif, grille, Winlink
et-radio       # Sélection du transceiver
et-maps-setup  # Cartes hors-ligne
et-mode        # Mode d'opération
```

## Téléchargements

| Fichier | Source | Taille |
|---------|--------|--------|
| wine-sources | [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/wine-sources-general.tar.gz) | ~100 Mo |
| Images ISO | [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/) | ~2,8 Go |

## Crédits

Ceci est un portage Debian de **EmComm-Tools OS**, créé à l'origine par Gaston Gonzalez (KT7RUN) pour Ubuntu.

Adaptation Debian et constructeur ISO par Sylvain Deguire (VA2OPS).

---

73 de VA2OPS 📻
