#!/usr/bin/env python3
"""
et-chattervox-keys - Chattervox Key Management
Author: Sylvain Deguire (VA2OPS)
Date: February 2026

Flask-based web UI for managing Chattervox digital signature keys.
- Generate/manage own signing keys (multiple callsigns)
- Import/manage other operators' public keys
- Send public keys via Pat Winlink
- Import keys from Winlink inbox
"""

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*pkg_resources.*")

import os
import sys
import json
import signal
import subprocess
import webbrowser
import threading
import time
import re
import logging
import glob as globmod
from pathlib import Path
from flask import Flask, render_template, request, jsonify

# Suppress Flask development server warning
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
app.secret_key = 'emcomm-tools-chattervox-keys-2026'

# Configuration paths
ET_CONFIG_DIR = Path.home() / ".config" / "emcomm-tools"
ET_CONFIG_FILE = ET_CONFIG_DIR / "user.json"
CHATTERVOX_DIR = Path.home() / ".chattervox"
CHATTERVOX_CONFIG = CHATTERVOX_DIR / "config.json"
CHATTERVOX_KEYSTORE = CHATTERVOX_DIR / "keystore.json"
PAT_MAILBOX_DIR = Path.home() / ".local" / "share" / "pat" / "mailbox"

# Key exchange email format
KEY_BLOCK_BEGIN = "-----BEGIN CHATTERVOX PUBLIC KEY-----"
KEY_BLOCK_END = "-----END CHATTERVOX PUBLIC KEY-----"
KEY_SUBJECT_PREFIX = "[CHATTERVOX-KEY]"



# ============================================================================
# Translations
# ============================================================================

TRANSLATIONS = {
    'en': {
        'title': 'Chattervox Key Management',
        'subtitle': 'Manage digital signature keys for Chattervox',
        'tab_my_keys': 'My Keys',
        'tab_other_keys': 'Other Operators',
        'generate_key': 'Generate Key',
        'callsign_placeholder': 'Callsign',
        'callsign_hint': 'Enter callsign to generate a key pair for',
        'no_own_keys': 'No signing keys yet. Generate one to get started.',
        'no_other_keys': 'No imported keys. Add keys from other operators.',
        'add_key': 'Add Key',
        'add_key_callsign': 'Operator Callsign',
        'add_key_pubkey': 'Public Key (hex)',
        'check_inbox': 'Check Inbox',
        'copy': 'Copy',
        'send_winlink': 'Send Winlink',
        'delete': 'Delete',
        'copied': 'Copied to clipboard!',
        'key_generated': 'Key generated for',
        'key_added': 'Key added for',
        'key_deleted': 'Key deleted for',
        'key_sent': 'Key queued for sending via Winlink',
        'key_imported': 'Key imported for',
        'confirm_delete': 'Delete key for',
        'confirm_delete_own': 'This is your signing key. Deleting it means you cannot sign messages with this callsign. Continue?',
        'send_title': 'Send Public Key via Winlink',
        'send_to': 'Send to (callsign):',
        'send_btn': 'Send',
        'cancel': 'Cancel',
        'close': 'Close',
        'inbox_title': 'Keys Found in Winlink Inbox',
        'inbox_empty': 'No Chattervox keys found in inbox.',
        'inbox_import': 'Import',
        'inbox_from': 'From:',
        'error': 'Error',
        'error_no_callsign': 'Callsign is required',
        'error_no_key': 'Public key is required',
        'error_invalid_key': 'Invalid key format (must be hex)',
        'error_genkey': 'Failed to generate key',
        'error_addkey': 'Failed to add key',
        'error_pat_not_found': 'Pat is not installed or mailbox not found',
        'signing_key': 'Signing Key',
        'public_only': 'Public Key',
        'language': 'Language',
        'restart_notice': 'Keys applied to running Chattervox session.',
        'restart_required': 'Restart Chattervox to apply key changes.',
    },
    'fr': {
        'title': 'Gestion des cl\u00e9s Chattervox',
        'subtitle': 'G\u00e9rer les cl\u00e9s de signature num\u00e9rique pour Chattervox',
        'tab_my_keys': 'Mes cl\u00e9s',
        'tab_other_keys': 'Autres op\u00e9rateurs',
        'generate_key': 'G\u00e9n\u00e9rer une cl\u00e9',
        'callsign_placeholder': 'Indicatif',
        'callsign_hint': 'Entrez l\'indicatif pour g\u00e9n\u00e9rer une paire de cl\u00e9s',
        'no_own_keys': 'Aucune cl\u00e9 de signature. G\u00e9n\u00e9rez-en une pour commencer.',
        'no_other_keys': 'Aucune cl\u00e9 import\u00e9e. Ajoutez les cl\u00e9s d\'autres op\u00e9rateurs.',
        'add_key': 'Ajouter une cl\u00e9',
        'add_key_callsign': 'Indicatif de l\'op\u00e9rateur',
        'add_key_pubkey': 'Cl\u00e9 publique (hex)',
        'check_inbox': 'V\u00e9rifier la bo\u00eete',
        'copy': 'Copier',
        'send_winlink': 'Envoyer Winlink',
        'delete': 'Supprimer',
        'copied': 'Copi\u00e9 dans le presse-papiers!',
        'key_generated': 'Cl\u00e9 g\u00e9n\u00e9r\u00e9e pour',
        'key_added': 'Cl\u00e9 ajout\u00e9e pour',
        'key_deleted': 'Cl\u00e9 supprim\u00e9e pour',
        'key_sent': 'Cl\u00e9 mise en file pour envoi via Winlink',
        'key_imported': 'Cl\u00e9 import\u00e9e pour',
        'confirm_delete': 'Supprimer la cl\u00e9 pour',
        'confirm_delete_own': 'C\'est votre cl\u00e9 de signature. La supprimer signifie que vous ne pouvez plus signer de messages avec cet indicatif. Continuer?',
        'send_title': 'Envoyer la cl\u00e9 publique via Winlink',
        'send_to': 'Envoyer \u00e0 (indicatif):',
        'send_btn': 'Envoyer',
        'cancel': 'Annuler',
        'close': 'Fermer',
        'inbox_title': 'Cl\u00e9s trouv\u00e9es dans la bo\u00eete Winlink',
        'inbox_empty': 'Aucune cl\u00e9 Chattervox trouv\u00e9e dans la bo\u00eete.',
        'inbox_import': 'Importer',
        'inbox_from': 'De:',
        'error': 'Erreur',
        'error_no_callsign': 'L\'indicatif est requis',
        'error_no_key': 'La cl\u00e9 publique est requise',
        'error_invalid_key': 'Format de cl\u00e9 invalide (hex requis)',
        'error_genkey': '\u00c9chec de la g\u00e9n\u00e9ration de cl\u00e9',
        'error_addkey': '\u00c9chec de l\'ajout de la cl\u00e9',
        'error_pat_not_found': 'Pat n\'est pas install\u00e9 ou bo\u00eete introuvable',
        'signing_key': 'Cl\u00e9 de signature',
        'public_only': 'Cl\u00e9 publique',
        'language': 'Langue',
        'restart_notice': 'Cl\u00e9s appliqu\u00e9es \u00e0 la session Chattervox en cours.',
        'restart_required': 'Red\u00e9marrez Chattervox pour appliquer les changements de cl\u00e9s.',
    }
}


def get_language():
    """Get current language from user config."""
    if ET_CONFIG_FILE.exists():
        try:
            with open(ET_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                return config.get('language', 'en')
        except Exception:
            pass
    return 'en'


def get_translations(lang=None):
    """Get translations for current language."""
    if not lang:
        lang = get_language()
    return TRANSLATIONS.get(lang, TRANSLATIONS['en']), lang


def get_user_callsign():
    """Get user's callsign from emcomm-tools config."""
    if ET_CONFIG_FILE.exists():
        try:
            with open(ET_CONFIG_FILE, 'r') as f:
                config = json.load(f)
                return config.get('callsign', 'N0CALL')
        except Exception:
            pass
    return 'N0CALL'


# ============================================================================
# Keystore operations
# ============================================================================

def load_keystore():
    """Load the chattervox keystore. Returns dict: {callsign: [key_objects]}."""
    if not CHATTERVOX_KEYSTORE.exists():
        return {}
    try:
        with open(CHATTERVOX_KEYSTORE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def save_keystore(keystore):
    """Save the chattervox keystore."""
    CHATTERVOX_DIR.mkdir(parents=True, exist_ok=True)
    with open(CHATTERVOX_KEYSTORE, 'w') as f:
        json.dump(keystore, f, indent=2)


def load_chattervox_config():
    """Load chattervox config.json."""
    if not CHATTERVOX_CONFIG.exists():
        return {}
    try:
        with open(CHATTERVOX_CONFIG, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def ensure_config_defaults(config):
    """Ensure all required chattervox config fields exist with defaults."""
    defaults = {
        'version': 3,
        'callsign': get_user_callsign(),
        'ssid': 0,
        'keystoreFile': str(CHATTERVOX_KEYSTORE),
        'kissPort': 'kiss://localhost:8001',
        'kissBaud': 9600,
        'feedbackDebounce': 20000,
    }
    for key, value in defaults.items():
        if key not in config:
            config[key] = value
    return config


def save_chattervox_config(config):
    """Save chattervox config.json."""
    CHATTERVOX_DIR.mkdir(parents=True, exist_ok=True)
    with open(CHATTERVOX_CONFIG, 'w') as f:
        json.dump(config, f, indent=2)


def signal_chattervox_reload():
    """Send SIGUSR1 to running chattervox process to hot-reload keys.
    Only matches the emcomm-tools fork running as node process.
    The old pkg binary won't match the pgrep pattern."""
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'node.*/chattervox/build/main.js'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            for pid_str in result.stdout.strip().split('\n'):
                pid = int(pid_str.strip())
                os.kill(pid, signal.SIGUSR1)
                print(f"[KEY-MGMT] Sent SIGUSR1 to chattervox pid {pid}")
            return True
        else:
            print("[KEY-MGMT] No source-based chattervox found, restart required")
    except Exception as e:
        print(f"[KEY-MGMT] Could not signal chattervox: {e}")
    return False


def get_my_keys():
    """Get own keys (those with a private field)."""
    keystore = load_keystore()
    my_keys = []
    config = load_chattervox_config()
    signing_key = config.get('signingKey', '')

    for callsign, keys in keystore.items():
        for key in keys:
            if 'private' in key:
                my_keys.append({
                    'callsign': callsign,
                    'public': key.get('public', ''),
                    'is_signing': key.get('public', '') == signing_key,
                })
    return my_keys


def get_other_keys():
    """Get other operators' keys (public only, no private field)."""
    keystore = load_keystore()
    other_keys = []
    for callsign, keys in keystore.items():
        for key in keys:
            if 'private' not in key:
                other_keys.append({
                    'callsign': callsign,
                    'public': key.get('public', ''),
                })
    return other_keys


def format_key_block(callsign, public_key):
    """Format a public key into the exchange block format."""
    return (
        f"{KEY_BLOCK_BEGIN}\n"
        f"Callsign: {callsign}\n"
        f"Algorithm: p192\n"
        f"Key: {public_key}\n"
        f"{KEY_BLOCK_END}"
    )


def parse_key_block(text):
    """Parse a key exchange block from text. Returns list of (callsign, key) tuples."""
    pattern = re.compile(
        rf'{re.escape(KEY_BLOCK_BEGIN)}\s*'
        r'Callsign:\s*(\S+)\s*'
        r'Algorithm:\s*\S+\s*'
        r'Key:\s*([0-9a-fA-F]+)\s*'
        rf'{re.escape(KEY_BLOCK_END)}',
        re.MULTILINE
    )
    return pattern.findall(text)


# ============================================================================
# Routes
# ============================================================================

@app.route('/')
def index():
    """Main page with tabbed key management UI."""
    t, lang = get_translations()
    user_callsign = get_user_callsign()
    return render_template('index.html', t=t, lang=lang, user_callsign=user_callsign)


@app.route('/set-language', methods=['POST'])
def set_language():
    """Set language preference."""
    data = request.get_json()
    lang = data.get('language', 'en')
    if ET_CONFIG_FILE.exists():
        try:
            with open(ET_CONFIG_FILE, 'r') as f:
                config = json.load(f)
            config['language'] = lang
            with open(ET_CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
        except Exception:
            pass
    return jsonify({'success': True, 'language': lang})


@app.route('/api/my-keys')
def api_my_keys():
    """Return JSON list of own keys."""
    return jsonify({'keys': get_my_keys()})


@app.route('/api/other-keys')
def api_other_keys():
    """Return JSON list of imported keys."""
    return jsonify({'keys': get_other_keys()})


@app.route('/api/genkey', methods=['POST'])
def api_genkey():
    """Generate a new key pair for a callsign."""
    data = request.get_json()
    callsign = data.get('callsign', '').strip().upper()

    if not callsign:
        return jsonify({'success': False, 'error': 'Callsign is required'})

    config = ensure_config_defaults(load_chattervox_config())
    original_callsign = config.get('callsign', '')

    try:
        # Temporarily set target callsign in config
        config['callsign'] = callsign
        # Ensure keystoreFile points to keystore
        config['keystoreFile'] = str(CHATTERVOX_KEYSTORE)
        save_chattervox_config(config)

        # Run chattervox genkey
        result = subprocess.run(
            ['chattervox', 'genkey'],
            capture_output=True, text=True, timeout=10
        )

        if result.returncode != 0:
            err = result.stderr.strip() or result.stdout.strip()
            return jsonify({'success': False, 'error': err or 'genkey failed'})

        # Read back the generated key
        keystore = load_keystore()
        keys = keystore.get(callsign, [])
        public_key = ''
        if keys:
            # Get the latest key with a private field
            for k in reversed(keys):
                if 'private' in k:
                    public_key = k.get('public', '')
                    break

        # Set as signing key if this is the user's own callsign
        user_callsign = get_user_callsign()
        if callsign == user_callsign and public_key:
            config['signingKey'] = public_key

        reloaded = signal_chattervox_reload()
        return jsonify({
            'success': True,
            'callsign': callsign,
            'public': public_key,
            'reloaded': reloaded,
        })
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return jsonify({'success': False, 'error': str(e)})
    finally:
        # Always restore original callsign
        config = load_chattervox_config()
        config['callsign'] = original_callsign or get_user_callsign()
        save_chattervox_config(config)


@app.route('/api/addkey', methods=['POST'])
def api_addkey():
    """Add another operator's public key."""
    data = request.get_json()
    callsign = data.get('callsign', '').strip().upper()
    public_key = data.get('public_key', '').strip()

    if not callsign:
        return jsonify({'success': False, 'error': 'Callsign is required'})
    if not public_key:
        return jsonify({'success': False, 'error': 'Public key is required'})
    if not re.match(r'^[0-9a-fA-F]{64,130}$', public_key):
        return jsonify({'success': False, 'error': 'Invalid key format (must be hex)'})

    # Ensure chattervox config exists with all required fields
    config = ensure_config_defaults(load_chattervox_config())
    save_chattervox_config(config)

    try:
        result = subprocess.run(
            ['chattervox', 'addkey', callsign, public_key],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            err = result.stderr.strip() or result.stdout.strip()
            return jsonify({'success': False, 'error': err or 'addkey failed'})

        reloaded = signal_chattervox_reload()
        return jsonify({'success': True, 'callsign': callsign, 'reloaded': reloaded})
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/deletekey', methods=['POST'])
def api_deletekey():
    """Delete a key from the keystore (direct edit, no CLI command)."""
    data = request.get_json()
    callsign = data.get('callsign', '').strip().upper()
    public_key = data.get('public_key', '').strip()

    if not callsign:
        return jsonify({'success': False, 'error': 'Callsign is required'})

    keystore = load_keystore()
    keys = keystore.get(callsign, [])

    if not keys:
        return jsonify({'success': False, 'error': 'Key not found'})

    # Remove the specific key matching the public key
    if public_key:
        keystore[callsign] = [k for k in keys if k.get('public') != public_key]
    else:
        # Remove all keys for this callsign
        keystore[callsign] = []

    # Clean up empty entries
    if not keystore[callsign]:
        del keystore[callsign]

    save_keystore(keystore)

    # If deleted key was the signing key, clear it from config
    config = load_chattervox_config()
    if config.get('signingKey') == public_key:
        config.pop('signingKey', None)
        save_chattervox_config(config)

    reloaded = signal_chattervox_reload()
    return jsonify({'success': True, 'callsign': callsign, 'reloaded': reloaded})


@app.route('/api/copy-key', methods=['POST'])
def api_copy_key():
    """Copy a public key to clipboard."""
    data = request.get_json()
    public_key = data.get('public_key', '').strip()

    if not public_key:
        return jsonify({'success': False, 'error': 'No key to copy'})

    try:
        subprocess.run(
            ['xclip', '-selection', 'clipboard', '-i'],
            input=public_key.encode(),
            timeout=5
        )
        return jsonify({'success': True})
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/send-key', methods=['POST'])
def api_send_key():
    """Send a public key via Pat Winlink email."""
    data = request.get_json()
    callsign = data.get('callsign', '').strip().upper()
    public_key = data.get('public_key', '').strip()
    to_callsign = data.get('to', '').strip().upper()

    if not callsign or not public_key or not to_callsign:
        return jsonify({'success': False, 'error': 'Missing required fields'})

    subject = f"{KEY_SUBJECT_PREFIX} {callsign} Public Key"
    body = format_key_block(callsign, public_key)

    try:
        result = subprocess.run(
            ['pat', 'compose', '--subject', subject, to_callsign],
            input=body.encode(),
            capture_output=True, timeout=10
        )
        if result.returncode != 0:
            err = result.stderr.decode().strip() or result.stdout.decode().strip()
            return jsonify({'success': False, 'error': err or 'pat compose failed'})

        return jsonify({'success': True, 'to': to_callsign})
    except FileNotFoundError:
        return jsonify({'success': False, 'error': 'Pat is not installed'})
    except subprocess.TimeoutExpired:
        return jsonify({'success': False, 'error': 'Pat compose timed out'})


@app.route('/api/scan-inbox')
def api_scan_inbox():
    """Scan Pat Winlink inbox for Chattervox key messages."""
    # Pat stores callsign-specific mailboxes
    user_callsign = get_user_callsign()
    inbox_dir = PAT_MAILBOX_DIR / user_callsign / "in"

    if not inbox_dir.exists():
        return jsonify({'keys': [], 'message': 'Inbox not found'})

    found_keys = []
    for msg_file in inbox_dir.iterdir():
        if not msg_file.is_file():
            continue
        try:
            content = msg_file.read_text(errors='replace')

            # Check if this message contains a key block
            parsed = parse_key_block(content)
            if parsed:
                # Try to extract sender from the message
                from_match = re.search(r'From:\s*(\S+)', content)
                sender = from_match.group(1) if from_match else 'Unknown'

                for key_callsign, key_hex in parsed:
                    # Check if we already have this key
                    keystore = load_keystore()
                    existing = keystore.get(key_callsign, [])
                    already_have = any(k.get('public') == key_hex for k in existing)

                    found_keys.append({
                        'callsign': key_callsign,
                        'public': key_hex,
                        'sender': sender,
                        'file': msg_file.name,
                        'already_imported': already_have,
                    })
        except Exception:
            continue

    return jsonify({'keys': found_keys})


@app.route('/api/import-key', methods=['POST'])
def api_import_key():
    """Import a key found in inbox (uses chattervox addkey)."""
    data = request.get_json()
    callsign = data.get('callsign', '').strip().upper()
    public_key = data.get('public_key', '').strip()

    if not callsign or not public_key:
        return jsonify({'success': False, 'error': 'Missing required fields'})

    try:
        result = subprocess.run(
            ['chattervox', 'addkey', callsign, public_key],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            err = result.stderr.strip() or result.stdout.strip()
            return jsonify({'success': False, 'error': err or 'addkey failed'})

        reloaded = signal_chattervox_reload()
        return jsonify({'success': True, 'callsign': callsign, 'reloaded': reloaded})
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
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
    port = 5055

    if '--no-browser' in sys.argv:
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--browser' in sys.argv:
        threading.Thread(target=open_browser, args=(port,), daemon=True).start()
        print(f"Starting Chattervox Key Management on http://127.0.0.1:{port}")
        app.run(host='127.0.0.1', port=port, debug=False)
    elif '--help' in sys.argv:
        print("Usage: et-chattervox-keys [OPTIONS]")
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

            win_width = 550
            win_height = 650

            try:
                import gi
                gi.require_version('Gdk', '3.0')
                from gi.repository import Gdk

                screen = Gdk.Screen.get_default()
                screen_width = screen.get_width()
                screen_height = screen.get_height()

                panel_height = 60

                if screen_height <= 800:
                    win_width = min(520, screen_width - 40)
                    win_height = screen_height - panel_height - 40
                else:
                    win_width = 550
                    win_height = min(700, screen_height - panel_height - 60)

                x = (screen_width - win_width) // 2
                y = 30

                print(f"[WINDOW] Screen: {screen_width}x{screen_height}, "
                      f"Window: {win_width}x{win_height} at ({x},{y})")
            except Exception as e:
                print(f"[WINDOW] Could not detect screen size: {e}")
                x = None
                y = None

            flask_thread = threading.Thread(
                target=run_flask, args=(port,), daemon=True)
            flask_thread.start()
            time.sleep(1)

            window = webview.create_window(
                'LiaisonOS',
                f'http://127.0.0.1:{port}',
                width=win_width,
                height=win_height,
                resizable=True,
                min_size=(450, 400),
                x=x,
                y=y,
                frameless=False
            )

            webview.start()

        except ImportError:
            print("PyWebView not installed. Falling back to browser mode.")
            threading.Thread(
                target=open_browser, args=(port,), daemon=True).start()
            app.run(host='127.0.0.1', port=port, debug=False)
