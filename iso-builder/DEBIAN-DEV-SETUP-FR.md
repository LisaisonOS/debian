# EmComm-Tools Debian ISO Builder - Configuration de l'environnement de développement

**Auteur :** Sylvain Deguire (VA2OPS)  
**Date :** Janvier 2026  
**Version :** 1.0

---

## Aperçu

Ce document décrit comment configurer un système Debian pour construire des ISOs EmComm-Tools Debian Live. Suivez ces étapes sur une installation Debian 12 (Bookworm) ou Debian 13 (Trixie) fraîche.

---

## 1. Configuration système requise

- **OS :** Debian 12+ (Bookworm ou Trixie)
- **Espace disque :** Minimum 50 Go libres (100 Go+ recommandé)
- **RAM :** 8 Go+ recommandé
- **CPU :** Multi-cœurs recommandé pour des builds plus rapides

---

## 2. Mise à jour initiale du système

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3. Installer les paquets requis

### 3.1 Outils de build essentiels

```bash
sudo apt install -y \
    live-build \
    build-essential \
    git \
    dialog \
    imagemagick \
    zip wget curl tree
```

### 3.2 QEMU (pour tester l'ISO)

```bash
sudo apt install -y qemu-system-x86
```

### 3.3 Wine (pour tester VARA/VarAC)

```bash
sudo apt install -y wine wine32:i386 winetricks
```

### 3.4 Optionnel - Développement audio

```bash
sudo apt install -y libpulse-dev portaudio19-dev
```

---

## 4. Installation en une seule commande (Tous les paquets)

Copiez et collez cette commande unique pour tout installer :

```bash
sudo apt install -y \
    live-build \
    build-essential \
    git \
    dialog \
    imagemagick \
    qemu-system-x86 \
    wine wine32:i386 winetricks \
    zip wget curl tree
```

### Optionnel - Pour le développement/test audio :

```bash
sudo apt install -y libpulse-dev portaudio19-dev
```

---

## 5. Cloner le dépôt

```bash
cd ~
git clone https://github.com/emcomm-tools/emcomm-tools-git.git emcomm-tools
cd emcomm-tools
```

Ou si vous utilisez votre propre fork :

```bash
git clone https://github.com/VOTRE_NOM_UTILISATEUR/emcomm-tools.git
cd emcomm-tools
```

---

## 6. Structure des répertoires

Après la configuration, votre répertoire devrait ressembler à :

```
~/emcomm-tools/
├── setup-emcomm-iso.sh      # Script de build principal
├── backgrounds/             # Images de fond d'écran
│   └── emcomm-base.png      # Image de base pour le générateur
├── motd/                    # Bannières de terminal
├── overlays/                # Overlays EmComm-Tools
│   └── et-r5-final/
│       └── overlay/
├── scripts/                 # Scripts de build et hooks
│   ├── autostart/
│   ├── hooks/
│   ├── package-lists/
│   ├── panel-launchers/
│   └── xfce-config/
├── wine-sources/            # Préfixes Wine (VARA, VarAC)
│   └── wine32-general/
└── build/                   # Sortie du build (créé automatiquement)
    └── emcomm-debian-iso/
```

---

## 7. Télécharger les sources Wine (Optionnel mais recommandé)

Les wine-sources contiennent des préfixes Wine pré-configurés pour l'installation de VARA, VarAC :

```bash
mkdir -p ~/emcomm-tools/wine-sources
cd ~/emcomm-tools/wine-sources
wget "https://sourceforge.net/projects/emcomm-tools/files/wine-sources-general.tar.gz/download" \
    -O wine-sources-general.tar.gz
tar -xzf wine-sources-general.tar.gz
rm wine-sources-general.tar.gz
```

---

## 8. Créer le fond d'écran de base

Le générateur de fond d'écran nécessite une image de base :

```bash
# Option 1 : Utiliser un fond d'écran vierge existant
cp ~/emcomm-tools/backgrounds/blank-wallpaper.png \
   ~/emcomm-tools/backgrounds/emcomm-base.png

# Option 2 : Créer un fond sombre simple (1920x1080)
convert -size 1920x1080 xc:'#1a1a2e' \
    ~/emcomm-tools/backgrounds/emcomm-base.png
```

---

## 9. Construire l'ISO

```bash
cd ~/emcomm-tools
./setup-emcomm-iso.sh
```

Le script va :
1. Demander quel overlay utiliser
2. Demander s'il faut inclure les cartes
3. Demander le fond d'écran (générer un personnalisé ou utiliser un existant)
4. Demander le MOTD/bannière
5. Demander quel préfixe Wine inclure
6. Construire l'ISO automatiquement

---

## 10. Sortie du build

Après un build réussi (~15-30 minutes), trouvez l'ISO à :

```
~/emcomm-tools/build/emcomm-debian-iso/live-image-amd64.hybrid.iso
```

---

## 11. Tester avec QEMU

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -cdrom live-image-amd64.hybrid.iso \
    -boot d
```

### Avec dossier partagé (pour tester des fichiers) :

```bash
mkdir -p /mnt/shared

qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -cdrom live-image-amd64.hybrid.iso \
    -virtfs local,path=/mnt/shared,mount_tag=hostshare,security_model=mapped-xattr,id=hostshare \
    -boot d
```

Dans la VM :
```bash
sudo mkdir -p /mnt/host
sudo mount -t 9p -o trans=virtio hostshare /mnt/host
```

---

## 12. Graver sur clé USB

```bash
sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress
sync
```

**ATTENTION :** Remplacez `/dev/sdX` par votre périphérique USB réel ! Utilisez `lsblk` pour l'identifier.

---

## 13. Dépannage

### Le build échoue avec des erreurs de miroir

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
sudo lb clean --binary
sudo lb build 2>&1 | tee build.log
```

### Cache de paquets corrompu

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
sudo rm -rf cache/
sudo lb build 2>&1 | tee build.log
```

### Consulter le journal de build

```bash
less ~/emcomm-tools/build/emcomm-debian-iso/build.log
```

### Rebuild complet propre

```bash
cd ~/emcomm-tools
sudo rm -rf build/emcomm-debian-iso
./setup-emcomm-iso.sh
```

---

## 14. Commandes utiles

### Lister les paquets installés manuellement

```bash
apt-mark showmanual | sort
```

### Consulter l'historique apt

```bash
cat /var/log/apt/history.log | grep "Commandline"
```

### Consulter le journal dpkg

```bash
grep " install " /var/log/dpkg.log
```

### Vérifier l'utilisation du disque

```bash
du -sh ~/emcomm-tools/build/emcomm-debian-iso/
```

---

## 15. Référence rapide

| Tâche | Commande |
|-------|----------|
| Mettre à jour le système | `sudo apt update && sudo apt upgrade -y` |
| Construire l'ISO | `./setup-emcomm-iso.sh` |
| Tester l'ISO | `qemu-system-x86_64 -enable-kvm -m 4G -cdrom *.iso -boot d` |
| Graver sur USB | `sudo dd if=*.iso of=/dev/sdX bs=4M status=progress` |
| Nettoyer le build | `sudo lb clean --binary && sudo lb build` |
| Nettoyage complet | `sudo rm -rf build/emcomm-debian-iso` |

---

## 16. Contact

- **Projet :** https://emcomm-tools.ca
- **GitHub :** https://github.com/emcomm-tools
- **SourceForge :** https://sourceforge.net/projects/emcomm-tools/

**73 de VA2OPS**
