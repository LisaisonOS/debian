# EmComm-Tools Debian ISO Builder - Development Environment Setup

**Author:** Sylvain Deguire (VA2OPS)  
**Date:** January 2026  
**Version:** 1.0

---

## Overview

This document describes how to set up a fresh Debian system for building EmComm-Tools Debian Live ISOs. Follow these steps on a clean Debian 12 (Bookworm) or Debian 13 (Trixie) installation.

---

## 1. Base System Requirements

- **OS:** Debian 12+ (Bookworm or Trixie)
- **Disk Space:** Minimum 50GB free (100GB+ recommended)
- **RAM:** 8GB+ recommended
- **CPU:** Multi-core recommended for faster builds

---

## 2. Initial System Update

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3. Install Required Packages

### 3.1 Core Build Tools

```bash
sudo apt install -y \
    live-build \
    build-essential \
    git \
    dialog \
    imagemagick \
    zip wget curl tree
```

### 3.2 QEMU (for ISO testing)

```bash
sudo apt install -y qemu-system-x86
```

### 3.3 Wine (for VARA/VarAC testing)

```bash
sudo apt install -y wine wine32:i386 winetricks
```

### 3.4 Optional - Audio Development

```bash
sudo apt install -y libpulse-dev portaudio19-dev
```

---

## 4. One-Liner Installation (All Packages)

Copy and paste this single command to install everything:

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

### Optional - For audio development/testing:

```bash
sudo apt install -y libpulse-dev portaudio19-dev
```

---

## 5. Clone the Repository

```bash
cd ~
git clone https://github.com/emcomm-tools/emcomm-tools-git.git emcomm-tools
cd emcomm-tools
```

Or if using your own fork:

```bash
git clone https://github.com/YOUR_USERNAME/emcomm-tools.git
cd emcomm-tools
```

---

## 6. Directory Structure

After setup, your directory should look like:

```
~/emcomm-tools/
├── setup-emcomm-iso.sh      # Main build script
├── sync-overlay.sh          # Overlay sync utility
├── backgrounds/             # Wallpaper images
│   └── emcomm-base.png      # Base image for generator
├── motd/                    # Terminal banners
├── overlays/                # EmComm-Tools overlays
│   └── et-r5-final/
│       └── overlay/
├── scripts/                 # Build scripts and hooks
│   ├── autostart/
│   ├── hooks/
│   ├── package-lists/
│   ├── panel-launchers/
│   └── xfce-config/
├── wine-sources/            # Wine prefixes (VARA, VarAC)
│   └── wine32-general/
└── build/                   # Build output (auto-created)
    └── emcomm-debian-iso/
```

---

## 7. Download Wine Sources (Optional but Recommended)

The wine-sources contain a pre-configured .win32 for installation of VARA and VarAC:

```bash
mkdir -p ~/emcomm-tools/wine-sources
cd ~/emcomm-tools/wine-sources
wget "https://sourceforge.net/projects/emcomm-tools/files/wine-sources-general.tar.gz/download" \
    -O wine-sources-general.tar.gz
tar -xzf wine-sources-general.tar.gz
rm wine-sources-general.tar.gz
```

---

## 8. Create Base Wallpaper

The wallpaper generator needs a base image:

```bash
# Option 1: Use existing blank wallpaper
cp ~/emcomm-tools/backgrounds/blank-wallpaper.png \
   ~/emcomm-tools/backgrounds/emcomm-base.png

# Option 2: Create a simple dark background (1920x1080)
convert -size 1920x1080 xc:'#1a1a2e' \
    ~/emcomm-tools/backgrounds/emcomm-base.png
```

---

## 9. Build the ISO

```bash
cd ~/emcomm-tools
./setup-emcomm-iso.sh
```

The script will:
1. Ask which overlay to use
2. Ask about including maps
3. Ask about wallpaper (generate custom or use existing)
4. Ask about MOTD/banner
5. Ask which Wine prefix to include
6. Build the ISO automatically

---

## 10. Build Output

After a successful build (~15-30 minutes), find the ISO at:

```
~/emcomm-tools/build/emcomm-debian-iso/live-image-amd64.hybrid.iso
```

---

## 11. Test with QEMU

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -cdrom live-image-amd64.hybrid.iso \
    -boot d
```

### With Shared Folder (for testing files):

```bash
mkdir -p /mnt/shared

qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -cdrom live-image-amd64.hybrid.iso \
    -virtfs local,path=/mnt/shared,mount_tag=hostshare,security_model=mapped-xattr,id=hostshare \
    -boot d
```

Inside VM:
```bash
sudo mkdir -p /mnt/host
sudo mount -t 9p -o trans=virtio hostshare /mnt/host
```

---

## 12. Burn to USB

```bash
sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress
sync
```

**WARNING:** Replace `/dev/sdX` with your actual USB device! Use `lsblk` to identify it.

---

## 13. Troubleshooting

### Build fails with mirror errors

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
sudo lb clean --binary
sudo lb build 2>&1 | tee build.log
```

### Package cache corrupted

```bash
cd ~/emcomm-tools/build/emcomm-debian-iso
sudo rm -rf cache/
sudo lb build 2>&1 | tee build.log
```

### Check build log

```bash
less ~/emcomm-tools/build/emcomm-debian-iso/build.log
```

### Full clean rebuild

```bash
cd ~/emcomm-tools
sudo rm -rf build/emcomm-debian-iso
./setup-emcomm-iso.sh
```

---

## 14. Useful Commands

### List manually installed packages

```bash
apt-mark showmanual | sort
```

### Check apt history

```bash
cat /var/log/apt/history.log | grep "Commandline"
```

### Check dpkg log

```bash
grep " install " /var/log/dpkg.log
```

### Check disk usage

```bash
du -sh ~/emcomm-tools/build/emcomm-debian-iso/
```

---

## 15. Quick Reference

| Task | Command |
|------|---------|
| Update system | `sudo apt update && sudo apt upgrade -y` |
| Build ISO | `./setup-emcomm-iso.sh` |
| Test ISO | `qemu-system-x86_64 -enable-kvm -m 4G -cdrom *.iso -boot d` |
| Burn USB | `sudo dd if=*.iso of=/dev/sdX bs=4M status=progress` |
| Clean build | `sudo lb clean --binary && sudo lb build` |
| Full clean | `sudo rm -rf build/emcomm-debian-iso` |

---

## 16. Contact

- **Project:** https://emcomm-tools.ca
- **GitHub:** https://github.com/emcomm-tools
- **SourceForge:** https://sourceforge.net/projects/emcomm-tools/

**73 de VA2OPS**
