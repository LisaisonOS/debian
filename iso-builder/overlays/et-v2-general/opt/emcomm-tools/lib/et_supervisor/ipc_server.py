"""
IPCServer: Unix domain socket server for dashboard/CLI communication.

Listens on /run/user/$UID/et-supervisor.sock
Protocol: newline-delimited JSON request/response.

Commands:
  {"cmd": "status"}                          -> current mode + process states
  {"cmd": "start-mode", "mode": "<mode-id>"} -> start a mode
  {"cmd": "stop"}                            -> stop current mode
  {"cmd": "health"}                          -> detailed health check results
  {"cmd": "list-modes"}                      -> available mode configs
"""

import json
import logging
import os
import socket
import threading

log = logging.getLogger("et-supervisor.ipc")

SOCKET_DIR = f"/run/user/{os.getuid()}"
SOCKET_PATH = os.path.join(SOCKET_DIR, "et-supervisor.sock")
BUFFER_SIZE = 8192


class IPCServer:
    """Unix domain socket server for et-supervisor IPC."""

    def __init__(self, mode_engine, health_monitor):
        self._engine = mode_engine
        self._health = health_monitor
        self._socket = None
        self._thread = None
        self._stop_event = threading.Event()

    @property
    def socket_path(self):
        return SOCKET_PATH

    def start(self):
        """Start the IPC server thread."""
        # Clean up stale socket
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)

        self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._socket.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o600)
        self._socket.listen(5)
        self._socket.settimeout(1.0)

        self._stop_event.clear()
        self._thread = threading.Thread(target=self._accept_loop, daemon=True)
        self._thread.start()
        log.info("IPC server listening on %s", SOCKET_PATH)

    def stop(self):
        """Stop the IPC server."""
        self._stop_event.set()
        if self._socket:
            try:
                self._socket.close()
            except OSError:
                pass
        if self._thread:
            self._thread.join(timeout=3)
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        log.info("IPC server stopped")

    def _accept_loop(self):
        while not self._stop_event.is_set():
            try:
                conn, _ = self._socket.accept()
                # Handle each connection in a separate thread
                t = threading.Thread(target=self._handle_conn, args=(conn,),
                                     daemon=True)
                t.start()
            except socket.timeout:
                continue
            except OSError:
                if not self._stop_event.is_set():
                    log.error("IPC accept error")
                break

    def _handle_conn(self, conn):
        try:
            conn.settimeout(5.0)
            data = conn.recv(BUFFER_SIZE)
            if not data:
                return

            # Protocol: newline-delimited JSON
            for line in data.decode("utf-8").strip().split("\n"):
                if not line:
                    continue
                try:
                    request = json.loads(line)
                except json.JSONDecodeError:
                    response = {"status": "error", "message": "Invalid JSON"}
                    conn.sendall(json.dumps(response).encode() + b"\n")
                    continue

                try:
                    response = self._dispatch(request)
                except Exception:
                    log.exception("Unhandled error in command: %s",
                                  request.get("cmd", "?"))
                    response = {"status": "error",
                                "message": "Internal supervisor error (check log)"}
                conn.sendall(json.dumps(response).encode() + b"\n")
        except (socket.timeout, BrokenPipeError, ConnectionResetError):
            pass
        finally:
            conn.close()

    def _dispatch(self, request):
        """Route a command to the appropriate handler."""
        cmd = request.get("cmd", "")

        if cmd == "status":
            return self._cmd_status()
        elif cmd == "start-mode":
            return self._cmd_start_mode(request)
        elif cmd == "stop":
            return self._cmd_stop()
        elif cmd == "health":
            return self._cmd_health()
        elif cmd == "list-modes":
            return self._cmd_list_modes()
        else:
            return {"status": "error", "message": f"Unknown command: {cmd}"}

    def _cmd_status(self):
        pm = self._engine._pm
        processes = [p.to_dict() for p in pm.processes.values()]
        mode_name = None
        config = self._engine.mode_config
        if config:
            names = config.get("name", {})
            mode_name = names.get("en", self._engine.current_mode)
        return {
            "status": "ok",
            "mode": self._engine.current_mode,
            "mode_name": mode_name,
            "processes": processes,
        }

    def _cmd_start_mode(self, request):
        mode_id = request.get("mode", "")
        if not mode_id:
            return {"status": "error", "message": "No mode specified"}
        params = request.get("params", {})
        ok, msg = self._engine.start_mode(mode_id, params=params)
        return {
            "status": "ok" if ok else "error",
            "message": msg,
            "mode": self._engine.current_mode,
        }

    def _cmd_stop(self):
        ok, msg = self._engine.stop()
        return {"status": "ok" if ok else "error", "message": msg}

    def _cmd_health(self):
        results = self._health.check_now()
        return {
            "status": "ok",
            "mode": self._engine.current_mode,
            "health": results,
        }

    def _cmd_list_modes(self):
        modes = self._engine.list_modes()
        radio_bands = self._engine.get_active_radio_bands()
        details = []
        for mode_id in modes:
            config = self._engine.load_mode(mode_id)
            if config:
                required = config.get("requires_bands", [])
                if required and radio_bands and not set(required) & set(radio_bands):
                    continue  # Radio doesn't support required bands
                details.append({
                    "id": mode_id,
                    "name": config.get("name", {}),
                    "category": config.get("category", ""),
                })
        return {"status": "ok", "modes": details}
