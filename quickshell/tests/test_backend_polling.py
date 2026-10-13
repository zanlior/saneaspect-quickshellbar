import contextlib
import importlib.util
import json
import pathlib
import queue
import threading
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('backend_polling', pathlib.Path(__file__).parents[1] / 'scripts/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class FakeEvents:
    def __init__(self, connected=None):
        self.availability = dict(connected or {})
        self.pending = set()
        self.lock = threading.Lock()
        self.started = False
        self.closed = False

    def start(self):
        self.started = True

    def close(self):
        self.closed = True

    def connected(self, service):
        return self.availability.get(service, False)

    def drain(self):
        with self.lock:
            result, self.pending = self.pending, set()
            return result

    def push(self, service):
        with self.lock:
            self.pending.add(service)


class InputLines:
    def __init__(self):
        self.lines = queue.Queue()

    def __iter__(self):
        while True:
            line = self.lines.get()
            if line is None:
                return
            yield line

    def send(self, message):
        self.lines.put(json.dumps(message))

    def close(self):
        self.lines.put(None)


@contextlib.contextmanager
def running_backend(backend, events, poll_functions):
    messages = InputLines()
    emitted = []
    backend.events = events
    stack = contextlib.ExitStack()
    stack.enter_context(patch.object(b.sys, 'stdin', messages))
    stack.enter_context(patch.object(b.signal, 'signal'))
    stack.enter_context(patch.object(b.shutil, 'which', return_value=None))
    stack.enter_context(patch.object(b, 'wallpapers', return_value=[]))
    stack.enter_context(patch.object(backend.prayers, 'get', return_value={}))
    stack.enter_context(patch.object(backend, 'check_prayer_reminders'))
    stack.enter_context(patch.object(backend.azan, 'stop'))
    stack.enter_context(patch.object(backend, 'emit', side_effect=emitted.append))
    defaults = {name:(lambda: {}) for name in ('media','battery','audio','displays','wifi','desktop','bluetooth','clipboard_history')}
    defaults.update(poll_functions)
    for name, fn in defaults.items():
        stack.enter_context(patch.object(b, name, side_effect=fn))
    worker = threading.Thread(target=backend.main, daemon=True)
    worker.start()
    try:
        yield messages, emitted
    finally:
        messages.close()
        worker.join(4)
        stack.close()
        if worker.is_alive():
            raise AssertionError('backend main loop did not stop')


def wait_for(predicate, timeout=2):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(.01)
    return predicate()


class BackendPollingTests(unittest.TestCase):
    def test_workspace_polling_follows_theme(self):
        self.assertNotIn('desktop', b.Backend.poll_intervals(workspace_theme=False))
        self.assertIn('desktop', b.Backend.poll_intervals(workspace_theme=True))

    def test_connected_profiles_slow_only_audio_and_desktop_polling(self):
        connected = b.Backend.poll_intervals(audio_connected=True, desktop_connected=True, workspace_theme=True, page='')
        fallback = b.Backend.poll_intervals(audio_connected=False, desktop_connected=False, workspace_theme=True, page='')
        self.assertEqual(connected['audio'], 30)
        self.assertEqual(connected['desktop'], 30)
        self.assertEqual(fallback['audio'], 1)
        self.assertEqual(fallback['desktop'], .5)
        for key, interval in [('media', 1), ('wifi', 5), ('display', 2)]:
            self.assertEqual(connected[key], interval)
            self.assertEqual(fallback[key], interval)

    def test_first_poll_is_due_even_when_monotonic_uptime_is_below_interval(self):
        self.assertTrue(b.Backend.poll_due('audio', {}, 10, 30, set(), .2))
        self.assertFalse(b.Backend.poll_due('audio', {'audio':1}, 10, 30, set(), .2))

    def test_page_scope_keeps_calendar_and_launcher_out_of_service_refreshes(self):
        backend = b.Backend()
        for page in ('', 'calendar', 'launcher'):
            self.assertEqual(backend.affected_services({'action': 'page', 'value': page}), set())

    def test_connected_audio_refreshes_on_event_and_unchanged_data_is_suppressed(self):
        backend = b.Backend()
        backend.settings['barTheme'] = 'workspace'
        events = FakeEvents({'audio': True, 'desktop': True})
        audio_calls = []
        desktop_calls = []

        def audio():
            audio_calls.append(time.monotonic())
            return {'outputs': [], 'inputs': [], 'apps': []}

        def desktop():
            desktop_calls.append(time.monotonic())
            return {'active': 1, 'workspaces': [1]}

        with running_backend(backend, events, {'audio': audio, 'desktop': desktop}) as (messages, emitted):
            self.assertTrue(wait_for(lambda: len(audio_calls) == 1 and len(desktop_calls) == 1))
            time.sleep(1.15)
            self.assertEqual(len(audio_calls), 1, 'connected audio should not use the fallback 1s poll')
            self.assertEqual(len(desktop_calls), 1, 'connected workspaces should not use the fallback 0.5s poll')
            events.push('audio')
            self.assertTrue(wait_for(lambda: len(audio_calls) == 2, .7), 'audio invalidation was not prompt')
            events.push('desktop')
            self.assertTrue(wait_for(lambda: len(desktop_calls) == 2, .7), 'workspace invalidation was not prompt')
            self.assertEqual(len([payload for payload in emitted if 'audio' in payload]), 1)
            self.assertEqual(len([payload for payload in emitted if 'desktop' in payload]), 1)
            messages.send({'action':'page','value':'calendar'})
            self.assertTrue(wait_for(lambda: backend.page == 'calendar'))
            audio_before, desktop_before = len(audio_calls), len(desktop_calls)
            time.sleep(.15)
            self.assertEqual(len(audio_calls), audio_before)
            self.assertEqual(len(desktop_calls), desktop_before)
            self.assertTrue(events.started)

    def test_disconnected_audio_keeps_one_second_fallback_freshness(self):
        backend = b.Backend()
        backend.settings['barTheme'] = 'workspace'
        events = FakeEvents({'audio': False, 'desktop': False})
        calls = []
        desktop_calls = []

        def audio():
            calls.append(time.monotonic())
            return {'outputs': []}

        def desktop():
            desktop_calls.append(time.monotonic())
            return {'active': 1, 'workspaces': [1]}

        with running_backend(backend, events, {'audio': audio, 'desktop': desktop}):
            self.assertTrue(wait_for(lambda: len(calls) >= 2 and len(desktop_calls) >= 3, 1.6))
            self.assertGreaterEqual(calls[1] - calls[0], .8)
            self.assertGreaterEqual(desktop_calls[1] - desktop_calls[0], .4)

    def test_display_cache_uses_brightness_sampling_and_event_forces_full_metadata(self):
        backend = b.Backend()
        events = FakeEvents({'display': True})
        calls = []
        lock = threading.Lock()

        def displays(monitors=None):
            with lock:
                calls.append(monitors is None)
                full_count = sum(calls)
            if monitors is None:
                return {'monitors': [{'name': 'DP-1', 'metadataRevision': full_count}], 'brightness': 50}
            return {'monitors': monitors, 'brightness': 51}

        with running_backend(backend, events, {'displays': displays}):
            self.assertTrue(wait_for(lambda: calls.count(True) == 1))
            self.assertTrue(wait_for(lambda: calls.count(False) >= 1, 2.8), '2s brightness poll did not reuse monitor metadata')
            with lock:
                before_event = len(calls)
            events.push('display')
            self.assertTrue(wait_for(lambda: calls.count(True) == 2, .8), 'display invalidation did not force full metadata')
            self.assertGreater(len(calls), before_event)

    def test_display_event_during_inflight_full_poll_is_followed_up(self):
        backend = b.Backend()
        events = FakeEvents({'display': True})
        started = threading.Event()
        release = threading.Event()
        calls = []

        def displays(monitors=None):
            calls.append(monitors)
            revision = len(calls)
            if revision == 1:
                started.set()
                release.wait(2)
            return {'monitors': [{'name': 'DP-1', 'metadataRevision': revision}], 'brightness': revision}

        try:
            with running_backend(backend, events, {'displays': displays}):
                self.assertTrue(started.wait(2))
                events.push('display')
                release.set()
                self.assertTrue(wait_for(lambda: len(calls) >= 2, 1.5), 'in-flight invalidation was lost')
                self.assertTrue(wait_for(lambda: backend.state.get('display', {}).get('monitors', [{}])[0].get('metadataRevision') == 2))
                self.assertIsNone(calls[0])
                self.assertIsNone(calls[1])
        finally:
            release.set()


    def test_monitor_timeout_recovers_after_failed_rollbacks_and_new_apply(self):
        backend = b.Backend()
        events = FakeEvents()
        backend.monitor_pending = (time.monotonic() - 1, ['rollback'])
        automatic_attempts = []
        third_started = threading.Event()
        release_third = threading.Event()
        applied = threading.Event()

        def outcome(message, lane, snapshot):
            if message['action'] == 'monitor-revert':
                self.assertTrue(message.get('_automatic_revert'))
                automatic_attempts.append(message['action'])
                if len(automatic_attempts) == 3:
                    third_started.set()
                    release_third.wait(2)
                    return {'lane': lane, 'fields': {'monitor_pending': snapshot['monitor_pending']},
                            'events': [], 'error': 'rollback failed'}
                if len(automatic_attempts) < 3:
                    return {'lane': lane, 'fields': {'monitor_pending': snapshot['monitor_pending']},
                            'events': [], 'error': 'rollback failed'}
                return {'lane': lane, 'fields': {'monitor_pending': None}, 'events': [], 'error': None}
            if message['action'] == 'monitor':
                applied.set()
                return {'lane': lane, 'fields': {'monitor_pending': (time.monotonic()+.2, ['new-layout'])},
                        'events': [], 'error': None}
            return {'lane': lane, 'fields': {}, 'events': [], 'error': None}

        with patch.object(backend, 'worker_outcome', side_effect=outcome):
            with running_backend(backend, events, {}) as (messages, _):
                self.assertTrue(third_started.wait(3), 'automatic rollback did not reach its retry limit')
                messages.send({'action':'monitor','value':'DP-1','extra':{'mode':'1920x1080@60Hz','scale':1}})
                time.sleep(.12)  # Let the main loop queue this command behind the active rollback.
                release_third.set()
                self.assertTrue(applied.wait(2), 'queued monitor command remained blocked after retry limit')
                self.assertTrue(wait_for(lambda: len(automatic_attempts) == 4, 1.5),
                                'a new monitor timeout did not recover after rollback failures')
                self.assertTrue(wait_for(lambda: backend.monitor_pending is None))
        release_third.set()

    def test_invalid_monitor_apply_does_not_consume_existing_rollback_budget(self):
        backend = b.Backend()
        events = FakeEvents()
        backend.monitor_pending = (time.monotonic() - 1, ['old-layout'])
        rollback_attempts = []
        invalid_applies = []
        first_rollback = threading.Event()

        def outcome(message, lane, snapshot):
            if message['action'] == 'monitor-revert':
                rollback_attempts.append(message.get('_automatic_revert', False))
                if len(rollback_attempts) == 1:
                    first_rollback.set()
                    return {'lane': lane, 'fields': {'monitor_pending': snapshot['monitor_pending']},
                            'events': [], 'error': 'temporary rollback failure'}
                return {'lane': lane, 'fields': {'monitor_pending': None}, 'events': [], 'error': None}
            if message['action'] == 'monitor':
                invalid_applies.append(message)
                return {'lane': lane, 'fields': {'monitor_pending': snapshot['monitor_pending']},
                        'events': [], 'error': 'invalid monitor mode'}
            return {'lane': lane, 'fields': {}, 'events': [], 'error': None}

        with patch.object(backend, 'worker_outcome', side_effect=outcome):
            with running_backend(backend, events, {}) as (messages, _):
                self.assertTrue(first_rollback.wait(2))
                for _ in range(3):
                    messages.send({'action':'monitor','value':'DP-1','extra':{'mode':'invalid','scale':1}})
                self.assertTrue(wait_for(lambda: len(invalid_applies) == 3, .8))
                self.assertTrue(wait_for(lambda: len(rollback_attempts) == 2, 1.5),
                                'validation failures changed the old rollback timeout or retry budget')
                self.assertTrue(wait_for(lambda: backend.monitor_pending is None))

    def test_monitor_copy_skips_hyprctl_and_updates_brightness_without_mutating_cache(self):
        monitor = {'name': 'eDP-1', 'focused': True, 'width': 1920, 'brightness': 5}
        with patch.object(b, 'js') as js, patch.object(b, 'run', return_value='eDP-1,backlight,100,42%,100%'), \
             patch.object(b.shutil, 'which', return_value=None), patch.dict(b.DDC_MAP, {}, clear=True), \
             patch.object(b, 'DDC_DISCOVERED', time.monotonic()):
            result = b.displays([monitor])
        js.assert_not_called()
        self.assertEqual(result['monitors'][0]['brightness'], 42)
        self.assertEqual(result['monitors'][0]['brightnessKind'], 'backlight')
        self.assertEqual(monitor['brightness'], 5)

    def test_display_metadata_refresh_conditions_include_disconnect_dirty_and_reconcile(self):
        due = b.Backend.display_metadata_due
        self.assertFalse(due(True, False, 100, True, 129.9))
        self.assertTrue(due(True, True, 129, True, 129.1))
        self.assertTrue(due(False, False, 129, True, 129.1))
        self.assertTrue(due(True, False, 100, True, 130))
        self.assertTrue(due(True, False, 129, False, 129.1))


if __name__ == '__main__':
    unittest.main()
