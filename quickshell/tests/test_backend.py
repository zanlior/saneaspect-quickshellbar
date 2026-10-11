import importlib.util, pathlib, tempfile, unittest, threading, queue, json
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('backend',pathlib.Path(__file__).parents[1]/'scripts/backend.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
class BackendTests(unittest.TestCase):
    def test_clipboard_decode_preserves_binary_data_and_checks_return_code(self):
        from types import SimpleNamespace
        backend=b.Backend()
        payload=b'\x89PNG\r\n\x00image'
        with patch.object(b.subprocess,'run',side_effect=[SimpleNamespace(returncode=0,stdout=payload),SimpleNamespace(returncode=0)] ) as run,patch.object(backend,'emit') as emit:
            backend.command({'action':'clipboard-copy','value':'42'})
            self.assertEqual(run.call_args_list[0].kwargs['input'],b'42\n')
            self.assertEqual(run.call_args_list[1].kwargs['input'],payload)
            emit.assert_called_once_with({'clipboardCopied':'42'})
        with self.assertRaises(ValueError):backend.command({'action':'clipboard-copy','value':'42; whoami'})
    def test_theme_failure_keeps_saved_selection_and_reports_original_state(self):
        backend=b.Backend();original=backend.settings['theme']
        with patch.object(b.themes,'apply',side_effect=RuntimeError('failed')),patch.object(backend,'emit') as emit,patch.object(b,'save_settings') as save:
            with self.assertRaises(RuntimeError):backend.command({'action':'setting','value':'theme','extra':'nord'})
            self.assertEqual(backend.settings['theme'],original)
            save.assert_not_called();self.assertEqual(emit.call_args.args[0]['settings']['theme'],original)
    def test_nmcli_escaped_ssid(self):
        self.assertEqual(b.split_nm(r'*:Coffee\:Shop:77:WPA2:wlan0'),['*','Coffee:Shop','77','WPA2','wlan0'])
        self.assertEqual(b.split_nm(r'*:path\\:77:WPA2:wlan0'),['*','path\\','77','WPA2','wlan0'])
    def test_ddc_mapping_ignores_displays_without_connectors(self):
        raw='Display 1\n I2C bus: /dev/i2c-7\n DRM connector: card0-DP-1\nInvalid display\n I2C bus: /dev/i2c-8\nDisplay 2\n I2C bus: /dev/i2c-9\n DRM connector: card1-HDMI-A-1'
        self.assertEqual(b.parse_ddc_displays(raw),{'DP-1':7,'HDMI-A-1':9})
    def test_ddcutil_3_asus_connector_label(self):
        raw='Display 1\n I2C bus: /dev/i2c-3\n DRM_connector: card1-DP-1\n Model: VG248\n Serial number: MALMQS233043\n'
        self.assertEqual(b.parse_ddc_displays(raw),{'DP-1':3})
    def test_ddc_bus_change_refreshes_cached_brightness(self):
        monitor={'name':'DP-1','focused':True}
        with patch.dict(b.DDC_MAP,{'DP-1':3},clear=True),patch.dict(b.DDC_CACHE,{'DP-1':{'bus':7,'value':40,'maximum':100,'time':b.time.monotonic()}},clear=True),patch.object(b,'DDC_DISCOVERED',b.time.monotonic()),patch.object(b,'js',return_value=[monitor]),patch.object(b,'run',side_effect=['','VCP 10 C 65 100']) as run:
            self.assertEqual(b.displays()['brightness'],65)
            self.assertEqual(b.DDC_CACHE['DP-1']['bus'],3)
            self.assertIn('3',run.call_args.args[0])
    def test_slow_brightness_writes_keep_latest_value_without_blocking_settings(self):
        messages=queue.Queue();started=threading.Event();release=threading.Event();setting=threading.Event();finished=threading.Event();values=[]
        class Input:
            def __iter__(self):
                while True:
                    line=messages.get()
                    if line is None:return
                    yield line
        backend=b.Backend()
        def command(message):
            if message['action']=='brightness':
                values.append(message['value'])
                if message['value']==10:started.set();release.wait(3)
                if message['value']==30:finished.set()
            elif message['action']=='setting':setting.set()
        with patch.object(b.sys,'stdin',Input()),patch.object(b.signal,'signal'),patch.object(b.ServiceEvents,'start'),patch.object(backend.prayers,'get',return_value={}),patch.object(backend,'command',side_effect=command),patch.object(backend,'emit'),patch.object(b,'wallpapers',return_value=[]),patch.multiple(b,media=lambda:{},battery=lambda:{},audio=lambda:{},displays=lambda:{},wifi=lambda:{},current_wallpaper=lambda:""):
            worker=threading.Thread(target=backend.main);worker.start()
            try:
                messages.put(json.dumps({'action':'brightness','value':10,'extra':'DP-1'}))
                self.assertTrue(started.wait(2))
                for message in [{'action':'setting','value':'fontFamily','extra':'Rubik'},{'action':'brightness','value':20,'extra':'DP-1'},{'action':'brightness','value':30,'extra':'DP-1'}]:messages.put(json.dumps(message))
                self.assertTrue(setting.wait(2),'Brightness blocked the settings command')
                release.set();self.assertTrue(finished.wait(2))
                self.assertEqual(values,[10,30])
            finally:
                release.set();messages.put(None);worker.join(3)
    def test_brightness_uses_monitor_maximum(self):
        with patch.dict(b.DDC_CACHE,{'DP-1':{'bus':7,'value':40,'maximum':255}},clear=True),patch.object(b,'run') as run:
            b.Backend().command({'action':'brightness','value':50,'extra':'DP-1'})
            run.assert_called_once_with(['ddcutil','setvcp','10','128','--bus','7'],timeout=5,check=True)
    def test_scan_status_tracks_the_scan_command_and_clears_after_completion(self):
        messages=queue.Queue();release=threading.Event();scanning=threading.Event();disconnecting=threading.Event();idle=threading.Event();actions=[]
        class Input:
            def __iter__(self):
                while True:
                    line=messages.get()
                    if line is None:return
                    yield line
        backend=b.Backend()
        def emit(data):
            if data.get('busyCommands',{}).get('wifi')=='wifi-scan':
                self.assertIn('wifi',data['busy']);scanning.set()
            elif data.get('busyCommands',{}).get('wifi')=='wifi-disconnect':disconnecting.set()
            elif scanning.is_set() and data.get('busyCommands')=={}:
                self.assertNotIn('wifi',data['busy']);idle.set()
        def command(message):
            actions.append(message['action'])
            if message['action']=='wifi-scan':release.wait(3)
        with patch.object(b.sys,'stdin',Input()),patch.object(b.signal,'signal'),patch.object(b.ServiceEvents,'start'),patch.object(backend.prayers,'get',return_value={}),patch.object(backend,'command',side_effect=command),patch.object(backend,'emit',side_effect=emit),patch.object(b,'wallpapers',return_value=[]),patch.multiple(b,media=lambda:{},battery=lambda:{},audio=lambda:{},displays=lambda:{},wifi=lambda:{},current_wallpaper=lambda:""):
            worker=threading.Thread(target=backend.main);worker.start()
            try:
                messages.put(json.dumps({'action':'wifi-scan'}))
                self.assertTrue(scanning.wait(2))
                messages.put(json.dumps({'action':'wifi-disconnect','value':'wlan0'}))
                # The main loop consumes the queued click while scan is still running.
                b.time.sleep(.12)
                release.set();self.assertTrue(disconnecting.wait(2));self.assertTrue(idle.wait(2))
                self.assertEqual(actions,['wifi-scan','wifi-disconnect'])
            finally:
                release.set();messages.put(None);worker.join(3)
    def test_monitor_rollback_preserves_position_and_scale(self):
        backend=b.Backend();monitor={'name':'DP-1','width':1920,'height':1080,'refreshRate':144,'x':1920,'y':0,'scale':1}
        with patch.object(b,'js',return_value=[monitor]),patch.object(b,'run',return_value='ok') as run,patch.object(backend,'emit'):
            backend.command({'action':'monitor','value':'DP-1','extra':{'mode':'1920x1080@60Hz','scale':1.25}})
            self.assertIn('1920x0',run.call_args.args[0][-1])
            backend.revert_monitor()
            self.assertIn('1920x1080@144',run.call_args.args[0][-1]);self.assertIn('1920x0',run.call_args.args[0][-1])
            self.assertIsNone(backend.monitor_pending)
    def test_settings_round_trip(self):
        with tempfile.TemporaryDirectory() as d,patch.object(b,'CONFIG',pathlib.Path(d)):
            settings=b.settings_load();settings['theme']='nord';b.save_settings(settings)
            self.assertEqual(b.settings_load()['theme'],'nord')
            self.assertFalse((pathlib.Path(d)/'settings.json.tmp').exists())
    def test_volume_clamps_and_uses_argument_list(self):
        backend=b.Backend()
        with patch.object(b,'run') as run:
            backend.command({'action':'volume','value':140})
            run.assert_called_once_with(['pactl','set-sink-volume','@DEFAULT_SINK@','100%'],check=True)
    def test_ssid_is_not_shell_code(self):
        backend=b.Backend()
        with patch.object(b,'run') as run:
            backend.command({'action':'wifi-connect','value':'$(touch /tmp/nope); x'})
            self.assertEqual(run.call_args.args[0],['nmcli','device','wifi','connect','$(touch /tmp/nope); x'])
    def test_bluetooth_rejects_invalid_address(self):
        with self.assertRaises(ValueError):b.Backend().command({'action':'bluetooth-connect','value':'bad; command'})
    def test_monitor_rejects_invalid_mode(self):
        with self.assertRaises(ValueError):b.Backend().command({'action':'monitor','value':'DP-1','extra':{'mode':'bad; command','scale':1}})
    def test_missing_command_reports_failure(self):
        with self.assertRaisesRegex(RuntimeError,'not installed'):b.run(['island-test-command-that-does-not-exist'],check=True)
    def test_lock_config_uses_wallpaper_and_saved_preferences(self):
        with tempfile.TemporaryDirectory() as d:
            wallpaper=pathlib.Path(d)/'wallpaper with spaces.jpg';wallpaper.touch()
            settings=dict(b.DEFAULTS,fontFamily='Noto Sans',monoFontFamily='Test Nerd Font',lockClockSize=110,lockBlur=12,clock24=False)
            with patch.object(b.shutil,'which',return_value='/usr/bin/awww'),patch.object(b,'run',return_value='DP-1: currently displaying: image: '+str(wallpaper)):
                config=b.render_lock_config(settings)
            self.assertIn('path = '+str(wallpaper),config)
            self.assertIn('font_size = 110',config)
            self.assertIn('blur_size = 12',config)
            self.assertIn('font_family = Noto Sans',config)
            self.assertIn('font_family = Test Nerd Font',config)
            self.assertIn('date +"%-I:%M %p"',config)
            self.assertNotRegex(config,r'@[A-Z_]+@')
    def test_lock_launches_hyprlock_with_generated_config(self):
        with tempfile.TemporaryDirectory() as d,patch.object(b,'CONFIG',pathlib.Path(d)),patch.object(b.shutil,'which',side_effect=lambda tool:'/usr/bin/hyprlock' if tool=='hyprlock' else None),patch.object(b.subprocess,'Popen') as launch:
            backend=b.Backend();backend.command({'action':'lock'})
            config=pathlib.Path(d)/'hyprlock.conf'
            self.assertIn('path = screenshot',config.read_text())
            self.assertIn('size = 196, 32',config.read_text())
            launch.assert_called_once_with(['hyprlock','-c',str(config)],stdout=b.subprocess.DEVNULL,stderr=b.subprocess.DEVNULL)
if __name__=='__main__':unittest.main()
