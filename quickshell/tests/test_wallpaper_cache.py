import importlib.util
import pathlib
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location('backend_wallpaper_cache', ROOT / 'scripts/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class WallpaperCacheTests(unittest.TestCase):
    def backend(self):
        backend = b.Backend()
        backend.settings.update(theme='nord', wallpaperFolder='/wallpapers')
        return backend

    def test_unrelated_settings_do_not_enumerate_or_emit_wallpapers(self):
        backend = self.backend()
        with patch.object(b, 'wallpapers') as scan, patch.object(b, 'save_settings'), patch.object(backend, 'emit') as emit:
            backend.command({'action': 'setting', 'value': 'clock24', 'extra': False})
        scan.assert_not_called()
        self.assertNotIn('wallpapers', emit.call_args.args[0])

    def test_wallpaper_folder_change_refreshes_and_emits_changed_snapshot(self):
        backend = self.backend()
        backend.wallpaper_key = backend.wallpaper_settings_key(backend.settings)
        backend.wallpaper_snapshot = ('/wallpapers/a.jpg',)
        with patch.object(b, 'wallpapers', return_value=['/new/b.jpg']) as scan, patch.object(b, 'save_settings'), patch.object(backend, 'emit') as emit:
            backend.command({'action': 'setting', 'value': 'wallpaperFolder', 'extra': '/new'})
        scan.assert_called_once()
        payload = emit.call_args.args[0]
        self.assertEqual(payload['wallpapers'], ['/new/b.jpg'])
        self.assertEqual(backend.wallpaper_snapshot, ('/new/b.jpg',))

    def test_reset_refreshes_when_effective_wallpaper_key_changes(self):
        backend = self.backend()
        old_key = backend.wallpaper_settings_key(backend.settings)
        with patch.object(b, 'wallpapers', return_value=['/defaults/default.jpg']) as scan, patch.object(b, 'save_settings'), patch.object(backend, 'emit') as emit:
            backend.command({'action': 'reset'})
        self.assertNotEqual(old_key, backend.wallpaper_settings_key(backend.settings))
        scan.assert_called_once()
        self.assertEqual(emit.call_args.args[0]['wallpapers'], ['/defaults/default.jpg'])

    def test_opening_wallpaper_page_refreshes_external_files(self):
        backend = self.backend()
        backend.wallpaper_key = backend.wallpaper_settings_key(backend.settings)
        backend.wallpaper_snapshot = ('/wallpapers/old.jpg',)
        with patch.object(b, 'wallpapers', return_value=['/wallpapers/new.jpg']) as scan, patch.object(b, 'current_wallpaper', return_value=''), patch.object(backend, 'emit') as emit:
            backend.command({'action': 'page', 'value': 'wallpapers'})
        scan.assert_called_once()
        self.assertEqual(emit.call_args_list[0].args[0], {'wallpapers': ['/wallpapers/new.jpg']})
        self.assertEqual(backend.wallpaper_snapshot, ('/wallpapers/new.jpg',))

    def test_equal_refresh_does_not_emit_duplicate_wallpaper_list(self):
        backend = self.backend()
        backend.wallpaper_key = backend.wallpaper_settings_key(backend.settings)
        backend.wallpaper_snapshot = ('/wallpapers/a.jpg',)
        with patch.object(b, 'wallpapers', return_value=['/wallpapers/a.jpg']), patch.object(b, 'current_wallpaper', return_value=''), patch.object(backend, 'emit') as emit:
            backend.command({'action': 'page', 'value': 'wallpapers'})
        self.assertEqual(emit.call_args_list, [unittest.mock.call({'wallpaperSelected': ''})])


if __name__ == '__main__':
    unittest.main()
