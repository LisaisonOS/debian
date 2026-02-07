#!/usr/bin/env python3
"""
et-radio - Radio Selection and Configuration
Author: Sylvain Deguire (VA2OPS)
Date: January 2026

Flask-based web UI for selecting and configuring radios.
Can be used standalone or integrated into et-firstboot.
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
app.secret_key = 'emcomm-tools-radio-2026'

# Configuration paths
RADIOS_DIR = Path("/opt/emcomm-tools/conf/radios.d")
ACTIVE_RADIO_LINK = RADIOS_DIR / "active-radio.json"
ET_CONFIG_DIR = Path.home() / ".config" / "emcomm-tools"
ET_CONFIG_FILE = ET_CONFIG_DIR / "user.json"


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


def load_radios():
    """Load all radio configurations from JSON files."""
    radios = []
    
    if not RADIOS_DIR.exists():
        return radios
    
    for file in sorted(RADIOS_DIR.glob("*.json")):
        # Skip the active-radio symlink
        if file.name == "active-radio.json":
            continue
        
        try:
            with open(file, 'r') as f:
                data = json.load(f)
                
            radio = {
                'id': file.stem,  # filename without .json
                'file': str(file),
                'model': data.get('model', file.stem),
                'manufacturer': data.get('manufacturer') or data.get('vendor', ''),
                'notes': data.get('configNotes') or data.get('notes', []),
                'rigctrl': data.get('rigctrl', {})
            }
            radios.append(radio)
        except Exception as e:
            print(f"Error loading {file}: {e}")
    
    return radios


def get_active_radio():
    """Get currently active radio ID."""
    if ACTIVE_RADIO_LINK.exists() and ACTIVE_RADIO_LINK.is_symlink():
        target = ACTIVE_RADIO_LINK.resolve()
        return target.stem
    return None


def set_active_radio(radio_id):
    """Set active radio by creating symlink."""
    # Remove existing symlink
    if ACTIVE_RADIO_LINK.exists() or ACTIVE_RADIO_LINK.is_symlink():
        ACTIVE_RADIO_LINK.unlink()
    
    if radio_id and radio_id != 'none':
        target = RADIOS_DIR / f"{radio_id}.json"
        if target.exists():
            ACTIVE_RADIO_LINK.symlink_to(target)
            return True
    return True  # 'none' is valid


def get_radio_by_id(radio_id):
    """Get radio config by ID."""
    radios = load_radios()
    for radio in radios:
        if radio['id'] == radio_id:
            return radio
    return None


def kill_bt_processes():
    """Kill any running Bluetooth TNC processes to avoid conflicts."""
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'dire.*kissattach'],
            capture_output=True, text=True
        )
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                subprocess.run(['kill', pid], capture_output=True)
    except Exception:
        pass


# ============================================================================
# Translations
# ============================================================================

TRANSLATIONS = {
    'en': {
        'title': 'Radio Selection',
        'subtitle': 'Choose the radio to use with EmComm Tools',
        'no_radio': 'No Radio',
        'no_radio_desc': 'Run without a radio connected',
        'select_radio': 'Select Your Radio',
        'selected': 'Selected Radio',
        'config_notes': 'Radio Configuration',
        'config_notes_desc': 'Configure these settings on your radio:',
        'instructions': 'Next Steps',
        'instr_1': 'Configure your radio with the settings shown above',
        'instr_2': 'Plug in or reconnect your radio\'s USB cable',
        'instr_3': 'Run et-mode to select operating mode',
        'back': 'Back',
        'continue': 'Continue',
        'save': 'Save & Continue',
        'cancel': 'Cancel',
        'done': 'Done',
        'no_radios_found': 'No radio configurations found',
        'check_path': 'Check that radio JSON files exist in:',
    },
    'fr': {
        'title': 'Sélection de Radio',
        'subtitle': 'Choisissez la radio à utiliser avec EmComm Tools',
        'no_radio': 'Aucune Radio',
        'no_radio_desc': 'Exécuter sans radio connectée',
        'select_radio': 'Sélectionnez Votre Radio',
        'selected': 'Radio Sélectionnée',
        'config_notes': 'Configuration de la Radio',
        'config_notes_desc': 'Configurez ces paramètres sur votre radio:',
        'instructions': 'Prochaines Étapes',
        'instr_1': 'Configurez votre radio avec les paramètres ci-dessus',
        'instr_2': 'Branchez ou reconnectez le câble USB de votre radio',
        'instr_3': 'Exécutez et-mode pour sélectionner le mode',
        'back': 'Retour',
        'continue': 'Continuer',
        'save': 'Sauvegarder',
        'cancel': 'Annuler',
        'done': 'Terminé',
        'no_radios_found': 'Aucune configuration de radio trouvée',
        'check_path': 'Vérifiez que les fichiers JSON existent dans:',
    }
}


def get_translations():
    """Get translations for current language."""
    lang = get_language()
    return TRANSLATIONS.get(lang, TRANSLATIONS['en']), lang


# ============================================================================
# Routes
# ============================================================================

@app.route('/')
def index():
    """Radio selection page."""
    t, lang = get_translations()
    radios = load_radios()
    active_radio = get_active_radio()
    
    return render_template('index.html',
                         t=t,
                         lang=lang,
                         radios=radios,
                         active_radio=active_radio,
                         radios_dir=str(RADIOS_DIR))


@app.route('/select', methods=['POST'])
def select_radio():
    """Handle radio selection."""
    data = request.get_json()
    radio_id = data.get('radio_id', 'none')
    
    # Kill BT processes
    kill_bt_processes()
    
    # Set active radio
    success = set_active_radio(radio_id)
    
    if success:
        if radio_id and radio_id != 'none':
            return jsonify({'success': True, 'radio_id': radio_id, 'redirect': f'/config/{radio_id}'})
        else:
            return jsonify({'success': True, 'radio_id': None, 'redirect': '/done'})
    else:
        return jsonify({'success': False, 'error': 'Failed to set radio'})


@app.route('/config/<radio_id>')
def config(radio_id):
    """Show radio configuration notes."""
    t, lang = get_translations()
    radio = get_radio_by_id(radio_id)
    
    if not radio:
        return redirect(url_for('index'))
    
    return render_template('config.html',
                         t=t,
                         lang=lang,
                         radio=radio)


@app.route('/done')
def done():
    """Completion page."""
    t, lang = get_translations()
    active_radio = get_active_radio()
    radio = get_radio_by_id(active_radio) if active_radio else None
    
    return render_template('done.html',
                         t=t,
                         lang=lang,
                         radio=radio)


@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the Flask server."""
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        os._exit(0)
    func()
    return 'Server shutting down...'


@app.route('/api/radios')
def api_radios():
    """API endpoint to list radios (for integration)."""
    radios = load_radios()
    active = get_active_radio()
    return jsonify({
        'radios': radios,
        'active': active
    })


# ============================================================================
# Main
# ============================================================================

def run_flask(port):
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
            app.run(host='127.0.0.1', port=port, debug=False, use_reloader=False)
        finally:
            sys.stdout, sys.stderr = old_stdout, old_stderr


def open_browser(port):
    """Open browser after short delay."""
    time.sleep(1)
    webbrowser.open(f'http://127.0.0.1:{port}')


if __name__ == '__main__':
    port = 5052
    
    if '--no-browser' in sys.argv:
        # Server only mode (for debugging)
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--browser' in sys.argv:
        # Open in default browser
        threading.Thread(target=open_browser, args=(port,), daemon=True).start()
        print(f"Starting Radio Selection on http://127.0.0.1:{port}")
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--help' in sys.argv:
        print("Usage: et-radio [OPTIONS]")
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
            
            # Calculate window size - adapt to screen
            try:
                import gi
                gi.require_version('Gdk', '3.0')
                from gi.repository import Gdk
                
                screen = Gdk.Screen.get_default()
                screen_width = screen.get_width()
                screen_height = screen.get_height()
                
                # Reserve space for panel (typically 48px) and some margin
                panel_height = 60
                
                # Adapt to screen size - for small screens like 7" Toughpad
                if screen_height <= 800:
                    # Small screen (7" tablet ~1024x600 or 1280x800)
                    win_width = min(500, screen_width - 40)
                    win_height = screen_height - panel_height - 40
                else:
                    # Normal/large screen
                    win_width = 500
                    win_height = min(700, screen_height - panel_height - 60)
                
                # Center horizontally, position near top
                x = (screen_width - win_width) // 2
                y = 30
                
                print(f"[WINDOW] Screen: {screen_width}x{screen_height}, Window: {win_width}x{win_height} at ({x},{y})")
            except Exception as e:
                print(f"[WINDOW] Could not detect screen size: {e}")
                win_width = 500
                win_height = 550
                x = None
                y = None
            
            # Start Flask in background thread
            flask_thread = threading.Thread(target=run_flask, args=(port,), daemon=True)
            flask_thread.start()
            
            # Wait for Flask to start
            time.sleep(1)
            
            # Create native window - with frame for touch support
            window = webview.create_window(
                'EmComm-Tools',
                f'http://127.0.0.1:{port}',
                width=win_width,
                height=win_height,
                resizable=True,
                min_size=(400, 400),
                x=x,
                y=y,
                frameless=False
            )
            
            webview.start()
            
        except ImportError:
            print("PyWebView not installed. Falling back to browser mode.")
            print("Install with: sudo apt install python3-webview")
            threading.Thread(target=open_browser, args=(port,), daemon=True).start()
            app.run(host='127.0.0.1', port=port, debug=False)
