#!/usr/bin/env python3
"""
et-mode - EmComm-Tools Mode Selection
Author: Sylvain Deguire (VA2OPS)
Date: January 2026

Flask-based web UI for selecting and starting operating modes.
Replaces the bash/dialog version with a modern web interface.
"""

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*pkg_resources.*")

import os
import sys
import json
import subprocess
import webbrowser
import threading
import time
import logging
from pathlib import Path
from flask import Flask, render_template, request, jsonify, redirect, url_for

# Suppress Flask development server warning
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
app.secret_key = 'emcomm-tools-mode-2026'

# Configuration paths
ET_CONFIG_DIR = Path.home() / ".config" / "emcomm-tools"
ET_CONFIG_FILE = ET_CONFIG_DIR / "user.json"
MODE_STATUS_FILE = ET_CONFIG_DIR / "et-mode"
QTTERMTCP_CONF_FILE = Path.home() / ".config" / "QtTermTCP.ini"
WINE_DIR = Path.home() / ".wine32" / "drive_c"

# ============================================================================
# Mode Definitions
# ============================================================================

MODES = [
    {
        "id": "none",
        "icon": "🚫",
        "name": "No Mode",
        "name_fr": "Aucun Mode",
        "description": "Stop all services",
        "description_fr": "Arrêter tous les services",
        "category": "system"
    },
    {
        "id": "aprs-client",
        "icon": "📍",
        "name": "APRS Client (YAAC)",
        "name_fr": "Client APRS (YAAC)",
        "description": "Position reporting and messaging",
        "description_fr": "Rapport de position et messagerie",
        "category": "aprs",
        "modem": False
    },
    {
        "id": "aprs-digipeater",
        "icon": "📡",
        "name": "APRS Digipeater",
        "name_fr": "Digipeater APRS",
        "description": "Relay APRS packets",
        "description_fr": "Relayer les paquets APRS",
        "category": "aprs",
        "modem": False
    },
    {
        "id": "bbs-client",
        "icon": "📋",
        "name": "BBS Client (Paracon)",
        "name_fr": "Client BBS (Paracon)",
        "description": "Connect to packet BBS",
        "description_fr": "Se connecter à un BBS packet",
        "category": "bbs",
        "modem": "standard"
    },
    {
        "id": "bbs-client2",
        "icon": "📋",
        "name": "BBS Client (QtTermTCP)",
        "name_fr": "Client BBS (QtTermTCP)",
        "description": "Connect to BBS with VARA support",
        "description_fr": "Se connecter à un BBS avec VARA",
        "category": "bbs",
        "modem": "with_vara"
    },
    {
        "id": "bbs-server",
        "icon": "🖥️",
        "name": "BBS Server (LinBPQ)",
        "name_fr": "Serveur BBS (LinBPQ)",
        "description": "Run your own BBS",
        "description_fr": "Exécuter votre propre BBS",
        "category": "bbs",
        "modem": "server"
    },
    {
        "id": "chat-chattervox",
        "icon": "💬",
        "name": "Chat (Chattervox)",
        "name_fr": "Clavardage (Chattervox)",
        "description": "Real-time packet chat",
        "description_fr": "Clavardage packet en temps réel",
        "category": "chat",
        "modem": False
    },
    {
        "id": "packet-digipeater",
        "icon": "📡",
        "name": "Packet Digipeater",
        "name_fr": "Digipeater Packet",
        "description": "Relay packet radio",
        "description_fr": "Relayer le packet radio",
        "category": "packet",
        "modem": False
    },
    {
        "id": "winlink-packet",
        "icon": "📧",
        "name": "Winlink VHF/UHF (Packet)",
        "name_fr": "Winlink VHF/UHF (Packet)",
        "description": "Email over VHF/UHF packet",
        "description_fr": "Courriel par packet VHF/UHF",
        "category": "winlink",
        "modem": False
    },
    {
        "id": "winlink-vara-fm",
        "icon": "📧",
        "name": "Winlink VHF/UHF (VARA FM)",
        "name_fr": "Winlink VHF/UHF (VARA FM)",
        "description": "Email over VARA FM",
        "description_fr": "Courriel par VARA FM",
        "category": "winlink",
        "modem": False,
        "requires": "vara-fm"
    },
    {
        "id": "winlink-ardop",
        "icon": "📧",
        "name": "Winlink HF (ARDOP)",
        "name_fr": "Winlink HF (ARDOP)",
        "description": "Email over HF with ARDOP",
        "description_fr": "Courriel HF avec ARDOP",
        "category": "winlink",
        "modem": False
    },
    {
        "id": "winlink-vara-hf",
        "icon": "📧",
        "name": "Winlink HF (VARA HF)",
        "name_fr": "Winlink HF (VARA HF)",
        "description": "Email over HF with VARA",
        "description_fr": "Courriel HF avec VARA",
        "category": "winlink",
        "modem": False,
        "requires": "vara-hf"
    }
]

MODEMS = {
    "standard": [
        {"id": "1200", "name": "1200 baud", "description": "Default for VHF/UHF", "description_fr": "Par défaut pour VHF/UHF"},
        {"id": "9600", "name": "9600 baud", "description": "VHF/UHF (special cable)", "description_fr": "VHF/UHF (câble spécial)"},
        {"id": "300", "name": "300 baud", "description": "HF packet", "description_fr": "Packet HF"}
    ],
    "with_vara": [
        {"id": "1200", "name": "1200 baud", "description": "Default for VHF/UHF", "description_fr": "Par défaut pour VHF/UHF"},
        {"id": "9600", "name": "9600 baud", "description": "VHF/UHF (special cable)", "description_fr": "VHF/UHF (câble spécial)"},
        {"id": "300", "name": "300 baud", "description": "HF packet", "description_fr": "Packet HF"},
        {"id": "vara-fm", "name": "VARA FM", "description": "VARA FM modem", "description_fr": "Modem VARA FM", "requires": "vara-fm"},
        {"id": "vara-hf", "name": "VARA HF", "description": "VARA HF modem", "description_fr": "Modem VARA HF", "requires": "vara-hf"}
    ],
    "server": [
        {"id": "1200", "name": "1200 baud", "description": "Default for VHF/UHF", "description_fr": "Par défaut pour VHF/UHF"},
        {"id": "9600", "name": "9600 baud", "description": "VHF/UHF (special cable)", "description_fr": "VHF/UHF (câble spécial)"},
        {"id": "300", "name": "300 baud", "description": "HF packet", "description_fr": "Packet HF"},
        {"id": "vara-fm", "name": "VARA FM", "description": "VARA FM modem", "description_fr": "Modem VARA FM"},
        {"id": "vara-hf", "name": "VARA HF", "description": "VARA HF modem", "description_fr": "Modem VARA HF"}
    ]
}

# ============================================================================
# Helper Functions
# ============================================================================

def get_language():
    """Get language preference from user config."""
    if ET_CONFIG_FILE.exists():
        try:
            with open(ET_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                return config.get('language', 'en')
        except Exception:
            pass
    return 'en'


def is_vara_fm_installed():
    """Check if VARA FM is installed."""
    return (WINE_DIR / "VARA FM" / "VARAFM.exe").exists()


def is_vara_hf_installed():
    """Check if VARA HF is installed."""
    return (WINE_DIR / "VARA" / "VARA.exe").exists()


def get_available_modes():
    """Get list of modes, filtering out unavailable VARA modes."""
    available = []
    for mode in MODES:
        requires = mode.get("requires")
        if requires == "vara-fm" and not is_vara_fm_installed():
            continue
        if requires == "vara-hf" and not is_vara_hf_installed():
            continue
        available.append(mode)
    return available


def get_available_modems(modem_type):
    """Get list of modems, filtering out unavailable VARA modems."""
    if modem_type not in MODEMS:
        return []
    
    available = []
    for modem in MODEMS[modem_type]:
        requires = modem.get("requires")
        if requires == "vara-fm" and not is_vara_fm_installed():
            continue
        if requires == "vara-hf" and not is_vara_hf_installed():
            continue
        available.append(modem)
    return available


def get_current_mode():
    """Get currently running mode."""
    if MODE_STATUS_FILE.exists():
        try:
            return MODE_STATUS_FILE.read_text().strip()
        except Exception:
            pass
    return "none"


def save_current_mode(mode_id):
    """Save current mode to status file."""
    ET_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    MODE_STATUS_FILE.write_text(mode_id)


def run_command(cmd, timeout=30):
    """Run a shell command and return result."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)


def stop_all_services():
    """Stop all EmComm Tools services."""
    run_command("et-kill-all")
    time.sleep(1)
    return True


def start_systemd_service(service_name):
    """Start a systemd user service and wait for it."""
    success, _, err = run_command(f"systemctl --user start {service_name}")
    if not success:
        return False, f"Failed to start {service_name}: {err}"
    
    # Wait for service to become active
    for _ in range(15):
        success, out, _ = run_command(f"systemctl --user is-active {service_name}")
        if success and "active" in out:
            time.sleep(2)  # Extra settle time
            return True, f"{service_name} started"
        time.sleep(1)
    
    return False, f"Timeout waiting for {service_name}"


def start_vara(vara_type):
    """Start VARA FM or HF modem."""
    if vara_type == "vara-fm":
        cmd = "et-vara-fm"
    else:
        cmd = "et-vara-hf"
    
    # Start in background
    subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Wait for VARA to start
    for _ in range(15):
        success, out, _ = run_command("pgrep -f VARA")
        if success:
            time.sleep(2)
            return True, f"VARA started"
        time.sleep(1)
    
    return False, "Timeout waiting for VARA"


def update_qttermtcp_config(vara_type):
    """Update QtTermTCP config for VARA mode."""
    if not QTTERMTCP_CONF_FILE.exists():
        return
    
    try:
        content = QTTERMTCP_CONF_FILE.read_text()
        
        if vara_type == "vara-fm":
            content = content.replace("VARAFM=0", "VARAFM=1")
            content = content.replace("VARAHF=1", "VARAHF=0")
        else:
            content = content.replace("VARAFM=1", "VARAFM=0")
            content = content.replace("VARAHF=0", "VARAHF=1")
        
        QTTERMTCP_CONF_FILE.write_text(content)
    except Exception:
        pass


# ============================================================================
# Mode Handlers
# ============================================================================

def start_mode(mode_id, modem=None):
    """Start the selected mode with optional modem."""
    log = []
    success = True
    
    # Stop all services first
    log.append("Stopping all services...")
    stop_all_services()
    
    # Save mode
    save_current_mode(mode_id)
    
    if mode_id == "none":
        log.append("All services stopped.")
        return True, log
    
    elif mode_id == "aprs-client":
        ok, msg = start_systemd_service("et-service-direwolf-simple")
        log.append(msg)
        if ok:
            run_command("et-yaac start &")
            log.append("Starting YAAC...")
        success = ok
    
    elif mode_id == "aprs-digipeater":
        ok, msg = start_systemd_service("et-service-direwolf-aprs-digipeater")
        log.append(msg)
        log.append("APRS Digipeater running.")
        success = ok
    
    elif mode_id == "bbs-client":
        # Paracon client
        if modem in ["1200", "9600", "300"]:
            service = {
                "1200": "et-service-direwolf-simple",
                "9600": "et-service-direwolf-9600",
                "300": "et-service-direwolf-300"
            }[modem]
            ok, msg = start_systemd_service(service)
            log.append(msg)
            if ok:
                run_command("et-paracon start &")
                log.append(f"Starting Paracon with {modem} baud...")
            success = ok
        else:
            success = False
            log.append("Invalid modem selection")
    
    elif mode_id == "bbs-client2":
        # QtTermTCP client
        if modem in ["1200", "9600", "300"]:
            service = {
                "1200": "et-service-direwolf-simple",
                "9600": "et-service-direwolf-9600",
                "300": "et-service-direwolf-300"
            }[modem]
            ok, msg = start_systemd_service(service)
            log.append(msg)
            if ok:
                run_command("et-qttermtcp start &")
                log.append(f"Starting QtTermTCP with {modem} baud...")
            success = ok
        elif modem == "vara-fm":
            update_qttermtcp_config("vara-fm")
            ok, msg = start_vara("vara-fm")
            log.append(msg)
            if ok:
                run_command("et-qttermtcp start &")
                log.append("Starting QtTermTCP with VARA FM...")
            success = ok
        elif modem == "vara-hf":
            update_qttermtcp_config("vara-hf")
            ok, msg = start_vara("vara-hf")
            log.append(msg)
            if ok:
                run_command("et-qttermtcp start &")
                log.append("Starting QtTermTCP with VARA HF...")
            success = ok
        else:
            success = False
            log.append("Invalid modem selection")
    
    elif mode_id == "bbs-server":
        # LinBPQ server
        if modem in ["1200", "9600", "300"]:
            service = {
                "1200": "et-service-direwolf-simple",
                "9600": "et-service-direwolf-9600",
                "300": "et-service-direwolf-300"
            }[modem]
            ok, msg = start_systemd_service(service)
            log.append(msg)
            if ok:
                run_command(f"et-bbs-server {modem} start &")
                log.append(f"Starting BBS Server with {modem} baud...")
            success = ok
        elif modem == "vara-fm":
            ok, msg = start_vara("vara-fm")
            log.append(msg)
            if ok:
                run_command("et-bbs-server vara-fm start &")
                log.append("Starting BBS Server with VARA FM...")
            success = ok
        elif modem == "vara-hf":
            ok, msg = start_vara("vara-hf")
            log.append(msg)
            if ok:
                run_command("et-bbs-server vara-hf start &")
                log.append("Starting BBS Server with VARA HF...")
            success = ok
        else:
            success = False
            log.append("Invalid modem selection")
    
    elif mode_id == "chat-chattervox":
        ok, msg = start_systemd_service("et-service-direwolf-simple")
        log.append(msg)
        if ok:
            run_command("et-chattervox start &")
            log.append("Starting Chattervox...")
        success = ok
    
    elif mode_id == "packet-digipeater":
        ok, msg = start_systemd_service("et-service-direwolf-packet-digipeater")
        log.append(msg)
        log.append("Packet Digipeater running.")
        success = ok
    
    elif mode_id == "winlink-packet":
        ok, msg = start_systemd_service("et-service-direwolf-simple")
        log.append(msg)
        if ok:
            ok2, msg2 = start_systemd_service("et-service-winlink-packet")
            log.append(msg2)
            if ok2:
                run_command("min http://localhost:8080 &")
                log.append("Opening Pat Winlink...")
            success = ok2
        else:
            success = False
    
    elif mode_id == "winlink-ardop":
        ok, msg = start_systemd_service("et-service-ardop")
        log.append(msg)
        if ok:
            ok2, msg2 = start_systemd_service("et-service-winlink-ardop")
            log.append(msg2)
            if ok2:
                run_command("min http://localhost:8080 &")
                log.append("Opening Pat Winlink with ARDOP...")
            success = ok2
        else:
            success = False
    
    elif mode_id == "winlink-vara-fm":
        ok, msg = start_vara("vara-fm")
        log.append(msg)
        if ok:
            run_command("et-winlink start-vara-fm &")
            time.sleep(1)
            run_command("min http://localhost:8080 &")
            log.append("Opening Pat Winlink with VARA FM...")
        success = ok
    
    elif mode_id == "winlink-vara-hf":
        ok, msg = start_vara("vara-hf")
        log.append(msg)
        if ok:
            run_command("et-winlink start-vara-hf &")
            time.sleep(1)
            run_command("min http://localhost:8080 &")
            log.append("Opening Pat Winlink with VARA HF...")
        success = ok
    
    else:
        success = False
        log.append(f"Unknown mode: {mode_id}")
    
    return success, log


# ============================================================================
# Translations
# ============================================================================

TRANSLATIONS = {
    'en': {
        'title': 'Mode Selection',
        'subtitle': 'Select your operating mode',
        'current_mode': 'Current Mode',
        'select_modem': 'Select Modem Speed',
        'modem_subtitle': 'Choose the modem for this mode',
        'note_9600': '9600 baud requires special cable and radio support',
        'vara_note': 'VARA requires manual configuration',
        'starting': 'Starting',
        'stopping': 'Stopping all services...',
        'success': 'Mode Started',
        'error': 'Error',
        'back': 'Back',
        'start': 'Start Mode',
        'stop_all': 'Stop All',
        'close': 'Close',
        'categories': {
            'aprs': 'APRS',
            'bbs': 'BBS / Packet',
            'chat': 'Chat',
            'packet': 'Packet',
            'winlink': 'Winlink'
        }
    },
    'fr': {
        'title': 'Sélection de Mode',
        'subtitle': 'Sélectionnez votre mode d\'opération',
        'current_mode': 'Mode Actuel',
        'select_modem': 'Sélectionner la Vitesse du Modem',
        'modem_subtitle': 'Choisissez le modem pour ce mode',
        'note_9600': '9600 baud nécessite un câble spécial et radio compatible',
        'vara_note': 'VARA nécessite une configuration manuelle',
        'starting': 'Démarrage',
        'stopping': 'Arrêt de tous les services...',
        'success': 'Mode Démarré',
        'error': 'Erreur',
        'back': 'Retour',
        'start': 'Démarrer',
        'stop_all': 'Tout Arrêter',
        'close': 'Fermer',
        'categories': {
            'aprs': 'APRS',
            'bbs': 'BBS / Packet',
            'chat': 'Clavardage',
            'packet': 'Packet',
            'winlink': 'Winlink'
        }
    }
}


def get_translations():
    lang = get_language()
    return TRANSLATIONS.get(lang, TRANSLATIONS['en']), lang


# ============================================================================
# Routes
# ============================================================================

@app.route('/')
def index():
    """Mode selection page."""
    t, lang = get_translations()
    modes = get_available_modes()
    current = get_current_mode()
    
    # Group modes by category
    categories = {}
    for mode in modes:
        cat = mode.get('category', 'other')
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(mode)
    
    return render_template('index.html',
                         t=t,
                         lang=lang,
                         modes=modes,
                         categories=categories,
                         current_mode=current)


@app.route('/modem/<mode_id>')
def modem_select(mode_id):
    """Modem selection page for modes that need it."""
    t, lang = get_translations()
    
    # Find the mode
    mode = None
    for m in MODES:
        if m['id'] == mode_id:
            mode = m
            break
    
    if not mode or not mode.get('modem'):
        return redirect(url_for('index'))
    
    modem_type = mode.get('modem')
    modems = get_available_modems(modem_type)
    
    return render_template('modem.html',
                         t=t,
                         lang=lang,
                         mode=mode,
                         modems=modems)


@app.route('/start', methods=['POST'])
def start():
    """Start the selected mode."""
    data = request.get_json()
    mode_id = data.get('mode_id')
    modem = data.get('modem')
    
    # Find mode to check if it needs modem
    mode = None
    for m in MODES:
        if m['id'] == mode_id:
            mode = m
            break
    
    if not mode:
        return jsonify({'success': False, 'error': 'Invalid mode'})
    
    # If mode needs modem and none provided, redirect to modem selection
    if mode.get('modem') and not modem:
        return jsonify({'success': False, 'needs_modem': True, 'modem_type': mode.get('modem')})
    
    # Start the mode
    success, log = start_mode(mode_id, modem)
    
    return jsonify({
        'success': success,
        'log': log,
        'mode_id': mode_id,
        'modem': modem
    })


@app.route('/stop', methods=['POST'])
def stop():
    """Stop all services."""
    stop_all_services()
    save_current_mode("none")
    return jsonify({'success': True, 'message': 'All services stopped'})


@app.route('/status')
def status():
    """Get current mode status."""
    current = get_current_mode()
    mode_name = "None"
    
    for m in MODES:
        if m['id'] == current:
            mode_name = m['name']
            break
    
    return jsonify({
        'mode_id': current,
        'mode_name': mode_name
    })


@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the Flask server."""
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        os._exit(0)
    func()
    return 'Server shutting down...'


# ============================================================================
# Main
# ============================================================================

def run_flask():
    """Run Flask server in background thread (silently)."""
    import os
    # Suppress Flask startup message
    cli = sys.modules.get('flask.cli')
    if cli:
        cli.show_server_banner = lambda *args, **kwargs: None
    
    # Redirect stdout/stderr to devnull for clean window
    with open(os.devnull, 'w') as devnull:
        old_stdout, old_stderr = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = devnull, devnull
        try:
            app.run(host='127.0.0.1', port=5053, debug=False, use_reloader=False)
        finally:
            sys.stdout, sys.stderr = old_stdout, old_stderr


if __name__ == '__main__':
    port = 5053
    
    if len(sys.argv) > 1:
        if sys.argv[1] == '--no-browser':
            # Server only mode (for debugging)
            app.run(host='127.0.0.1', port=port, debug=False)
        elif sys.argv[1] == '--browser':
            # Open in default browser (old behavior)
            threading.Thread(target=open_browser, args=(port,), daemon=True).start()
            print(f"Starting Mode Selection on http://127.0.0.1:{port}")
            app.run(host='127.0.0.1', port=port, debug=False)
        elif sys.argv[1] == '--help':
            print("Usage: et-mode [OPTIONS]")
            print("")
            print("Options:")
            print("  --no-browser    Start server only (no window)")
            print("  --browser       Open in default web browser")
            print("  --help          Show this help message")
            print("")
            print("Default: Opens in native PyWebView window")
            sys.exit(0)
    else:
        # Default: PyWebView native window
        try:
            import webview
            
            # Window dimensions
            win_width = 500
            win_height = 750
            
            # Calculate position to align with dashboard (left of dashboard)
            try:
                import gi
                gi.require_version('Gdk', '3.0')
                from gi.repository import Gdk
                
                # Use modern Display/Monitor API instead of deprecated Screen methods
                display = Gdk.Display.get_default()
                monitor = display.get_primary_monitor() or display.get_monitor(0)
                geometry = monitor.get_geometry()
                screen_width = geometry.width
                
                # Dashboard position calculation (matches et-dashboard)
                if screen_width >= 1920:
                    dashboard_width = 380
                    margin = 10
                elif screen_width >= 1680:
                    dashboard_width = 340
                    margin = 8
                elif screen_width >= 1366:
                    dashboard_width = 300
                    margin = 8
                else:
                    dashboard_width = 280
                    margin = 5
                
                # Position: left of dashboard, same top margin
                x = screen_width - dashboard_width - margin - win_width - margin
                y = margin
            except:
                x = None
                y = None
            
            # Start Flask in background thread
            flask_thread = threading.Thread(target=run_flask, daemon=True)
            flask_thread.start()
            
            # Wait for Flask to start
            time.sleep(1)
            
            # Create native window - frameless for clean look like dashboard
            window = webview.create_window(
                'EmComm-Tools - Mode Selection',
                f'http://127.0.0.1:{port}',
                width=win_width,
                height=win_height,
                resizable=True,
                min_size=(400, 600),
                x=x,
                y=y,
                frameless=True
            )
            webview.start()
            
        except ImportError:
            print("PyWebView not installed. Falling back to browser mode.")
            print("Install with: sudo apt install python3-webview")
            threading.Thread(target=open_browser, args=(port,), daemon=True).start()
            app.run(host='127.0.0.1', port=port, debug=False)
