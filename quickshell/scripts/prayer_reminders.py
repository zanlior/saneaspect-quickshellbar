"""Prayer reminders, a persistent delivery journal, and local azan playback."""
import fcntl
import hashlib
import json
import pathlib
import random
import shutil
import subprocess
import tempfile
import threading
import time

from prayer_times import PRAYERS, configuration


def mp3_files(source):
    """Read a collection at playback time so adding or removing MP3s takes effect immediately."""
    if not source.strip():
        return []
    path = pathlib.Path(source).expanduser()
    try:
        candidates = path.iterdir() if path.is_dir() else [path]
        return sorted({str(p.resolve()) for p in candidates if p.is_file() and p.suffix.lower() == '.mp3'})
    except OSError:
        return []


def collection_source(settings, prayer):
    if prayer == 'Fajr':
        return settings.get('prayerFajrAzanFolder', '')
    return settings.get('prayerAzanFolder', '').strip() or settings.get('prayerAzanFile', '')


class PrayerReminders:
    # A short grace period tolerates scheduler jitter without replaying missed prayers after sleep.
    GRACE = 60

    def __init__(self, state_file):
        self.state_file = pathlib.Path(state_file)

    def due(self, timetable, settings, now=None):
        now = time.time() if now is None else now
        if timetable.get('configuration') != configuration(settings):
            return []
        offsets = []
        if settings.get('prayerReminders', True):
            offsets.extend((15, 5))
        if settings.get('prayerReminders', True) or settings.get('prayerAzan', True):
            offsets.append(0)
        candidates = []
        for day in timetable.get('days', []):
            for prayer in day.get('prayers', []):
                if prayer['name'] not in PRAYERS:
                    continue
                for minutes in offsets:
                    target = prayer['epoch'] - minutes * 60
                    if 0 <= now - target <= self.GRACE:
                        identity = [settings['prayerCity'].strip().casefold(), settings['prayerCountry'].strip().casefold(),
                                    day['date'], prayer['name'], minutes]
                        key = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
                        candidates.append((key, dict(prayer, minutes=minutes, target=target)))
        if not candidates:
            return []
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        # The lock also prevents two briefly overlapping shell instances from delivering twice.
        with self.state_file.with_suffix('.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                saved = json.loads(self.state_file.read_text())
                if not isinstance(saved, dict):
                    saved = {}
            except (OSError, ValueError):
                saved = {}
            saved = {k: v for k, v in saved.items() if isinstance(v, (int, float)) and v >= now - 14 * 86400}
            due = []
            for key, event in candidates:
                if key not in saved:
                    saved[key] = event['target']
                    due.append(event)
            if due:
                temporary = self.state_file.with_suffix('.tmp')
                temporary.write_text(json.dumps(saved))
                temporary.replace(self.state_file)
            return due


class AzanPlayer:
    def __init__(self):
        self.process = None
        self.log = None
        self.error = ''
        self.current_file = ''
        self.lock = threading.RLock()

    def play_prayer(self, prayer, settings, required=False):
        source = collection_source(settings, prayer)
        if not source.strip() and not required:
            return None
        files = mp3_files(source)
        if not files:
            if not required:
                return None
            group = 'Fajr' if prayer == 'Fajr' else 'other prayers'
            raise ValueError(f'Choose a folder containing MP3 recordings for {group} in Prayer Times settings.')
        chosen = random.choice(files)
        self.play(chosen, settings['prayerAzanVolume'])
        return chosen

    def play(self, filename, volume):
        with self.lock:
            path = pathlib.Path(filename).expanduser()
            if not filename.strip() or not path.is_file():
                raise ValueError('Choose an existing azan audio file in Prayer Times settings.')
            player = shutil.which('mpv')
            if not player:
                raise RuntimeError('Install mpv to play the azan recording.')
            self.stop()
            self.error = ''
            self.current_file = str(path.resolve())
            self.log = tempfile.TemporaryFile()
            try:
                self.process = subprocess.Popen(
                    [player, '--no-config', '--video=no', '--audio-display=no', '--force-window=no',
                     '--terminal=no', '--volume=' + str(max(0, min(100, int(volume)))), '--', str(path.resolve())],
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=self.log)
            except Exception:
                self.log.close(); self.log = None
                raise

    def stop(self):
        with self.lock:
            if self.process and self.process.poll() is None:
                self.process.terminate()
                try:
                    self.process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    self.process.kill(); self.process.wait(timeout=2)
            self.process = None
            if self.log:
                self.log.close(); self.log = None

    def status(self, settings):
        with self.lock:
            if self.process and self.process.poll() is not None:
                if self.process.returncode:
                    self.error = 'Azan playback failed. Check the audio file and sound output.'
                self.process = None
                if self.log:
                    self.log.close(); self.log = None
            # Accept a single path for callers using the original player interface.
            if isinstance(settings, str):
                regular = mp3_files(settings); fajr = []
            else:
                regular = mp3_files(collection_source(settings, 'Dhuhr'))
                fajr = mp3_files(collection_source(settings, 'Fajr'))
            return dict(playing=self.process is not None, configured=bool(regular),
                        regularCount=len(regular), fajrCount=len(fajr),
                        currentFile=self.current_file, error=self.error)
