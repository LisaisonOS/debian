#!/bin/bash
# =============================================================================
# EmComm-Tools Debian ISO Builder
# https://emcomm-tools.ca
# 
# Author: Sylvain Deguire (VA2OPS)
# Based on EmComm-Tools OS by Gaston Gonzalez ()
#
# Directory structure:
#   ./overlays/          - EmComm-Tools overlay versions (et-v1-general, et-v2-general, etc.)
#   ./wine-sources/      - Wine prefixes with VarAC, VARA, FT8, etc.
#   ./backgrounds/       - Wallpaper images (emcomm-base.png for generator)
#   ./motd/              - Custom terminal banners
#   ./build/             - Build output (auto-created)
#
# Usage: ./setup-emcomm-iso-v2.sh [build-profile.json]
#   No arguments = interactive mode (dialog prompts)
#   With profile = headless mode (reads all settings from JSON)
# =============================================================================

set -e

# Get script directory (allows running from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory structure (relative to script)
OVERLAYS_DIR="$SCRIPT_DIR/overlays"
WINE_SOURCE_DIR="$SCRIPT_DIR/wine-sources"
WALLPAPER_DIR="$SCRIPT_DIR/backgrounds"
MOTD_DIR="$SCRIPT_DIR/motd"
BUILD_DIR="$SCRIPT_DIR/build"
ISO_DIR="$BUILD_DIR/emcomm-debian-iso"

# =============================================================================
# EmComm-Tools Version Configuration
# =============================================================================
# Version is loaded from build-config.json for easy editing
# Run: nano build-config.json (or use any text editor)

CONFIG_FILE="$SCRIPT_DIR/build-config.json"

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'DEFAULT_CONFIG'
{
    "version": "1.0.0",
    "codename": "Trixie",
    "distro_name": "EmComm-Tools Debian Edition",
    "website": "https://emcomm-tools.ca",
    "support_url": "https://emcomm-tools.ca/support",
    "author": "VA2OPS"
}
DEFAULT_CONFIG
    echo "Created default build-config.json"
fi

# Load version from JSON config
if command -v jq &> /dev/null; then
    ET_VERSION=$(jq -r '.version' "$CONFIG_FILE")
    ET_CODENAME=$(jq -r '.codename' "$CONFIG_FILE")
    ET_DISTRO_NAME=$(jq -r '.distro_name' "$CONFIG_FILE")
    ET_WEBSITE=$(jq -r '.website' "$CONFIG_FILE")
    ET_SUPPORT_URL=$(jq -r '.support_url' "$CONFIG_FILE")
    ET_AUTHOR=$(jq -r '.author' "$CONFIG_FILE")
else
    echo "jq not found, installing..."
    sudo apt install -y jq
    ET_VERSION=$(jq -r '.version' "$CONFIG_FILE")
    ET_CODENAME=$(jq -r '.codename' "$CONFIG_FILE")
    ET_DISTRO_NAME=$(jq -r '.distro_name' "$CONFIG_FILE")
    ET_WEBSITE=$(jq -r '.website' "$CONFIG_FILE")
    ET_SUPPORT_URL=$(jq -r '.support_url' "$CONFIG_FILE")
    ET_AUTHOR=$(jq -r '.author' "$CONFIG_FILE")
fi

# =============================================================================
# Build Profile Detection
# =============================================================================
BUILD_PROFILE=""
if [ -n "$1" ] && [ -f "$1" ]; then
    BUILD_PROFILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    echo "Build profile: $BUILD_PROFILE"
elif [ -n "$1" ]; then
    echo "ERROR: Build profile not found: $1"
    exit 1
fi

# =============================================================================
# Build Profile Validation
# =============================================================================
validate_build_profile() {
    local profile="$1"
    local errors=0

    echo "Validating build profile..."

    # Required fields
    for field in arch_version overlay iso_type; do
        val=$(jq -r ".$field // empty" "$profile")
        if [ -z "$val" ]; then
            echo "  ERROR: Required field '$field' is missing"
            errors=$((errors + 1))
        fi
    done

    # Overlay directory must exist
    local overlay_name=$(jq -r '.overlay // empty' "$profile")
    if [ -n "$overlay_name" ]; then
        local overlay_path="${OVERLAYS_DIR}/${overlay_name}"
        if [ ! -d "$overlay_path" ]; then
            echo "  ERROR: Overlay directory not found: $overlay_path"
            errors=$((errors + 1))
        fi
    fi

    # Wine prefix must exist if iso_type=complete
    local iso_type=$(jq -r '.iso_type // empty' "$profile")
    if [ "$iso_type" = "complete" ]; then
        local wine_prefix=$(jq -r '.wine_prefix // empty' "$profile")
        if [ -z "$wine_prefix" ]; then
            echo "  ERROR: wine_prefix required for complete ISO"
            errors=$((errors + 1))
        elif [ ! -d "${WINE_SOURCE_DIR}/${wine_prefix}" ]; then
            echo "  ERROR: Wine prefix not found: ${WINE_SOURCE_DIR}/${wine_prefix}"
            errors=$((errors + 1))
        fi
    fi

    # Wallpaper base image must exist if mode=generate
    local wp_mode=$(jq -r '.wallpaper.mode // "default"' "$profile")
    if [ "$wp_mode" = "generate" ]; then
        if [ ! -f "$WALLPAPER_DIR/emcomm-base.png" ]; then
            echo "  ERROR: Base wallpaper not found: $WALLPAPER_DIR/emcomm-base.png"
            errors=$((errors + 1))
        fi
    fi

    # Selected wallpaper file must exist if mode=select
    if [ "$wp_mode" = "select" ]; then
        local wp_file=$(jq -r '.wallpaper.filename // empty' "$profile")
        if [ -z "$wp_file" ]; then
            echo "  ERROR: wallpaper.filename required for select mode"
            errors=$((errors + 1))
        elif [ ! -f "$WALLPAPER_DIR/$wp_file" ]; then
            echo "  ERROR: Wallpaper file not found: $WALLPAPER_DIR/$wp_file"
            errors=$((errors + 1))
        fi
    fi

    # MOTD file must exist if not default
    local motd=$(jq -r '.motd // "default"' "$profile")
    if [ "$motd" != "default" ]; then
        if [ ! -f "$MOTD_DIR/$motd" ]; then
            echo "  ERROR: MOTD file not found: $MOTD_DIR/$motd"
            errors=$((errors + 1))
        fi
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        echo "Profile validation failed with $errors error(s)."
        exit 1
    fi

    echo "  Profile validated OK."
}

if [ -n "$BUILD_PROFILE" ]; then
    validate_build_profile "$BUILD_PROFILE"
fi

# Check for dialog (only needed in interactive mode)
if [ -z "$BUILD_PROFILE" ]; then
    if ! command -v dialog &> /dev/null; then
        echo "Installing dialog... / Installation de dialog..."
        sudo apt install -y dialog
    fi
fi

# =============================================================================
# Language Selection / Sélection de la langue
# =============================================================================
if [ -n "$BUILD_PROFILE" ]; then
    SCRIPT_LANG=$(jq -r '.language // "en"' "$BUILD_PROFILE")
else
    LANG_CHOICE=$(dialog --title "Language / Langue" \
        --menu "Select your language / Sélectionnez votre langue:" 12 50 2 \
        1 "English" \
        2 "Français" \
        3>&1 1>&2 2>&3)

    clear

    case $LANG_CHOICE in
        2) SCRIPT_LANG="fr" ;;
        *) SCRIPT_LANG="en" ;;
    esac
fi

# =============================================================================
# Version Confirmation / Confirmation de la version
# =============================================================================
if [ -z "$BUILD_PROFILE" ]; then
    if [ "$SCRIPT_LANG" = "fr" ]; then
        VERSION_TITLE="Confirmation de la version"
        VERSION_MSG="Vous êtes sur le point de construire:\n\n  Distribution: ${ET_DISTRO_NAME}\n  Version: ${ET_VERSION}\n  Base Debian: ${ET_CODENAME}\n  Auteur: ${ET_AUTHOR}\n\nCette version apparaîtra dans:\n  • L'installateur Calamares\n  • Les dialogues À propos\n  • Le système de mise à jour\n\nContinuer avec cette version?"
        VERSION_EDIT_MSG="Pour modifier la version, éditez le fichier de configuration:\n\n  nano ${CONFIG_FILE}\n\nExemple de contenu:\n  {\n    \"version\": \"1.0.1\",\n    \"codename\": \"Trixie\",\n    \"distro_name\": \"EmComm-Tools Debian Edition\",\n    ...\n  }"
        VERSION_EXIT_MSG="Construction annulée."
    else
        VERSION_TITLE="Version Confirmation"
        VERSION_MSG="You are about to build:\n\n  Distribution: ${ET_DISTRO_NAME}\n  Version: ${ET_VERSION}\n  Debian Base: ${ET_CODENAME}\n  Author: ${ET_AUTHOR}\n\nThis version will appear in:\n  • Calamares installer\n  • About dialogs\n  • Update system\n\nContinue with this version?"
        VERSION_EDIT_MSG="To change the version, edit the config file:\n\n  nano ${CONFIG_FILE}\n\nExample content:\n  {\n    \"version\": \"1.0.1\",\n    \"codename\": \"Trixie\",\n    \"distro_name\": \"EmComm-Tools Debian Edition\",\n    ...\n  }"
        VERSION_EXIT_MSG="Build cancelled."
    fi

    dialog --title "$VERSION_TITLE" \
        --yesno "$VERSION_MSG" 18 60

    VERSION_CONFIRM=$?
    clear

    if [ $VERSION_CONFIRM -ne 0 ]; then
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "$VERSION_EXIT_MSG"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "$VERSION_EDIT_MSG"
        echo ""
        exit 0
    fi
fi

# =============================================================================
# Bilingual Messages / Messages bilingues
# =============================================================================
set_messages() {
    if [ "$SCRIPT_LANG" = "fr" ]; then
        # French messages
        MSG_SCRIPT_TITLE="=== Constructeur ISO EmComm-Tools Debian ==="
        MSG_SCRIPT_DIR="Répertoire du script:"
        
        # Version
        MSG_SELECTED_VERSION="Version sélectionnée:"

        # Overlay
        DLG_OVERLAY_TITLE="Sélection de l'overlay"
        DLG_OVERLAY_MENU="Sélectionnez la version de l'overlay:"
        MSG_SELECTED_OVERLAY="Overlay sélectionné:"
        MSG_NO_OVERLAY_SELECTED="Aucun overlay sélectionné. Fermeture."
        MSG_NO_OVERLAYS_FOUND="Aucun overlay trouvé dans"
        MSG_ADD_OVERLAY_FOLDERS="Veuillez ajouter des dossiers overlay dans le répertoire overlays/."
        MSG_OVERLAYS_DIR_NOT_FOUND="Répertoire overlays non trouvé:"
        MSG_CREATE_OVERLAYS_DIR="Veuillez créer le répertoire overlays/ et y ajouter des dossiers overlay."
        MSG_ERROR_OVERLAY_NOT_FOUND="ERREUR: Répertoire overlay non trouvé:"
        MSG_USING_OVERLAY="Utilisation de l'overlay:"
        
        # Maps
        DLG_MAPS_TITLE="Constructeur ISO EmComm-Tools"
        DLG_MAPS_MENU="Configuration des cartes hors-ligne:\n\nVoulez-vous inclure les cartes dans l'ISO?"
        DLG_MAPS_OPT1="Non - Utiliser disque externe (Recommandé, ~2.8Go ISO)"
        DLG_MAPS_OPT2="Oui - Intégrer les cartes dans l'ISO (~5.5Go ISO)"
        DLG_MAPS_OPT3="Annuler la construction"
        MSG_MAPS_NOT_INCLUDED="Les cartes NE seront PAS incluses dans l'ISO."
        MSG_MAPS_EXTERNAL_DRIVE="Les utilisateurs configureront le disque externe au premier démarrage."
        MSG_MAPS_INCLUDED="Les cartes SERONT incluses dans l'ISO."
        MSG_MAPS_WARNING_SIZE="Attention: L'ISO fera ~5.5Go!"
        MSG_BUILD_CANCELLED="Construction annulée."
        MSG_PRESS_ENTER="Appuyez sur Entrée pour continuer..."
        
        # Wallpaper
        MSG_INSTALLING_IMAGEMAGICK="Installation d'ImageMagick pour la génération du fond d'écran..."
        DLG_WALLPAPER_TITLE="Configuration du fond d'écran"
        DLG_WALLPAPER_MENU="Comment voulez-vous configurer le fond d'écran?"
        DLG_WALLPAPER_OPT1="Générer un fond d'écran personnalisé (indicatif + slogan)"
        DLG_WALLPAPER_OPT2="Sélectionner parmi les images existantes"
        DLG_WALLPAPER_OPT3="Utiliser celui par défaut de l'overlay"
        MSG_CUSTOM_WALLPAPER_TITLE="=== Générateur de fond d'écran personnalisé ==="
        MSG_ENTER_CALLSIGN="Entrez l'indicatif (ex: VA2OPS): "
        MSG_ENTER_TAGLINE="Entrez le slogan (optionnel, Entrée pour passer): "
        MSG_TEXT_COLOR_OPTIONS="Options de couleur du texte:"
        MSG_COLOR_WHITE="Blanc (par défaut)"
        MSG_COLOR_GRAY="Gris pâle"
        MSG_COLOR_ORANGE="Orange (style radioamateur)"
        MSG_COLOR_BLUE="Bleu pâle"
        MSG_SELECT_COLOR="Choisir la couleur [1]: "
        MSG_GENERATING_WALLPAPER="Génération du fond d'écran..."
        MSG_WALLPAPER_GENERATED="Fond d'écran généré:"
        MSG_NO_CALLSIGN_DEFAULT="Aucun indicatif entré, utilisation du fond d'écran par défaut."
        MSG_BASE_IMAGE_NOT_FOUND="Image de base non trouvée:"
        MSG_COPY_BASE_IMAGE="Veuillez copier emcomm-base.png dans le répertoire backgrounds/"
        MSG_USING_DEFAULT_WALLPAPER="Utilisation du fond d'écran par défaut de l'overlay."
        DLG_WALLPAPER_SELECT_TITLE="Sélection du fond d'écran"
        DLG_WALLPAPER_SELECT_MENU="Sélectionnez le fond d'écran pour l'ISO:"
        MSG_SELECTED_WALLPAPER="Fond d'écran sélectionné:"
        MSG_NO_WALLPAPERS_FOUND="Aucun fond d'écran trouvé dans"
        MSG_WALLPAPER_DIR_NOT_FOUND="Répertoire des fonds d'écran non trouvé:"
        
        # Boot Logo
        DLG_BOOTLOGO_TITLE="Configuration du logo de démarrage"
        DLG_BOOTLOGO_MENU="Générer un logo de démarrage Plymouth personnalisé?\n(Remplace le casque jaune Debian au démarrage)"
        DLG_BOOTLOGO_OPT1="Oui - Avec l'indicatif"
        DLG_BOOTLOGO_OPT2="Oui - Sans indicatif (logo seulement)"
        DLG_BOOTLOGO_OPT3="Non - Garder celui de Debian par défaut"
        MSG_ENTER_CALLSIGN_BOOTLOGO="Entrez l'indicatif pour le logo de démarrage (ex: VA2OPS): "
        MSG_GENERATING_BOOTLOGO_CALLSIGN="Génération du logo de démarrage avec indicatif:"
        MSG_NO_CALLSIGN_NO_TEXT="Aucun indicatif entré, génération du logo sans texte"
        MSG_GENERATING_BOOTLOGO_NOTEXT="Génération du logo de démarrage (sans indicatif)..."
        MSG_BOOTLOGO_SUCCESS="Logo de démarrage généré avec succès!"
        MSG_BOOTLOGO_FAILED="Attention: Échec de la génération du logo de démarrage"
        MSG_CANNOT_GENERATE_BOOTLOGO="Impossible de générer le logo de démarrage."
        MSG_USING_DEFAULT_BOOTLOGO="Utilisation du logo Debian par défaut (casque jaune)"
        
        # MOTD
        DLG_MOTD_TITLE="Sélection MOTD / Bannière"
        DLG_MOTD_MENU="Sélectionnez la bannière du terminal pour l'ISO:"
        DLG_MOTD_DEFAULT="Par défaut (de l'overlay)"
        MSG_SELECTED_MOTD="MOTD sélectionné:"
        MSG_USING_DEFAULT_MOTD="Utilisation du MOTD par défaut de l'overlay"
        MSG_NO_MOTD_FILES="Aucun fichier MOTD trouvé dans"
        MSG_MOTD_DIR_NOT_FOUND="Répertoire MOTD non trouvé:"
        MSG_CREATE_MOTD_DIR="Créez-le et ajoutez des fichiers texte pour une bannière personnalisée."
        
        # ISO Type Selection
        DLG_ISO_TYPE_TITLE="Type d'ISO"
        DLG_ISO_TYPE_MENU="Sélectionnez le type d'ISO à construire:\n\nVarAC est distribué sous accord de distribution limitée.\nLa licence sera présentée au premier lancement."
        DLG_ISO_TYPE_COMPLETE="Complète - Avec VARA + VarAC pré-installé"
        DLG_ISO_TYPE_LITE="Légère - Sans Wine/VARA/VarAC"
        MSG_ISO_COMPLETE_SELECTED="ISO COMPLÈTE sélectionnée"
        MSG_VARA_VARAC_INCLUDED="VARA HF/FM et VarAC seront inclus dans l'ISO"
        MSG_LICENSE_ENFORCED="L'accord de licence VarAC sera présenté au premier lancement"
        MSG_ISO_LITE_SELECTED="ISO LÉGÈRE sélectionnée"
        MSG_NO_WINE_INCLUDED="Wine/VARA/VarAC ne seront PAS inclus"
        
        # Wine Prefix Selection
        DLG_WINE_TITLE="Sélection du préfixe Wine"
        DLG_WINE_MENU="Sélectionnez le dossier Wine à inclure dans l'ISO:"
        MSG_SELECTED_WINE="Dossier Wine sélectionné:"
        MSG_NO_WINE_SELECTED="Aucun dossier Wine sélectionné. Construction annulée."
        MSG_NO_WINE_FOLDERS="Aucun dossier Wine trouvé dans"
        MSG_WINE_DIR_NOT_FOUND="Répertoire wine-sources non trouvé:"
        MSG_CREATE_WINE_DIR="Veuillez créer le répertoire et y ajouter vos dossiers Wine."
        MSG_ERROR_WINE_NOT_FOUND="ERREUR: Dossier Wine non trouvé:"
        MSG_WINE_CHECKING="Vérification du préfixe Wine..."
        MSG_WINE_VARAC_OK="✓ VarAC.exe trouvé"
        MSG_WINE_LICENSE_OK="✓ License.txt trouvé"
        MSG_WINE_VARAC_MISSING="⚠ VarAC.exe manquant dans ce préfixe"
        MSG_WINE_LICENSE_MISSING="⚠ License.txt manquant (requis pour l'enforcement de licence)"
        MSG_COPYING_WINE="Copie du préfixe Wine:"
        MSG_SKIPPING_WINE="Préfixe Wine non inclus (ISO légère)"
        MSG_WINE_SUMMARY_COMPLETE="Wine: VARA + VarAC inclus (licence enforced)"
        MSG_WINE_SUMMARY_LITE="Wine: Non inclus (ISO légère)"
        
        # Build process
        MSG_BUILD_START_LINE1="║  Démarrage du processus de construction...                            ║"
        MSG_BUILD_START_LINE3="║  NOTE: Après avoir entré votre mot de passe sudo, le script prendra   ║"
        MSG_BUILD_START_LINE4="║  1-2 minutes avant d'afficher quoi que ce soit. Soyez patient!        ║"
        MSG_CHECKING_CACHE="Vérification du cache existant..."
        MSG_SAVING_CACHE="Sauvegarde du cache des paquets..."
        MSG_CLEANING_BUILD="Nettoyage de l'ancienne construction..."
        MSG_RESTORING_CACHE="Restauration du cache des paquets..."
        MSG_CACHE_RESTORED="Cache restauré! La construction sera plus rapide."
        MSG_ERROR_WRONG_DIR="ERREUR: Pas dans le bon répertoire! Attendu:"
        MSG_CONFIGURING_LIVEBUILD="Configuration de live-build..."
        MSG_COPYING_PACKAGES="Copie de la liste des paquets..."
        MSG_COPYING_OVERLAY="Copie de l'overlay..."
        MSG_SETTING_WALLPAPER="Configuration du fond d'écran..."
        MSG_COPYING_GEN_WALLPAPER="Copie du fond d'écran généré..."
        MSG_COPYING_SEL_WALLPAPER="Copie du fond d'écran sélectionné:"
        MSG_USING_OVERLAY_WALLPAPER="Utilisation du fond d'écran par défaut de l'overlay"
        MSG_WARNING_NO_WALLPAPER="Attention: Aucun fond d'écran trouvé!"
        MSG_SETTING_PLYMOUTH="Configuration de l'image de marque Plymouth..."
        MSG_BOOTLOGO_INSTALLED="Logo de démarrage installé (remplace le casque jaune Debian)"
        MSG_CREATING_PLYMOUTH_HOOK="Création du hook de configuration Plymouth..."
        MSG_CONFIGURING_PLYMOUTH="Configuration de l'image de marque Plymouth..."
        MSG_PLYMOUTH_CONFIGURED="Image de marque Plymouth configurée."
        MSG_PLYMOUTH_HOOK_CREATED="Hook Plymouth créé: 0050-plymouth-branding.hook.chroot"
        MSG_COPYING_MOTD="Copie du MOTD sélectionné:"
        MSG_CLEANING_UBUNTU="Nettoyage des fichiers spécifiques à Ubuntu..."
        MSG_CLEANING_ETUSER="Nettoyage des variantes et-user..."
        MSG_COPYING_WINE="Copie du préfixe Wine depuis:"
        MSG_CREATING_SCRIPTS="Création des scripts EmComm-Tools..."
        MSG_COPYING_AUTOSTART="Copie de l'entrée autostart du premier démarrage..."
        MSG_VARAC_ICON_FOUND="Icône VarAC trouvée dans l'overlay"
        MSG_ICONS_COPIED="Icônes copiées dans pixmaps pour compatibilité Debian"
        MSG_WARNING_VARAC_ICON="ATTENTION: Icône VarAC non trouvée dans l'overlay"
        MSG_CREATING_HOOKS="Création des hooks..."
        MSG_COPYING_ENVIRONMENT="Copie de /etc/environment..."
        MSG_ADDING_LAUNCHERS="Ajout des lanceurs du panneau XFCE..."
        MSG_ADDING_FUSE="Ajout du correctif fuse..."
        MSG_COPYING_MAP_HOOK="Copie du hook de téléchargement des cartes..."
        MSG_MAP_HOOK_COPIED="Hook de téléchargement des cartes copié."
        MSG_SKIPPING_MAP_DOWNLOAD="Téléchargement des cartes ignoré (mode disque externe)."
        
        # Setup complete
        MSG_SETUP_COMPLETE="=== Configuration terminée! ==="
        MSG_USER_ACCOUNT="Compte utilisateur: user / live (connexion auto activée)"
        MSG_MAPS_INCLUDED_SUMMARY="Cartes: INCLUSES (ISO fera ~5.5Go)"
        MSG_MAPS_EXTERNAL_SUMMARY="Cartes: DISQUE EXTERNE (ISO fera ~2.8Go)"
        
        # ISO build
        MSG_ISO_BUILD_LINE1="║  Démarrage de la construction ISO...                                  ║"
        MSG_ISO_BUILD_LINE2="║  Cela prendra 15-30 minutes selon votre vitesse Internet.             ║"
        MSG_ISO_BUILD_LINE3="║  Journal de construction: build.log                                   ║"
        
        # Build results
        MSG_BUILD_SUCCESS="║  CONSTRUCTION RÉUSSIE!                                                ║"
        MSG_ISO_CREATED="ISO créé:"
        MSG_SIZE="Taille:"
        MSG_START_QEMU="Démarrer QEMU pour tester l'ISO? (o/n): "
        MSG_STARTING_QEMU="Démarrage de QEMU..."
        MSG_QEMU_STARTED="QEMU démarré en arrière-plan."
        MSG_WARNING_ISO_NOT_FOUND="Attention: Fichier ISO non trouvé!"
        MSG_BUILD_FAILED="║  ÉCHEC DE LA CONSTRUCTION!                                            ║"
        MSG_CHECK_LOG="Vérifiez build.log pour les erreurs."
        MSG_RETRY_HINT="Si la construction a échoué à cause d'un problème de miroir, réessayez avec:"
        
        # Yes/No prompt
        MSG_YES_CHAR="o"
        
        # Update System
        DLG_UPDATE_TITLE="Configuration du système de mise à jour"
        DLG_UPDATE_MENU="Configurer la vérification automatique des mises à jour?\n\nCeci permet aux utilisateurs de recevoir les mises à jour\nde l'overlay sans réinstaller l'OS."
        DLG_UPDATE_OPT1="Oui - Serveur public (emcomm-tools.ca)"
        DLG_UPDATE_OPT2="Oui - URL personnalisée (club/organisation)"
        DLG_UPDATE_OPT3="Non - Hors-ligne seulement (mises à jour manuelles)"
        MSG_UPDATE_CUSTOM_URL="Entrez l'URL du serveur de mise à jour (sans / à la fin): "
        DLG_UPDATE_CHANNEL_TITLE="Canal de mise à jour"
        DLG_UPDATE_CHANNEL_MENU="Sélectionnez le canal de mise à jour:"
        DLG_UPDATE_CHANNEL_STABLE="Stable - Versions testées"
        DLG_UPDATE_CHANNEL_BETA="Bêta - Accès anticipé"
        DLG_UPDATE_CHANNEL_PERSONAL="Personnel - Builds privés"
        MSG_UPDATE_ENABLED="Système de mise à jour activé:"
        MSG_UPDATE_CHANNEL="Canal de mise à jour:"
        MSG_UPDATE_DISABLED="Système de mise à jour désactivé (mode hors-ligne)"
        MSG_GENERATING_MANIFEST="Génération du catalogue de fichiers (manifest.json)..."
        MSG_MANIFEST_GENERATED="Catalogue généré avec"
        MSG_MANIFEST_FILES="fichiers"
    else
        # English messages
        MSG_SCRIPT_TITLE="=== EmComm-Tools Debian ISO Builder ==="
        MSG_SCRIPT_DIR="Script directory:"
        
        # Version
        MSG_SELECTED_VERSION="Selected version:"

        # Overlay
        DLG_OVERLAY_TITLE="Overlay Selection"
        DLG_OVERLAY_MENU="Select the overlay version to use:"
        MSG_SELECTED_OVERLAY="Selected overlay:"
        MSG_NO_OVERLAY_SELECTED="No overlay selected. Exiting."
        MSG_NO_OVERLAYS_FOUND="No overlays found in"
        MSG_ADD_OVERLAY_FOLDERS="Please add overlay folders to the overlays/ directory."
        MSG_OVERLAYS_DIR_NOT_FOUND="Overlays directory not found:"
        MSG_CREATE_OVERLAYS_DIR="Please create the overlays/ directory and add overlay folders."
        MSG_ERROR_OVERLAY_NOT_FOUND="ERROR: Overlay directory not found:"
        MSG_USING_OVERLAY="Using overlay:"
        
        # Maps
        DLG_MAPS_TITLE="EmComm-Tools ISO Builder"
        DLG_MAPS_MENU="Offline Maps Configuration:\n\nDo you want to include maps in the ISO?"
        DLG_MAPS_OPT1="No - Use external drive (Recommended, ~2.8GB ISO)"
        DLG_MAPS_OPT2="Yes - Bake maps into ISO (~5.5GB ISO)"
        DLG_MAPS_OPT3="Cancel build"
        MSG_MAPS_NOT_INCLUDED="Maps will NOT be included in ISO."
        MSG_MAPS_EXTERNAL_DRIVE="Users will setup external drive on first boot."
        MSG_MAPS_INCLUDED="Maps WILL be included in ISO."
        MSG_MAPS_WARNING_SIZE="Warning: ISO will be ~5.5GB!"
        MSG_BUILD_CANCELLED="Build cancelled."
        MSG_PRESS_ENTER="Press Enter to continue with build..."
        
        # Wallpaper
        MSG_INSTALLING_IMAGEMAGICK="Installing ImageMagick for wallpaper generation..."
        DLG_WALLPAPER_TITLE="Wallpaper Configuration"
        DLG_WALLPAPER_MENU="How do you want to set the wallpaper?"
        DLG_WALLPAPER_OPT1="Generate custom wallpaper (callsign + tagline)"
        DLG_WALLPAPER_OPT2="Select from existing images"
        DLG_WALLPAPER_OPT3="Use default from overlay"
        MSG_CUSTOM_WALLPAPER_TITLE="=== Custom Wallpaper Generator ==="
        MSG_ENTER_CALLSIGN="Enter callsign (e.g., VA2OPS): "
        MSG_ENTER_TAGLINE="Enter tagline (optional, press Enter to skip): "
        MSG_TEXT_COLOR_OPTIONS="Text color options:"
        MSG_COLOR_WHITE="White (default)"
        MSG_COLOR_GRAY="Light gray"
        MSG_COLOR_ORANGE="Orange (ham radio style)"
        MSG_COLOR_BLUE="Light blue"
        MSG_SELECT_COLOR="Select color [1]: "
        MSG_GENERATING_WALLPAPER="Generating wallpaper..."
        MSG_WALLPAPER_GENERATED="Wallpaper generated:"
        MSG_NO_CALLSIGN_DEFAULT="No callsign entered, using default wallpaper."
        MSG_BASE_IMAGE_NOT_FOUND="Base image not found:"
        MSG_COPY_BASE_IMAGE="Please copy emcomm-base.png to backgrounds/ directory"
        MSG_USING_DEFAULT_WALLPAPER="Using default wallpaper from overlay."
        DLG_WALLPAPER_SELECT_TITLE="Wallpaper Selection"
        DLG_WALLPAPER_SELECT_MENU="Select wallpaper for the ISO:"
        MSG_SELECTED_WALLPAPER="Selected wallpaper:"
        MSG_NO_WALLPAPERS_FOUND="No wallpapers found in"
        MSG_WALLPAPER_DIR_NOT_FOUND="Wallpaper directory not found:"
        
        # Boot Logo
        DLG_BOOTLOGO_TITLE="Boot Logo Configuration"
        DLG_BOOTLOGO_MENU="Generate custom Plymouth boot logo?\n(Replaces Debian yellow helmet during boot)"
        DLG_BOOTLOGO_OPT1="Yes - With callsign text"
        DLG_BOOTLOGO_OPT2="Yes - Without callsign text (logo only)"
        DLG_BOOTLOGO_OPT3="No - Keep Debian default"
        MSG_ENTER_CALLSIGN_BOOTLOGO="Enter callsign for boot logo (e.g., VA2OPS): "
        MSG_GENERATING_BOOTLOGO_CALLSIGN="Generating boot logo with callsign:"
        MSG_NO_CALLSIGN_NO_TEXT="No callsign entered, generating logo without text"
        MSG_GENERATING_BOOTLOGO_NOTEXT="Generating boot logo (no callsign)..."
        MSG_BOOTLOGO_SUCCESS="Boot logo generated successfully!"
        MSG_BOOTLOGO_FAILED="Warning: Failed to generate boot logo"
        MSG_CANNOT_GENERATE_BOOTLOGO="Cannot generate boot logo."
        MSG_USING_DEFAULT_BOOTLOGO="Using Debian default boot logo (yellow helmet)"
        
        # MOTD
        DLG_MOTD_TITLE="MOTD / Banner Selection"
        DLG_MOTD_MENU="Select terminal banner for the ISO:"
        DLG_MOTD_DEFAULT="Default (from overlay)"
        MSG_SELECTED_MOTD="Selected MOTD:"
        MSG_USING_DEFAULT_MOTD="Using default MOTD from overlay"
        MSG_NO_MOTD_FILES="No MOTD files found in"
        MSG_MOTD_DIR_NOT_FOUND="MOTD directory not found:"
        MSG_CREATE_MOTD_DIR="Create it and add text files to select a custom banner."
        
        # ISO Type Selection
        DLG_ISO_TYPE_TITLE="ISO Type"
        DLG_ISO_TYPE_MENU="Select the ISO type to build:\n\nVarAC is distributed under a Limited Distribution Agreement.\nLicense will be presented on first launch."
        DLG_ISO_TYPE_COMPLETE="Complete - With VARA + VarAC pre-installed"
        DLG_ISO_TYPE_LITE="Lite - Without Wine/VARA/VarAC"
        MSG_ISO_COMPLETE_SELECTED="COMPLETE ISO selected"
        MSG_VARA_VARAC_INCLUDED="VARA HF/FM and VarAC will be included in the ISO"
        MSG_LICENSE_ENFORCED="VarAC license agreement will be presented on first launch"
        MSG_ISO_LITE_SELECTED="LITE ISO selected"
        MSG_NO_WINE_INCLUDED="Wine/VARA/VarAC will NOT be included"
        
        # Wine Prefix Selection
        DLG_WINE_TITLE="Wine Prefix Selection"
        DLG_WINE_MENU="Select Wine folder to include in ISO:"
        MSG_SELECTED_WINE="Selected Wine folder:"
        MSG_NO_WINE_SELECTED="No Wine folder selected. Build cancelled."
        MSG_NO_WINE_FOLDERS="No Wine folders found in"
        MSG_WINE_DIR_NOT_FOUND="wine-sources directory not found:"
        MSG_CREATE_WINE_DIR="Please create the directory and add your Wine folders."
        MSG_ERROR_WINE_NOT_FOUND="ERROR: Wine folder not found:"
        MSG_WINE_CHECKING="Checking Wine prefix..."
        MSG_WINE_VARAC_OK="✓ VarAC.exe found"
        MSG_WINE_LICENSE_OK="✓ License.txt found"
        MSG_WINE_VARAC_MISSING="⚠ VarAC.exe missing in this prefix"
        MSG_WINE_LICENSE_MISSING="⚠ License.txt missing (required for license enforcement)"
        MSG_COPYING_WINE="Copying Wine prefix:"
        MSG_SKIPPING_WINE="Wine prefix not included (Lite ISO)"
        MSG_WINE_SUMMARY_COMPLETE="Wine: VARA + VarAC included (license enforced)"
        MSG_WINE_SUMMARY_LITE="Wine: Not included (Lite ISO)"
        
        # Build process
        MSG_BUILD_START_LINE1="║  Starting build process...                                            ║"
        MSG_BUILD_START_LINE3="║  NOTE: After entering your sudo password, the script will take        ║"
        MSG_BUILD_START_LINE4="║  1-2 minutes before showing any output. Please be patient!            ║"
        MSG_CHECKING_CACHE="Checking for existing cache..."
        MSG_SAVING_CACHE="Saving package cache..."
        MSG_CLEANING_BUILD="Cleaning old build..."
        MSG_RESTORING_CACHE="Restoring package cache..."
        MSG_CACHE_RESTORED="Cache restored! Build will be faster."
        MSG_ERROR_WRONG_DIR="ERROR: Not in correct directory! Expected:"
        MSG_CONFIGURING_LIVEBUILD="Configuring live-build..."
        MSG_COPYING_PACKAGES="Copying package list..."
        MSG_COPYING_OVERLAY="Copying overlay..."
        MSG_SETTING_WALLPAPER="Setting up wallpaper..."
        MSG_COPYING_GEN_WALLPAPER="Copying generated wallpaper..."
        MSG_COPYING_SEL_WALLPAPER="Copying selected wallpaper:"
        MSG_USING_OVERLAY_WALLPAPER="Using default wallpaper from overlay"
        MSG_WARNING_NO_WALLPAPER="Warning: No wallpaper found!"
        MSG_SETTING_PLYMOUTH="Setting up Plymouth boot branding..."
        MSG_BOOTLOGO_INSTALLED="Boot logo installed (replaces Debian yellow helmet)"
        MSG_CREATING_PLYMOUTH_HOOK="Creating Plymouth configuration hook..."
        MSG_CONFIGURING_PLYMOUTH="Configuring Plymouth boot branding..."
        MSG_PLYMOUTH_CONFIGURED="Plymouth branding configured."
        MSG_PLYMOUTH_HOOK_CREATED="Plymouth hook created: 0050-plymouth-branding.hook.chroot"
        MSG_COPYING_MOTD="Copying selected MOTD:"
        MSG_CLEANING_UBUNTU="Cleaning Ubuntu-specific files..."
        MSG_CLEANING_ETUSER="Cleaning et-user variants..."
        MSG_COPYING_WINE="Copying Wine prefix from:"
        MSG_CREATING_SCRIPTS="Creating EmComm-Tools scripts..."
        MSG_COPYING_AUTOSTART="Copying first-boot autostart entry..."
        MSG_VARAC_ICON_FOUND="VarAC icon found in overlay"
        MSG_ICONS_COPIED="Icons copied to pixmaps for Debian compatibility"
        MSG_WARNING_VARAC_ICON="WARNING: VarAC icon not found in overlay"
        MSG_CREATING_HOOKS="Creating hooks..."
        MSG_COPYING_ENVIRONMENT="Copying /etc/environment..."
        MSG_ADDING_LAUNCHERS="Adding XFCE panel launchers..."
        MSG_ADDING_FUSE="Adding fuse fix..."
        MSG_COPYING_MAP_HOOK="Copying map download hook..."
        MSG_MAP_HOOK_COPIED="Map download hook copied."
        MSG_SKIPPING_MAP_DOWNLOAD="Skipping map download (external drive mode)."
        
        # Setup complete
        MSG_SETUP_COMPLETE="=== Setup complete! ==="
        MSG_USER_ACCOUNT="User account: user / live (autologin enabled)"
        MSG_MAPS_INCLUDED_SUMMARY="Maps: INCLUDED (ISO will be ~5.5GB)"
        MSG_MAPS_EXTERNAL_SUMMARY="Maps: EXTERNAL DRIVE (ISO will be ~2.8GB)"
        
        # ISO build
        MSG_ISO_BUILD_LINE1="║  Starting ISO build...                                                ║"
        MSG_ISO_BUILD_LINE2="║  This will take 15-30 minutes depending on your internet speed.       ║"
        MSG_ISO_BUILD_LINE3="║  Build log: build.log                                                 ║"
        
        # Build results
        MSG_BUILD_SUCCESS="║  BUILD SUCCESSFUL!                                                    ║"
        MSG_ISO_CREATED="ISO created:"
        MSG_SIZE="Size:"
        MSG_START_QEMU="Start QEMU to test the ISO? (y/n): "
        MSG_STARTING_QEMU="Starting QEMU..."
        MSG_QEMU_STARTED="QEMU started in background."
        MSG_WARNING_ISO_NOT_FOUND="Warning: ISO file not found!"
        MSG_BUILD_FAILED="║  BUILD FAILED!                                                        ║"
        MSG_CHECK_LOG="Check build.log for errors."
        MSG_RETRY_HINT="If build failed due to mirror sync issues, retry with:"
        
        # Yes/No prompt
        MSG_YES_CHAR="y"
        
        # Update System
        DLG_UPDATE_TITLE="Update System Configuration"
        DLG_UPDATE_MENU="Configure automatic update checking?\n\nThis allows users to receive overlay updates\nwithout reinstalling the OS."
        DLG_UPDATE_OPT1="Yes - Public server (emcomm-tools.ca)"
        DLG_UPDATE_OPT2="Yes - Custom URL (club/organization)"
        DLG_UPDATE_OPT3="No - Offline only (manual updates)"
        MSG_UPDATE_CUSTOM_URL="Enter update server URL (no trailing slash): "
        DLG_UPDATE_CHANNEL_TITLE="Update Channel"
        DLG_UPDATE_CHANNEL_MENU="Select update channel:"
        DLG_UPDATE_CHANNEL_STABLE="Stable - Tested releases"
        DLG_UPDATE_CHANNEL_BETA="Beta - Early access"
        DLG_UPDATE_CHANNEL_PERSONAL="Personal - Private builds"
        MSG_UPDATE_ENABLED="Update system enabled:"
        MSG_UPDATE_CHANNEL="Update channel:"
        MSG_UPDATE_DISABLED="Update system disabled (offline mode)"
        MSG_GENERATING_MANIFEST="Generating file catalog (manifest.json)..."
        MSG_MANIFEST_GENERATED="Manifest generated with"
        MSG_MANIFEST_FILES="files"
    fi
}

# Initialize messages based on selected language
set_messages

echo "$MSG_SCRIPT_TITLE"
echo "$MSG_SCRIPT_DIR $SCRIPT_DIR"
echo ""

# =============================================================================
# Architecture Version (v2 only — v1 is frozen, kept as reference in repo)
# =============================================================================
ARCH_VERSION="v2"
echo "$MSG_SELECTED_VERSION $ARCH_VERSION"
echo ""

# =============================================================================
# Overlay Selection (filtered by version)
# =============================================================================
if [ -n "$BUILD_PROFILE" ]; then
    OVERLAY_NAME=$(jq -r '.overlay' "$BUILD_PROFILE")
    SELECTED_OVERLAY="${OVERLAYS_DIR}/${OVERLAY_NAME}"
    OVERLAY_DIR="$SELECTED_OVERLAY/overlay"
    if [ ! -d "$OVERLAY_DIR" ]; then
        OVERLAY_DIR="$SELECTED_OVERLAY"
    fi
    echo "$MSG_SELECTED_OVERLAY $OVERLAY_NAME"
else
    if [ -d "$OVERLAYS_DIR" ]; then
        # Find overlay folders matching selected version
        OVERLAY_FOLDERS=($(find "$OVERLAYS_DIR" -mindepth 1 -maxdepth 1 -type d \
            -name "et-${ARCH_VERSION}-*" | sort))

        if [ ${#OVERLAY_FOLDERS[@]} -gt 0 ]; then
            MENU_OPTIONS=()
            i=1
            for ov in "${OVERLAY_FOLDERS[@]}"; do
                MENU_OPTIONS+=($i "$(basename "$ov")")
                ((i++))
            done

            OV_CHOICE=$(dialog --title "$DLG_OVERLAY_TITLE" \
                --menu "$DLG_OVERLAY_MENU" 15 60 10 \
                "${MENU_OPTIONS[@]}" \
                3>&1 1>&2 2>&3)

            clear

            if [ -n "$OV_CHOICE" ]; then
                SELECTED_OVERLAY="${OVERLAY_FOLDERS[$((OV_CHOICE-1))]}"
                OVERLAY_DIR="$SELECTED_OVERLAY/overlay"

                # Check if overlay subfolder exists, if not use the folder directly
                if [ ! -d "$OVERLAY_DIR" ]; then
                    OVERLAY_DIR="$SELECTED_OVERLAY"
                fi

                echo "$MSG_SELECTED_OVERLAY $(basename "$SELECTED_OVERLAY")"
            else
                echo "$MSG_NO_OVERLAY_SELECTED"
                exit 1
            fi
        else
            echo "$MSG_NO_OVERLAYS_FOUND $OVERLAYS_DIR"
            echo "$MSG_ADD_OVERLAY_FOLDERS"
            exit 1
        fi
    else
        echo "$MSG_OVERLAYS_DIR_NOT_FOUND $OVERLAYS_DIR"
        echo "$MSG_CREATE_OVERLAYS_DIR"
        exit 1
    fi
fi

# Verify overlay exists
if [ ! -d "$OVERLAY_DIR" ]; then
    echo "$MSG_ERROR_OVERLAY_NOT_FOUND $OVERLAY_DIR"
    exit 1
fi

echo "$MSG_USING_OVERLAY $OVERLAY_DIR"
echo ""

# =============================================================================
# Maps Configuration
# =============================================================================
INCLUDE_MAPS="no"

if [ -n "$BUILD_PROFILE" ]; then
    MAPS_INCLUDE=$(jq -r '.maps.include // false' "$BUILD_PROFILE")
    if [ "$MAPS_INCLUDE" = "true" ]; then
        INCLUDE_MAPS="yes"
        echo "$MSG_MAPS_INCLUDED"
    else
        INCLUDE_MAPS="no"
        echo "$MSG_MAPS_NOT_INCLUDED"
    fi
else
    MAP_CHOICE=$(dialog --title "$DLG_MAPS_TITLE" \
        --menu "$DLG_MAPS_MENU" 15 60 3 \
        1 "$DLG_MAPS_OPT1" \
        2 "$DLG_MAPS_OPT2" \
        3 "$DLG_MAPS_OPT3" \
        3>&1 1>&2 2>&3)

    clear

    case $MAP_CHOICE in
        1)
            echo "$MSG_MAPS_NOT_INCLUDED"
            echo "$MSG_MAPS_EXTERNAL_DRIVE"
            INCLUDE_MAPS="no"
            ;;
        2)
            echo "$MSG_MAPS_INCLUDED"
            echo "$MSG_MAPS_WARNING_SIZE"
            INCLUDE_MAPS="yes"
            ;;
        3|"")
            echo "$MSG_BUILD_CANCELLED"
            exit 0
            ;;
    esac

    echo ""
    read -p "$MSG_PRESS_ENTER"
fi

# =============================================================================
# OSM/Navit Map Selection (provinces and states for offline navigation)
# =============================================================================
SELECTED_OSM_REGIONS=""

if [ "$INCLUDE_MAPS" = "yes" ]; then

  if [ -n "$BUILD_PROFILE" ]; then
    # Read OSM regions from profile JSON array
    SELECTED_OSM_REGIONS=$(jq -r '.maps.osm_regions // [] | .[]' "$BUILD_PROFILE" | tr '\n' ' ')

    if [ -n "$SELECTED_OSM_REGIONS" ]; then
        if [ "$SCRIPT_LANG" = "fr" ]; then
            echo "Régions OSM/Navit sélectionnées:"
        else
            echo "Selected OSM/Navit regions:"
        fi
        for region_entry in $SELECTED_OSM_REGIONS; do
            IFS=':' read -r region country <<< "$region_entry"
            echo "  - ${region} (${country})"
        done
        echo ""
    else
        if [ "$SCRIPT_LANG" = "fr" ]; then
            echo "Aucune carte OSM/Navit sélectionnée (tilesets seulement)."
        else
            echo "No OSM/Navit maps selected (tilesets only)."
        fi
        echo ""
    fi
  else
    if [ "$SCRIPT_LANG" = "fr" ]; then
        DLG_OSM_TITLE="Cartes OSM pour navigation Navit"
        DLG_OSM_MENU="Sélectionnez les régions à inclure pour la navigation hors-ligne.\nLes fichiers .pbf seront téléchargés et convertis au format Navit.\n\n[Espace] pour sélectionner, [Entrée] pour confirmer:"
    else
        DLG_OSM_TITLE="OSM Maps for Navit Navigation"
        DLG_OSM_MENU="Select regions to include for offline navigation.\n.pbf files will be downloaded and converted to Navit format.\n\n[Space] to select, [Enter] to confirm:"
    fi

    # Hardcoded region list from Geofabrik
    # Format: tag "Display Name" on/off
    # Tag encodes: region-slug:country
    OSM_REGIONS_DIALOG=(
        # --- Canada ---
        "alberta:canada"                    "CA - Alberta"                     off
        "british-columbia:canada"           "CA - British Columbia"            off
        "manitoba:canada"                   "CA - Manitoba"                    off
        "new-brunswick:canada"              "CA - New Brunswick"               off
        "newfoundland-and-labrador:canada"  "CA - Newfoundland and Labrador"   off
        "northwest-territories:canada"      "CA - Northwest Territories"       off
        "nova-scotia:canada"                "CA - Nova Scotia"                 off
        "nunavut:canada"                    "CA - Nunavut"                     off
        "ontario:canada"                    "CA - Ontario"                     off
        "prince-edward-island:canada"       "CA - Prince Edward Island"        off
        "quebec:canada"                     "CA - Quebec"                      on
        "saskatchewan:canada"               "CA - Saskatchewan"                off
        "yukon:canada"                      "CA - Yukon"                       off
        # --- USA ---
        "alabama:us"        "US - Alabama"          off
        "alaska:us"         "US - Alaska"           off
        "arizona:us"        "US - Arizona"          off
        "arkansas:us"       "US - Arkansas"         off
        "california:us"     "US - California"       off
        "colorado:us"       "US - Colorado"         off
        "connecticut:us"    "US - Connecticut"      off
        "delaware:us"       "US - Delaware"         off
        "district-of-columbia:us" "US - District of Columbia" off
        "florida:us"        "US - Florida"          off
        "georgia:us"        "US - Georgia"          off
        "hawaii:us"         "US - Hawaii"           off
        "idaho:us"          "US - Idaho"            off
        "illinois:us"       "US - Illinois"         off
        "indiana:us"        "US - Indiana"          off
        "iowa:us"           "US - Iowa"             off
        "kansas:us"         "US - Kansas"           off
        "kentucky:us"       "US - Kentucky"         off
        "louisiana:us"      "US - Louisiana"        off
        "maine:us"          "US - Maine"            off
        "maryland:us"       "US - Maryland"         off
        "massachusetts:us"  "US - Massachusetts"    off
        "michigan:us"       "US - Michigan"         off
        "minnesota:us"      "US - Minnesota"        off
        "mississippi:us"    "US - Mississippi"       off
        "missouri:us"       "US - Missouri"         off
        "montana:us"        "US - Montana"          off
        "nebraska:us"       "US - Nebraska"         off
        "nevada:us"         "US - Nevada"           off
        "new-hampshire:us"  "US - New Hampshire"    off
        "new-jersey:us"     "US - New Jersey"       off
        "new-mexico:us"     "US - New Mexico"       off
        "new-york:us"       "US - New York"         off
        "north-carolina:us" "US - North Carolina"   off
        "north-dakota:us"   "US - North Dakota"     off
        "ohio:us"           "US - Ohio"             off
        "oklahoma:us"       "US - Oklahoma"         off
        "oregon:us"         "US - Oregon"           off
        "pennsylvania:us"   "US - Pennsylvania"     off
        "rhode-island:us"   "US - Rhode Island"     off
        "south-carolina:us" "US - South Carolina"   off
        "south-dakota:us"   "US - South Dakota"     off
        "tennessee:us"      "US - Tennessee"        off
        "texas:us"          "US - Texas"            off
        "utah:us"           "US - Utah"             off
        "vermont:us"        "US - Vermont"          off
        "virginia:us"       "US - Virginia"         off
        "washington:us"     "US - Washington"       off
        "west-virginia:us"  "US - West Virginia"    off
        "wisconsin:us"      "US - Wisconsin"        off
        "wyoming:us"        "US - Wyoming"          off
    )

    OSM_SELECTION=$(dialog --title "$DLG_OSM_TITLE" \
        --checklist "$DLG_OSM_MENU" 30 65 20 \
        "${OSM_REGIONS_DIALOG[@]}" \
        3>&1 1>&2 2>&3)

    clear

    if [ -n "$OSM_SELECTION" ]; then
        SELECTED_OSM_REGIONS="$OSM_SELECTION"

        if [ "$SCRIPT_LANG" = "fr" ]; then
            echo "Régions OSM/Navit sélectionnées:"
        else
            echo "Selected OSM/Navit regions:"
        fi

        for region_entry in $SELECTED_OSM_REGIONS; do
            region_entry=$(echo "$region_entry" | tr -d '"')
            IFS=':' read -r region country <<< "$region_entry"
            echo "  - ${region} (${country})"
        done
        echo ""
    else
        if [ "$SCRIPT_LANG" = "fr" ]; then
            echo "Aucune carte OSM/Navit sélectionnée (tilesets seulement)."
        else
            echo "No OSM/Navit maps selected (tilesets only)."
        fi
        echo ""
    fi
  fi # end BUILD_PROFILE / interactive OSM selection
fi

# =============================================================================
# Wallpaper Selection
# =============================================================================
WALLPAPER_BASE="$WALLPAPER_DIR/emcomm-base.png"
SELECTED_WALLPAPER=""
GENERATED_WALLPAPER=""

# Check for ImageMagick
if ! command -v convert &> /dev/null; then
    echo "$MSG_INSTALLING_IMAGEMAGICK"
    sudo apt install -y imagemagick
fi

if [ -n "$BUILD_PROFILE" ]; then
    # Profile mode: generate/select/default wallpaper without dialogs
    WP_PROFILE_MODE=$(jq -r '.wallpaper.mode // "default"' "$BUILD_PROFILE")

    case $WP_PROFILE_MODE in
        generate)
            WP_CALLSIGN=$(jq -r '.wallpaper.callsign // empty' "$BUILD_PROFILE")
            WP_TAGLINE=$(jq -r '.wallpaper.tagline // empty' "$BUILD_PROFILE")
            WP_COLOR_CHOICE=$(jq -r '.wallpaper.color // 1' "$BUILD_PROFILE")
            CENTER_SIZE=$(jq -r '.wallpaper.center_size // 120' "$BUILD_PROFILE")
            TAG_SIZE=$(jq -r '.wallpaper.tag_size // 72' "$BUILD_PROFILE")
            TAG_OFFSET=$(jq -r '.wallpaper.tag_offset // 200' "$BUILD_PROFILE")

            case "${WP_COLOR_CHOICE}" in
                2) WP_CALLSIGN_COLOR="rgba(200,200,200,0.90)"; WP_TAG_COLOR="rgba(170,170,170,0.80)" ;;
                3) WP_CALLSIGN_COLOR="rgba(255,165,0,0.90)"; WP_TAG_COLOR="rgba(255,200,100,0.80)" ;;
                4) WP_CALLSIGN_COLOR="rgba(135,206,250,0.90)"; WP_TAG_COLOR="rgba(173,216,230,0.80)" ;;
                *) WP_CALLSIGN_COLOR="rgba(255,255,255,0.90)"; WP_TAG_COLOR="rgba(200,200,200,0.75)" ;;
            esac

            if [ -n "$WP_CALLSIGN" ] && [ -f "$WALLPAPER_BASE" ]; then
                GENERATED_WALLPAPER="/tmp/generated-wallpaper.png"
                RESIZED_BASE="/tmp/wallpaper-4k-base.png"

                convert "$WALLPAPER_BASE" \
                    -resize 3840x2160^ \
                    -gravity center \
                    -extent 3840x2160 \
                    "$RESIZED_BASE"

                echo "$MSG_GENERATING_WALLPAPER"
                if [ -n "$WP_TAGLINE" ]; then
                    convert "$RESIZED_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize $CENTER_SIZE \
                        -fill "$WP_CALLSIGN_COLOR" \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        -gravity south \
                        -font "DejaVu-Sans" \
                        -pointsize $TAG_SIZE \
                        -fill "$WP_TAG_COLOR" \
                        -annotate +0+$TAG_OFFSET "$WP_TAGLINE" \
                        "$GENERATED_WALLPAPER"
                else
                    convert "$RESIZED_BASE" \
                        -gravity center \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize $CENTER_SIZE \
                        -fill "$WP_CALLSIGN_COLOR" \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        "$GENERATED_WALLPAPER"
                fi

                rm -f "$RESIZED_BASE"
                echo "$MSG_WALLPAPER_GENERATED $WP_CALLSIGN"
            else
                echo "$MSG_USING_DEFAULT_WALLPAPER"
            fi
            ;;
        select)
            WP_FILENAME=$(jq -r '.wallpaper.filename // empty' "$BUILD_PROFILE")
            if [ -n "$WP_FILENAME" ] && [ -f "$WALLPAPER_DIR/$WP_FILENAME" ]; then
                SELECTED_WALLPAPER="$WALLPAPER_DIR/$WP_FILENAME"
                echo "$MSG_SELECTED_WALLPAPER $WP_FILENAME"
            else
                echo "$MSG_USING_DEFAULT_WALLPAPER"
            fi
            ;;
        *)
            echo "$MSG_USING_DEFAULT_WALLPAPER"
            ;;
    esac
else
    # Interactive wallpaper mode selection
    WP_MODE=$(dialog --title "$DLG_WALLPAPER_TITLE" \
        --menu "$DLG_WALLPAPER_MENU" 15 60 3 \
        1 "$DLG_WALLPAPER_OPT1" \
        2 "$DLG_WALLPAPER_OPT2" \
        3 "$DLG_WALLPAPER_OPT3" \
        3>&1 1>&2 2>&3)

    clear

    case $WP_MODE in
    1)
        # Generate custom wallpaper with preview loop
        if [ -f "$WALLPAPER_BASE" ]; then
            echo "$MSG_CUSTOM_WALLPAPER_TITLE"
            echo ""
            read -p "$MSG_ENTER_CALLSIGN" WP_CALLSIGN
            read -p "$MSG_ENTER_TAGLINE" WP_TAGLINE
            echo ""
            echo "$MSG_TEXT_COLOR_OPTIONS"
            echo "  1) $MSG_COLOR_WHITE"
            echo "  2) $MSG_COLOR_GRAY"
            echo "  3) $MSG_COLOR_ORANGE"
            echo "  4) $MSG_COLOR_BLUE"
            read -p "$MSG_SELECT_COLOR" WP_COLOR_CHOICE
            
            # Set colors based on choice
            case "${WP_COLOR_CHOICE:-1}" in
                2) WP_CALLSIGN_COLOR="rgba(200,200,200,0.90)"; WP_TAG_COLOR="rgba(170,170,170,0.80)" ;;
                3) WP_CALLSIGN_COLOR="rgba(255,165,0,0.90)"; WP_TAG_COLOR="rgba(255,200,100,0.80)" ;;
                4) WP_CALLSIGN_COLOR="rgba(135,206,250,0.90)"; WP_TAG_COLOR="rgba(173,216,230,0.80)" ;;
                *) WP_CALLSIGN_COLOR="rgba(255,255,255,0.90)"; WP_TAG_COLOR="rgba(200,200,200,0.75)" ;;
            esac
            
            if [ -n "$WP_CALLSIGN" ]; then
                GENERATED_WALLPAPER="/tmp/generated-wallpaper.png"
                PREVIEW_WALLPAPER="/tmp/preview-wallpaper.png"
                
                # Resize base to 4K
                RESIZED_BASE="/tmp/wallpaper-4k-base.png"
                convert "$WALLPAPER_BASE" \
                    -resize 3840x2160^ \
                    -gravity center \
                    -extent 3840x2160 \
                    "$RESIZED_BASE"
                
                # =============================================================
                # Font Size Configuration with Preview Loop
                # =============================================================
                # Default values
                DEFAULT_CENTER_SIZE=120
                DEFAULT_TAG_SIZE=72        # Doubled from 36
                DEFAULT_TAG_OFFSET=200     # Higher up from bottom (was 120)
                DEFAULT_PANEL_HEIGHT=96    # XFCE panel at 4K (48px at 1080p)
                
                # Max width for center text (inner circle ~1400px at 4K)
                MAX_TEXT_WIDTH=1400
                
                # Initialize settings
                WALLPAPER_ACCEPTED="no"
                CENTER_SIZE=$DEFAULT_CENTER_SIZE
                TAG_SIZE=$DEFAULT_TAG_SIZE
                TAG_OFFSET=$DEFAULT_TAG_OFFSET
                PANEL_HEIGHT=$DEFAULT_PANEL_HEIGHT
                
                while [ "$WALLPAPER_ACCEPTED" != "yes" ]; do
                    echo ""
                    echo "=============================================="
                    if [ "$SCRIPT_LANG" = "fr" ]; then
                        echo "Configuration de la taille des polices"
                        echo "=============================================="
                        echo "Taille actuelle du texte central: $CENTER_SIZE"
                        echo "Taille actuelle du slogan: $TAG_SIZE"
                        echo "Position du slogan (depuis le bas): $TAG_OFFSET px"
                        echo "Hauteur du panneau XFCE (simulation): $PANEL_HEIGHT px"
                        echo ""
                        echo "Options:"
                        echo "  1) Générer avec ces paramètres"
                        echo "  2) Modifier la taille du texte central"
                        echo "  3) Modifier la taille du slogan"
                        echo "  4) Modifier la position du slogan"
                        echo "  5) Auto-ajuster le texte central au cercle"
                        echo "  6) Modifier la hauteur du panneau (simulation)"
                        read -p "Choix [1]: " FONT_CHOICE
                    else
                        echo "Font Size Configuration"
                        echo "=============================================="
                        echo "Current center text size: $CENTER_SIZE"
                        echo "Current tagline size: $TAG_SIZE"
                        echo "Tagline position (from bottom): $TAG_OFFSET px"
                        echo "XFCE panel height (simulation): $PANEL_HEIGHT px"
                        echo ""
                        echo "Options:"
                        echo "  1) Generate with these settings"
                        echo "  2) Change center text size"
                        echo "  3) Change tagline size"
                        echo "  4) Change tagline position"
                        echo "  5) Auto-fit center text to circle"
                        echo "  6) Change panel height (simulation)"
                        read -p "Choice [1]: " FONT_CHOICE
                    fi
                    
                    case "${FONT_CHOICE:-1}" in
                        2)
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                read -p "Nouvelle taille du texte central (60-200) [$CENTER_SIZE]: " NEW_SIZE
                            else
                                read -p "New center text size (60-200) [$CENTER_SIZE]: " NEW_SIZE
                            fi
                            [ -n "$NEW_SIZE" ] && CENTER_SIZE=$NEW_SIZE
                            continue
                            ;;
                        3)
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                read -p "Nouvelle taille du slogan (24-120) [$TAG_SIZE]: " NEW_SIZE
                            else
                                read -p "New tagline size (24-120) [$TAG_SIZE]: " NEW_SIZE
                            fi
                            [ -n "$NEW_SIZE" ] && TAG_SIZE=$NEW_SIZE
                            continue
                            ;;
                        4)
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                read -p "Nouvelle position du slogan en pixels depuis le bas (100-400) [$TAG_OFFSET]: " NEW_POS
                            else
                                read -p "New tagline position in pixels from bottom (100-400) [$TAG_OFFSET]: " NEW_POS
                            fi
                            [ -n "$NEW_POS" ] && TAG_OFFSET=$NEW_POS
                            continue
                            ;;
                        5)
                            # Auto-fit: reduce font size until text fits
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                echo "Auto-ajustement de la taille du texte..."
                            else
                                echo "Auto-fitting text size..."
                            fi
                            
                            CENTER_SIZE=160
                            while [ $CENTER_SIZE -gt 60 ]; do
                                TEXT_LEN=${#WP_CALLSIGN}
                                EST_WIDTH=$(( TEXT_LEN * CENTER_SIZE * 6 / 10 ))
                                
                                if [ $EST_WIDTH -le $MAX_TEXT_WIDTH ]; then
                                    break
                                fi
                                CENTER_SIZE=$((CENTER_SIZE - 10))
                            done
                            
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                echo "Taille auto-ajustée: $CENTER_SIZE"
                            else
                                echo "Auto-fitted size: $CENTER_SIZE"
                            fi
                            continue
                            ;;
                        6)
                            if [ "$SCRIPT_LANG" = "fr" ]; then
                                echo "Tailles de panneau courantes:"
                                echo "  48  = Petit panneau (1080p)"
                                echo "  96  = Panneau par défaut (4K)"
                                echo "  128 = Grand panneau"
                                read -p "Nouvelle hauteur du panneau [$PANEL_HEIGHT]: " NEW_HEIGHT
                            else
                                echo "Common panel sizes:"
                                echo "  48  = Small panel (1080p)"
                                echo "  96  = Default panel (4K scaled)"
                                echo "  128 = Large panel"
                                read -p "New panel height [$PANEL_HEIGHT]: " NEW_HEIGHT
                            fi
                            [ -n "$NEW_HEIGHT" ] && PANEL_HEIGHT=$NEW_HEIGHT
                            continue
                            ;;
                    esac
                    
                    # Generate the wallpaper
                    if [ "$SCRIPT_LANG" = "fr" ]; then
                        echo "Génération du fond d'écran..."
                    else
                        echo "Generating wallpaper..."
                    fi
                    
                    if [ -n "$WP_TAGLINE" ]; then
                        convert "$RESIZED_BASE" \
                            -gravity center \
                            -font "DejaVu-Sans-Bold" \
                            -pointsize $CENTER_SIZE \
                            -fill "$WP_CALLSIGN_COLOR" \
                            -annotate +0+0 "$WP_CALLSIGN" \
                            -gravity south \
                            -font "DejaVu-Sans" \
                            -pointsize $TAG_SIZE \
                            -fill "$WP_TAG_COLOR" \
                            -annotate +0+$TAG_OFFSET "$WP_TAGLINE" \
                            "$GENERATED_WALLPAPER"
                    else
                        convert "$RESIZED_BASE" \
                            -gravity center \
                            -font "DejaVu-Sans-Bold" \
                            -pointsize $CENTER_SIZE \
                            -fill "$WP_CALLSIGN_COLOR" \
                            -annotate +0+0 "$WP_CALLSIGN" \
                            "$GENERATED_WALLPAPER"
                    fi
                    
                    # Create preview with simulated XFCE panel at bottom
                    convert "$GENERATED_WALLPAPER" \
                        -fill "rgba(0,0,0,0.85)" \
                        -draw "rectangle 0,$((2160 - PANEL_HEIGHT)) 3840,2160" \
                        "$PREVIEW_WALLPAPER"
                    
                    # Open preview
                    if [ "$SCRIPT_LANG" = "fr" ]; then
                        echo ""
                        echo "Ouverture de l'aperçu..."
                    else
                        echo ""
                        echo "Opening preview..."
                    fi
                    
                    # Try different image viewers
                    if command -v xdg-open &> /dev/null; then
                        xdg-open "$PREVIEW_WALLPAPER" 2>/dev/null &
                    elif command -v eog &> /dev/null; then
                        eog "$PREVIEW_WALLPAPER" 2>/dev/null &
                    elif command -v feh &> /dev/null; then
                        feh "$PREVIEW_WALLPAPER" 2>/dev/null &
                    elif command -v display &> /dev/null; then
                        display "$PREVIEW_WALLPAPER" 2>/dev/null &
                    fi
                    
                    sleep 1
                    
                    echo ""
                    if [ "$SCRIPT_LANG" = "fr" ]; then
                        echo "=============================================="
                        echo "Vérifiez l'aperçu du fond d'écran"
                        echo "=============================================="
                        read -p "Accepter ce fond d'écran? (o/n) [o]: " ACCEPT_CHOICE
                        if [ "${ACCEPT_CHOICE,,}" = "n" ]; then
                            echo "Réessayons avec de nouveaux paramètres..."
                        else
                            WALLPAPER_ACCEPTED="yes"
                            echo "Fond d'écran accepté!"
                        fi
                    else
                        echo "=============================================="
                        echo "Check the wallpaper preview"
                        echo "=============================================="
                        read -p "Accept this wallpaper? (y/n) [y]: " ACCEPT_CHOICE
                        if [ "${ACCEPT_CHOICE,,}" = "n" ]; then
                            echo "Let's try again with new settings..."
                        else
                            WALLPAPER_ACCEPTED="yes"
                            echo "Wallpaper accepted!"
                        fi
                    fi
                done
                
                rm -f "$RESIZED_BASE" "$PREVIEW_WALLPAPER"
                
                echo "$MSG_WALLPAPER_GENERATED $WP_CALLSIGN"
            else
                echo "$MSG_NO_CALLSIGN_DEFAULT"
            fi
        else
            echo "$MSG_BASE_IMAGE_NOT_FOUND $WALLPAPER_BASE"
            echo "$MSG_COPY_BASE_IMAGE"
            echo "$MSG_USING_DEFAULT_WALLPAPER"
        fi
        ;;
    2)
        # Select from existing images
        if [ -d "$WALLPAPER_DIR" ]; then
            WALLPAPERS=($(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) ! -name "emcomm-base.png" | sort))
            
            if [ ${#WALLPAPERS[@]} -gt 0 ]; then
                MENU_OPTIONS=()
                i=1
                for wp in "${WALLPAPERS[@]}"; do
                    MENU_OPTIONS+=($i "$(basename "$wp")")
                    ((i++))
                done
                
                WP_CHOICE=$(dialog --title "$DLG_WALLPAPER_SELECT_TITLE" \
                    --menu "$DLG_WALLPAPER_SELECT_MENU" 20 60 10 \
                    "${MENU_OPTIONS[@]}" \
                    3>&1 1>&2 2>&3)
                
                clear
                
                if [ -n "$WP_CHOICE" ]; then
                    SELECTED_WALLPAPER="${WALLPAPERS[$((WP_CHOICE-1))]}"
                    echo "$MSG_SELECTED_WALLPAPER $(basename "$SELECTED_WALLPAPER")"
                fi
            else
                echo "$MSG_NO_WALLPAPERS_FOUND $WALLPAPER_DIR"
            fi
        else
            echo "$MSG_WALLPAPER_DIR_NOT_FOUND $WALLPAPER_DIR"
        fi
        ;;
    3|"")
        echo "$MSG_USING_DEFAULT_WALLPAPER"
        ;;
    esac
fi # end BUILD_PROFILE / interactive wallpaper

# =============================================================================
# Boot Logo Generation (Plymouth - replaces Debian yellow helmet)
# =============================================================================
GENERATED_BOOT_LOGO=""

if [ -n "$BUILD_PROFILE" ]; then
    BOOT_LOGO_PROFILE=$(jq -r '.boot_logo // "default"' "$BUILD_PROFILE")
    case $BOOT_LOGO_PROFILE in
        callsign) BOOT_LOGO_CHOICE="1" ;;
        logo-only) BOOT_LOGO_CHOICE="2" ;;
        *) BOOT_LOGO_CHOICE="3" ;;
    esac
else
    BOOT_LOGO_CHOICE=$(dialog --title "$DLG_BOOTLOGO_TITLE" \
        --menu "$DLG_BOOTLOGO_MENU" 14 65 3 \
        1 "$DLG_BOOTLOGO_OPT1" \
        2 "$DLG_BOOTLOGO_OPT2" \
        3 "$DLG_BOOTLOGO_OPT3" \
        3>&1 1>&2 2>&3)

    clear
fi

case $BOOT_LOGO_CHOICE in
    1|2)
        if [ -f "$WALLPAPER_BASE" ]; then
            GENERATED_BOOT_LOGO="/tmp/boot-logo.png"
            
            # Get image height for center square crop
            IMG_HEIGHT=$(identify -format "%h" "$WALLPAPER_BASE")
            
            if [ "$BOOT_LOGO_CHOICE" = "1" ]; then
                # With callsign - reuse from wallpaper or ask
                if [ -z "$WP_CALLSIGN" ]; then
                    read -p "$MSG_ENTER_CALLSIGN_BOOTLOGO" WP_CALLSIGN
                fi
                
                if [ -n "$WP_CALLSIGN" ]; then
                    echo "$MSG_GENERATING_BOOTLOGO_CALLSIGN $WP_CALLSIGN"
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -crop "${IMG_HEIGHT}x${IMG_HEIGHT}+0+0" \
                        +repage \
                        -resize "1440x1440" \
                        -depth 16 \
                        -font "DejaVu-Sans-Bold" \
                        -pointsize 160 \
                        -fill "rgba(255,255,255,0.95)" \
                        -gravity center \
                        -annotate +0+0 "$WP_CALLSIGN" \
                        "$GENERATED_BOOT_LOGO"
                else
                    echo "$MSG_NO_CALLSIGN_NO_TEXT"
                    convert "$WALLPAPER_BASE" \
                        -gravity center \
                        -crop "${IMG_HEIGHT}x${IMG_HEIGHT}+0+0" \
                        +repage \
                        -resize "1440x1440" \
                        -depth 16 \
                        "$GENERATED_BOOT_LOGO"
                fi
            else
                # Without callsign - just the graphic
                echo "$MSG_GENERATING_BOOTLOGO_NOTEXT"
                convert "$WALLPAPER_BASE" \
                    -gravity center \
                    -crop "${IMG_HEIGHT}x${IMG_HEIGHT}+0+0" \
                    +repage \
                    -resize "1440x1440" \
                    -depth 16 \
                    "$GENERATED_BOOT_LOGO"
            fi
            
            if [ -f "$GENERATED_BOOT_LOGO" ]; then
                echo "$MSG_BOOTLOGO_SUCCESS"
            else
                echo "$MSG_BOOTLOGO_FAILED"
                GENERATED_BOOT_LOGO=""
            fi
        else
            echo "$MSG_BASE_IMAGE_NOT_FOUND $WALLPAPER_BASE"
            echo "$MSG_CANNOT_GENERATE_BOOTLOGO"
        fi
        ;;
    *)
        echo "$MSG_USING_DEFAULT_BOOTLOGO"
        ;;
esac

# =============================================================================
# Update System Configuration
# =============================================================================
UPDATE_ENABLED="false"
UPDATE_URL=""
UPDATE_CHANNEL="stable"

if [ -n "$BUILD_PROFILE" ]; then
    UPDATE_ENABLED=$(jq -r '.update.enabled // false' "$BUILD_PROFILE")
    if [ "$UPDATE_ENABLED" = "true" ]; then
        UPDATE_URL=$(jq -r '.update.url // "https://emcomm-tools.ca/updates"' "$BUILD_PROFILE")
        UPDATE_CHANNEL=$(jq -r '.update.channel // "stable"' "$BUILD_PROFILE")
        echo "$MSG_UPDATE_ENABLED $UPDATE_URL"
        echo "$MSG_UPDATE_CHANNEL $UPDATE_CHANNEL"
    else
        echo "$MSG_UPDATE_DISABLED"
    fi
else
    UPDATE_CHOICE=$(dialog --title "$DLG_UPDATE_TITLE" \
        --menu "$DLG_UPDATE_MENU" 16 65 3 \
        1 "$DLG_UPDATE_OPT1" \
        2 "$DLG_UPDATE_OPT2" \
        3 "$DLG_UPDATE_OPT3" \
        3>&1 1>&2 2>&3)

    clear

    case $UPDATE_CHOICE in
        1)
            UPDATE_ENABLED="true"
            UPDATE_URL="https://emcomm-tools.ca/updates"
            echo "$MSG_UPDATE_ENABLED $UPDATE_URL"
            ;;
        2)
            UPDATE_ENABLED="true"
            read -p "$MSG_UPDATE_CUSTOM_URL" UPDATE_URL
            if [ -z "$UPDATE_URL" ]; then
                UPDATE_URL="https://emcomm-tools.ca/updates"
            fi
            echo "$MSG_UPDATE_ENABLED $UPDATE_URL"
            ;;
        3|"")
            UPDATE_ENABLED="false"
            echo "$MSG_UPDATE_DISABLED"
            ;;
    esac

    # Channel selection (only if updates enabled)
    if [ "$UPDATE_ENABLED" = "true" ]; then
        CHANNEL_CHOICE=$(dialog --title "$DLG_UPDATE_CHANNEL_TITLE" \
            --menu "$DLG_UPDATE_CHANNEL_MENU" 12 50 3 \
            1 "$DLG_UPDATE_CHANNEL_STABLE" \
            2 "$DLG_UPDATE_CHANNEL_BETA" \
            3 "$DLG_UPDATE_CHANNEL_PERSONAL" \
            3>&1 1>&2 2>&3)

        clear

        case $CHANNEL_CHOICE in
            1) UPDATE_CHANNEL="stable" ;;
            2) UPDATE_CHANNEL="beta" ;;
            3) UPDATE_CHANNEL="personal" ;;
            *) UPDATE_CHANNEL="stable" ;;
        esac

        echo "$MSG_UPDATE_CHANNEL $UPDATE_CHANNEL"
    fi
fi # end BUILD_PROFILE / interactive update config

echo ""

# =============================================================================
# MOTD (Banner) Selection
# =============================================================================
SELECTED_MOTD=""

if [ -n "$BUILD_PROFILE" ]; then
    MOTD_VALUE=$(jq -r '.motd // "default"' "$BUILD_PROFILE")
    if [ "$MOTD_VALUE" != "default" ]; then
        SELECTED_MOTD="$MOTD_DIR/$MOTD_VALUE"
        echo "$MSG_SELECTED_MOTD $MOTD_VALUE"
    else
        echo "$MSG_USING_DEFAULT_MOTD"
    fi
else
    if [ -d "$MOTD_DIR" ]; then
        # Find all MOTD files
        MOTD_FILES=($(find "$MOTD_DIR" -maxdepth 1 -type f | sort))

        if [ ${#MOTD_FILES[@]} -gt 0 ]; then
            # Build dialog menu
            MENU_OPTIONS=()
            MENU_OPTIONS+=(0 "$DLG_MOTD_DEFAULT")
            i=1
            for motd in "${MOTD_FILES[@]}"; do
                MENU_OPTIONS+=($i "$(basename "$motd")")
                ((i++))
            done

            MOTD_CHOICE=$(dialog --title "$DLG_MOTD_TITLE" \
                --menu "$DLG_MOTD_MENU" 20 60 10 \
                "${MENU_OPTIONS[@]}" \
                3>&1 1>&2 2>&3)

            clear

            if [ -n "$MOTD_CHOICE" ] && [ "$MOTD_CHOICE" != "0" ]; then
                SELECTED_MOTD="${MOTD_FILES[$((MOTD_CHOICE-1))]}"
                echo "$MSG_SELECTED_MOTD $(basename "$SELECTED_MOTD")"
            else
                echo "$MSG_USING_DEFAULT_MOTD"
            fi
        else
            echo "$MSG_NO_MOTD_FILES $MOTD_DIR"
        fi
    else
        echo "$MSG_MOTD_DIR_NOT_FOUND $MOTD_DIR"
        echo "$MSG_CREATE_MOTD_DIR"
    fi
fi

# =============================================================================
# ISO Type Selection (Complete vs Lite)
# =============================================================================
# VarAC is distributed under a Limited Distribution Agreement with Irad (4Z1AC).
# Wine prefixes containing VarAC must ONLY be distributed as part of the ISO
# where license acceptance is enforced via et-varac.
# SourceForge downloads of .wine32 with VarAC are NOT permitted.

echo ""

INCLUDE_WINE32="no"
WINE_PREFIX_PATH=""
SELECTED_WINE=""

if [ -n "$BUILD_PROFILE" ]; then
    ISO_TYPE_VALUE=$(jq -r '.iso_type // "complete"' "$BUILD_PROFILE")
    if [ "$ISO_TYPE_VALUE" = "lite" ]; then
        INCLUDE_WINE32="no"
        echo "$MSG_ISO_LITE_SELECTED"
        echo "  $MSG_NO_WINE_INCLUDED"
    else
        INCLUDE_WINE32="yes"
        echo "$MSG_ISO_COMPLETE_SELECTED"
        echo "  $MSG_VARA_VARAC_INCLUDED"
        echo "  $MSG_LICENSE_ENFORCED"
    fi
    echo ""
else
    ISO_TYPE_CHOICE=$(dialog --title "$DLG_ISO_TYPE_TITLE" \
        --menu "$DLG_ISO_TYPE_MENU" 15 70 2 \
        1 "$DLG_ISO_TYPE_COMPLETE" \
        2 "$DLG_ISO_TYPE_LITE" \
        3>&1 1>&2 2>&3)

    clear

    case $ISO_TYPE_CHOICE in
        1)
            INCLUDE_WINE32="yes"
            echo "$MSG_ISO_COMPLETE_SELECTED"
            echo "  $MSG_VARA_VARAC_INCLUDED"
            echo "  $MSG_LICENSE_ENFORCED"
            echo ""
            ;;
        2)
            INCLUDE_WINE32="no"
            echo "$MSG_ISO_LITE_SELECTED"
            echo "  $MSG_NO_WINE_INCLUDED"
            echo ""
            ;;
        *)
            echo "$MSG_BUILD_CANCELLED"
            exit 0
            ;;
    esac
fi

# =============================================================================
# Wine Source Selection (only if Complete ISO selected)
# =============================================================================
if [ "$INCLUDE_WINE32" = "yes" ]; then

  if [ -n "$BUILD_PROFILE" ]; then
    SELECTED_WINE=$(jq -r '.wine_prefix' "$BUILD_PROFILE")
    WINE_PREFIX_PATH="${WINE_SOURCE_DIR}/${SELECTED_WINE}"
    echo "$MSG_SELECTED_WINE $SELECTED_WINE"
  else
    if [ -d "$WINE_SOURCE_DIR" ]; then
        # Find all folders in wine-sources (General, Private, Personal)
        WINE_FOLDERS=()
        while IFS= read -r -d '' folder; do
            WINE_FOLDERS+=("$(basename "$folder")")
        done < <(find "$WINE_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

        if [ ${#WINE_FOLDERS[@]} -gt 0 ]; then
            # Build dialog menu
            MENU_OPTIONS=()
            i=1
            for folder in "${WINE_FOLDERS[@]}"; do
                MENU_OPTIONS+=("$i" "$folder")
                ((i++))
            done

            WINE_CHOICE=$(dialog --title "$DLG_WINE_TITLE" \
                --menu "$DLG_WINE_MENU" 15 60 ${#WINE_FOLDERS[@]} \
                "${MENU_OPTIONS[@]}" \
                3>&1 1>&2 2>&3)

            clear

            if [ -n "$WINE_CHOICE" ]; then
                SELECTED_WINE="${WINE_FOLDERS[$((WINE_CHOICE-1))]}"
                WINE_PREFIX_PATH="${WINE_SOURCE_DIR}/${SELECTED_WINE}"
                echo "$MSG_SELECTED_WINE $SELECTED_WINE"

                # Verify the wine prefix has required files
                echo "$MSG_WINE_CHECKING"

                # Determine actual .wine32 location
                if [ -d "${WINE_PREFIX_PATH}/.wine32" ]; then
                    WINE32_CHECK_DIR="${WINE_PREFIX_PATH}/.wine32"
                else
                    WINE32_CHECK_DIR="${WINE_PREFIX_PATH}"
                fi

                # Check for VarAC.exe
                if [ -f "${WINE32_CHECK_DIR}/drive_c/VarAC/VarAC.exe" ]; then
                    echo "  $MSG_WINE_VARAC_OK"
                else
                    echo "  $MSG_WINE_VARAC_MISSING"
                fi

                # Check for License.txt (required for et-varac license enforcement)
                if [ -f "${WINE32_CHECK_DIR}/drive_c/VarAC/License.txt" ]; then
                    echo "  $MSG_WINE_LICENSE_OK"
                else
                    echo "  $MSG_WINE_LICENSE_MISSING"
                    echo ""
                    read -p "$MSG_PRESS_ENTER"
                fi

            else
                echo "$MSG_NO_WINE_SELECTED"
                exit 0
            fi
        else
            echo "$MSG_NO_WINE_FOLDERS $WINE_SOURCE_DIR"
            echo "$MSG_CREATE_WINE_DIR"
            exit 1
        fi
    else
        echo "$MSG_WINE_DIR_NOT_FOUND $WINE_SOURCE_DIR"
        echo "$MSG_CREATE_WINE_DIR"
        exit 1
    fi
  fi
    
    # Verify wine folder exists
    if [ ! -d "$WINE_PREFIX_PATH" ]; then
        echo "$MSG_ERROR_WINE_NOT_FOUND $WINE_PREFIX_PATH"
        exit 1
    fi
fi

echo ""

# =============================================================================
# Build Profile Summary (headless mode only)
# =============================================================================
if [ -n "$BUILD_PROFILE" ]; then
    # Resolve display values for summary
    _WP_SUMMARY="Default (from overlay)"
    if [ -n "$GENERATED_WALLPAPER" ]; then
        _WP_COLOR_NAME="white"
        case "${WP_COLOR_CHOICE}" in
            2) _WP_COLOR_NAME="gray" ;;
            3) _WP_COLOR_NAME="orange" ;;
            4) _WP_COLOR_NAME="blue" ;;
        esac
        _WP_SUMMARY="Generate — ${WP_CALLSIGN} (${_WP_COLOR_NAME}, ${CENTER_SIZE}pt)"
    elif [ -n "$SELECTED_WALLPAPER" ]; then
        _WP_SUMMARY="$(basename "$SELECTED_WALLPAPER")"
    fi

    _BOOT_SUMMARY="Default (Debian)"
    case "$BOOT_LOGO_CHOICE" in
        1) _BOOT_SUMMARY="With callsign" ;;
        2) _BOOT_SUMMARY="Logo only (no text)" ;;
    esac

    _ISO_SUMMARY="Lite (no Wine)"
    if [ "$INCLUDE_WINE32" = "yes" ]; then
        _ISO_SUMMARY="Complete (VARA + VarAC)"
    fi

    _MAPS_SUMMARY="No (external drive)"
    if [ "$INCLUDE_MAPS" = "yes" ]; then
        _MAPS_SUMMARY="Yes (baked into ISO)"
    fi

    _UPDATE_SUMMARY="Disabled (offline)"
    if [ "$UPDATE_ENABLED" = "true" ]; then
        _UPDATE_SUMMARY="${UPDATE_URL} (${UPDATE_CHANNEL})"
    fi

    _MOTD_SUMMARY="Default"
    if [ -n "$SELECTED_MOTD" ]; then
        _MOTD_SUMMARY="$(basename "$SELECTED_MOTD")"
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║  Build Profile Summary                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Profile:      $(basename "$BUILD_PROFILE")"
    echo "  Distribution: ${ET_DISTRO_NAME} ${ET_VERSION}"
    echo "  Architecture: ${ARCH_VERSION}"
    echo "  Overlay:      $(basename "$SELECTED_OVERLAY")"
    echo "  ISO type:     ${_ISO_SUMMARY}"
    if [ "$INCLUDE_WINE32" = "yes" ]; then
        echo "  Wine prefix:  ${SELECTED_WINE}"
    fi
    echo "  Maps:         ${_MAPS_SUMMARY}"
    echo "  Wallpaper:    ${_WP_SUMMARY}"
    echo "  Boot logo:    ${_BOOT_SUMMARY}"
    echo "  Updates:      ${_UPDATE_SUMMARY}"
    echo "  MOTD:         ${_MOTD_SUMMARY}"
    echo ""
    read -p "  Press Enter to start build, Ctrl+C to cancel..."
    echo ""
fi

# =============================================================================
# BUILD PHASE - Starting now!
# =============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "$MSG_BUILD_START_LINE1"
echo "║                                                                       ║"
echo "$MSG_BUILD_START_LINE3"
echo "$MSG_BUILD_START_LINE4"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# Save cache if it exists
echo "$MSG_CHECKING_CACHE"
if [ -d "${ISO_DIR}/cache" ]; then
    echo "$MSG_SAVING_CACHE"
    sudo mv ${ISO_DIR}/cache /tmp/lb-cache-backup
fi

# Nuke old directory - fresh start!
echo "$MSG_CLEANING_BUILD"
cd "$SCRIPT_DIR"
sudo rm -rf ${ISO_DIR}
mkdir -p ${ISO_DIR}
cd ${ISO_DIR}

# Restore cache if we saved it
if [ -d "/tmp/lb-cache-backup" ]; then
    echo "$MSG_RESTORING_CACHE"
    sudo mv /tmp/lb-cache-backup ${ISO_DIR}/cache
    echo "$MSG_CACHE_RESTORED"
fi

# Verify we're in right place!
if [ "$PWD" != "$ISO_DIR" ]; then
    echo "$MSG_ERROR_WRONG_DIR $ISO_DIR"
    exit 1
fi

# Configure live-build
echo "$MSG_CONFIGURING_LIVEBUILD"
# Trixie is stable (13.3) — live mirror has frozen, consistent packages
# Security/updates disabled during build to avoid version conflicts between
# main repo and security repo (solver 3.0 can't resolve mixed sources).
# The installed system uses binary mirror (deb.debian.org) which includes security.
# Override mirror: DEBIAN_MIRROR=http://snapshot.debian.org/archive/debian/20260218T000000Z ./setup-emcomm-iso.sh
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"

lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap "${DEBIAN_MIRROR}" \
  --mirror-chroot "${DEBIAN_MIRROR}" \
  --mirror-binary "https://deb.debian.org/debian" \
  --security false \
  --updates false \
  --debian-installer none \
  --debian-installer-gui true \
  --bootappend-live "boot=live components quiet splash"

# Package list
echo "$MSG_COPYING_PACKAGES"
cp "${SCRIPT_DIR}/scripts/package-lists/emcomm.list.chroot" config/package-lists/

# Note: zenity is already included with XFCE (used by et-varac for license dialog)

# Copy overlay
echo "$MSG_COPYING_OVERLAY"
mkdir -p config/includes.chroot
cp -a ${OVERLAY_DIR}/* config/includes.chroot/

# Copy selected wallpaper
echo "$MSG_SETTING_WALLPAPER"
mkdir -p config/includes.chroot/usr/share/backgrounds
if [ -n "$GENERATED_WALLPAPER" ] && [ -f "$GENERATED_WALLPAPER" ]; then
    echo "$MSG_COPYING_GEN_WALLPAPER"
    cp "$GENERATED_WALLPAPER" config/includes.chroot/usr/share/backgrounds/wallpaper.png
elif [ -n "$SELECTED_WALLPAPER" ] && [ -f "$SELECTED_WALLPAPER" ]; then
    echo "$MSG_COPYING_SEL_WALLPAPER $(basename "$SELECTED_WALLPAPER")"
    cp "$SELECTED_WALLPAPER" config/includes.chroot/usr/share/backgrounds/wallpaper.png
elif [ -f "${OVERLAY_DIR}/usr/share/backgrounds/va2ops-wallpaper.png" ]; then
    echo "$MSG_USING_OVERLAY_WALLPAPER"
    cp "${OVERLAY_DIR}/usr/share/backgrounds/va2ops-wallpaper.png" config/includes.chroot/usr/share/backgrounds/wallpaper.png
else
    echo "$MSG_WARNING_NO_WALLPAPER"
fi

# Copy boot logo and setup Plymouth branding
if [ -n "$GENERATED_BOOT_LOGO" ] && [ -f "$GENERATED_BOOT_LOGO" ]; then
    echo "$MSG_SETTING_PLYMOUTH"
    
    # Store the boot logo in a permanent location (NOT /tmp - it gets cleaned!)
    mkdir -p config/includes.chroot/usr/share/emcomm-branding
    cp "$GENERATED_BOOT_LOGO" config/includes.chroot/usr/share/emcomm-branding/watermark.png
    echo "$MSG_BOOTLOGO_INSTALLED"
    
    # === ISOLINUX BOOTLOADER SPLASH ===
    # This replaces the yellow Debian helmet in the boot menu!
    echo "Creating custom bootloader splash..."
    mkdir -p config/bootloaders/isolinux
    
    # Generate a 640x480 splash image for isolinux (BIOS boot)
    # Use generated wallpaper with callsign if available
    if [ -n "$GENERATED_WALLPAPER" ] && [ -f "$GENERATED_WALLPAPER" ]; then
        convert "$GENERATED_WALLPAPER" \
            -resize 640x480^ \
            -gravity center \
            -extent 640x480 \
            config/bootloaders/isolinux/splash.png
        echo "ISOLINUX splash created with callsign (BIOS boot)"
    elif [ -f "$WALLPAPER_BASE" ]; then
        convert "$WALLPAPER_BASE" \
            -resize 640x480^ \
            -gravity center \
            -extent 640x480 \
            -font "DejaVu-Sans-Bold" \
            -pointsize 24 \
            -fill "white" \
            -gravity northwest \
            -annotate +150+30 "EmComm-Tools Debian Edition" \
            config/bootloaders/isolinux/splash.png
        echo "ISOLINUX splash created (BIOS boot)"
    else
        # Fallback: just use the boot logo scaled up
        convert "$GENERATED_BOOT_LOGO" \
            -resize 1440x1440 \
            -gravity center \
            -background black \
            -extent 640x480 \
            -depth 16 \
            config/bootloaders/isolinux/splash.png
        echo "ISOLINUX splash created from boot logo"
    fi
    
    # === GRUB SPLASH FOR UEFI BOOT ===
    echo "Creating GRUB splash for UEFI boot..."
    mkdir -p config/bootloaders/grub-pc
    mkdir -p config/bootloaders/grub-efi
    
    # Generate splash for GRUB (can be larger, typically 1920x1080 or 1024x768)
    # Use generated wallpaper with callsign if available, otherwise base wallpaper
    if [ -n "$GENERATED_WALLPAPER" ] && [ -f "$GENERATED_WALLPAPER" ]; then
        # Use the wallpaper with callsign already on it
        convert "$GENERATED_WALLPAPER" \
            -resize 1920x1080^ \
            -gravity center \
            -extent 1920x1080 \
            config/bootloaders/grub-pc/splash.png
        cp config/bootloaders/grub-pc/splash.png config/bootloaders/grub-efi/splash.png
        echo "GRUB splash created with callsign (UEFI boot)"
    elif [ -f "$WALLPAPER_BASE" ]; then
        convert "$WALLPAPER_BASE" \
            -resize 1920x1080^ \
            -gravity center \
            -extent 1920x1080 \
            -font "DejaVu-Sans-Bold" \
            -pointsize 36 \
            -fill "white" \
            -gravity northwest \
            -annotate +100+50 "EmComm-Tools Debian Edition" \
            config/bootloaders/grub-pc/splash.png
        cp config/bootloaders/grub-pc/splash.png config/bootloaders/grub-efi/splash.png
        echo "GRUB splash created (UEFI boot)"
    else
        convert "$GENERATED_BOOT_LOGO" \
            -resize 1440x1440 \
            -gravity center \
            -background black \
            -extent 1920x1080 \
            config/bootloaders/grub-pc/splash.png
        cp config/bootloaders/grub-pc/splash.png config/bootloaders/grub-efi/splash.png
        echo "GRUB splash created from boot logo"
    fi
    
    # Also copy splash to includes.binary for direct inclusion in ISO
    mkdir -p config/includes.binary/boot/grub
    cp config/bootloaders/grub-pc/splash.png config/includes.binary/boot/grub/splash.png
    
    # Create live.cfg.in that includes our splash (this is used by live-build)
    cat > config/bootloaders/grub-pc/live-theme.cfg << 'GRUB_LIVE_THEME'
# EmComm-Tools GRUB Live Boot Theme
insmod png
if background_image /boot/grub/splash.png; then
    set color_normal=white/black
    set color_highlight=black/white
    set menu_color_normal=white/black
    set menu_color_highlight=black/light-gray
else
    set color_normal=cyan/blue
    set color_highlight=white/blue
    set menu_color_normal=cyan/blue
    set menu_color_highlight=white/blue
fi
GRUB_LIVE_THEME
    cp config/bootloaders/grub-pc/live-theme.cfg config/bootloaders/grub-efi/live-theme.cfg
    
    # Create custom grub.cfg header to be included
    cat > config/bootloaders/grub-pc/config.cfg << 'GRUB_CONFIG'
# EmComm-Tools Custom GRUB Config
insmod png
insmod gfxterm
insmod vbe
set gfxmode=1920x1080,1680x1050,1280x1024,auto
terminal_output gfxterm
background_image /boot/grub/splash.png
set timeout=10
set default=0
GRUB_CONFIG
    cp config/bootloaders/grub-pc/config.cfg config/bootloaders/grub-efi/config.cfg

    # Create a hook to install GRUB splash into the ISO
    cat > config/hooks/live/0051-grub-branding.hook.chroot << 'GRUB_HOOK'
#!/bin/bash
# Configure GRUB branding for EmComm-Tools (UEFI boot)

echo "Configuring GRUB boot branding..."

# The splash.png will be copied by live-build to /boot/grub/
# This hook ensures GRUB is configured to use it

# Update GRUB defaults for better splash support
if [ -f /etc/default/grub ]; then
    # Enable splash
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
    
    # Set GRUB background if not already set
    if ! grep -q "GRUB_BACKGROUND" /etc/default/grub; then
        echo 'GRUB_BACKGROUND="/boot/grub/splash.png"' >> /etc/default/grub
    fi
fi

echo "GRUB branding configured."
GRUB_HOOK
    chmod +x config/hooks/live/0051-grub-branding.hook.chroot
    echo "GRUB hook created: 0051-grub-branding.hook.chroot"
    
    # Create a BINARY hook to modify GRUB config at ISO build stage
    cat > config/hooks/live/0052-grub-splash.hook.binary << 'GRUB_BINARY_HOOK'
#!/bin/bash
# Binary hook: Add splash background to GRUB config for live ISO
# This runs during the binary stage when the ISO structure is created

echo "Applying GRUB splash to live boot menu..."

# Find and modify the grub.cfg in the binary directory
GRUB_CFG="binary/boot/grub/grub.cfg"

if [ -f "$GRUB_CFG" ]; then
    # Add splash background command at the beginning of grub.cfg
    SPLASH_CMD="insmod png\nif background_image /boot/grub/splash.png; then\n  set color_normal=white/black\n  set color_highlight=black/light-gray\nfi\n"
    
    # Create temp file with splash commands prepended
    echo -e "$SPLASH_CMD" > /tmp/grub_header.cfg
    cat "$GRUB_CFG" >> /tmp/grub_header.cfg
    mv /tmp/grub_header.cfg "$GRUB_CFG"
    
    echo "GRUB config updated with splash background"
else
    echo "WARNING: GRUB config not found at $GRUB_CFG"
fi

# Also check EFI grub
EFI_GRUB_CFG="binary/EFI/boot/grub.cfg"
if [ -f "$EFI_GRUB_CFG" ]; then
    echo -e "$SPLASH_CMD" > /tmp/grub_header.cfg
    cat "$EFI_GRUB_CFG" >> /tmp/grub_header.cfg
    mv /tmp/grub_header.cfg "$EFI_GRUB_CFG"
    echo "EFI GRUB config updated with splash background"
fi

echo "GRUB splash configuration complete."
GRUB_BINARY_HOOK
    chmod +x config/hooks/live/0052-grub-splash.hook.binary
    echo "GRUB binary hook created: 0052-grub-splash.hook.binary"
    
    # Create Plymouth configuration hook
    echo "$MSG_CREATING_PLYMOUTH_HOOK"
    cat > config/hooks/live/0050-plymouth-branding.hook.chroot << 'PLYMOUTH_HOOK'
#!/bin/bash
# Configure Plymouth boot branding for EmComm-Tools

echo "Configuring Plymouth boot branding..."

# Ensure Plymouth is installed (this creates the default themes)
apt-get install -y plymouth plymouth-themes

# NOW copy our custom logo AFTER plymouth-themes has installed
if [ -f /usr/share/emcomm-branding/watermark.png ]; then
    echo "Installing custom boot logo..."
    
    # Replace the main Debian logo
    cp /usr/share/emcomm-branding/watermark.png /usr/share/plymouth/debian-logo.png
    
    # Replace spinner theme watermark (used by installed system)
    cp /usr/share/emcomm-branding/watermark.png /usr/share/plymouth/themes/spinner/watermark.png
    
    # Replace logo.png in ceratopsian theme (used by live boot Plymouth)
    if [ -d /usr/share/plymouth/themes/ceratopsian ]; then
        echo "Replacing ceratopsian logo.png..."
        cp /usr/share/emcomm-branding/watermark.png /usr/share/plymouth/themes/ceratopsian/logo.png
    fi
    
    echo "Custom boot logos installed in all themes."
else
    echo "WARNING: Custom boot logo not found at /usr/share/emcomm-branding/watermark.png"
fi

# Set spinner as default theme for installed system
plymouth-set-default-theme spinner

# Update initramfs to include the new branding
update-initramfs -u -k all

echo "Plymouth branding configured."
PLYMOUTH_HOOK
    chmod +x config/hooks/live/0050-plymouth-branding.hook.chroot
    echo "$MSG_PLYMOUTH_HOOK_CREATED"
fi

# =============================================================================
# Calamares Installer Branding Configuration
# =============================================================================
echo "Configuring Calamares installer branding..."

# Update existing debian branding with version from build-config.json
# The overlay provides: slide1.png, show.qml, emcomm-logo.png, welcome.png, etc.
# We only update branding.desc with the current version info

BRANDING_DIR="config/includes.chroot/etc/calamares/branding/debian"
mkdir -p "$BRANDING_DIR"

# Create/update the branding.desc file with version from build-config.json
cat > "$BRANDING_DIR/branding.desc" << CALAMARES_BRANDING
---
componentName: debian
welcomeStyleCalamares: true
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 800px,580px
windowPlacement: center

strings:
    productName:         "${ET_DISTRO_NAME}"
    shortProductName:    "EmComm-Tools"
    version:             "${ET_VERSION}"
    shortVersion:        "${ET_VERSION}"
    versionedName:       "${ET_DISTRO_NAME} ${ET_VERSION}"
    shortVersionedName:  "EmComm-Tools ${ET_VERSION}"
    bootloaderEntryName: "EmComm-Tools"
    productUrl:          "${ET_WEBSITE}"
    supportUrl:          "${ET_SUPPORT_URL}"
    knownIssuesUrl:      "${ET_WEBSITE}/issues"
    releaseNotesUrl:     "${ET_WEBSITE}/releases"
    donateUrl:           "https://buymeacoffee.com/emcommtools"

sidebar: widget
navigation: widget

images:
    productLogo:         "emcomm-logo.png"
    productIcon:         "emcomm-logo.png"
    productWelcome:      "welcome.png"

slideshow:               "show.qml"

style:
   SidebarBackground:    "#2b2b2b"
   SidebarText:          "#FFFFFF"
   SidebarTextCurrent:   "#00ff88"
   SidebarBackgroundCurrent: "#2b2b2b"

slideshowAPI: 2
CALAMARES_BRANDING

echo "Calamares branding.desc updated with version ${ET_VERSION}"

# The overlay already provides slide1.png, show.qml, emcomm-logo.png, welcome.png
# No need to generate them - they come from the overlay

# Create hook to ensure Calamares uses debian branding (should already be set)
cat > config/hooks/live/0052-calamares-branding.hook.chroot << 'CALAMARES_HOOK'
#!/bin/bash
# Ensure Calamares uses debian branding (with EmComm-Tools customization)

echo "Verifying Calamares branding configuration..."

if [ -f /etc/calamares/settings.conf ]; then
    # Ensure branding is set to debian
    if grep -q "^branding:" /etc/calamares/settings.conf; then
        sed -i 's/^branding:.*/branding: debian/' /etc/calamares/settings.conf
    fi
fi

echo "Calamares branding verified."
CALAMARES_HOOK
chmod +x config/hooks/live/0052-calamares-branding.hook.chroot
echo "Calamares branding hook created: 0052-calamares-branding.hook.chroot"

# Copy selected MOTD
if [ -n "$SELECTED_MOTD" ] && [ -f "$SELECTED_MOTD" ]; then
    echo "$MSG_COPYING_MOTD $(basename "$SELECTED_MOTD")"
    cp "$SELECTED_MOTD" config/includes.chroot/etc/motd
fi

# Clean problematic overlay files
echo "$MSG_CLEANING_UBUNTU"
rm -f config/includes.chroot/etc/skel/.config/gnome-initial-setup-done
rm -rf config/includes.chroot/etc/skel/.config/systemd/user/default.target.wants
rm -rf config/includes.chroot/usr/share/glib-2.0
rm -f config/includes.chroot/etc/adduser.conf
rm -rf config/includes.chroot/etc/apt

# Explicitly remove GNOME schema override that causes "No such schema" errors
rm -f config/includes.chroot/usr/share/glib-2.0/schemas/90_ubuntu-settings.gschema.override 2>/dev/null || true

# Remove GNOME-specific configs that cause errors on XFCE
rm -rf config/includes.chroot/etc/skel/.config/dconf
rm -f config/includes.chroot/etc/skel/.config/glib-2.0

# et-term is in overlay (XFCE-compatible version)

# Remove et-user-* variants, keep only et-user
echo "$MSG_CLEANING_ETUSER"
rm -f config/includes.chroot/opt/emcomm-tools/bin/et-user-*

# et-user is in overlay (bilingual version with password security)

# et-fldigi is in overlay (Debian paths: /usr/bin)

# et-winlink is in overlay (with browser auto-launch)

# Copy .wine32 (VARA/VarAC) - only for Complete ISO
if [ "$INCLUDE_WINE32" = "yes" ] && [ -n "$WINE_PREFIX_PATH" ]; then
    echo "$MSG_COPYING_WINE $WINE_PREFIX_PATH"
    
    # Determine the actual .wine32 location
    if [ -d "${WINE_PREFIX_PATH}/.wine32" ]; then
        # .wine32 is inside the selected folder
        sudo cp -a "${WINE_PREFIX_PATH}/.wine32" config/includes.chroot/etc/skel/.wine32
    else
        # The selected folder IS the .wine32 (contains drive_c directly)
        sudo cp -a "$WINE_PREFIX_PATH" config/includes.chroot/etc/skel/.wine32
    fi
else
    echo "$MSG_SKIPPING_WINE"
    # Lite ISO - ensure no .wine32 in the final image
    if [ -d "config/includes.chroot/etc/skel/.wine32" ]; then
        sudo rm -rf config/includes.chroot/etc/skel/.wine32
    fi
fi

# ============================================================
# CREATE SCRIPTS DIRECTLY (more reliable than hooks)
# ============================================================
echo "$MSG_CREATING_SCRIPTS"
mkdir -p config/includes.chroot/opt/emcomm-tools/bin

# et-ft8 is in overlay

# et-varac is in overlay (Wine app - simplified)

# et-get-vara is in overlay

# et-maps-setup is in overlay

# et-first-boot is in overlay

# Create autostart entries from overlay
echo "$MSG_COPYING_AUTOSTART"
mkdir -p config/includes.chroot/etc/xdg/autostart

# Copy all autostart .desktop files from overlay
if [ -d "${OVERLAY_DIR}/etc/skel/.config/autostart" ]; then
    cp "${OVERLAY_DIR}/etc/skel/.config/autostart/"*.desktop config/includes.chroot/etc/xdg/autostart/ 2>/dev/null || true
    echo "Autostart entries copied from overlay"
fi

# Fallback: also copy from scripts/autostart if exists (legacy support)
if [ -d "${SCRIPT_DIR}/scripts/autostart" ]; then
    cp "${SCRIPT_DIR}/scripts/autostart/"*.desktop config/includes.chroot/etc/xdg/autostart/ 2>/dev/null || true
fi

# Create symlinks to /usr/local/bin
mkdir -p config/includes.chroot/usr/local/bin
ln -sf /opt/emcomm-tools/bin/et-ft8 config/includes.chroot/usr/local/bin/et-ft8
ln -sf /opt/emcomm-tools/bin/et-varac config/includes.chroot/usr/local/bin/et-varac
ln -sf /opt/emcomm-tools/bin/et-get-vara config/includes.chroot/usr/local/bin/et-get-vara
ln -sf /opt/emcomm-tools/bin/et-maps-setup config/includes.chroot/usr/local/bin/et-maps-setup
ln -sf /opt/emcomm-tools/bin/et-first-boot config/includes.chroot/usr/local/bin/et-first-boot

# Ensure VarAC icon exists
if [ -f "${OVERLAY_DIR}/usr/share/icons/varac.png" ]; then
    echo "$MSG_VARAC_ICON_FOUND"
    # Copy to pixmaps too for compatibility
    mkdir -p config/includes.chroot/usr/share/pixmaps
    cp "${OVERLAY_DIR}/usr/share/icons/varac.png" config/includes.chroot/usr/share/pixmaps/
    cp "${OVERLAY_DIR}/usr/share/icons/"*.png config/includes.chroot/usr/share/pixmaps/ 2>/dev/null || true
    echo "$MSG_ICONS_COPIED"
else
    echo "$MSG_WARNING_VARAC_ICON"
fi

# ============================================================
# Copy Pre-built Binaries (compiled locally, avoid chroot compile issues)
# ============================================================
echo "Copying pre-built binaries..."
PREBUILT_DIR="${SCRIPT_DIR}/scripts/bins"
if [ -d "$PREBUILT_DIR" ]; then
    mkdir -p config/includes.chroot/usr/share/emcomm-tools/prebuilt
    cp -v "$PREBUILT_DIR"/* config/includes.chroot/usr/share/emcomm-tools/prebuilt/ 2>/dev/null || true
    echo "Pre-built binaries copied."
else
    echo "No pre-built binaries directory found (optional)."
fi

# Copy hooks from versioned directory
echo "$MSG_CREATING_HOOKS"
mkdir -p config/hooks/live

HOOKS_DIR="${SCRIPT_DIR}/scripts/hooks/${ARCH_VERSION}"
HOOK_COUNT=0
for hook in "${HOOKS_DIR}"/*.hook.chroot; do
    [ -f "$hook" ] || continue
    # Skip map download hook — it is conditionally generated below based on INCLUDE_MAPS
    [ "$(basename "$hook")" = "0400-download-maps.hook.chroot" ] && continue
    cp "$hook" config/hooks/live/
    chmod +x "config/hooks/live/$(basename "$hook")"
    HOOK_COUNT=$((HOOK_COUNT + 1))
done
echo "Copied ${HOOK_COUNT} hooks from ${ARCH_VERSION}."

# Fix /etc/environment
echo "$MSG_COPYING_ENVIRONMENT"
cp "${SCRIPT_DIR}/scripts/etc/environment" config/includes.chroot/etc/

# XFCE Panel launchers (Navit, ET-Predict)
echo "$MSG_ADDING_LAUNCHERS"

# Remove any existing panel config from overlay to avoid conflicts
rm -rf config/includes.chroot/etc/skel/.config/xfce4/panel
rm -f config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-4
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-5
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-24
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-25
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-26

# Panel launcher: thunar
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-4-thunar.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-4/thunar.desktop

# Panel launcher: xfce4-terminal
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-5-xfce4-terminal.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-5/xfce4-terminal.desktop

# Panel launcher: navit
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-24-navit.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-24/navit.desktop

# Panel launcher: et-predict
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-25-et-predict.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-25/et-predict.desktop

# Panel launcher: et-crypto
cp "${SCRIPT_DIR}/scripts/panel-launchers/launcher-26-et-crypto.desktop" config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-26/et-crypto.desktop

# XFCE panel config to add the launchers
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

# XFCE config: xfce4-desktop.xml
cp "${SCRIPT_DIR}/scripts/xfce-config/xfce4-desktop.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# XFCE panel config
cp "${SCRIPT_DIR}/scripts/xfce-config/xfce4-panel.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# XFCE config: displays.xml
cp "${SCRIPT_DIR}/scripts/xfce-config/displays.xml" config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# Note: Conky uses .conkyrc from overlay (already has proper styling)
# Just ensure gap_y is set to 10 in overlay file before build

# Fuse fix
echo "$MSG_ADDING_FUSE"
mkdir -p config/packages.chroot
wget -P config/packages.chroot http://ftp.debian.org/debian/pool/main/f/fuse/libfuse2t64_2.9.9-9_amd64.deb

# Download maps if user chose to include them
if [ "$INCLUDE_MAPS" = "yes" ]; then
    echo "Generating map download hook (0400-download-maps.hook.chroot)..."

    # -----------------------------------------------------------------
    # Part 1: Tileset download section (always included when maps=yes)
    # -----------------------------------------------------------------
    cat > config/hooks/live/0400-download-maps.hook.chroot << 'MAPHOOK_HEADER'
#!/bin/bash
# =============================================================================
# EmComm-Tools Map Download Hook
# Generated by setup-emcomm-iso.sh
# Downloads: mbtiles tilesets + selected OSM/Navit maps
# =============================================================================
set -e

download_with_retry() {
    local url="$1"
    local dest="$2"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        echo "  Downloading: $(basename "$dest") (attempt $((retry+1))/$max_retries)..."
        if curl -L -f --progress-bar -o "$dest" "$url"; then
            return 0
        fi
        retry=$((retry+1))
        echo "  Retry in 5 seconds..."
        sleep 5
    done

    echo "  ERROR: Failed to download $(basename "$dest") after $max_retries attempts!"
    return 1
}

# =============================================================================
# Part 1: mbtiles Tilesets (US, Canada, World)
# =============================================================================
echo "=============================================="
echo "Downloading mbtiles tilesets..."
echo "=============================================="

TILESET_DIR="/etc/skel/.local/share/emcomm-tools/mbtileserver/tilesets"
mkdir -p "${TILESET_DIR}"

ET_RELEASE_URL="https://github.com/thetechprepper/emcomm-tools-os-community/releases/download"
ET_RELEASE_TAG="emcomm-tools-os-community-20251128-r5-final-5.0.0"

TILESETS=(
    "osm-us-zoom0to11-20251120.mbtiles"
    "osm-ca-zoom0to10-20251120.mbtiles"
    "osm-world-zoom0to7-20251121.mbtiles"
)

for tileset in "${TILESETS[@]}"; do
    if [ -f "${TILESET_DIR}/${tileset}" ]; then
        echo "  ${tileset} already exists, skipping."
        continue
    fi
    download_with_retry "${ET_RELEASE_URL}/${ET_RELEASE_TAG}/${tileset}" "${TILESET_DIR}/${tileset}"
done

echo "Tilesets download complete."
MAPHOOK_HEADER

    # -----------------------------------------------------------------
    # Part 2: OSM/Navit maps (only if regions were selected)
    # -----------------------------------------------------------------
    if [ -n "$SELECTED_OSM_REGIONS" ]; then
        cat >> config/hooks/live/0400-download-maps.hook.chroot << 'MAPHOOK_OSM_FUNCS'

# =============================================================================
# Part 2: OSM Maps for Navit (selected provinces/states)
# =============================================================================
echo ""
echo "=============================================="
echo "Downloading OSM maps for Navit..."
echo "=============================================="

PBF_MAP_DIR="/etc/skel/my-maps"
NAVIT_MAP_DIR="/etc/skel/.navit/maps"
mkdir -p "${PBF_MAP_DIR}" "${NAVIT_MAP_DIR}"

GEOFABRIK_CA="http://download.geofabrik.de/north-america/canada"
GEOFABRIK_US="http://download.geofabrik.de/north-america/us"

download_and_convert_osm() {
    local region="$1"
    local country="$2"
    local pbf_file="${region}-latest.osm.pbf"
    local bin_file="${region}-latest.osm.bin"

    if [ "$country" = "canada" ]; then
        local url="${GEOFABRIK_CA}/${pbf_file}"
    else
        local url="${GEOFABRIK_US}/${pbf_file}"
    fi

    echo ""
    echo "--- ${region} (${country}) ---"

    # Download .pbf
    if [ -f "${PBF_MAP_DIR}/${pbf_file}" ]; then
        echo "  ${pbf_file} already exists, skipping download."
    else
        download_with_retry "${url}" "${PBF_MAP_DIR}/${pbf_file}"
    fi

    # Convert to Navit .bin format
    if [ -f "${PBF_MAP_DIR}/${pbf_file}" ]; then
        if [ -f "${NAVIT_MAP_DIR}/${bin_file}" ]; then
            echo "  ${bin_file} already exists, skipping conversion."
        else
            echo "  Converting to Navit format: ${bin_file}..."
            maptool --protobuf -i "${PBF_MAP_DIR}/${pbf_file}" "${NAVIT_MAP_DIR}/${bin_file}"
            echo "  Conversion complete."
        fi
    else
        echo "  WARNING: ${pbf_file} not found, cannot convert for Navit."
    fi
}

MAPHOOK_OSM_FUNCS

        # Inject the selected regions as function calls
        for region_entry in $SELECTED_OSM_REGIONS; do
            # Remove quotes that dialog adds
            region_entry=$(echo "$region_entry" | tr -d '"')
            IFS=':' read -r region country <<< "$region_entry"
            echo "download_and_convert_osm \"${region}\" \"${country}\"" >> config/hooks/live/0400-download-maps.hook.chroot
        done

        cat >> config/hooks/live/0400-download-maps.hook.chroot << 'MAPHOOK_OSM_END'

echo ""
echo "OSM/Navit map downloads complete."
MAPHOOK_OSM_END

    fi

    # Close the hook
    cat >> config/hooks/live/0400-download-maps.hook.chroot << 'MAPHOOK_FOOTER'

echo ""
echo "=============================================="
echo "All map downloads complete!"
echo "=============================================="
MAPHOOK_FOOTER

    chmod +x config/hooks/live/0400-download-maps.hook.chroot
    echo "Map download hook generated: 0400-download-maps.hook.chroot"

else
    echo "$MSG_SKIPPING_MAP_DOWNLOAD"
fi

# ZIM files are downloaded by hook 0198-download-zim-files.hook.chroot during build

# =============================================================================
# Generate Update System Configuration and Manifest
# =============================================================================
mkdir -p config/includes.chroot/opt/emcomm-tools/conf

# Generate update.conf
cat > config/includes.chroot/opt/emcomm-tools/conf/update.conf << EOF
# =============================================================================
# EmComm-Tools Update Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

# Enable/disable update system
UPDATE_ENABLED=${UPDATE_ENABLED}

# Update server URL (no trailing slash)
UPDATE_URL=${UPDATE_URL}

# Update channel: stable, beta, personal
UPDATE_CHANNEL=${UPDATE_CHANNEL}

# Check frequency: daily, weekly, manual
CHECK_INTERVAL=weekly

# Last update check (auto-updated by et-update-check)
LAST_CHECK=never

# Number of backups to keep
BACKUP_KEEP=3

# Auto-update without prompting (not recommended)
AUTO_UPDATE=false
EOF

# Generate manifest.json (catalog of installed files)
echo "$MSG_GENERATING_MANIFEST"

ET_OVERLAY_BIN="${OVERLAY_DIR}/opt/emcomm-tools"
MANIFEST_FILE="config/includes.chroot/opt/emcomm-tools/manifest.json"
MANIFEST_TEMP="/tmp/manifest-files-$$.json"

echo "[]" > "$MANIFEST_TEMP"
FILE_COUNT=0

if [ -d "$ET_OVERLAY_BIN" ]; then
    find "$ET_OVERLAY_BIN" -type f | sort | while read file; do
        # Skip certain files
        basename_file=$(basename "$file")
        case "$basename_file" in
            *.pyc|*.pyo|__pycache__|.git*|*.swp|*.bak|*.json)
                continue
                ;;
        esac
        
        # Get relative path from /opt/emcomm-tools
        rel_path="${file#$ET_OVERLAY_BIN/}"
        
        # Calculate checksum
        sha256=$(sha256sum "$file" | cut -d' ' -f1)
        
        # Get file size
        size=$(stat -c "%s" "$file")
        
        # Get permissions
        permissions=$(stat -c "%a" "$file")
        
        # Try to extract version from file
        file_version=$(grep -m1 "^# Version:" "$file" 2>/dev/null | sed 's/# Version: *//' | tr -d '[:space:]')
        [ -z "$file_version" ] && file_version="1.0.0"
        
        # Add to JSON array
        jq --arg path "$rel_path" \
           --arg version "$file_version" \
           --arg sha256 "$sha256" \
           --argjson size "$size" \
           --arg permissions "$permissions" \
           '. += [{
               "path": $path,
               "version": $version,
               "sha256": $sha256,
               "size": $size,
               "permissions": $permissions
           }]' "$MANIFEST_TEMP" > "${MANIFEST_TEMP}.tmp" && mv "${MANIFEST_TEMP}.tmp" "$MANIFEST_TEMP"
        
    done
    
    FILE_COUNT=$(jq 'length' "$MANIFEST_TEMP")
fi

# Build final manifest
RELEASE_DATE=$(date '+%Y-%m-%d')
BASE_URL="${UPDATE_URL}/${UPDATE_CHANNEL}/files"

jq -n \
    --arg schema_version "1.0" \
    --arg distribution "$ET_DISTRO_NAME" \
    --arg version "$ET_VERSION" \
    --arg channel "$UPDATE_CHANNEL" \
    --arg release_date "$RELEASE_DATE" \
    --arg base_url "$BASE_URL" \
    --slurpfile files "$MANIFEST_TEMP" \
    '{
        "schema_version": $schema_version,
        "distribution": $distribution,
        "version": $version,
        "channel": $channel,
        "release_date": $release_date,
        "base_url": $base_url,
        "files": $files[0]
    }' > "$MANIFEST_FILE"

rm -f "$MANIFEST_TEMP"

echo "$MSG_MANIFEST_GENERATED $FILE_COUNT $MSG_MANIFEST_FILES"

echo ""
echo "$MSG_SETUP_COMPLETE"
echo ""
echo "$MSG_USER_ACCOUNT"
if [ "$INCLUDE_WINE32" = "yes" ]; then
    echo "$MSG_WINE_SUMMARY_COMPLETE ($SELECTED_WINE)"
else
    echo "$MSG_WINE_SUMMARY_LITE"
fi
if [ "$INCLUDE_MAPS" = "yes" ]; then
    echo "$MSG_MAPS_INCLUDED_SUMMARY"
    if [ -n "$SELECTED_OSM_REGIONS" ]; then
        echo "  OSM/Navit maps:"
        for region_entry in $SELECTED_OSM_REGIONS; do
            region_entry=$(echo "$region_entry" | tr -d '"')
            IFS=':' read -r region country <<< "$region_entry"
            echo "    - ${region} (${country})"
        done
    fi
else
    echo "$MSG_MAPS_EXTERNAL_SUMMARY"
fi
echo ""

# Stay in the build directory!
cd ${ISO_DIR}

# =============================================================================
# Automatic Build
# =============================================================================
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "$MSG_ISO_BUILD_LINE1"
echo "║                                                                       ║"
echo "$MSG_ISO_BUILD_LINE2"
echo "$MSG_ISO_BUILD_LINE3"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""


# Clean cached sources to prevent stale builds
echo "Cleaning cached sources from previous builds..."
sudo rm -rf chroot/opt/src/* 2>/dev/null || true
sudo rm -rf chroot/opt/js8spotter* 2>/dev/null || true
sudo rm -rf chroot/opt/mbtileserver* 2>/dev/null || true
sudo rm -rf chroot/opt/flwrap* 2>/dev/null || true
sudo rm -rf chroot/opt/flmsg* 2>/dev/null || true
sudo rm -rf chroot/opt/flamp* 2>/dev/null || true
echo "Cache cleaned."

# Copy local downloads into chroot so hooks can use them as fallback
# Use includes.chroot_before_packages to guarantee files are in place before hooks run
DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"
if [ -d "$DOWNLOADS_DIR" ] && [ "$(ls -A "$DOWNLOADS_DIR" 2>/dev/null)" ]; then
    echo "Copying local downloads for hook fallback..."
    mkdir -p config/includes.chroot_before_packages/opt/downloads
    cp -v "$DOWNLOADS_DIR"/* config/includes.chroot_before_packages/opt/downloads/
else
    echo "No downloads/ directory found (optional - hooks will download from internet)"
fi

# Add local package repositories if available
mkdir -p config/archives

# Offline apt cache (from save-apt-cache.sh)
APT_CACHE_DIR="$(cd "${SCRIPT_DIR}/apt-cache" 2>/dev/null && pwd)" || APT_CACHE_DIR=""
rm -f config/archives/local-cache.list.chroot
if [ -n "$APT_CACHE_DIR" ] && [ -d "$APT_CACHE_DIR/pool" ] && [ "$(ls -A "$APT_CACHE_DIR/pool" 2>/dev/null)" ]; then
    echo "Offline apt cache found — adding as local repository..."
    echo "deb [trusted=yes] file://${APT_CACHE_DIR} ./" > config/archives/local-cache.list.chroot
    echo "Offline cache: $(ls "$APT_CACHE_DIR/pool/"*.deb 2>/dev/null | wc -l) packages available"
else
    echo "No offline apt cache found (optional - packages will download from Debian mirrors)"
fi

# Local repo for pinned/patched packages (manual fixes for broken mirrors)
LOCAL_REPO_DIR="$(cd "${SCRIPT_DIR}/local-repo" 2>/dev/null && pwd)" || LOCAL_REPO_DIR=""
rm -f config/archives/local-repo.list.chroot config/archives/local-repo.pref.chroot
if [ -n "$LOCAL_REPO_DIR" ] && [ -f "$LOCAL_REPO_DIR/Packages" ]; then
    echo "Local package repo found — adding as apt source..."
    echo "deb [trusted=yes] file://${LOCAL_REPO_DIR} ./" > config/archives/local-repo.list.chroot
    # Pin file forces apt to prefer pinned versions over newer mirror versions
    if [ -f "$LOCAL_REPO_DIR/pin-preferences" ]; then
        cp "$LOCAL_REPO_DIR/pin-preferences" config/archives/local-repo.pref.chroot
        echo "Local repo: apt pin preferences applied"
    fi
    echo "Local repo: $(grep -c '^Package:' "$LOCAL_REPO_DIR/Packages") packages available"
else
    echo "No local repo found (optional - for pinned packages when mirrors are broken)"
fi

sudo lb build 2>&1 | tee build.log
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    # Find the ISO file
    ISO_FILE=$(ls -t *.iso 2>/dev/null | head -1)
    
    if [ -n "$ISO_FILE" ]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "$MSG_BUILD_SUCCESS"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "$MSG_ISO_CREATED ${ISO_DIR}/${ISO_FILE}"
        echo "$MSG_SIZE $(du -h "$ISO_FILE" | cut -f1)"
        echo ""
        
        # Offer to start QEMU
        read -p "$MSG_START_QEMU" QEMU_CHOICE
        
        if [ "${QEMU_CHOICE,,}" = "$MSG_YES_CHAR" ]; then
            echo "$MSG_STARTING_QEMU"
            qemu-system-x86_64 \
                -enable-kvm \
                -m 4G \
                -cdrom "$ISO_FILE" \
                -boot d &
            echo "$MSG_QEMU_STARTED"
        fi
    else
        echo "$MSG_WARNING_ISO_NOT_FOUND"
    fi
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "$MSG_BUILD_FAILED"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "$MSG_CHECK_LOG"
    echo ""
    echo "$MSG_RETRY_HINT"
    echo "  sudo lb clean --binary && sudo lb build 2>&1 | tee build.log"
fi

echo ""

