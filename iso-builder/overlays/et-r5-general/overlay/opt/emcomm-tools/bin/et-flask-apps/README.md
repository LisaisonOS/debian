# EmComm-Tools Flask Apps with PyWebView

Author: Sylvain Deguire (VA2OPS)
Date: January 2026

## Apps Included

| App | Port | Description |
|-----|------|-------------|
| **et-firstboot** | 5051 | First boot wizard (6 steps) |
| **et-radio** | 5052 | Radio selection |
| **et-mode** | 5053 | Mode selection & service control |
| **et-user** | 5054 | User configuration (callsign, grid, Winlink) |

## Requirements

```bash
sudo apt install python3-flask python3-webview
```

## Running

Each app opens in a native PyWebView window by default:

```bash
python3 et-mode.py              # Native window (default)
python3 et-mode.py --browser    # Open in web browser
python3 et-mode.py --no-browser # Server only (debugging)
```

### et-firstboot specific:
```bash
python3 et-firstboot.py --force  # Re-run even if completed
```

## Window Sizes

| App | Default Size | Min Size |
|-----|--------------|----------|
| et-firstboot | 520x800 | 420x600 |
| et-radio | 500x700 | 400x500 |
| et-mode | 500x750 | 400x600 |
| et-user | 480x650 | 400x500 |

## File Structure

```
et-flask-apps/
├── README.md
├── et-firstboot/
│   ├── et-firstboot.py
│   ├── static/css/, js/
│   └── templates/
├── et-radio/
│   ├── et-radio.py
│   ├── static/css/, js/
│   └── templates/
├── et-mode/
│   ├── et-mode.py
│   ├── static/css/, js/
│   └── templates/
└── et-user/
    ├── et-user.py
    ├── static/css/, js/
    └── templates/
```

## 73 de VA2OPS!
