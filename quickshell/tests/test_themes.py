import json,os,pathlib,sys,tempfile,unittest
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'scripts'))
import themes

class ThemeTests(unittest.TestCase):
    def test_all_themes_have_complete_gtk_assets_and_terminal_palette(self):
        import re
        for name,entry in themes.REGISTRY.items():
            for version in ('3.0','4.0'):
                folder=themes.ROOT/'themes/gtk'/entry['gtk']/('gtk-'+version)
                css=(folder/'gtk.css').read_text()
                self.assertGreater(len(css),10000)
                for ref in re.findall(r'url\(["\x27]?([^"\x27)]+)',css):
                    self.assertTrue((folder/ref).is_file(),str(folder/ref))
            kitty=themes.kitty_colors(name,entry)
            self.assertIn('background ',kitty)
            for i in range(16):self.assertRegex(kitty,rf'(?m)^color{i}\s+#[0-9a-fA-F]{{6}}')

    def test_apply_preserves_fonts_custom_css_and_replaces_links_without_editing_original(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_DATA_HOME':temp+'/share'}):
            config=pathlib.Path(temp)/'config';(config/'gtk-4.0').mkdir(parents=True)
            original=pathlib.Path(temp)/'old.css';original.write_text('old-theme')
            (config/'gtk-4.0/gtk-dark.css').symlink_to(original)
            (config/'gtk-4.0/gtk.css').write_text('/* custom */\nbutton { padding: 9px; }')
            (config/'gtk-4.0/settings.ini').write_text('[Settings]\ngtk-font-name=My Font 12\n')
            for name in ('ariadne','e-ink'):
                themes.apply(name,config,reload=False)
            self.assertEqual(original.read_text(),'old-theme')
            css=(config/'gtk-4.0/gtk.css').read_text()
            self.assertEqual(css.count('Island theme begin'),1)
            self.assertIn('padding: 9px',css)
            self.assertIn('My Font 12',(config/'gtk-4.0/settings.ini').read_text())
            self.assertIn('Island-e-ink',css)

    def test_failed_write_restores_original_files(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_DATA_HOME':temp+'/share'}):
            config=pathlib.Path(temp)/'config';(config/'kitty').mkdir(parents=True)
            original=config/'kitty/colors.conf';original.write_text('original')
            real=themes.atomic
            def failing(path,data):
                if path.name=='island-colors.lua':raise OSError('disk full')
                real(path,data)
            with patch.object(themes,'atomic',side_effect=failing),self.assertRaises(OSError):themes.apply('ariadne',config,reload=False)
            self.assertEqual(original.read_text(),'original')
            self.assertFalse((config/'hypr/modules/island-colors.lua').exists())

    def test_unknown_name_never_writes(self):
        with patch.object(themes,'atomic') as write,self.assertRaises(ValueError):themes.apply('../bad',pathlib.Path('/tmp/unused'))
        write.assert_not_called()

    def test_matugen_palette_uses_dark_values(self):
        data={'colors':{n:{'dark':'#123456'} for n in ('background','surface_container_low','surface_container_high','on_background','on_surface_variant','primary','error','secondary','tertiary','primary_fixed','secondary_fixed')}}
        with tempfile.NamedTemporaryFile() as image,patch.object(themes,'command',return_value=json.dumps(data)):
            self.assertEqual(themes.material_palette(image.name)['colors'],['#123456']*6)
