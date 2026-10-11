import os
import queue
import socket
import threading
import time
import unittest
from unittest.mock import patch

from scripts.service_events import ServiceEvents


class BlockingLines:
    def __init__(self):
        self.lines = queue.Queue()
        self.closed = threading.Event()
        self.read_count = 0

    def readline(self):
        item = self.lines.get()
        self.read_count += 1
        return "" if item is None else item

    def finish(self):
        self.lines.put(None)

    def close(self):
        self.closed.set()
        self.lines.put(None)


class FakeProcess:
    def __init__(self, args, **kwargs):
        self.args = args
        self.stdout = BlockingLines()
        self.stderr = None
        self.returncode = None
        self.started = threading.Event()
        self.terminated = threading.Event()
        self.started.set()

    def poll(self):
        return self.returncode

    def terminate(self):
        self.returncode = -15
        self.terminated.set()
        self.stdout.close()

    def kill(self):
        self.returncode = -9
        self.terminated.set()
        self.stdout.close()

    def wait(self, timeout=None):
        self.terminated.wait(timeout)
        if self.returncode is None:
            raise TimeoutError
        return self.returncode


class ServiceEventsTests(unittest.TestCase):
    def wait_for(self, predicate, timeout=1.5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.005)
        return predicate()

    def test_command_watchers_filter_and_coalesce_invalidations(self):
        stop = threading.Event()
        processes = []

        def popen(args, **kwargs):
            process = FakeProcess(args, **kwargs)
            processes.append(process)
            return process

        events = ServiceEvents(stop, popen=popen, socket_factory=lambda *_: None, reconnect_delay=0.01)
        events.start()
        try:
            self.assertTrue(self.wait_for(lambda: len(processes) >= 2))
            self.assertTrue(self.wait_for(lambda: events.connected('audio') and events.connected('wifi')))
            pactl = next(proc for proc in processes if proc.args[0] == 'pactl')
            nmcli = next(proc for proc in processes if proc.args[0] == 'nmcli')
            self.assertTrue(events.connected('audio'))
            self.assertTrue(events.connected('wifi'))
            # Initial connection transitions request one fresh snapshot.
            self.assertEqual(events.drain(), {'audio', 'wifi'})

            pactl.stdout.lines.put("Event 'change' on sink #1\n")
            pactl.stdout.lines.put("Event 'change' on client #5\n")
            pactl.stdout.lines.put("Event 'remove' on sink-input #7\n")
            nmcli.stdout.lines.put("Connectivity is now 'full'\n")
            nmcli.stdout.lines.put("\n")
            self.assertTrue(self.wait_for(lambda: pactl.stdout.read_count >= 3 and nmcli.stdout.read_count >= 2))
            # Wait until every sent line has been consumed before checking coalescing.
            self.assertEqual(events.drain(), {'audio', 'wifi'})
            self.assertEqual(events.drain(), set())
        finally:
            events.close()
        self.assertTrue(all(proc.terminated.is_set() for proc in processes))

    def test_already_exited_monitor_closes_its_stdout(self):
        stop = threading.Event()
        processes = []

        def popen(args, **kwargs):
            process = FakeProcess(args, **kwargs)
            process.returncode = 0
            processes.append(process)
            process.stdout.finish()
            return process

        events = ServiceEvents(stop, popen=popen, socket_factory=lambda *_: None, reconnect_delay=0.5)
        events.start()
        try:
            self.assertTrue(self.wait_for(lambda: len(processes) >= 2))
            self.assertTrue(self.wait_for(lambda: all(proc.stdout.closed.is_set() for proc in processes)))
        finally:
            events.close()

    def test_command_disconnect_marks_service_unavailable_and_close_unblocks_reader(self):
        stop = threading.Event()
        processes = []

        def popen(args, **kwargs):
            process = FakeProcess(args, **kwargs)
            processes.append(process)
            return process

        events = ServiceEvents(stop, popen=popen, socket_factory=lambda *_: None, reconnect_delay=0.01)
        events.start()
        self.assertTrue(self.wait_for(lambda: len(processes) >= 2))
        self.assertTrue(self.wait_for(lambda: events.connected('wifi')))
        events.drain()
        proc = next(proc for proc in processes if proc.args[0] == 'nmcli')
        # Simulate a monitor exiting; next spawn is its reconnect.
        proc.stdout.close()
        self.assertTrue(self.wait_for(lambda: len([p for p in processes if p.args[0] == 'nmcli']) >= 2))
        self.assertIn('wifi', events.drain())
        events.close()
        self.assertTrue(all(proc.terminated.is_set() for proc in processes))
        self.assertFalse(events.connected('wifi'))

    def test_hyprland_socket_events_route_to_desktop_and_display(self):
        with unittest.mock.patch.dict(os.environ, {
            'XDG_RUNTIME_DIR': '/run/test-user',
            'HYPRLAND_INSTANCE_SIGNATURE': 'test-instance',
        }):
            captured = {}

            class FakeSocket:
                def __init__(self, *_):
                    self.lines = queue.Queue()
                    self.closed = threading.Event()
                    captured['socket'] = self

                def connect(self, path):
                    captured['path'] = path

                def recv(self, _size):
                    item = self.lines.get()
                    return b'' if item is None else item

                def shutdown(self, *_):
                    self.lines.put(None)

                def close(self):
                    self.closed.set()
                    self.lines.put(None)

            stop = threading.Event()
            events = ServiceEvents(stop, popen=lambda *_a, **_k: None,
                                   socket_factory=lambda *_: FakeSocket(), reconnect_delay=0.01)
            events.start()
            try:
                self.assertTrue(self.wait_for(lambda: events.connected('desktop')))
                self.assertTrue(events.connected('display'))
                sock = captured['socket']
                self.assertTrue(captured['path'].endswith('hypr/test-instance/.socket2.sock'))
                self.assertEqual(events.drain(), {'desktop', 'display'})
                sock.lines.put(b'workspacev2>>3,web\n')
                sock.lines.put(b'focusedmon>>DP-1,web\n')
                sock.lines.put(b'monitoraddedv2>>1,DP-1,1920x1080@60\n')
                sock.lines.put(b'activewindow>>title,class\n')
                seen = set()
                self.assertTrue(self.wait_for(lambda: (seen.update(events.drain()) or {'desktop', 'display'} <= seen)))
                self.assertEqual(seen, {'desktop', 'display'})
                sock.lines.put(None)
                self.assertTrue(self.wait_for(lambda: not events.connected('desktop')))
                self.assertEqual(events.drain(), {'desktop', 'display'})
            finally:
                events.close()
            self.assertTrue(captured['socket'].closed.is_set())

    def test_missing_monitor_tools_or_hypr_environment_use_fallback(self):
        with patch.dict(os.environ, {}, clear=True):
            stop = threading.Event()
            events = ServiceEvents(stop, popen=lambda *_a, **_k: (_ for _ in ()).throw(FileNotFoundError()),
                                   socket_factory=lambda *_: self.fail('socket should not be created'),
                                   reconnect_delay=0.01)
            events.start()
            try:
                self.assertTrue(self.wait_for(lambda: len(events._threads) == 3))
                self.assertFalse(events.connected('audio'))
                self.assertFalse(events.connected('wifi'))
                self.assertFalse(events.connected('display'))
            finally:
                events.close()


if __name__ == '__main__':
    unittest.main()
