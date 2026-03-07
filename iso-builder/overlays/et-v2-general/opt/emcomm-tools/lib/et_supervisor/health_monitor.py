"""
HealthMonitor: Periodic health checks on running process chains.

Checks:
1. PID alive (os.waitpid with WNOHANG)
2. TCP port probe (connect+disconnect) for services like direwolf:8001, pat:8080
"""

import socket
import logging
import threading
import time

log = logging.getLogger("et-supervisor.health")


def check_tcp_port(port, host="127.0.0.1", timeout=2):
    """Test if a TCP port is accepting connections.

    Returns:
        True if connection succeeded.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            s.connect((host, port))
            return True
    except (ConnectionRefusedError, TimeoutError, OSError):
        return False


def wait_for_port(port, timeout=15, interval=1, host="127.0.0.1"):
    """Wait for a TCP port to become available.

    Returns:
        True if port became available within timeout.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        if check_tcp_port(port, host):
            log.info("Port %d is ready", port)
            return True
        time.sleep(interval)
    log.warning("Port %d not ready after %ds", port, timeout)
    return False


class HealthMonitor:
    """Periodically checks health of running processes."""

    def __init__(self, process_manager, interval=5.0):
        self._pm = process_manager
        self._interval = interval
        self._thread = None
        self._stop_event = threading.Event()
        self._crash_callback = None

    def set_crash_callback(self, callback):
        """Set callback(process_name, state) called when a process dies.

        Args:
            callback: function(name, state) where state is "CRASHED" or "STOPPED".
        """
        self._crash_callback = callback

    def start(self):
        """Start the health monitoring thread."""
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()
        log.info("Health monitor started (interval=%ds)", self._interval)

    def stop(self):
        """Stop the health monitoring thread."""
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=self._interval + 1)
            self._thread = None
        log.info("Health monitor stopped")

    def _monitor_loop(self):
        while not self._stop_event.is_set():
            self._check_all()
            self._stop_event.wait(self._interval)

    def _check_all(self):
        """Run health checks on all tracked processes."""
        for name, proc_info in self._pm.processes.items():
            if proc_info.state != "RUNNING":
                continue

            # Check PID alive
            alive = self._pm.check_process(name)
            if not alive:
                # Get the updated state after check_process
                updated = self._pm.processes.get(name)
                state = updated.state if updated else "CRASHED"
                log.warning("Health check: %s is no longer running (state=%s)",
                            name, state)
                if self._crash_callback:
                    self._crash_callback(name, state)
                continue

            # Check TCP port if configured
            if proc_info.health_port:
                port_ok = check_tcp_port(proc_info.health_port)
                if not port_ok:
                    log.warning("Health check: %s port %d not responding",
                                name, proc_info.health_port)

    def check_now(self):
        """Run health checks immediately (for CLI status queries)."""
        results = {}
        for name, proc_info in self._pm.processes.items():
            entry = {"pid_alive": False, "port_ok": None}
            if proc_info.state == "RUNNING":
                entry["pid_alive"] = self._pm.check_process(name)
                if proc_info.health_port:
                    entry["port_ok"] = check_tcp_port(proc_info.health_port)
            results[name] = entry
        return results
