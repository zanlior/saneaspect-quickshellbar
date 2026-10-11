import importlib.util
import json
import pathlib
import queue
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location('backend_dispatch', ROOT / 'scripts/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class Input:
    def __init__(self):
        self.messages = queue.Queue()

    def __iter__(self):
        while True:
            line = self.messages.get()
            if line is None:
                return
            yield line

    def send(self, action, **fields):
        self.messages.put(json.dumps({'action': action, **fields}))


class BackendDispatchTests(unittest.TestCase):
    def test_blocked_preference_and_clipboard_workers_leave_main_responsive(self):
        incoming = Input()
        backend = b.Backend()
        theme_started = threading.Event()
        clipboard_started = threading.Event()
        release_theme = threading.Event()
        release_clipboard = threading.Event()
        volume_done = threading.Event()
        reminder_tick = threading.Event()
        emitted_media = threading.Event()
        def command(message):
            if message['action'] == 'setting':
                theme_started.set(); release_theme.wait(3)
            elif message['action'] == 'clipboard-copy':
                clipboard_started.set(); release_clipboard.wait(3)
            elif message['action'] == 'volume':
                volume_done.set()
        def emit(data):
            if data.get('media') == {'alive': True}: emitted_media.set()
        with patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(backend, 'command', side_effect=command), patch.object(backend, 'emit', side_effect=emit), \
             patch.object(backend, 'check_prayer_reminders', side_effect=lambda: reminder_tick.set()), \
             patch.object(backend.prayers, 'get', return_value={}), \
             patch.object(b, 'wallpapers', return_value=[]), patch.object(b, 'media', return_value={'alive': True}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(b, 'current_wallpaper', return_value=''):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('setting', value='theme', extra='nord')
                self.assertTrue(theme_started.wait(2))
                incoming.send('clipboard-copy', value='7')
                self.assertTrue(clipboard_started.wait(2))
                incoming.send('page', value='calendar')
                incoming.send('volume', value=20)
                self.assertTrue(volume_done.wait(2), 'volume waited behind unrelated work')
                self.assertTrue(reminder_tick.wait(2), 'reminder tick waited behind unrelated work')
                self.assertTrue(emitted_media.wait(2), 'service polling waited behind unrelated work')
                self.assertEqual(backend.page, 'calendar')
            finally:
                release_theme.set(); release_clipboard.set(); incoming.messages.put(None); thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_preference_lane_persists_setting_then_reset_then_wallpaper(self):
        incoming = Input()
        backend = b.Backend()
        selected = threading.Event()
        real_save = b.save_settings
        saved = []
        def save(settings):
            saved.append(dict(settings))
            real_save(settings)
        def emit(data):
            if data.get('wallpaperSelected') == '/chosen.jpg': selected.set()
        with tempfile.TemporaryDirectory() as directory, patch.object(b, 'CONFIG', pathlib.Path(directory)), \
             patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(b, 'save_settings', side_effect=save), patch.object(b, 'wallpapers', return_value=[]), \
             patch.object(b, 'set_wallpaper', return_value='/chosen.jpg'), patch.object(b, 'current_wallpaper', return_value=''), \
             patch.object(backend, 'emit', side_effect=emit), patch.object(b, 'media', return_value={}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(backend.prayers, 'get', return_value={}), patch.object(backend, 'check_prayer_reminders'):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('setting', value='fontFamily', extra='Rubik')
                incoming.send('reset')
                incoming.send('wallpaper', value='/chosen.jpg')
                self.assertTrue(selected.wait(3))
                self.assertEqual(len(saved), 2)
                self.assertEqual(saved[0]['fontFamily'], 'Rubik')
                self.assertEqual(saved[1], b.DEFAULTS)
                persisted = json.loads((pathlib.Path(directory) / 'settings.json').read_text())
                self.assertEqual(persisted, b.DEFAULTS)
            finally:
                incoming.messages.put(None); thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_preference_worker_changes_are_isolated_until_commit_and_failures_preserve_state(self):
        backend = b.Backend()
        original = dict(backend.settings)
        with patch.object(b, 'save_settings') as save, patch.object(backend, 'emit'):
            outcome = backend.worker_outcome({'action': 'setting', 'value': 'fontFamily', 'extra': 'Rubik'}, 'preferences')
            self.assertEqual(backend.settings, original)
            self.assertEqual(outcome['fields']['settings']['fontFamily'], 'Rubik')
            backend.commit_outcome(outcome)
            self.assertEqual(backend.settings['fontFamily'], 'Rubik')
            outcome = backend.worker_outcome({'action': 'setting', 'value': 'clock24', 'extra': False}, 'preferences')
            backend.commit_outcome(outcome)
            self.assertEqual(backend.settings['fontFamily'], 'Rubik')
            self.assertFalse(backend.settings['clock24'])
            before_failure = dict(backend.settings)
            save.side_effect = OSError('disk unavailable')
            failed = backend.worker_outcome({'action': 'setting', 'value': 'fontFamily', 'extra': 'Inter'}, 'preferences')
            backend.commit_outcome(failed)
            self.assertIn('disk unavailable', failed['error'])
            self.assertEqual(backend.settings, before_failure)
            save.side_effect = None
            save.reset_mock()
            with patch.object(b, 'wallpapers', side_effect=OSError('scan unavailable')):
                scan_failed = backend.worker_outcome({'action': 'setting', 'value': 'wallpaperFolder', 'extra': '/other'}, 'preferences')
            self.assertIn('scan unavailable', scan_failed['error'])
            self.assertEqual(backend.settings, before_failure)
            save.assert_not_called()

    def test_live_preference_lane_keeps_consecutive_setting_snapshots(self):
        incoming = Input()
        backend = b.Backend()
        committed = threading.Event()
        settings_events = []
        def emit(data):
            if 'settings' in data:
                settings_events.append(dict(data['settings']))
                # The first event is the backend's startup state.
                if len(settings_events) == 3: committed.set()
        with tempfile.TemporaryDirectory() as directory, patch.object(b, 'CONFIG', pathlib.Path(directory)), \
             patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(b, 'wallpapers', return_value=[]), patch.object(b, 'media', return_value={}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(backend.prayers, 'get', return_value={}), patch.object(backend, 'check_prayer_reminders'), \
             patch.object(backend, 'emit', side_effect=emit):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('setting', value='fontFamily', extra='Rubik')
                incoming.send('setting', value='clock24', extra=False)
                self.assertTrue(committed.wait(3))
                persisted = json.loads((pathlib.Path(directory) / 'settings.json').read_text())
                self.assertEqual(persisted['fontFamily'], 'Rubik')
                self.assertFalse(persisted['clock24'])
                self.assertEqual(settings_events[-1]['fontFamily'], 'Rubik')
            finally:
                incoming.messages.put(None); thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_audio_slider_coalescing_respects_target_and_volume_step_barriers(self):
        incoming = Input()
        backend = b.Backend()
        first_started = threading.Event(); release_first = threading.Event()
        queued = threading.Event(); last_done = threading.Event()
        actions = []
        def command(message):
            action = message['action']
            if action == 'volume' and message.get('value') == 10:
                actions.append(('volume', message.get('extra'), 10))
                first_started.set(); release_first.wait(3)
            elif action == 'volume':
                actions.append(('volume', message.get('extra'), message.get('value')))
                if message.get('value') == 30: last_done.set()
            elif action == 'volume-step':
                actions.append(('volume-step', message['value']))
            elif action == 'test-barrier':
                queued.set()
        with patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(backend, 'command', side_effect=command), patch.object(backend, 'emit'), \
             patch.object(b, 'wallpapers', return_value=[]), patch.object(b, 'media', return_value={}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(backend.prayers, 'get', return_value={}), patch.object(backend, 'check_prayer_reminders'):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('volume', value=10, extra='sink-A')
                self.assertTrue(first_started.wait(2))
                incoming.send('volume', value=11, extra='sink-B')
                incoming.send('volume', value=20, extra='sink-B')
                incoming.send('volume', value=20, extra='sink-A')
                incoming.send('volume-step', value=5)
                incoming.send('volume', value=30, extra='sink-A')
                incoming.send('test-barrier')
                self.assertTrue(queued.wait(2))
                release_first.set()
                self.assertTrue(last_done.wait(3))
                self.assertEqual(actions, [
                    ('volume', 'sink-A', 10),
                    ('volume', 'sink-B', 20),
                    ('volume', 'sink-A', 20),
                    ('volume-step', 5),
                    ('volume', 'sink-A', 30),
                ])
            finally:
                release_first.set();incoming.messages.put(None);thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_brightness_absolute_writes_coalesce_but_relative_steps_keep_order(self):
        incoming = Input()
        backend = b.Backend()
        first_started = threading.Event(); release_first = threading.Event()
        queued = threading.Event(); last_done = threading.Event()
        actions = []
        def command(message):
            action = message['action']
            if action == 'brightness' and message.get('value') == 10:
                actions.append(('brightness', message.get('extra'), 10))
                first_started.set(); release_first.wait(3)
            elif action == 'brightness':
                actions.append(('brightness', message.get('extra'), message.get('value')))
                if message.get('value') == 50: last_done.set()
            elif action == 'brightness-step':
                actions.append(('brightness-step', message['value']))
            elif action == 'test-barrier':
                queued.set()
        with patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(backend, 'command', side_effect=command), patch.object(backend, 'emit'), \
             patch.object(b, 'wallpapers', return_value=[]), patch.object(b, 'media', return_value={}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(backend.prayers, 'get', return_value={}), patch.object(backend, 'check_prayer_reminders'):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('brightness', value=10, extra='DP-1')
                self.assertTrue(first_started.wait(2))
                incoming.send('brightness', value=25, extra='DP-1')
                incoming.send('brightness', value=20, extra='DP-1')
                incoming.send('brightness-step', value=1)
                incoming.send('brightness-step', value=2)
                incoming.send('brightness', value=40, extra='DP-1')
                incoming.send('brightness', value=50, extra='DP-1')
                incoming.send('test-barrier')
                self.assertTrue(queued.wait(2))
                release_first.set()
                self.assertTrue(last_done.wait(3))
                self.assertEqual(actions, [
                    ('brightness', 'DP-1', 10),
                    ('brightness', 'DP-1', 20),
                    ('brightness-step', 1),
                    ('brightness-step', 2),
                    ('brightness', 'DP-1', 50),
                ])
            finally:
                release_first.set();incoming.messages.put(None);thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_shutdown_settles_monitor_and_rolls_back_before_blocked_theme(self):
        incoming = Input()
        backend = b.Backend()
        applying = threading.Event(); release_apply = threading.Event()
        theme_started = threading.Event(); release_theme = threading.Event()
        rollback_done = threading.Event()
        operations = []
        monitor = {'name': 'DP-1', 'width': 1920, 'height': 1080, 'refreshRate': 144, 'x': 0, 'y': 0, 'scale': 1}
        def run(args, **kwargs):
            operations.append(args)
            if args == ['apply']:
                applying.set(); release_apply.wait(4); return 'ok'
            if args == ['restore']:
                rollback_done.set(); return 'ok'
            return ''
        def apply_theme(name, *args):
            theme_started.set(); release_theme.wait(4)
            return name, {'colors': []}, []
        with patch.object(b.ServiceEvents, 'start', return_value=None), patch.object(b.sys, 'stdin', incoming), patch.object(b.signal, 'signal'), \
             patch.object(b, 'run', side_effect=run), patch.object(b, 'js', return_value=[monitor]), \
             patch.object(backend, 'monitor_command', side_effect=lambda name, mode, position, scale: ['restore'] if '144' in mode else ['apply']), \
             patch.object(b.themes, 'apply', side_effect=apply_theme), patch.object(b, 'wallpapers', return_value=[]), \
             patch.object(b, 'current_wallpaper', return_value=''), patch.object(b, 'media', return_value={}), \
             patch.object(b, 'battery', return_value={}), patch.object(b, 'audio', return_value={}), \
             patch.object(b, 'displays', return_value={}), patch.object(b, 'wifi', return_value={}), \
             patch.object(b, 'save_settings'), patch.object(backend.prayers, 'get', return_value={}), \
             patch.object(backend, 'check_prayer_reminders'), patch.object(backend, 'emit'):
            thread = threading.Thread(target=backend.main)
            thread.start()
            try:
                incoming.send('monitor', value='DP-1', extra={'mode': '1920x1080@60Hz', 'scale': 1.25})
                self.assertTrue(applying.wait(2))
                incoming.send('setting', value='theme', extra='nord')
                self.assertTrue(theme_started.wait(2))
                incoming.messages.put(None)
                self.assertFalse(rollback_done.wait(.1), 'rollback ran before the monitor apply settled')
                release_apply.set()
                self.assertTrue(rollback_done.wait(2), 'shutdown did not roll back the completed monitor apply')
                self.assertFalse(release_theme.is_set(), 'shutdown waited for theme work before restoring the monitor')
            finally:
                release_apply.set();release_theme.set();thread.join(4)
                self.assertFalse(thread.is_alive())

    def test_monitor_reverts_before_reading_next_baseline(self):
        backend = b.Backend()
        monitor = {'name': 'DP-1', 'width': 1920, 'height': 1080, 'refreshRate': 144, 'x': 0, 'y': 0, 'scale': 1}
        operations = []
        def run(args, **kwargs):
            operations.append(('run', args))
            return 'ok'
        def js(args):
            operations.append(('read', args))
            return [monitor]
        backend.monitor_pending = (b.time.monotonic() + 10, ['restore-layout'])
        with patch.object(b, 'run', side_effect=run), patch.object(b, 'js', side_effect=js), patch.object(backend, 'emit'):
            backend.command({'action': 'monitor', 'value': 'DP-1', 'extra': {'mode': '1920x1080@60Hz', 'scale': 1.25}})
        self.assertEqual(operations[0][0], 'run')
        self.assertEqual(operations[0][1], ['restore-layout'])
        self.assertEqual(operations[1][0], 'read')

    def test_page_invalidation_is_scoped_to_detail_services(self):
        backend = b.Backend()
        self.assertEqual(backend.affected_services({'action': 'page', 'value': 'calendar'}), set())
        self.assertEqual(backend.affected_services({'action': 'page', 'value': 'audio'}), {'audio'})
        self.assertEqual(backend.affected_services({'action': 'setting', 'value': 'fontFamily'}), set())


if __name__ == '__main__':
    unittest.main()
