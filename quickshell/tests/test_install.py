import importlib.util, json, pathlib, tempfile, unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('installer',pathlib.Path(__file__).parents[1]/'scripts/install.py')
i=importlib.util.module_from_spec(spec);spec.loader.exec_module(i)

class InstallationTests(unittest.TestCase):
    def test_installation_does_not_add_shortcuts_outside_user_bindings(self):
        for lua in (True,False):
            with self.subTest(lua=lua),tempfile.TemporaryDirectory() as d:
                config=pathlib.Path(d)/'config';hypr=config/'hypr';hypr.mkdir(parents=True)
                if lua:
                    (hypr/'modules').mkdir()
                    (hypr/'hyprland.lua').write_text('')
                    (hypr/'modules/autostart.lua').write_text('')
                else:(hypr/'hyprland.conf').write_text('')
                with patch.object(i,'CONFIG',config),patch.object(i,'apply_install',return_value='test-backup') as install,patch.object(i.argparse._sys,'argv',['install.py','--apply']):
                    i.main()
                module=hypr/('modules/island.lua' if lua else 'island.conf')
                text=install.call_args.args[0][module]
                self.assertNotIn('hl.bind(',text)
                self.assertNotIn('bind =',text)
                self.assertIn('start.sh',text)

    def test_installation_records_restorable_backups(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);config=root/'config';state=root/'state';config.mkdir()
            existing=config/'existing.lua';existing.write_text('original\n');new=config/'new.lua'
            with patch.object(i,'CONFIG',config),patch.object(i,'STATE',state),patch.object(i,'MANIFEST',state/'installation.json'):
                i.apply_install({existing:'updated\n',new:'new\n'})
                manifest=json.loads(i.MANIFEST.read_text())
                self.assertEqual(existing.read_text(),'updated\n');self.assertTrue((config/'quickshell/island').is_symlink())
                i.restore_files(manifest)
                self.assertEqual(existing.read_text(),'original\n');self.assertFalse(new.exists())

    def test_failed_installation_restores_all_files(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);config=root/'config';state=root/'state';config.mkdir()
            existing=config/'existing.lua';existing.write_text('original\n');new=config/'new.lua'
            real_write=i.write_atomic
            def fail_second(path,text):
                if path==new:raise OSError('simulated disk error')
                real_write(path,text)
            with patch.object(i,'CONFIG',config),patch.object(i,'STATE',state),patch.object(i,'MANIFEST',state/'installation.json'),patch.object(i,'write_atomic',side_effect=fail_second):
                with self.assertRaises(OSError):i.apply_install({existing:'updated\n',new:'new\n'})
                self.assertEqual(existing.read_text(),'original\n');self.assertFalse(new.exists());self.assertFalse(i.MANIFEST.exists())

if __name__=='__main__':unittest.main()
