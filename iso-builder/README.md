# EmComm-Tools ISO Builder

Build your own customized EmComm-Tools Live ISO based on Debian.

## Quick Start

```bash
cd emcomm-tools
./setup-emcomm-iso.sh
```

The script will guide you through configuration and build the ISO automatically.

## Requirements

- Debian 12+ (Trixie recommended)
- ~10GB free disk space
- Internet connection
- `sudo` access

## Directory Structure

```
emcomm-tools/
├── setup-emcomm-iso.sh      # Main build script
├── overlays/                # EmComm-Tools overlay files
│   └── et-r5-final/         # Based on TTP's R5 release
│       └── overlay/
│           └── opt/emcomm-tools/bin/   # et-* scripts
├── scripts/                 # ISO build configuration files
│   ├── package-lists/       # Debian packages to install
│   ├── hooks/               # Build hooks (0xxx-*.hook.chroot)
│   ├── autostart/           # Desktop autostart entries
│   ├── panel-launchers/     # XFCE panel launcher .desktop files
│   ├── xfce-config/         # XFCE XML configuration files
│   └── etc/                 # System config files (/etc)
├── backgrounds/             # Wallpaper images
├── motd/                    # Terminal banners
└── wine-sources/            # Pre-configured Wine prefix (from SourceForge)
```

## Configuration Options

The setup script offers several customization options:

### 1. Overlay Selection
Choose which EmComm-Tools version to build.

### 2. Wallpaper
- **Generate custom** - Enter your callsign + tagline
- **Select existing** - Choose from `backgrounds/` folder
- **Use default** - From the overlay

### 3. Wine Prefix
A pre-configured Wine prefix is downloaded from SourceForge (~100MB). This provides a ready-to-use Wine environment for VARA and VarAC.

**Note:** VARA and VarAC are NOT included due to licensing. Users must install them on first boot by running VarAC from the panel - it will download and run the official installer.

### 4. MOTD Banner
Custom terminal message displayed on login.

## Build Output

The ISO is created in:
```
build/emcomm-debian-iso/live-image-amd64.hybrid.iso
```

After a successful build, the script offers to test in QEMU.

## First Boot

On first boot, a wizard configures:
1. User settings (callsign, grid, Winlink password)
2. Radio/transceiver selection
3. Offline maps (optional)

To install VARA/VarAC: Click the VarAC icon in the panel and follow the official installer.

## Dashboard & Configuration

A dashboard is displayed on the desktop with quick access buttons:
- **OPERATOR [⚙]** - Configure callsign, grid, Winlink password
- **INTERFACES [⚙]** - Configure radio/transceiver
- **MODE [⚙]** - Select operating mode
- **Quick launch buttons** - Winlink, JS8Call, VarAC, BBS

Users can also configure from the command line:
```bash
et-user        # Callsign, grid, Winlink
et-radio       # Transceiver selection
et-maps-setup  # Offline maps
et-mode        # Operating mode
```

## Downloads

| File | Source | Size |
|------|--------|------|
| wine-sources | [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/wine-sources-general.tar.gz) | ~100MB |
| ISO images | [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/) | ~2.8GB |

## Credits

- **EmComm-Tools OS** by Gaston Gonzalez (KT7RUN)
- **Debian ISO Builder** by Sylvain Deguire (VA2OPS)

## License

See [LICENSE](../LICENSE) for details.

---

73 de VA2OPS 📻
