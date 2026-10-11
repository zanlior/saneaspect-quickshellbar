"""Standalone mock-workload comparison for backend service query counts.

Run with: python3 tests/benchmark_polling.py

The baseline is a fixed reference schedule copied from the reviewed
pre-optimization backend: audio every 1s, desktop every 0.5s, display every
2s, Wi-Fi every 5s, and media every 1s. The optimized run uses connected
event-stream intervals and monitor metadata caching. This script does not
start persistent event watchers or contact desktop services.
"""
import collections
import importlib.util
import json
import pathlib
import sys
from unittest.mock import patch

root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'scripts'))
spec = importlib.util.spec_from_file_location('backend_workload_eval', root / 'scripts/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


def run_count(schedule, cache_monitors):
    counts = collections.Counter()
    monitor_cache = None

    def fake_run(args, **kwargs):
        if args[0] == 'pactl':
            counts['audio'] += 1
            if args[1:4] == ['-f', 'json', 'list']:
                return '[]'
            return 'default'
        if args[0] == 'hyprctl':
            if args[2:] == ['monitors']:
                counts['display'] += 1
                return json.dumps([{'name': 'eDP-1', 'focused': True, 'width': 1920, 'height': 1080}])
            counts['desktop'] += 1
            if args[2:] == ['activeworkspace']:
                return '{"id":1}'
            return '[{"id":1}]'
        if args[0] == 'brightnessctl':
            counts['display'] += 1
            return 'eDP-1,backlight,100,42%,100%'
        if args[0] == 'nmcli':
            counts['wifi'] += 1
            return 'enabled' if args[1:2] == ['radio'] else ''
        if args[0] == 'playerctl':
            counts['media'] += 1
            return ''
        raise AssertionError(f'unexpected mocked command: {args}')

    b.DDC_CACHE.clear()
    b.DDC_MAP.clear()
    b.DDC_DISCOVERED = 0
    media, audio, displays, wifi, desktop = b.media, b.audio, b.displays, b.wifi, b.desktop
    last = {}
    with patch.object(b, 'run', side_effect=fake_run), \
         patch.object(b.shutil, 'which', return_value=None), \
         patch.object(b.time, 'monotonic', return_value=100):
        for step in range(60):
            now = step * .5
            for name, (fn, interval) in schedule.items():
                if name not in last or now - last[name] >= interval:
                    if name == 'display' and cache_monitors and monitor_cache is not None:
                        result = displays(monitor_cache)
                    else:
                        result = fn()
                    if name == 'display' and cache_monitors:
                        monitor_cache = result['monitors']
                    last[name] = now
    return counts


def main():
    # This fixed baseline models the original polling cadences before event
    # subscriptions and monitor metadata caching were introduced.
    baseline = run_count({
        'audio': (b.audio, 1), 'desktop': (b.desktop, .5), 'display': (b.displays, 2),
        'wifi': (b.wifi, 5), 'media': (b.media, 1),
    }, cache_monitors=False)
    connected_intervals = b.Backend.poll_intervals(audio_connected=True, desktop_connected=True, notch=True, page='')
    optimized = run_count({
        'audio': (b.audio, connected_intervals['audio']),
        'desktop': (b.desktop, connected_intervals['desktop']),
        'display': (b.displays, connected_intervals['display']),
        'wifi': (b.wifi, connected_intervals['wifi']),
        'media': (b.media, connected_intervals['media']),
    }, cache_monitors=True)
    baseline_total = sum(baseline.values())
    optimized_total = sum(optimized.values())
    reduction = (baseline_total - optimized_total) / baseline_total * 100
    print(f'baseline: {dict(baseline)} total={baseline_total}')
    print(f'optimized: {dict(optimized)} total={optimized_total}')
    print(f'mock query reduction: {reduction:.1f}%')
    assert baseline_total == 348
    assert optimized_total == 71


if __name__ == '__main__':
    main()
