#!/usr/bin/env python3
"""
et-tile-downloader - Standalone Map Tile Downloader
Author: Sylvain Deguire (VA2OPS)
Date: March 2026

Standalone Flask microservice for downloading map tilesets.
Launched alongside et-predict, opened as popup from et-predict-app.
Reads tile catalog from shared conf/tiles.json.
"""

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*pkg_resources.*")

import os
import sys
import json
import subprocess
import logging
from pathlib import Path
from flask import Flask, render_template, request, jsonify

# Suppress Flask development server warning
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
app.secret_key = 'emcomm-tools-tile-downloader-2026'

# Configuration paths
ET_BASE = Path("/opt/emcomm-tools")
TILES_JSON = ET_BASE / "conf" / "tiles.json"
TILESET_DIR = Path.home() / ".local/share/emcomm-tools/mbtileserver/tilesets"
SKEL_TILESET_DIR = Path("/etc/skel/.local/share/emcomm-tools/mbtileserver/tilesets")
ET_CONFIG_FILE = Path.home() / ".config" / "emcomm-tools" / "user.json"

# ============================================================================
# Translations
# ============================================================================

TRANSLATIONS = {
    'en': {
        'title': 'Download Maps',
        'subtitle': 'Select offline map tilesets to download',
        'download': 'Download Selected',
        'downloading': 'Downloading',
        'complete': 'Complete',
        'error': 'Error',
        'close': 'Close',
        'already_installed': 'Installed',
        'no_selection': 'Select at least one tileset',
        'all_installed': 'All tilesets are already installed.',
        'language': 'Language',
        'storage_usb': 'Saving to USB (EMCOMM-DATA)',
        'storage_local': 'Saving to local disk',
        'no_usb': 'No EMCOMM-DATA USB found',
        'no_usb_detail': 'Plug in your USB drive to save maps permanently',
    },
    'fr': {
        'title': 'T\u00e9l\u00e9charger les cartes',
        'subtitle': 'S\u00e9lectionnez les tuiles de carte \u00e0 t\u00e9l\u00e9charger',
        'download': 'T\u00e9l\u00e9charger la s\u00e9lection',
        'downloading': 'T\u00e9l\u00e9chargement',
        'complete': 'Termin\u00e9',
        'error': 'Erreur',
        'close': 'Fermer',
        'already_installed': 'Install\u00e9',
        'no_selection': 'S\u00e9lectionnez au moins un jeu de tuiles',
        'all_installed': 'Tous les jeux de tuiles sont d\u00e9j\u00e0 install\u00e9s.',
        'language': 'Langue',
        'storage_usb': 'Sauvegarde sur USB (EMCOMM-DATA)',
        'storage_local': 'Sauvegarde sur disque local',
        'no_usb': 'Aucune cl\u00e9 USB EMCOMM-DATA trouv\u00e9e',
        'no_usb_detail': 'Branchez votre cl\u00e9 USB pour sauvegarder les cartes',
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


def load_tile_config():
    """Load tile catalog from shared conf/tiles.json."""
    with open(TILES_JSON) as f:
        config = json.load(f)
    return config["base_url"], config["files"]


def migrate_osm_to_tt(directory):
    """Rename old osm-* tileset files to tt-* naming convention."""
    if not directory.exists():
        return
    for old_file in directory.glob("osm-*.mbtiles"):
        new_name = "tt-" + old_file.name[4:]
        new_file = directory / new_name
        if not new_file.exists():
            old_file.rename(new_file)
        else:
            old_file.unlink()


def is_live_boot():
    """Check if running in live boot mode (USB)."""
    return Path("/run/live").exists()


def find_usb_tileset_dir():
    """Find EMCOMM-DATA USB partition and return tilesets path, or None."""
    for base in [Path("/media"), Path("/run/media")]:
        if not base.exists():
            continue
        for user_dir in base.iterdir():
            if not user_dir.is_dir():
                continue
            emcomm_data = user_dir / "EMCOMM-DATA"
            if emcomm_data.is_dir():
                return emcomm_data / "tilesets"
    return None


def get_download_dir():
    """Return (download_path, is_usb). Live Run -> USB. HDD -> local."""
    if is_live_boot():
        usb_dir = find_usb_tileset_dir()
        if usb_dir:
            return usb_dir, True
    return TILESET_DIR, False


def _ensure_symlink(filename, usb_file):
    """Create symlink from TILESET_DIR/<file> -> USB tilesets/<file>."""
    TILESET_DIR.mkdir(parents=True, exist_ok=True)
    link = TILESET_DIR / filename
    if link.is_symlink():
        link.unlink()
    if not link.exists():
        link.symlink_to(usb_file)


def get_storage_info():
    """Return storage context for the UI template."""
    if is_live_boot():
        usb_dir = find_usb_tileset_dir()
        if usb_dir:
            return 'usb'
        return 'no_usb'
    return 'local'


def get_existing_files(tile_files):
    """Check which tilesets are already downloaded or available in skel."""
    migrate_osm_to_tt(TILESET_DIR)
    migrate_osm_to_tt(SKEL_TILESET_DIR)
    existing = []
    usb_dir = find_usb_tileset_dir() if is_live_boot() else None
    if usb_dir:
        migrate_osm_to_tt(usb_dir)
    for fname in tile_files:
        if (TILESET_DIR / fname).exists() or (SKEL_TILESET_DIR / fname).exists():
            existing.append(fname)
        elif usb_dir and (usb_dir / fname).exists():
            existing.append(fname)
    return existing


# ============================================================================
# Routes
# ============================================================================

@app.route('/')
def index():
    """Main page with tile download UI."""
    t, lang = get_translations()
    base_url, tile_files = load_tile_config()
    existing = get_existing_files(tile_files)
    storage_info = get_storage_info()
    return render_template('index.html', t=t, lang=lang,
                           tile_files=tile_files, existing_files=existing,
                           storage_info=storage_info)


@app.route('/api/download/tile', methods=['POST'])
def api_download_tile():
    """Download a single tile file."""
    base_url, tile_files = load_tile_config()
    filename = request.json.get('file')

    if not filename or filename not in tile_files:
        return jsonify({'success': False, 'error': 'Invalid file'})

    download_dir, is_usb = get_download_dir()

    # Live Run but no USB — block download
    if is_live_boot() and not is_usb:
        return jsonify({'success': False, 'error': 'No EMCOMM-DATA USB found. Plug in your USB drive.'})

    download_dir.mkdir(parents=True, exist_ok=True)
    dest_file = download_dir / filename

    # Already exists at download destination
    if dest_file.exists():
        if is_usb:
            _ensure_symlink(filename, dest_file)
        return jsonify({'success': True, 'skipped': True})

    # Check TILESET_DIR (local) — already there and not a symlink
    local_file = TILESET_DIR / filename
    if local_file.exists() and not local_file.is_symlink():
        return jsonify({'success': True, 'skipped': True})

    # Available in skel — symlink instead of downloading
    skel_file = SKEL_TILESET_DIR / filename
    if skel_file.exists():
        TILESET_DIR.mkdir(parents=True, exist_ok=True)
        if not local_file.exists():
            local_file.symlink_to(skel_file)
        return jsonify({'success': True, 'skipped': True})

    # Download
    url = f"{base_url}/{filename}/download"
    try:
        subprocess.run(
            ['curl', '-L', '-f', '-o', str(dest_file), url],
            check=True, capture_output=True
        )
        # Create symlink for mbtileserver
        if is_usb:
            _ensure_symlink(filename, dest_file)
        return jsonify({'success': True})
    except subprocess.CalledProcessError as e:
        # Clean up partial file
        if dest_file.exists():
            dest_file.unlink()
        error_map = {
            6: 'No internet connection',
            7: 'Server error',
            22: 'File not found on server',
            23: 'Disk full',
            28: 'Download timed out',
        }
        return jsonify({
            'success': False,
            'error': error_map.get(e.returncode, f'curl error {e.returncode}')
        })


@app.route('/api/status')
def api_status():
    """Return current tile status (for refresh after download)."""
    base_url, tile_files = load_tile_config()
    existing = get_existing_files(tile_files)
    return jsonify({'existing': existing, 'total': len(tile_files)})


@app.route('/api/quit', methods=['POST'])
def api_quit():
    """Shut down the Flask server."""
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        os._exit(0)
    func()
    return 'Server shutting down...'


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    port = 5056

    if '--no-browser' in sys.argv:
        print(f"Starting et-tile-downloader on http://127.0.0.1:{port}")
        app.run(host='127.0.0.1', port=port, debug=False)
    else:
        import webbrowser
        import threading
        import time

        def open_browser():
            time.sleep(1)
            webbrowser.open(f'http://127.0.0.1:{port}')

        threading.Thread(target=open_browser, daemon=True).start()
        print(f"Starting et-tile-downloader on http://127.0.0.1:{port}")
        app.run(host='127.0.0.1', port=port, debug=False)
