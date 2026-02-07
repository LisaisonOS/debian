# EmComm-Tools 2.0 Persistence System

**"Plug and Communicate"**

This module provides USB-based configuration persistence for EmComm-Tools,
enabling users to boot any computer and have their settings automatically
restored.

## Features

- **Automatic detection** of EmComm-Tools USB drives
- **Config persistence** - Save/restore all app configs (JS8Call, Pat, Fldigi, etc.)
- **Winlink mailbox** persistence
- **Ready Kit support** - Pre-loaded maps and Wikipedia
- **Bilingual** - French/English support

## Directory Structure

```
/opt/emcomm-tools/bin/et-persistence/
├── et-persistence              # Main wrapper script (subcommand interface)
├── et-persistence-detect       # Find emcomm-data on USB
├── et-persistence-init         # Initialize new USB for persistence
├── et-persistence-save         # Save configs to USB
├── et-persistence-restore      # Restore configs from USB
├── et-mount-usb-data           # Symlink maps/wikipedia from USB
├── persistence-mapping.json    # Config file mapping
└── persistence.py              # Python module for et-firstboot integration
```

## USB Drive Structure

```
VENTOY USB (64GB)
├── emcomm-tools-2.0.iso
│
├── emcomm-data/              ◄── Persistence directory
│   ├── user.json             # User identity (callsign, grid)
│   ├── manifest.json         # Metadata
│   ├── configs/              # App configurations
│   │   ├── pat/
│   │   ├── js8call/
│   │   ├── wsjtx/
│   │   └── ...
│   ├── mailbox/              # Winlink messages
│   └── backups/              # Auto-backups
│
├── maps/                     # Pre-loaded maps (Ready Kit)
│   ├── mbtiles/
│   └── navit/
│
├── wikipedia/                # Pre-loaded ZIM files
│
└── docs/                     # Reference documentation
```

## Usage

### Command Line

```bash
# Detect persistence
et-persistence detect

# Show status
et-persistence status

# Save all configs to USB
et-persistence save

# Restore configs from USB
et-persistence restore

# Initialize new USB
et-persistence init /media/user/MYUSB

# Mount pre-loaded data (maps, wikipedia)
et-persistence mount
```

### Python Integration (for et-firstboot.py)

```python
import sys
sys.path.insert(0, '/opt/emcomm-tools/bin/et-persistence')
from persistence import PersistenceManager

pm = PersistenceManager()
if pm.detect():
    callsign = pm.get_callsign()
    print(f"Welcome back {callsign}!")
    
    # Restore user config
    pm.restore_user_config(Path.home() / ".config/emcomm-tools/user.json")
```

## Boot Flow

```
Boot EmComm-Tools Live
         │
         ▼
  et-mount-usb-data    ──► Symlinks maps, wikipedia (no RAM copy!)
         │
         ▼
  et-firstboot.py
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Config    No Config
 Found?    Found?
    │         │
    ▼         ▼
"Welcome    Run
 back!"     wizard
    │         │
    └────┬────┘
         │
         ▼
   Ready to Communicate!
```

## License

Part of EmComm-Tools Debian Edition
https://emcomm-tools.ca

73 de VA2OPS
