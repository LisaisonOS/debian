"""
RigClient — Shared persistent TCP client for rigctld.

Single connection, cached state, thread-safe.
All radio queries go through here — no subprocess spawning.

Usage:
    from et_supervisor.rig_client import rig
    rig.refresh()          # One call to radio
    print(rig.freq)        # From cache
    print(rig.mode)        # From cache
    print(rig.band)        # From cache
    rig.set_freq(14078000) # Write + refresh cache
"""

import socket
import threading
import logging
import time

log = logging.getLogger("et-supervisor.rig-client")

# Band map: MHz floor → band name
_BAND_RANGES = [
    (1.8, 2.0, '160m'), (3.5, 4.0, '80m'), (5.3, 5.4, '60m'),
    (7.0, 7.3, '40m'), (10.1, 10.15, '30m'), (14.0, 14.35, '20m'),
    (18.068, 18.168, '17m'), (21.0, 21.45, '15m'),
    (24.89, 24.99, '12m'), (28.0, 29.7, '10m'),
    (50.0, 54.0, '6m'), (144.0, 148.0, '2m'), (420.0, 450.0, '70cm'),
]

# Mode normalization: rigctld mode → ADIF mode
_MODE_MAP = {
    'USB': 'SSB', 'LSB': 'SSB', 'AM': 'AM', 'FM': 'FM',
    'CW': 'CW', 'CWR': 'CW', 'RTTY': 'RTTY', 'RTTYR': 'RTTY',
    'PKTUSB': 'DIG', 'PKTLSB': 'DIG', 'PKTFM': 'FM',
    'DATA': 'DIG', 'FMN': 'FM',
}


def _freq_to_band(freq_hz):
    """Convert frequency in Hz to band name."""
    if not freq_hz:
        return ''
    mhz = freq_hz / 1_000_000
    for low, high, name in _BAND_RANGES:
        if low <= mhz <= high:
            return name
    return ''


def _normalize_mode(mode_str):
    """Normalize rigctld mode to ADIF mode. Returns None if unknown."""
    if not mode_str:
        return None
    return _MODE_MAP.get(mode_str.upper().strip())


class RigClient:
    """Persistent TCP client for rigctld with cached state."""

    def __init__(self, host='localhost', port=4532, timeout=3):
        self._host = host
        self._port = port
        self._timeout = timeout
        self._sock = None
        self._lock = threading.Lock()

        # Cached state
        self.freq = None        # Hz (int)
        self.freq_mhz = None   # MHz (float)
        self.mode = None        # ADIF mode string
        self.mode_raw = None    # Raw rigctld mode string
        self.band = None        # Band name string
        self.power = None       # Watts (int) or None
        self.passband = None    # Passband width (int)
        self.connected = False

        # QSY tracking
        self._prev_freq = None
        self._freq_callback = None

    def _connect(self):
        """Open TCP connection to rigctld."""
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass
            self._sock = None

        try:
            self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._sock.settimeout(self._timeout)
            self._sock.connect((self._host, self._port))
            self.connected = True
            log.info("Connected to rigctld at %s:%d", self._host, self._port)
            return True
        except (ConnectionRefusedError, TimeoutError, OSError) as e:
            self._sock = None
            self.connected = False
            log.debug("Cannot connect to rigctld: %s", e)
            return False

    def _send_recv(self, command):
        """Send a command and receive the response. Auto-reconnects."""
        with self._lock:
            # Try existing connection first
            if self._sock:
                try:
                    self._sock.sendall((command + '\n').encode())
                    return self._read_response()
                except (BrokenPipeError, ConnectionResetError, OSError):
                    self._sock = None
                    self.connected = False

            # Reconnect and retry
            if not self._connect():
                return None

            try:
                self._sock.sendall((command + '\n').encode())
                return self._read_response()
            except Exception as e:
                log.debug("rigctld send/recv failed: %s", e)
                self._sock = None
                self.connected = False
                return None

    def _read_response(self):
        """Read one response line from rigctld."""
        data = b''
        try:
            while True:
                chunk = self._sock.recv(4096)
                if not chunk:
                    break
                data += chunk
                if data.endswith(b'\n'):
                    break
        except socket.timeout:
            pass
        return data.decode('utf-8', errors='ignore').strip()

    def _cmd(self, command):
        """Send one command, return response string (or None)."""
        return self._send_recv(command)

    def refresh(self):
        """Fetch radio state with individual commands. Updates cache."""
        # Get frequency
        resp = self._cmd('f')
        if resp is None:
            self.connected = False
            return False

        self.connected = True
        try:
            val = int(resp)
            if val > 100000:
                self._prev_freq = self.freq
                self.freq = val
                self.freq_mhz = round(val / 1_000_000, 6)
                self.band = _freq_to_band(val)

                # QSY callback
                if (self._freq_callback and self._prev_freq
                        and self._prev_freq != val):
                    try:
                        self._freq_callback(val, self._prev_freq)
                    except Exception:
                        pass
        except (ValueError, TypeError):
            pass

        # Get mode + passband
        resp = self._cmd('m')
        if resp:
            lines = resp.splitlines()
            if lines:
                normalized = _normalize_mode(lines[0])
                if normalized:
                    self.mode_raw = lines[0].strip().upper()
                    self.mode = normalized
                if len(lines) > 1:
                    try:
                        val = int(lines[1])
                        if 100 <= val <= 50000:
                            self.passband = val
                    except (ValueError, TypeError):
                        pass

        # Get power level
        resp = self._cmd('l RFPOWER')
        if resp:
            try:
                val = float(resp)
                if 0 <= val <= 1.0:
                    self.power = round(val * 100)
            except (ValueError, TypeError):
                pass

        return True

    def get_all(self):
        """Refresh and return all cached state as dict."""
        self.refresh()
        return {
            'freq': self.freq,
            'freq_mhz': self.freq_mhz,
            'mode': self.mode,
            'mode_raw': self.mode_raw,
            'band': self.band,
            'power': self.power,
            'passband': self.passband,
            'connected': self.connected,
        }

    # === Write commands ===

    def set_freq(self, freq_hz):
        """Set radio frequency in Hz."""
        result = self._send_recv(f'F {freq_hz}')
        if result is not None:
            self.freq = freq_hz
            self.freq_mhz = round(freq_hz / 1_000_000, 6)
            self.band = _freq_to_band(freq_hz)
        return result is not None

    def set_mode(self, mode, passband=0):
        """Set radio mode and optional passband width."""
        result = self._send_recv(f'M {mode} {passband}')
        if result is not None:
            self.mode_raw = mode
            self.mode = _normalize_mode(mode) or mode
            if passband:
                self.passband = passband
        return result is not None

    def set_ptt(self, on):
        """Key or unkey PTT. on=True for TX, False for RX."""
        return self._send_recv(f'T {1 if on else 0}') is not None

    def set_ctcss_tone(self, tone_tenths):
        """Set CTCSS tone in tenths of Hz (e.g. 1000 for 100.0 Hz)."""
        result = self._send_recv(f'C {tone_tenths}')
        if result is not None:
            # Enable tone
            self._send_recv('U TONE 1')
        return result is not None

    def set_rptr_shift(self, shift):
        """Set repeater shift: '+', '-', or '0' for simplex."""
        return self._send_recv(f'R {shift}') is not None

    def set_rptr_offset(self, offset_hz):
        """Set repeater offset in Hz."""
        return self._send_recv(f'O {offset_hz}') is not None

    # === QSY tracking ===

    def on_freq_change(self, callback):
        """Register a callback for frequency changes.

        callback(new_freq_hz, old_freq_hz) called when refresh()
        detects a frequency change.
        """
        self._freq_callback = callback

    # === Background polling ===

    def start_polling(self, interval=2):
        """Start background thread that refreshes radio state every N seconds.

        Calls freq_callback on QSY. Listeners can also check cached state.
        """
        if hasattr(self, '_poll_thread') and self._poll_thread and self._poll_thread.is_alive():
            return  # Already running
        self._poll_stop = threading.Event()
        self._poll_interval = interval
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._poll_thread.start()
        log.info("Rig polling started (every %ds)", interval)

    def stop_polling(self):
        """Stop background polling thread."""
        if hasattr(self, '_poll_stop'):
            self._poll_stop.set()
            log.info("Rig polling stopped")

    def _poll_loop(self):
        """Background polling loop."""
        while not self._poll_stop.is_set():
            try:
                self.refresh()
            except Exception:
                pass
            self._poll_stop.wait(self._poll_interval)

    # === Connection management ===

    def close(self):
        """Close the TCP connection."""
        self.stop_polling()
        with self._lock:
            if self._sock:
                try:
                    self._sock.close()
                except Exception:
                    pass
                self._sock = None
            self.connected = False

    def is_connected(self):
        """Check if connected (without querying radio)."""
        return self.connected and self._sock is not None

    def __del__(self):
        self.close()


# === Singleton instance ===
# All apps import and use this shared instance
rig = RigClient()
