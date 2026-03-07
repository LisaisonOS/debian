#!/usr/bin/env python3
"""
et-user - EmComm-Tools User Configuration
Author: Sylvain Deguire (VA2OPS)
Date: January 2026

Flask-based web UI for user configuration.
Sets callsign, grid square, and Winlink password.
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
from flask import Flask, render_template, request, jsonify

# Suppress Flask development server warning
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
app.secret_key = 'emcomm-tools-user-2026'

# Configuration paths
ET_CONFIG_DIR = Path.home() / ".config" / "emcomm-tools"
ET_CONFIG_FILE = ET_CONFIG_DIR / "user.json"
PAT_CONFIG_FILE = Path.home() / ".config" / "pat" / "config.json"

# Default config
DEFAULT_CONFIG = {
    "language": "en",
    "callsign": "N0CALL",
    "grid": "AA00aa",
    "name": "",
    "winlinkPasswd": None
}


def load_config():
    """Load user configuration."""
    if ET_CONFIG_FILE.exists():
        try:
            with open(ET_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                # Merge with defaults
                for key, value in DEFAULT_CONFIG.items():
                    if key not in config:
                        config[key] = value
                # Handle both 'grid' and 'grid_square' for compatibility
                if 'grid_square' in config and 'grid' not in config:
                    config['grid'] = config['grid_square']
                return config
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()


def save_config(config):
    """Save user configuration."""
    try:
        ET_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(ET_CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"Config saved successfully to {ET_CONFIG_FILE}")
    except Exception as e:
        print(f"ERROR saving config: {e}")
        raise


def save_pat_config(callsign, grid_square, password):
    """Save Winlink password to Pat configuration."""
    pat_dir = PAT_CONFIG_FILE.parent
    pat_dir.mkdir(parents=True, exist_ok=True)
    
    # Load existing Pat config or create new
    if PAT_CONFIG_FILE.exists():
        try:
            with open(PAT_CONFIG_FILE, 'r') as f:
                pat_config = json.load(f)
        except Exception:
            pat_config = {}
    else:
        pat_config = {}
    
    # Update fields
    pat_config['mycall'] = callsign.upper()
    if grid_square:
        pat_config['locator'] = grid_square.upper()
    if password:
        pat_config['secure_login_password'] = password
    
    # Save
    with open(PAT_CONFIG_FILE, 'w') as f:
        json.dump(pat_config, f, indent=2)
    
    return True


# ============================================================================
# Translations
# ============================================================================

TRANSLATIONS = {
    'en': {
        'title': 'User Configuration',
        'subtitle': 'Configure your operator settings',
        'callsign': 'Callsign',
        'callsign_hint': 'Your amateur radio callsign',
        'grid_square': 'Grid Square',
        'grid_square_hint': 'Maidenhead locator (e.g., FN35at)',
        'grid_lookup': 'Find',
        'name': 'Name',
        'name_hint': 'Your name (optional)',
        'winlink_password': 'Winlink Password',
        'winlink_hint': 'For Winlink email access',
        'save': 'Save',
        'cancel': 'Cancel',
        'saved': 'Configuration Saved!',
        'error': 'Error',
        'callsign_required': 'Callsign is required',
        'invalid_callsign': 'Invalid callsign format',
        'password_hidden': '••••••••',
        'not_set': 'Not set',
        'language': 'Language'
    },
    'fr': {
        'title': 'Configuration Utilisateur',
        'subtitle': 'Configurez vos paramètres d\'opérateur',
        'callsign': 'Indicatif',
        'callsign_hint': 'Votre indicatif radio amateur',
        'grid_square': 'Grille',
        'grid_square_hint': 'Localisateur Maidenhead (ex: FN35at)',
        'grid_lookup': 'Trouver',
        'name': 'Nom',
        'name_hint': 'Votre nom (optionnel)',
        'winlink_password': 'Mot de passe Winlink',
        'winlink_hint': 'Pour l\'accès courriel Winlink',
        'save': 'Sauvegarder',
        'cancel': 'Annuler',
        'saved': 'Configuration Sauvegardée!',
        'error': 'Erreur',
        'callsign_required': 'L\'indicatif est requis',
        'invalid_callsign': 'Format d\'indicatif invalide',
        'password_hidden': '••••••••',
        'not_set': 'Non défini',
        'language': 'Langue'
    }
}


def get_translations(lang=None):
    """Get translations for current language."""
    if not lang:
        config = load_config()
        lang = config.get('language', 'en')
    return TRANSLATIONS.get(lang, TRANSLATIONS['en']), lang


# ============================================================================
# Routes
# ============================================================================

@app.route('/')
def index():
    """Main configuration page."""
    config = load_config()
    t, lang = get_translations(config.get('language', 'en'))
    
    # Mask password for display
    has_password = bool(config.get('winlinkPasswd'))
    
    return render_template('index.html',
                         t=t,
                         lang=lang,
                         config=config,
                         has_password=has_password)


@app.route('/set-language', methods=['POST'])
def set_language():
    """Set language preference."""
    data = request.get_json()
    lang = data.get('language', 'en')
    
    config = load_config()
    config['language'] = lang
    save_config(config)
    
    return jsonify({'success': True, 'language': lang})


@app.route('/save', methods=['POST'])
def save():
    """Save user configuration."""
    try:
        data = request.get_json()
        
        callsign = data.get('callsign', '').strip().upper()
        grid_square = data.get('grid_square', '').strip().upper()
        name = data.get('name', '').strip()
        password = data.get('password', '').strip()
        
        # Validate callsign
        if not callsign:
            return jsonify({'success': False, 'error': 'Callsign is required'})
        
        # Load current config to preserve other fields
        config = load_config()
        
        # Update fields
        config['callsign'] = callsign
        config['grid'] = grid_square  # Use 'grid' to match original user.json
        config['name'] = name
        
        # Only update password if provided
        if password:
            config['winlinkPasswd'] = password
            # Also save to Pat config
            try:
                save_pat_config(callsign, grid_square, password)
            except Exception as e:
                print(f"Warning: Could not save Pat config: {e}")
        
        # Save config
        save_config(config)
        print(f"Saved config to {ET_CONFIG_FILE}: {config}")
        
        return jsonify({
            'success': True,
            'callsign': callsign
        })
    except Exception as e:
        print(f"Error in save: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)})


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

def run_flask(port):
    """Run Flask server in background thread."""
    app.run(host='127.0.0.1', port=port, debug=False, use_reloader=False)


def open_browser(port):
    """Open browser after short delay."""
    time.sleep(1)
    webbrowser.open(f'http://127.0.0.1:{port}')


if __name__ == '__main__':
    port = 5054
    
    if '--no-browser' in sys.argv:
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--browser' in sys.argv:
        threading.Thread(target=open_browser, args=(port,), daemon=True).start()
        print(f"Starting User Configuration on http://127.0.0.1:{port}")
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--help' in sys.argv:
        print("Usage: et-user [OPTIONS]")
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
            
            # Window dimensions (same width as et-radio for consistency)
            win_width = 500
            
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
                    win_width = min(450, screen_width - 40)
                    win_height = screen_height - panel_height - 40
                else:
                    # Normal/large screen
                    win_width = 450
                    win_height = min(600, screen_height - panel_height - 60)
                
                # Center horizontally, position near top
                x = (screen_width - win_width) // 2
                y = 30
                
                print(f"[WINDOW] Screen: {screen_width}x{screen_height}, Window: {win_width}x{win_height} at ({x},{y})")
            except Exception as e:
                print(f"[WINDOW] Could not detect screen size: {e}")
                win_width = 450
                win_height = 550
                x = None
                y = None
            
            flask_thread = threading.Thread(target=run_flask, args=(port,), daemon=True)
            flask_thread.start()
            time.sleep(1)
            
            # Create native window - with frame for touch support
            window = webview.create_window(
                'EmComm-Tools',
                f'http://127.0.0.1:{port}',
                width=win_width,
                height=win_height,
                resizable=True,
                min_size=(400, 350),
                x=x,
                y=y,
                frameless=False
            )
            
            webview.start()
            
        except ImportError:
            print("PyWebView not installed. Falling back to browser mode.")
            threading.Thread(target=open_browser, args=(port,), daemon=True).start()
            app.run(host='127.0.0.1', port=port, debug=False)
