#!/usr/bin/env python3
"""
EmComm-Tools Persistence Module
Author: Sylvain Deguire (VA2OPS)
Date: January 2026

This module provides persistence detection and management for EmComm-Tools.
It can be imported by et-firstboot.py or used standalone.

Usage in et-firstboot.py:
    from persistence import PersistenceManager
    pm = PersistenceManager()
    if pm.detect():
        callsign = pm.get_callsign()
        # Show "Welcome back!" dialog
"""

import os
import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List, Any

class PersistenceManager:
    """Manages EmComm-Tools configuration persistence on USB drives."""
    
    PERSISTENCE_MARKER = "emcomm-data"
    SEARCH_PATHS = ["/media", "/run/media", "/mnt"]
    
    def __init__(self):
        self.persistence_path: Optional[Path] = None
        self.mapping_file = Path(__file__).parent / "persistence-mapping.json"
        self.mapping: Dict[str, Any] = {}
        self._load_mapping()
    
    def _load_mapping(self):
        """Load the config mapping file."""
        if self.mapping_file.exists():
            try:
                with open(self.mapping_file) as f:
                    self.mapping = json.load(f)
            except Exception as e:
                print(f"[PERSISTENCE] Warning: Could not load mapping: {e}")
    
    def detect(self) -> bool:
        """
        Detect EmComm-Tools persistence on any mounted USB drive.
        Returns True if found, False otherwise.
        """
        for base_path in self.SEARCH_PATHS:
            base = Path(base_path)
            if not base.exists():
                continue
            
            # Search up to 3 levels deep
            for depth in range(1, 4):
                for candidate in base.glob("/".join(["*"] * depth)):
                    if candidate.is_dir() and candidate.name == self.PERSISTENCE_MARKER:
                        # Verify it's valid
                        if (candidate / "user.json").exists() or (candidate / "manifest.json").exists():
                            self.persistence_path = candidate
                            print(f"[PERSISTENCE] Found at: {self.persistence_path}")
                            return True
        
        # Also check if emcomm-data is at the root of a mounted drive
        for base_path in self.SEARCH_PATHS:
            base = Path(base_path)
            if not base.exists():
                continue
            
            # Check /media/username/DRIVENAME/emcomm-data
            for user_dir in base.iterdir():
                if not user_dir.is_dir():
                    continue
                for drive in user_dir.iterdir():
                    if not drive.is_dir():
                        continue
                    candidate = drive / self.PERSISTENCE_MARKER
                    if candidate.exists():
                        if (candidate / "user.json").exists() or (candidate / "manifest.json").exists():
                            self.persistence_path = candidate
                            print(f"[PERSISTENCE] Found at: {self.persistence_path}")
                            return True
        
        return False
    
    def get_usb_root(self) -> Optional[Path]:
        """Get the root of the USB drive (parent of emcomm-data)."""
        if self.persistence_path:
            return self.persistence_path.parent
        return None
    
    def get_callsign(self) -> str:
        """Get callsign from persistence, or 'N0CALL' if not found."""
        if not self.persistence_path:
            return "N0CALL"
        
        user_conf = self.persistence_path / "user.json"
        if user_conf.exists():
            try:
                with open(user_conf) as f:
                    data = json.load(f)
                    return data.get("callsign", "N0CALL")
            except:
                pass
        
        manifest = self.persistence_path / "manifest.json"
        if manifest.exists():
            try:
                with open(manifest) as f:
                    data = json.load(f)
                    return data.get("callsign", "N0CALL")
            except:
                pass
        
        return "N0CALL"
    
    def get_user_config(self) -> Dict[str, Any]:
        """Load user config from persistence."""
        if not self.persistence_path:
            return {}
        
        user_conf = self.persistence_path / "user.json"
        if user_conf.exists():
            try:
                with open(user_conf) as f:
                    return json.load(f)
            except:
                pass
        return {}
    
    def restore_user_config(self, dest: Path) -> bool:
        """
        Restore user.json from persistence to destination.
        
        Args:
            dest: Destination path (e.g., ~/.config/emcomm-tools/user.json)
        
        Returns:
            True if successful, False otherwise.
        """
        if not self.persistence_path:
            return False
        
        src = self.persistence_path / "user.json"
        if not src.exists():
            return False
        
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            print(f"[PERSISTENCE] Restored: {src} -> {dest}")
            return True
        except Exception as e:
            print(f"[PERSISTENCE] Error restoring user config: {e}")
            return False
    
    def save_user_config(self, src: Path) -> bool:
        """
        Save user config to persistence.
        
        Args:
            src: Source path (e.g., ~/.config/emcomm-tools/user.json)
        
        Returns:
            True if successful, False otherwise.
        """
        if not self.persistence_path:
            return False
        
        if not src.exists():
            return False
        
        try:
            dest = self.persistence_path / "user.json"
            shutil.copy2(src, dest)
            self._update_manifest()
            print(f"[PERSISTENCE] Saved: {src} -> {dest}")
            return True
        except Exception as e:
            print(f"[PERSISTENCE] Error saving user config: {e}")
            return False
    
    def _update_manifest(self):
        """Update the manifest file with current timestamp."""
        if not self.persistence_path:
            return
        
        manifest_path = self.persistence_path / "manifest.json"
        manifest = {
            "version": "2.0.0",
            "callsign": self.get_callsign(),
            "last_save": datetime.now().isoformat(),
            "hostname": os.uname().nodename,
        }
        
        try:
            with open(manifest_path, 'w') as f:
                json.dump(manifest, f, indent=2)
        except Exception as e:
            print(f"[PERSISTENCE] Error updating manifest: {e}")
    
    def init_persistence(self, usb_root: Path) -> bool:
        """
        Initialize persistence on a USB drive.
        
        Args:
            usb_root: Root path of USB drive (e.g., /media/user/VENTOY)
        
        Returns:
            True if successful, False otherwise.
        """
        try:
            persistence_dir = usb_root / self.PERSISTENCE_MARKER
            
            # Create directory structure
            dirs = [
                "configs/pat",
                "configs/js8call",
                "configs/wsjtx",
                "configs/fldigi/macros",
                "configs/flmsg",
                "configs/vara",
                "configs/varac",
                "configs/direwolf",
                "configs/linbpq",
                "mailbox",
                "backups",
            ]
            
            for d in dirs:
                (persistence_dir / d).mkdir(parents=True, exist_ok=True)
            
            # Create manifest
            manifest = {
                "version": "2.0.0",
                "callsign": "",
                "created": datetime.now().isoformat(),
                "last_save": None,
            }
            
            with open(persistence_dir / "manifest.json", 'w') as f:
                json.dump(manifest, f, indent=2)
            
            # Create template user.json
            user_conf = {
                "callsign": "",
                "grid": "",
                "name": "",
                "winlinkPasswd": "",
                "language": "en",
                "configured": False,
            }
            
            user_conf_path = persistence_dir / "user.json"
            if not user_conf_path.exists():
                with open(user_conf_path, 'w') as f:
                    json.dump(user_conf, f, indent=2)
            
            self.persistence_path = persistence_dir
            print(f"[PERSISTENCE] Initialized at: {persistence_dir}")
            return True
            
        except Exception as e:
            print(f"[PERSISTENCE] Error initializing: {e}")
            return False
    
    def get_summary(self) -> Dict[str, Any]:
        """Get a summary of available persistence data."""
        summary = {
            "found": self.persistence_path is not None,
            "path": str(self.persistence_path) if self.persistence_path else None,
            "callsign": self.get_callsign(),
            "usb_root": str(self.get_usb_root()) if self.get_usb_root() else None,
            "has_maps": False,
            "has_wikipedia": False,
            "has_mailbox": False,
        }
        
        if self.persistence_path:
            usb_root = self.get_usb_root()
            if usb_root:
                # Check for maps
                for maps_dir in ["maps/mbtiles", "tilesets"]:
                    if (usb_root / maps_dir).exists():
                        summary["has_maps"] = True
                        break
                
                # Check for wikipedia
                if (usb_root / "wikipedia").exists():
                    summary["has_wikipedia"] = True
                
                # Check for mailbox
                if (self.persistence_path / "mailbox").exists():
                    mailbox_files = list((self.persistence_path / "mailbox").rglob("*"))
                    summary["has_mailbox"] = len(mailbox_files) > 0
        
        return summary


# CLI interface for testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="EmComm-Tools Persistence Manager")
    parser.add_argument("command", choices=["detect", "summary", "callsign"], help="Command to run")
    args = parser.parse_args()
    
    pm = PersistenceManager()
    
    if args.command == "detect":
        if pm.detect():
            print(pm.persistence_path)
        else:
            print("Not found")
            exit(1)
    
    elif args.command == "summary":
        if pm.detect():
            summary = pm.get_summary()
            print(json.dumps(summary, indent=2))
        else:
            print("No persistence found")
            exit(1)
    
    elif args.command == "callsign":
        if pm.detect():
            print(pm.get_callsign())
        else:
            print("N0CALL")
            exit(1)
