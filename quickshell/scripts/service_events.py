"""Small, reconnecting invalidation watchers for desktop service state."""
from __future__ import annotations

import os
import socket
import subprocess
import threading
import time
from typing import Callable


_AUDIO_EVENT_KINDS = frozenset({'sink', 'source', 'sink-input', 'server', 'card'})
_DESKTOP_EVENTS = frozenset({
    'workspace', 'workspacev2', 'createworkspace', 'createworkspacev2',
    'destroyworkspace', 'destroyworkspacev2', 'moveworkspace', 'moveworkspacev2',
    'focusedmon', 'focusedmonv2', 'openwindow', 'openwindowv2',
    'closewindow', 'closewindowv2', 'movewindow', 'movewindowv2',
    'populateworkspace', 'depopulateworkspace',
})
_DISPLAY_EVENTS = frozenset({
    'monitoradded', 'monitoraddedv2', 'monitorremoved', 'monitorremovedv2',
    'focusedmon', 'focusedmonv2', 'configreloaded',
})


class ServiceEvents:
    """Watch system event streams and collect service names needing refresh.

    Watchers only invalidate snapshots; consumers call :meth:`drain` and perform
    their own reads. Each monitor is independent and reconnects after a bounded
    delay when its source is unavailable.
    """

    def __init__(self, stop: threading.Event, *, popen: Callable = subprocess.Popen,
                 socket_factory: Callable = socket.socket, reconnect_delay: float = 5.0):
        self.stop = stop
        self._popen = popen
        self._socket_factory = socket_factory
        self._reconnect_delay = max(0.0, reconnect_delay)
        self._lock = threading.Lock()
        self._resource_lock = threading.Lock()
        self._pending: set[str] = set()
        self._connected = {'audio': False, 'wifi': False, 'desktop': False, 'display': False}
        self._processes: dict[str, object] = {}
        self._socket = None
        self._threads: list[threading.Thread] = []
        self._closed = threading.Event()
        self._started = False

    def start(self) -> None:
        with self._resource_lock:
            if self._started or self._closed.is_set():
                return
            self._started = True
            watchers = (
                ('audio', self._watch_command, ('audio', ['pactl', 'subscribe'])),
                ('wifi', self._watch_command, ('wifi', ['nmcli', 'monitor'])),
                ('hyprland', self._watch_hyprland, ()),
            )
            for name, target, args in watchers:
                thread = threading.Thread(target=target, args=args,
                                          name=f'service-events-{name}', daemon=True)
                self._threads.append(thread)
                thread.start()

    def connected(self, service: str) -> bool:
        with self._lock:
            return bool(self._connected.get(service, False))

    def drain(self) -> set[str]:
        with self._lock:
            pending, self._pending = self._pending, set()
            return pending

    def close(self) -> None:
        self._closed.set()
        with self._resource_lock:
            processes = list(self._processes.values())
            stream = self._socket
        for process in processes:
            self._stop_process(process)
        if stream is not None:
            try:
                stream.shutdown(socket.SHUT_RDWR)
            except (OSError, AttributeError):
                pass
            try:
                stream.close()
            except OSError:
                pass
        with self._resource_lock:
            threads = list(self._threads)
        for thread in threads:
            if thread is not threading.current_thread():
                thread.join(timeout=1.5)
        self._set_connected('audio', False)
        self._set_connected('wifi', False)
        self._set_hyprland_connected(False)

    def _active(self) -> bool:
        return not self.stop.is_set() and not self._closed.is_set()

    def _wait_reconnect(self) -> bool:
        # Short bounded waits also let close() stop a watcher promptly.
        deadline = time.monotonic() + self._reconnect_delay
        while self._active():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return True
            if self.stop.wait(min(remaining, 0.1)):
                return False
            if self._closed.wait(min(remaining, 0.1)):
                return False
        return False

    def _invalidate(self, *services: str) -> None:
        with self._lock:
            self._pending.update(services)

    def _set_connected(self, service: str, value: bool) -> None:
        with self._lock:
            if self._connected[service] != value:
                self._connected[service] = value
                self._pending.add(service)

    def _set_hyprland_connected(self, value: bool) -> None:
        with self._lock:
            for service in ('desktop', 'display'):
                if self._connected[service] != value:
                    self._connected[service] = value
                    self._pending.add(service)

    def _register_process(self, service: str, process) -> bool:
        with self._resource_lock:
            if self._closed.is_set():
                accepted = False
            else:
                self._processes[service] = process
                accepted = True
        if not accepted:
            self._stop_process(process)
        return accepted

    def _forget_process(self, service: str, process) -> None:
        with self._resource_lock:
            if self._processes.get(service) is process:
                self._processes.pop(service, None)

    def _watch_command(self, service: str, args: list[str]) -> None:
        while self._active():
            process = None
            try:
                env = os.environ.copy()
                env['LC_ALL'] = 'C'
                process = self._popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                      text=True, bufsize=1, env=env)
                if process is None:
                    raise OSError('monitor process could not be started')
                if not self._register_process(service, process):
                    return
                self._set_connected(service, True)
                output = process.stdout
                while self._active():
                    line = output.readline()
                    if not line:
                        break
                    if service == 'audio':
                        if self._is_audio_event(line):
                            self._invalidate('audio')
                    elif line.strip():
                        self._invalidate('wifi')
            except (OSError, ValueError, RuntimeError):
                # Missing utilities, failed execs, and closed streams all use polling fallback.
                pass
            finally:
                if process is not None:
                    self._forget_process(service, process)
                    self._stop_process(process)
                self._set_connected(service, False)
            if not self._wait_reconnect():
                return

    @staticmethod
    def _is_audio_event(line: str) -> bool:
        # pactl emits e.g. "Event 'change' on sink-input #42". Ignore clients,
        # modules, and other unrelated subscription traffic.
        try:
            event, target = line.split("' on ", 1)
            return event.startswith("Event '") and target.split(None, 1)[0] in _AUDIO_EVENT_KINDS
        except (ValueError, IndexError):
            return False

    def _hyprland_path(self) -> str | None:
        runtime = os.environ.get('XDG_RUNTIME_DIR')
        signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
        if not runtime or not signature or '/' in signature or signature in ('.', '..'):
            return None
        return os.path.join(runtime, 'hypr', signature, '.socket2.sock')

    def _watch_hyprland(self) -> None:
        while self._active():
            stream = None
            try:
                path = self._hyprland_path()
                if path is None:
                    raise OSError('Hyprland socket environment is unavailable')
                stream = self._socket_factory(socket.AF_UNIX, socket.SOCK_STREAM)
                if stream is None:
                    raise OSError('Hyprland socket could not be created')
                with self._resource_lock:
                    if self._closed.is_set():
                        stream.close()
                        stream = None
                    else:
                        self._socket = stream
                if stream is None:
                    return
                stream.connect(path)
                self._set_hyprland_connected(True)
                buffer = b''
                while self._active():
                    chunk = stream.recv(4096)
                    if not chunk:
                        break
                    buffer += chunk
                    while b'\n' in buffer:
                        line, buffer = buffer.split(b'\n', 1)
                        self._handle_hyprland_event(line)
            except (OSError, ValueError):
                pass
            finally:
                if stream is not None:
                    with self._resource_lock:
                        if self._socket is stream:
                            self._socket = None
                    try:
                        stream.close()
                    except OSError:
                        pass
                self._set_hyprland_connected(False)
            if not self._wait_reconnect():
                return

    def _handle_hyprland_event(self, raw: bytes) -> None:
        try:
            event = raw.decode('utf-8').split('>>', 1)[0]
        except UnicodeDecodeError:
            return
        desktop = event in _DESKTOP_EVENTS
        display = event in _DISPLAY_EVENTS
        if desktop:
            self._invalidate('desktop')
        if display:
            self._invalidate('display')

    @staticmethod
    def _stop_process(process) -> None:
        if process is None:
            return
        try:
            if process.poll() is None:
                process.terminate()
        except (OSError, ValueError):
            pass
        try:
            process.wait(timeout=0.5)
        except (subprocess.TimeoutExpired, TimeoutError):
            try:
                process.kill()
            except (OSError, ValueError):
                pass
            try:
                process.wait(timeout=0.5)
            except (subprocess.TimeoutExpired, TimeoutError, OSError, ValueError):
                pass
        try:
            if process.stdout is not None:
                process.stdout.close()
        except (OSError, ValueError, AttributeError):
            pass
