<h1 align="center">EmComm-Tools OS — Debian Edition</h1>
<p align="center">
  <em>Explore. Connect. Respond.</em><br>
  <em>Explorer. Connecter. Répondre.</em>
</p>

<p align="center">
  <a href="https://sourceforge.net/projects/emcomm-tools/"><img src="https://img.shields.io/badge/Version-2.1.8-f59e0b?style=for-the-badge" alt="Version 2.1.8"></a>
  <a href="https://sourceforge.net/projects/emcomm-tools/files/ISO/"><img src="https://img.shields.io/badge/Download-ISO-22c55e?style=for-the-badge&logo=sourceforge" alt="Download ISO"></a>
  <a href="https://opensource.org/licenses/MS-PL"><img src="https://img.shields.io/badge/License-Ms--PL-3b82f6?style=for-the-badge" alt="License Ms-PL"></a>
  <a href="https://va2ops.ca"><img src="https://img.shields.io/badge/VA2OPS-va2ops.ca-8b5cf6?style=for-the-badge" alt="VA2OPS"></a>
</p>

<p align="center">
  A bilingual (FR/EN) Debian-based Linux distribution purpose-built for amateur radio emergency communications.<br>
  Boot from USB, connect your radio, and you are on the air — with JS8Call, Pat-Winlink, VARA, VarAC, YAAC, fldigi, and a YAAC SAR plugin ready to go.
</p>

---

## Français | English

<table>
<tr>
<td width="50%" valign="top">

<h3>Français</h3>

<p>Distribution Linux EmComm bilingue (FR/EN) basée sur Debian pour radioamateurs.</p>

<p><strong>Mainteneur :</strong> <a href="https://va2ops.ca/fr/">Sylvain Deguire (VA2OPS)</a></p>

<p>
📖 <a href="FUTURES_fr.md">Documentation</a><br>
💾 <a href="https://sourceforge.net/projects/emcomm-tools/files/ISO/">Téléchargements ISO</a><br>
☕ <a href="https://buymeacoffee.com/emcommtools">Offrez-moi un café</a><br>
⚠️ <a href="DISCLAIMER.md">Avis de non-responsabilité</a>
</p>

</td>
<td width="50%" valign="top">

<h3>English</h3>

<p>Bilingual (FR/EN) Debian-based EmComm Linux for Ham Radio.</p>

<p><strong>Maintainer:</strong> <a href="https://va2ops.ca">Sylvain Deguire (VA2OPS)</a></p>

<p>
📖 <a href="FUTURES.md">Documentation</a><br>
💾 <a href="https://sourceforge.net/projects/emcomm-tools/files/ISO/">ISO Downloads</a><br>
☕ <a href="https://buymeacoffee.com/emcommtools">Buy Me a Coffee</a><br>
⚠️ <a href="DISCLAIMER.md">Disclaimer</a>
</p>

</td>
</tr>
</table>

---

## ✨ What's New in 2.1.8

### 🏕️ POTA/SOTA Field Logger (et-logger)

New field logging application for Parks on the Air and Summits on the Air activations.

- **Auto-QSY** — Frequency, mode, and band update live when you turn the VFO knob
- **Callsign lookup** — Merged US/CA license database with autocomplete
- **Map view** — Leaflet map with contact lines, callsign labels, and distance
- **Nearest POTA parks** — 87,000 parks in SQLite with bounding-box filter and auto-zoom
- **Park-to-Park (P2P)** — Multi-park support for 2-fer/3-fer activations
- **ADIF export** — Per-park files with POTA naming convention
- **Touch-friendly** — Custom popup pickers for RST, Band, Mode (designed for 7" screens)
- **GPS position**, duplicate detection, QSO counter (10 for valid activation)
- **Dark theme, bilingual EN/FR**

### 📡 Persistent Radio Connection (rig-client)

All radio communication now goes through a single persistent TCP connection to rigctld — no more subprocess spawning, reducing relay clicks on older rigs like the FT-897D.

- **Background polling** — Radio state refreshed every 2 seconds silently
- **QSY callback** — Applications notified instantly when you change frequency
- **Wine mode switching fix** — Eliminates CAT control errors when switching from Wine modes to JS8Call/FT8

### 🐛 Bug Fixes

- **JS8Call & WSJT-X** — Save path fix for HDD installs (crash-on-launch resolved)
- **Repeater Directory** — FM mode programming fix for radios rejecting passband parameters

---

## 📻 Key Features

| Feature | Description |
|---------|-------------|
| 🌐 **Bilingual** | French and English with language selection at first boot |
| 📧 **Pat-Winlink** | Email over RF with VARA HF/FM and ARDOP |
| 💬 **JS8Call / VarAC** | HF keyboard messaging and chat |
| 📡 **APRS (YAAC)** | Position tracking with SAR plugin for field evidence marking |
| 📟 **BBS / Packet** | LinBPQ server, QtTermTCP, Paracon clients |
| 🔭 **WSJT-X / fldigi** | FT8, FT4, PSK, RTTY, CW and more |
| 🏕️ **POTA/SOTA Logger** | Built-in field logger with ADIF export |
| 📻 **Repeater Directory** | Offline browser with RepeaterBook import and one-click radio programming |
| 🛰️ **GPS Tracking** | Real-time grid square updates with repeater distance refresh |
| 🗺️ **Offline Maps** | Navit navigation + MBTile server for offline mapping |
| 📖 **Offline Reference** | Kiwix with Wikipedia and encyclopedia ZIM files |
| 🔌 **24+ Radios** | Icom, Yaesu, Kenwood, Xiegu, Elecraft, QRP Labs and more |
| 💾 **USB Persistence** | Complete environment saved and restored across reboots |
| 🖥️ **Web Dashboard** | One-click mode launch with 16 operational modes |

---

## 📥 Quick Start

1. **Download** the ISO from [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/ISO/)
2. **Write** to USB with [balenaEtcher](https://etcher.balena.io) or [Ventoy](https://ventoy.net)
3. **Boot** from USB — select your language (FR/EN)
4. **Configure** your callsign and radio
5. **Operate** — select a mode from the dashboard and you're on the air

> **Tip:** Use [Ventoy](https://ventoy.net) for multi-boot USB with a separate data partition for maps and Wikipedia files. See the [full README](https://sourceforge.net/projects/emcomm-tools/files/ISO/README.md) on SourceForge for the complete Ventoy guide.

---

## 📻 Supported Radios

### USB Direct

| Vendor | Model | Notes |
|--------|-------|-------|
| BG2FX | FX-4CR | USB CAT + audio |
| Icom | IC-705, IC-7100, IC-7200, IC-7300, IC-9700 | USB CAT + audio |
| QRP Labs | QMX | USB CAT |
| Xiegu | X6100 | USB CAT + audio |
| Yaesu | FT-710, FT-891, FT-991A, FTX-1 | USB CAT + audio (varies) |

### Via DigiRig Interface

Elecraft KX-2, Lab599 TX-500MP, Xiegu G90, Yaesu FT-818ND, FT-857D, FT-897D, and any radio with DigiRig Mobile or Lite.

### Bluetooth KISS TNC

Kenwood TH-D74, Kenwood TH-D75, VGC VR-N76, BTECH UV-PRO

---

## 🏗️ Operational Modes

The dashboard provides **16 one-click operational modes:**

| Category | Modes |
|----------|-------|
| **Winlink** | VARA HF, VARA FM, Packet, ARDOP |
| **Chat** | JS8Call, VarAC, Fldigi, Chattervox, Chattervox BT |
| **BBS** | Paracon, QtTermTCP, BBS Server (LinBPQ) |
| **APRS** | YAAC Client, YAAC BT, APRS Digipeater |
| **Other** | FT8/FT4 (WSJT-X), Direwolf KISS TNC |

---

## 🔗 Links

| | |
|---|---|
| 🌐 **Website** | [emcomm-tools.ca](https://emcomm-tools.ca) |
| 💾 **ISO Downloads** | [SourceForge](https://sourceforge.net/projects/emcomm-tools/files/ISO/) |
| 🐙 **GitHub** | [emcomm-tools/debian](https://github.com/emcomm-tools/debian/) |
| 👤 **Maintainer** | [va2ops.ca](https://va2ops.ca) |
| ☕ **Support** | [Buy Me a Coffee](https://buymeacoffee.com/emcommtools) |
| 📧 **Contact** | <a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="c5acaba3aa85a0a8a6aaa8a8e8b1aaaaa9b6eba6a4">[email&#160;protected]</a> |

---

## 🙏 Acknowledgments

- **Gaston Gonzalez (KT7RUN)** — Original EmComm-Tools OS Community project
- **The Debian Ham Radio Team** — Maintaining excellent ham radio packages
- **José Alberto Nieto Ros (EA5HVK)** — VARA HF/FM modem development
- **Irad Deutsch (4Z1AC) and the VarAC Development Team** — VarAC
- **Andrew Pavlin (KA2DDO)** — YAAC (Yet Another APRS Client)
- **Martin Hebnes Pedersen (LA5NTA)** — Pat Winlink
- **John Wiseman (G8BPQ)** — linBPQ / QtTermTCP
- **Martin F N Cooper** — Paracon
- **David Freese (W1HKJ)** — fldigi
- **Joe Taylor (K1JT) and the WSJT Development Team** — WSJT-X

---

## 📄 License

This project is a derivative work of EmComm-Tools OS Community, licensed under the **[Microsoft Public License (Ms-PL)](https://opensource.org/licenses/MS-PL)**. In compliance with Ms-PL Section 3(C), we retain all copyright, patent, trademark, and attribution notices from the origina
