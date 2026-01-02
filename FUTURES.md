# EmComm-Tools OS - Debian Edition

## Vision et Philosophie / Vision and Philosophy

This document outlines the future direction of EmComm-Tools OS Debian Edition, a fork of the original EmComm-Tools OS Community project by Gaston Gonzalez (KT7RUN / TheTechPrepper).

**Maintainer:** Sylvain Deguire (VA2OPS)

---

## Why Debian Over Ubuntu?

### Bilingual Support: A Quebec Necessity

This fork includes full **French/English bilingual support** - something not offered in the original EmComm-Tools OS.

**Why this matters:**

In Quebec, language laws (*Loi 101* / Bill 101) have specific requirements for French language availability. As an individual ham radio operator, using English-only software is a personal choice. However, for **radio clubs and legal entities** in Quebec, promoting or officially adopting an English-only solution can create compliance issues.

This Debian edition addresses this by providing:
- Bilingual installation and first-boot wizards (FR/EN)
- French translations for management scripts and menus
- Documentation in both languages
- Language selection at startup - the system asks, rather than assumes

**Technical Implementation:**

The overlay scripts from the original EmComm-Tools project have been modified to support bilingual operation. These modifications respect the original Ms-PL license while extending functionality for Francophone users.

This is not a criticism of the original project - TheTechPrepper built an excellent solution for his community. This fork simply extends that work to serve the Francophone ham radio community in Quebec and other French-speaking regions.

---

### The "Appliance" Debate

The original EmComm-Tools project was built on Ubuntu with the philosophy of creating a self-contained "appliance" - a frozen-in-time system where everything works together perfectly. While this approach has merit for certain use cases, the ham radio and emergency communications software landscape evolves rapidly.

**The problem with the appliance approach:**

- **Stability depends on updates** - When JS8Call, fldigi, or pat-winlink release bug fixes, you need to be able to apply them. A frozen OS makes this difficult or impossible.
- **Ham radio software evolves rapidly** - New digital modes, protocol improvements, and hardware support arrive regularly. Being stuck on old versions means missing out.
- **Security is less of a concern for many users** - Let's be honest: many EmComm operators will never connect their station PC to the internet. No personal files, no work documents, just radio. For these users, security patches matter less.
- **But what about stability?** - That's the real issue. When your base OS reaches end-of-life, you lose the ability to update *anything*. Your package manager stops working. Dependencies break. You're stuck.
- **So what are you gaining by freezing the OS?** - A false sense of "it works, don't touch it" that eventually becomes "it doesn't work, and I can't fix it."

### The Debian Advantage

**A Brief History:**

Debian is one of the oldest and most respected Linux distributions, founded in 1993 by Ian Murdock. The name combines his then-girlfriend (later wife) Debra with his own name Ian - "Deb-Ian."

**Ubuntu's Relationship to Debian:**

What many users don't realize is that **Ubuntu is built on top of Debian**. When Mark Shuttleworth created Ubuntu in 2004, he didn't start from scratch - he took Debian as the foundation and added:
- A more frequent release cycle (every 6 months)
- Simplified installation and desktop experience
- Commercial backing through Canonical Ltd.
- Ubuntu-specific branding and policies (including trademark restrictions)

In practical terms, Ubuntu takes Debian's package repositories, modifies some packages, adds their own, and releases it with Ubuntu branding. The underlying system - the package manager (apt/dpkg), the file system structure, the core utilities - all come from Debian.

**What this means for EmComm-Tools:**

Moving from Ubuntu to Debian isn't a radical change - it's going back to the source. Most of what worked on Ubuntu works identically on Debian because Ubuntu inherited it from Debian in the first place. The main differences are:
- No trademark restrictions on redistribution
- Longer, more stable release cycles
- Direct access to Debian's extensive package repositories
- A community-driven project without corporate overhead

**Long-Term Stability with Active Maintenance:**
Debian Stable provides a 3-5 year support cycle with continuous security updates. Unlike Ubuntu's 6-month release cadence that can break things, Debian prioritizes stability while remaining actively maintained.

**No Trademark Restrictions:**
The original EmComm-Tools project is licensed under the **Microsoft Public License (Ms-PL)** - a permissive open-source license that explicitly allows derivative works and distribution. However, the *base operating system* creates a problem.

Ubuntu's trademark policy restricts redistribution of modified Ubuntu ISOs. This is why the original project states "You must build your own distribution" and "Please do not distribute pre-built images." It's not the EmComm-Tools code that's restricted - it's the Ubuntu branding underneath.

**Debian has no such restrictions.** By building on Debian instead of Ubuntu, we can freely distribute pre-built ISOs while still honoring the Ms-PL license terms. Users get a ready-to-boot image without legal complications.

**Ham Radio Software Availability:**
Debian repositories contain most ham radio applications that required manual compilation on Ubuntu. The Debian Ham Radio Pure Blend includes js8call, wsjtx, fldigi, direwolf, and many others - all properly packaged and maintained.

**My Commitment:**
I will not sit on my hands. This project will always provide the best up-to-date LTS (Long-Term Support) operating system, ensuring your EmComm station remains secure and functional.

---

## Getting Started with Pre-Built ISOs

### For First-Time Linux Users

One of the biggest barriers to ham radio digital modes is the complexity of setting up a Linux environment. Our pre-built ISO files eliminate this barrier entirely.

**Benefits of Pre-Baked ISOs:**

- **No Linux installation required** - Boot directly from USB and start operating
- **Wine pre-configured** - Wine32 environment ready for Windows ham radio applications
- **Native ham apps included** - JS8Call, WSJTX, fldigi, pat-winlink, direwolf, and more
- **Bilingual interface (FR/EN)** - Language selection at first boot
- **Tested hardware compatibility** - Optimized for field deployment on devices like Panasonic Toughpads
- **Offline-ready** - All tools work without internet connectivity (SHTF scenarios)

### VARA HF/FM and VarAC Installation

**Important:** VARA HF, VARA FM, and VarAC are **not pre-installed** in the ISO. These applications have specific licensing terms that do not permit redistribution.

**First-Boot Installation Option:**

At first boot, the system will offer to download and install VARA and VarAC for you:

1. **Fresh Install:** If you select "Yes", an installation script will:
   - Download VARA HF/FM and VarAC installers via `wget`
   - Launch each installer through Wine
   - **You must complete the installation wizard manually** for each application
   - This process respects the developers' distribution policies and license agreements

2. **Restore from Backup:** If you previously used the original EmComm-Tools OS (Ubuntu/TTP version) and created a Wine backup using the `05-backup-wine-install.sh` script (TAR file), you can restore it directly. This method preserves your existing VARA configuration and registration.

**Note:** An internet connection is required for the fresh install option. Plan accordingly if you're setting up for field deployment.

### ISO Versions: Small vs Full

Two ISO versions are available for download:

| Version | Size | Maps Included | Best For |
|---------|------|---------------|----------|
| **Small** | ~3 GB | No | Users with good internet, storage-constrained devices |
| **Full** | ~8 GB | Yes (US, Canada, World) | Field deployment prep, offline-first setups |

**Small ISO - First Boot Map Options:**

If you download the small ISO, the first-boot wizard will offer to:
1. **Download maps** - Fetch and install map tilesets (requires internet)
2. **Skip** - Run without maps (can add later)

**External Drive / USB Storage:**

For devices with limited internal storage (like Panasonic Toughpads), maps can be hosted on an external drive or USB thumb drive instead of the internal disk. This keeps your system partition lean while still having full offline map capability.

This flexibility lets you choose the right balance between ISO size, download time, and storage usage for your specific deployment scenario.

### USB Boot Creator Tools

The only software you need is a USB boot creator. Here are the most reliable options by platform:

#### Windows

| Tool | Description | Download |
|------|-------------|----------|
| **Rufus** | Fast, reliable, open-source. The gold standard for Windows. | [rufus.ie](https://rufus.ie) |
| **balenaEtcher** | Simple 3-step process, validates writes, cross-platform. | [etcher.balena.io](https://etcher.balena.io) |
| **Ventoy** | Multi-boot capable - put multiple ISOs on one USB. | [ventoy.net](https://ventoy.net) |

#### macOS

| Tool | Description | Download |
|------|-------------|----------|
| **balenaEtcher** | Best choice for Mac - simple, reliable, native app. | [etcher.balena.io](https://etcher.balena.io) |
| **UNetbootin** | Cross-platform, works well for Linux ISOs. | [unetbootin.github.io](https://unetbootin.github.io) |
| **dd (Terminal)** | Built-in, powerful but requires care. | `sudo dd if=image.iso of=/dev/diskN bs=4M` |

#### Linux

| Tool | Description | Install |
|------|-------------|---------|
| **balenaEtcher** | Same simple interface as other platforms. | AppImage available |
| **Ventoy** | Install once, then just copy ISO files to USB. | [ventoy.net](https://ventoy.net) |
| **GNOME Disks** | Built into most GNOME desktops, "Restore Disk Image" feature. | Pre-installed |
| **dd** | Classic Unix tool, fast and reliable. | `sudo dd if=image.iso of=/dev/sdX bs=4M status=progress` |

#### Recommendation

For beginners: **balenaEtcher** - Works on all platforms, impossible to accidentally overwrite your hard drive, validates the write.

For advanced users: **Ventoy** - Install it once on your USB drive, then simply copy ISO files to it. You can have EmComm-Tools, a Windows installer, and system rescue tools all on one USB.

---

## Roadmap / Feuille de Route

### Phase 1: Foundation (Current)

- [x] Migration from Ubuntu to Debian Stable
- [x] Pure `live-build` workflow (replacing Cubic)
- [x] Wine32 environment ready for VARA HF/FM and VarAC
- [x] First-boot VARA/VarAC installation wizard
- [x] Support for restoring Wine backups from Ubuntu/TTP version
- [x] PostgreSQL and MySQL for BBS server applications
- [x] Bilingual management scripts (FR/EN)
- [x] WSJTX integration for FT8/FT4

### Phase 2: Enhanced Digital Modes (Planned)

- [ ] Improved VARA integration with automatic audio routing
- [ ] JS8Call message templates for EmComm operations
- [ ] pat-winlink form templates for Canadian EmComm
- [ ] Tactical Traffic Planner (TTP) integration

### Phase 3: Offline Capabilities (Planned)

- [ ] Expanded offline map coverage
- [ ] Offline ham radio documentation (ARRL Handbook excerpts where permitted)
- [ ] Local AI assistant integration (RAG-based)
- [ ] Mesh networking support (Meshtastic integration)

### Phase 4: Field Deployment (Planned)

- [ ] Power management optimization for Toughpads
- [ ] Quick-deploy scripts for EmComm exercises
- [ ] Integration with Canadian ARES/CANWARN procedures
- [ ] Multi-language support expansion (Indigenous languages for remote communities)

---

## Contributing

This is an open-source project. Contributions, bug reports, and feature requests are welcome.

**Repository:** [github.com/emcomm-tools/debian](https://github.com/emcomm-tools/debian)

**ISO Downloads:** [sourceforge.net/p/emcomm-tools](https://sourceforge.net/p/emcomm-tools/)

**Website:** [emcomm-tools.ca](https://emcomm-tools.ca) | [emcomm-tools.com](https://emcomm-tools.com)

**Contact:** VA2OPS

---

## License

This project is a derivative work of EmComm-Tools OS Community, licensed under the **Microsoft Public License (Ms-PL)**.

In compliance with Ms-PL Section 3(C), we retain all copyright, patent, trademark, and attribution notices from the original software.

**What the Ms-PL allows:**
- Creating derivative works (this Debian edition)
- Distributing pre-built ISO images
- Modification and redistribution

**What we honor:**
- Original attribution to Gaston Gonzalez (KT7RUN) aka *The Tech Prepper* and contributors
- Distribution under the same Ms-PL license
- No use of original project trademarks or branding

The switch from Ubuntu to Debian eliminates the Ubuntu trademark restrictions that previously prevented distribution of pre-built images, while fully respecting the Ms-PL terms of the original EmComm-Tools project.

---

## Acknowledgments

- **Gaston Gonzalez (KT7RUN)** aka *The Tech Prepper* - Original EmComm-Tools OS Community project
- **The Debian Ham Radio Team** - Maintaining excellent ham radio packages
- **EA5HVK** - VARA HF/FM modem development
- **VarAC Development Team** - VarAC chat application for VARA

---

*73 de VA2OPS*
