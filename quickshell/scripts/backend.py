#!/usr/bin/env python3
"""Island's small, argument-safe bridge to Linux desktop services."""
import concurrent.futures, copy, json, os, pathlib, queue, re, shlex, shutil, signal, subprocess, sys, threading, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', pathlib.Path.home()/'.config'))/'island-shell'
DEFAULTS = json.loads((ROOT/'defaults.json').read_text())
sys.path.insert(0,str(ROOT/'scripts'))
from service_events import ServiceEvents
import themes
from prayer_times import PrayerService, configuration as prayer_configuration
from prayer_reminders import PrayerReminders, AzanPlayer


def run(args, timeout=6, check=False):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        if check: raise RuntimeError(f'{args[0]} is not installed')
        return ''
    except subprocess.TimeoutExpired:
        if check: raise RuntimeError(f'{args[0]} timed out')
        return ''
    if check and p.returncode: raise RuntimeError(p.stderr.strip() or p.stdout.strip() or f'{args[0]} failed')
    return p.stdout.strip()


def js(args, fallback=None):
    try: return json.loads(run(args))
    except (ValueError, TypeError): return fallback if fallback is not None else []


def split_nm(line):
    fields, field, escaped = [], '', False
    for ch in line:
        if escaped: field += ch; escaped = False
        elif ch == '\\': escaped = True
        elif ch == ':': fields.append(field); field = ''
        else: field += ch
    fields.append(field + ('\\' if escaped else ''))
    return fields


def settings_load():
    result = copy.deepcopy(DEFAULTS)
    try:
        saved = json.loads((CONFIG/'settings.json').read_text())
        if isinstance(saved, dict):
            for key, value in saved.items():
                if key in DEFAULTS and type(value) is type(DEFAULTS[key]): result[key] = value
    except (OSError, ValueError): pass
    return result


def save_settings(settings):
    CONFIG.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG/'settings.json.tmp'
    tmp.write_text(json.dumps(settings, indent=2)+'\n')
    tmp.replace(CONFIG/'settings.json')


def wifi():
    rows = []
    saved = {split_nm(line)[0] for line in run(['nmcli','-t','-f','NAME','connection','show']).splitlines()}
    for line in run(['nmcli','-t','-f','IN-USE,SSID,SIGNAL,SECURITY,DEVICE','device','wifi','list','--rescan','no']).splitlines():
        v = split_nm(line)
        if len(v) == 5 and v[1] and not any(x['ssid']==v[1] for x in rows):
            rows.append(dict(active=v[0]=='*', saved=v[1] in saved, ssid=v[1], signal=int(v[2] or 0), security=v[3], device=v[4]))
    return dict(enabled=run(['nmcli','radio','wifi'])=='enabled', networks=rows)


def bluetooth():
    devices=[]
    for line in run(['bluetoothctl','devices']).splitlines():
        p=line.split(' ',2)
        if len(p)!=3 or p[0]!='Device': continue
        info=run(['bluetoothctl','info',p[1]])
        devices.append(dict(address=p[1],name=p[2],paired='Paired: yes' in info,connected='Connected: yes' in info))
    return dict(enabled='Powered: yes' in run(['bluetoothctl','show']),devices=devices)


def audio():
    result={}
    for key, kind in [('outputs','sinks'),('inputs','sources'),('apps','sink-inputs')]:
        result[key]=[]
        for n in js(['pactl','-f','json','list',kind]):
            if kind=='sources' and n.get('monitor_of_sink') not in (None,4294967295,'4294967295'): continue
            channels=list(n.get('volume',{}).values())
            vol=round(sum(int(c.get('value_percent','0%').strip('%')) for c in channels)/max(len(channels),1))
            props=n.get('properties',{})
            result[key].append(dict(id=str(n['index']),name=n.get('name',''),label=n.get('description') or props.get('application.name') or 'Application',volume=vol,mute=n.get('mute',False)))
    result['defaultOutput']=run(['pactl','get-default-sink'])
    result['defaultInput']=run(['pactl','get-default-source'])
    return result


DDC_CACHE = {}
DDC_MAP = {}
DDC_DISCOVERED = 0
DDC_LOCK = threading.RLock()

def parse_ddc_displays(raw):
    result = {}
    for block in re.split(r'(?m)^(?=Display \d+)', raw):
        if not block.startswith('Display '): continue
        bus = re.search(r'I2C bus:\s*/dev/i2c-(\d+)', block)
        connector = re.search(r'DRM[ _]connector:\s*(?:card\d+-)?([\w-]+)', block)
        if bus and connector: result[connector[1]] = int(bus[1])
    return result

def displays(monitors=None):
    # Serialize reads and writes: DDC/CI devices cannot handle overlapping requests.
    with DDC_LOCK:
        return read_displays(monitors)

def read_displays(monitors=None):
    global DDC_MAP, DDC_DISCOVERED
    mons=copy.deepcopy(monitors) if monitors is not None else js(['hyprctl','-j','monitors'])
    b=run(['brightnessctl','-m']).split(',')
    brightness=int(b[3].strip('%')) if len(b)>3 else -1
    now=time.monotonic()
    if shutil.which('ddcutil') and now-DDC_DISCOVERED>60:
        DDC_MAP=parse_ddc_displays(run(['ddcutil','detect','--verbose'],timeout=15));DDC_DISCOVERED=now
    for m in mons:
        name=m['name'];m['brightness']=-1
        if name.startswith(('eDP','LVDS','DSI')) and brightness>=0:
            m.update(brightness=brightness,brightnessKind='backlight')
        elif name in DDC_MAP:
            bus=DDC_MAP[name];cached=DDC_CACHE.get(name)
            if not cached or cached['bus']!=bus or now-cached['time']>5:
                match=re.search(r'VCP 10 C (\d+) (\d+)',run(['ddcutil','getvcp','10','--bus',str(bus),'--terse'],timeout=5))
                cached=dict(time=now,bus=bus,value=-1,maximum=100)
                if match and int(match[2])>0:cached.update(value=round(int(match[1])*100/int(match[2])),maximum=int(match[2]))
                DDC_CACHE[name]=cached
            m.update(brightness=cached['value'],brightnessKind='ddc')
    focused=next((m for m in mons if m.get('focused')),None)
    return dict(monitors=mons,brightness=focused.get('brightness',brightness) if focused else brightness,nightAvailable=bool(shutil.which('hyprsunset')))


def media():
    raw=run(['playerctl','metadata','--format','{{title}}\n{{artist}}\n{{album}}\n{{mpris:artUrl}}\n{{mpris:length}}\n{{playerName}}'])
    p=raw.split('\n')
    if len(p)<6:return {}
    try:length=int(p[4])/1000000
    except ValueError:length=0
    try:position=float(run(['playerctl','position']))
    except ValueError:position=0
    return dict(title=p[0],artist=p[1],album=p[2],art=p[3],length=length,player=p[5],position=position,playing=run(['playerctl','status'])=='Playing')


def desktop():
    active = js(['hyprctl', '-j', 'activeworkspace'], {})
    workspaces = js(['hyprctl', '-j', 'workspaces'], [])
    return dict(active=active.get('id', 1), workspaces=sorted(w['id'] for w in workspaces if w.get('id', 0) > 0))


def battery():
    for p in pathlib.Path('/sys/class/power_supply').glob('*'):
        try:
            if (p/'type').read_text().strip()=='Battery':return dict(percent=int((p/'capacity').read_text()),charging=(p/'status').read_text().strip()=='Charging')
        except OSError: pass
    return dict(percent=-1,charging=False)


def wallpapers(settings, category_only=False):
    folder=pathlib.Path(settings['wallpaperFolder']).expanduser()
    source=themes.REGISTRY.get(settings['theme'],{}).get('source',settings['theme'])
    themed=folder/source
    if source=='catppuccin' and not themed.is_dir():themed=folder/'mocha'
    if themed.is_dir():folder=themed
    elif category_only:return []
    return [str(p) for p in sorted(folder.rglob('*')) if p.is_file() and p.suffix.lower() in ('.png','.jpg','.jpeg','.webp')]


def set_wallpaper(value):
    p=pathlib.Path(str(value)).expanduser().resolve()
    if not p.is_file():raise ValueError('Wallpaper does not exist')
    for tool in ('awww','swww'):
        if shutil.which(tool):
            run([tool,'img',str(p),'--transition-type','fade'],check=True)
            return str(p)
    raise RuntimeError('Install and start swww or awww to set wallpapers')


def clipboard_history():
    raw=run([themes.helper('cliphist'),'list'],check=True)
    return [dict(id=line.split('\t',1)[0],text=line.split('\t',1)[1]) for line in raw.splitlines() if '\t' in line][:250]


def current_wallpaper():
    for tool in ('awww','swww'):
        if not shutil.which(tool):continue
        for line in run([tool,'query']).splitlines():
            marker='currently displaying: image: '
            if marker not in line:continue
            candidate=line.split(marker,1)[1].strip()
            if '\n' not in candidate and '\r' not in candidate and pathlib.Path(candidate).is_file():
                return candidate
    return ''


def render_lock_config(settings):
    background=current_wallpaper() or 'screenshot'
    values={
        'BACKGROUND':background,
        'CLOCK_SIZE':str(int(settings['lockClockSize'])),
        'BLUR':str(int(settings['lockBlur'])),
        'FONT':str(settings['fontFamily']).replace('\n',' ').replace('\r',' '),
        'ICON_FONT':str(settings['monoFontFamily']).replace('\n',' ').replace('\r',' '),
        'TIME_FORMAT':'%-H:%M' if settings['clock24'] else '%-I:%M %p',
        'STATUS_COMMAND':shlex.join([sys.executable,str(ROOT/'scripts/lock_status.py')]),
    }
    config=(ROOT/'hyprlock.conf').read_text()
    for key,value in values.items():config=config.replace('@'+key+'@',value)
    return config


class Backend:
    def __init__(self):
        self.settings=settings_load(); self.page=''; self.q=queue.Queue(); self.state={}; self.night=None; self.pair=None; self.monitor_pending=None
        self.wallpaper_cache={}
        self.wallpaper_snapshot=()
        self.wallpaper_key=None
        self.prayers=PrayerService()
        self.prayer_reminders=PrayerReminders(CONFIG/'prayer-reminders.json')
        self.azan=AzanPlayer()
        self.pool=concurrent.futures.ThreadPoolExecutor(max_workers=6)
        self.commands=concurrent.futures.ThreadPoolExecutor(max_workers=3)
        self.controls=concurrent.futures.ThreadPoolExecutor(max_workers=2)
        self.preference_executor=concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.monitor_executor=concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.night_executor=concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.output_lock=threading.Lock();self.stop=threading.Event();self.busy=set();self.events=ServiceEvents(self.stop)
    def emit(self, data):
        with self.output_lock:print(json.dumps(data),flush=True)
    @staticmethod
    def wallpaper_settings_key(settings):
        return (settings['theme'],str(pathlib.Path(settings['wallpaperFolder']).expanduser()))
    def refresh_wallpapers(self, settings=None, force=False):
        settings=self.settings if settings is None else settings
        key=self.wallpaper_settings_key(settings)
        if force or key not in self.wallpaper_cache:
            self.wallpaper_cache={key:tuple(wallpapers(settings))}
        return self.wallpaper_cache[key]
    def publish_wallpapers(self, force=False):
        key=self.wallpaper_settings_key(self.settings)
        if force or self.wallpaper_key != key:
            snapshot=self.refresh_wallpapers(self.settings,force=force)
            changed=snapshot != self.wallpaper_snapshot
            self.wallpaper_key=key
            self.wallpaper_snapshot=snapshot
            if changed:self.emit({'wallpapers':list(snapshot)})
            return list(snapshot)
        return list(self.wallpaper_snapshot)
    def worker_outcome(self, message, lane, snapshot=None):
        allowed={
            'preferences':({'setting','reset','game','game-toggle','wallpaper','wallpaper-refresh'},('settings','wallpaper_cache','wallpaper_snapshot','wallpaper_key')),
            'monitor':({'monitor','monitor-keep','monitor-revert'},('monitor_pending',)),
            'night':({'night','night-toggle'},('night',)),
            'stateless':({'clipboard-copy','clipboard-refresh','workspace','volume','mic','app-volume','mute','input','output','volume-step','brightness','brightness-step','media','seek','wifi-toggle','wifi-scan','wifi-connect','wifi-disconnect','bluetooth-toggle','bluetooth-scan','bluetooth-connect','bluetooth-disconnect','lock','power','open-folder','prayer-due','prayer-test-reminder','prayer-test-azan','prayer-stop-azan'},()),
        }
        actions,fields=allowed[lane]
        if actions is not None and message.get('action') not in actions:
            raise ValueError(f"Action {message.get('action')} is not allowed on {lane} lane")
        snapshot=snapshot or {'settings':copy.deepcopy(self.settings),'wallpaper_cache':dict(self.wallpaper_cache),'wallpaper_snapshot':tuple(self.wallpaper_snapshot),'wallpaper_key':self.wallpaper_key,'monitor_pending':self.monitor_pending,'night':self.night}
        worker=copy.copy(self)
        for key,value in snapshot.items():setattr(worker,key,copy.deepcopy(value) if key=='settings' else dict(value) if key=='wallpaper_cache' else tuple(value) if key=='wallpaper_snapshot' else value)
        events=[]
        worker.emit=lambda data:events.append(copy.deepcopy(data))
        error=None
        try:
            if message.get('action')=='wallpaper-refresh':
                snapshot=worker.refresh_wallpapers(worker.settings,force=True)
                if snapshot!=worker.wallpaper_snapshot:worker.emit({'wallpapers':list(snapshot)})
                worker.wallpaper_snapshot=snapshot;worker.wallpaper_key=worker.wallpaper_settings_key(worker.settings)
                worker.emit({'wallpaperSelected':current_wallpaper()})
            else:worker.command(copy.deepcopy(message))
        except Exception as exc:error=str(exc)
        return {'lane':lane,'fields':{key:getattr(worker,key) for key in fields},'events':events,'error':error}
    def commit_outcome(self, outcome):
        for key,value in outcome['fields'].items():setattr(self,key,value)
        for event in outcome['events']:self.emit(event)
        if outcome['error']:self.emit({'error':outcome['error']})
        return outcome
    def affected_services(self, message):
        action=message.get('action')
        direct={
            'volume':('audio',),'mic':('audio',),'app-volume':('audio',),'mute':('audio',),'input':('audio',),'output':('audio',),'volume-step':('audio',),
            'brightness':('display',),'brightness-step':('display',),'monitor':('display',),'monitor-keep':('display',),'monitor-revert':('display',),
            'media':('media',),'seek':('media',),'workspace':('desktop',),
            'wifi-toggle':('wifi',),'wifi-scan':('wifi',),'wifi-connect':('wifi',),'wifi-disconnect':('wifi',),
            'bluetooth-toggle':('bluetooth','audio'),'bluetooth-scan':('bluetooth',),'bluetooth-connect':('bluetooth','audio'),'bluetooth-disconnect':('bluetooth','audio'),
            'clipboard-copy':('clipboard',),'page':(),
        }
        services=set(direct.get(action,()))
        if action=='reset' or (action=='setting' and str(message.get('value','')).startswith('prayer')):services.add('prayers')
        page_services={
            'sound':('audio',),'audio':('audio',),'display':('display',),'wifi':('wifi',),'bluetooth':('bluetooth',),'clipboard':('clipboard',),'media':('media',),'control':('audio','display','wifi','bluetooth'),'prayers':('prayers',),
        }
        if action=='page':services.update(page_services.get(str(message.get('value','')),()))
        return services
    @staticmethod
    def poll_intervals(audio_connected=False, desktop_connected=False, notch=False, page=''):
        """Return the service polling cadence for the current event profile."""
        intervals={'media':1,'battery':15,'audio':30 if audio_connected else 1,
                   'display':2,'wifi':5,'prayers':60}
        if notch:intervals['desktop']=30 if desktop_connected else .5
        if page in ('control','bluetooth','settings'):intervals['bluetooth']=8
        if page=='clipboard':intervals['clipboard']=2
        return intervals
    @staticmethod
    def display_metadata_due(connected, dirty, last_read, has_snapshot, now):
        return not connected or dirty or not has_snapshot or now-last_read>=30
    @staticmethod
    def poll_due(key, last, now, interval, dirty, min_gap):
        elapsed=now-last.get(key,0)
        return key not in last or (key in dirty and elapsed>=min_gap) or elapsed>=interval
    def resource_for(self, message):
        action=message.get('action')
        if action in ('volume','mic','app-volume','mute','input','output','volume-step'):return 'audio'
        if action in ('media','seek'):return 'media'
        if action in ('clipboard-copy','clipboard-refresh'):return 'clipboard'
        if action=='workspace':return 'workspace'
        if action in ('lock','power','open-folder'):return 'session'
        if isinstance(action,str) and action.startswith('wifi-'):return 'wifi'
        if isinstance(action,str) and action.startswith('bluetooth-') and action not in ('bluetooth-pair',):return 'bluetooth'
        if action in ('brightness','brightness-step'):return 'display-step'
        return None
    def lane_for(self, message):
        action=message.get('action')
        if action in ('setting','reset','game','game-toggle','wallpaper','wallpaper-refresh'):return 'preferences'
        if action in ('monitor','monitor-keep','monitor-revert'):return 'monitor'
        if action in ('night','night-toggle'):return 'night'
        resource=self.resource_for(message)
        if resource:return ('control:' if resource in ('audio','media','workspace') else 'command:')+resource
        return None
    def monitor_command(self,name,mode,position,scale):
        if (CONFIG.parent/'hypr/hyprland.lua').exists():
            code='hl.monitor({output='+json.dumps(name)+',mode='+json.dumps(mode)+',position='+json.dumps(position)+',scale='+str(float(scale))+'})'
            return ['hyprctl','eval',code]
        return ['hyprctl','keyword','monitor',f'{name},{mode},{position},{scale}']
    def deliver_prayer_reminder(self,event,settings):
        name=event['name'];minutes=event['minutes']
        title=f'{name} in {minutes} minutes' if minutes else f'It is time for {name}'
        if event.get('test'):title='Test reminder: '+title
        clock=event['time']
        if not settings['clock24']:
            hour,minute=map(int,clock.split(':'));clock=f'{hour%12 or 12}:{minute:02} '+('PM' if hour>=12 else 'AM')
        if minutes==0 and settings['prayerAzan']:
            try:self.azan.play_prayer(name,settings)
            except Exception as e:self.emit({'error':'Azan playback failed: '+str(e)})
        if settings['prayerReminders']:
            # Deliver directly to Island: another notification daemon may own
            # the desktop service or suppress notifications in DND mode.
            self.emit({'prayerNotification':dict(summary=title,body=f'{name} begins at {clock} in {settings["prayerCity"]}.')})
    def check_prayer_reminders(self):
        settings=dict(self.settings)
        for event in self.prayer_reminders.due(self.state.get('prayers',{}),settings):
            self.q.put({'action':'prayer-due','value':event,'extra':settings})
        status=self.azan.status(settings)
        if status != self.state.get('prayerAudio'):
            self.state['prayerAudio']=status;self.emit({'prayerAudio':status})
            if status['error']:self.emit({'error':status['error']})
    def command(self,m):
        a=m.get('action'); v=m.get('value'); extra=m.get('extra')
        if a=='prayer-due':self.deliver_prayer_reminder(v,extra);return
        if a=='prayer-test-reminder':
            timetable=self.state.get('prayers',{})
            upcoming=[p for d in timetable.get('days',[]) for p in d['prayers'] if p['epoch']>time.time()]
            if not upcoming:raise RuntimeError('Wait for the prayer timetable to load before testing a reminder.')
            self.deliver_prayer_reminder(dict(min(upcoming,key=lambda p:p['epoch']),minutes=15,test=True),dict(self.settings,prayerReminders=True))
            return
        if a=='prayer-test-azan':self.azan.play_prayer('Fajr' if v=='Fajr' else 'Dhuhr',self.settings,required=True);return
        if a=='prayer-stop-azan':self.azan.stop();return
        if a=='page':
            self.page=str(v)
            if self.page=='wallpapers':
                self.publish_wallpapers(force=True)
                self.emit({'wallpaperSelected':current_wallpaper()})
            if self.page=='clipboard':self.emit({'clipboard':clipboard_history()})
            return
        if a=='wallpaper-refresh':
            snapshot=self.refresh_wallpapers(self.settings,force=True)
            if snapshot!=self.wallpaper_snapshot:self.emit({'wallpapers':list(snapshot)})
            self.wallpaper_snapshot=snapshot;self.wallpaper_key=self.wallpaper_settings_key(self.settings)
            self.emit({'wallpaperSelected':current_wallpaper()})
            return
        if a=='clipboard-refresh':
            self.emit({'clipboard':clipboard_history()})
            return
        if a=='setting':
            if v not in DEFAULTS:raise ValueError('Unknown setting')
            if type(extra) is not type(DEFAULTS[v]):raise ValueError('Invalid setting value')
            old_wallpaper_key=self.wallpaper_settings_key(self.settings)
            staged=copy.deepcopy(self.settings)
            staged[v]=extra
            if v=='theme':
                candidates=wallpapers(dict(self.settings,theme=extra),category_only=True) if not m.get('preserveWallpaper') else []
                wallpaper=candidates[0] if candidates else ''
                try:
                    extra,entry,warnings=themes.apply(str(extra),CONFIG.parent,wallpaper or current_wallpaper())
                except Exception:
                    self.emit({'settings':self.settings});raise
                self.emit({'dynamicPalette':entry['colors'] if extra=='material-you' else None})
                if wallpaper:
                    try:self.emit({'wallpaperSelected':set_wallpaper(wallpaper)})
                    except Exception as e:self.emit({'error':'Theme saved; wallpaper change failed: '+str(e)})
                if warnings:self.emit({'error':'Theme saved; reload issue: '+'; '.join(warnings)})
                staged[v]=extra
            new_key=self.wallpaper_settings_key(staged)
            snapshot=None
            if new_key!=old_wallpaper_key:snapshot=tuple(wallpapers(staged))
            save_settings(staged)
            self.settings=staged
            data={'settings':self.settings}
            if snapshot is not None:
                self.wallpaper_cache={new_key:snapshot}
                if snapshot!=self.wallpaper_snapshot:data['wallpapers']=list(snapshot)
                self.wallpaper_snapshot=snapshot;self.wallpaper_key=new_key
            self.emit(data); return
        if a=='reset':
            old_wallpaper_key=self.wallpaper_settings_key(self.settings)
            staged=copy.deepcopy(DEFAULTS)
            new_key=self.wallpaper_settings_key(staged)
            snapshot=tuple(wallpapers(staged)) if new_key!=old_wallpaper_key else None
            save_settings(staged)
            self.settings=staged
            data={'settings':self.settings}
            if snapshot is not None:
                self.wallpaper_cache={new_key:snapshot}
                if snapshot!=self.wallpaper_snapshot:data['wallpapers']=list(snapshot)
                self.wallpaper_snapshot=snapshot;self.wallpaper_key=new_key
            self.emit(data);return
        if a=='clipboard-copy':
            ident=str(v)
            if not ident.isdigit():raise ValueError('Invalid clipboard entry')
            decoded=subprocess.run([themes.helper('cliphist'),'decode'],input=(ident+'\n').encode(),capture_output=True,timeout=5)
            if decoded.returncode:raise RuntimeError('Clipboard entry is no longer available')
            copied=subprocess.run(['wl-copy'],input=decoded.stdout,capture_output=True,timeout=5)
            if copied.returncode:raise RuntimeError('Could not copy clipboard entry')
            self.emit({'clipboardCopied':ident})
        elif a=='workspace':
            workspace=int(v)
            if not 1 <= workspace <= 10:raise ValueError('Invalid workspace')
            run(['hyprctl','dispatch',f'hl.dsp.focus({{workspace = {workspace}}})'],check=True)
        elif a=='volume-step':
            delta=int(v)
            run(['pactl','set-sink-volume','@DEFAULT_SINK@',f'{delta:+d}%'],check=True)
        elif a=='brightness-step':
            monitors=displays()
            target=next((m for m in monitors['monitors'] if m.get('focused')),None)
            if not target or target.get('brightness',-1)<0:raise RuntimeError('Brightness unavailable')
            self.command({'action':'brightness','value':target['brightness']+int(v),'extra':target['name']})
        elif a=='night-toggle':self.command({'action':'night','value':not bool(self.night),'extra':self.settings['nightTemperature']})
        elif a=='game-toggle':self.command({'action':'game','value':not self.settings['gameMode']})
        elif a=='wifi-toggle':run(['nmcli','radio','wifi','on' if v else 'off'],check=True)
        elif a=='wifi-scan':run(['nmcli','device','wifi','rescan'],check=True)
        elif a=='wifi-connect':
            # Secrets arrive over stdin, never through a shell or in log output.
            if extra:
                p=subprocess.run(['nmcli','--ask','device','wifi','connect',str(v)],input=str(extra)+'\n',capture_output=True,text=True,timeout=45)
                if p.returncode:raise RuntimeError('Connection failed. Check the password and NetworkManager permissions.')
            else:run(['nmcli','device','wifi','connect',str(v)],timeout=30,check=True)
        elif a=='wifi-disconnect':run(['nmcli','device','disconnect',str(v)],check=True)
        elif a=='bluetooth-toggle':run(['bluetoothctl','power','on' if v else 'off'],check=True)
        elif a=='bluetooth-scan':run(['bluetoothctl','--timeout','8','scan','on'],timeout=12,check=True)
        elif a=='bluetooth-pair':
            if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}',str(v)):raise ValueError('Invalid device')
            if self.pair and self.pair.poll() is None:raise RuntimeError('A pairing request is already open')
            self.pair=subprocess.Popen([sys.executable,str(ROOT/'scripts/bluetooth_agent.py'),str(v)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            process=self.pair
            def relay():
                for line in process.stdout:
                    try:self.emit(json.loads(line))
                    except ValueError:pass
                if process.wait():self.emit({'error':'Bluetooth agent failed. Check python-dbus and python-gobject are installed.','pairing':None})
            threading.Thread(target=relay,daemon=True).start()
        elif a=='pair-response':
            if self.pair and self.pair.poll() is None:
                self.pair.stdin.write(json.dumps({'value':v})+'\n');self.pair.stdin.flush()
        elif a in ('bluetooth-connect','bluetooth-disconnect'):
            if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}',str(v)):raise ValueError('Invalid device')
            result=run(['bluetoothctl',a.split('-')[1],str(v)],timeout=35,check=True)
            if 'Failed' in result:raise RuntimeError(result)
        elif a in ('output','input'):run(['pactl','set-default-'+('sink' if a=='output' else 'source'),str(v)],check=True)
        elif a in ('volume','mic','app-volume'):
            kind={'volume':'sink','mic':'source','app-volume':'sink-input'}[a]
            target=str(extra) if extra is not None else ('@DEFAULT_SINK@' if a=='volume' else '@DEFAULT_SOURCE@')
            run(['pactl','set-'+kind+'-volume',target,str(max(0,min(100,round(float(v)))))+'%'],check=True)
        elif a=='mute':run(['pactl','set-sink-mute','@DEFAULT_SINK@','toggle'],check=True)
        elif a=='brightness':
            with DDC_LOCK:
                value=max(0,min(100,round(float(v))))
                name=str(extra) if extra else next((m['name'] for m in js(['hyprctl','-j','monitors']) if m.get('focused')),'')
                if name in DDC_CACHE and DDC_CACHE[name]['value']>=0:
                    d=DDC_CACHE[name]
                    run(['ddcutil','setvcp','10',str(round(value*d['maximum']/100)),'--bus',str(d['bus'])],timeout=5,check=True)
                    d.update(value=value,time=time.monotonic())
                elif name.startswith(('eDP','LVDS','DSI')) or not name:
                    run(['brightnessctl','set',str(max(1,value))+'%'],check=True)
                else:raise RuntimeError('This monitor has no accessible brightness control. Enable DDC/CI in its menu and install ddcutil.')
        elif a=='monitor':
            name=str(v); mode=str(extra['mode']); scale=float(extra['scale'])
            if not re.fullmatch(r'[\w.-]+',name) or not re.fullmatch(r'\d+x\d+@\d+(?:\.\d+)?(?:Hz)?|preferred',mode):raise ValueError('Invalid monitor mode')
            if not 0.5<=scale<=3:raise ValueError('Scale must be between 0.5 and 3')
            if self.monitor_pending:self.revert_monitor()
            current=next((m for m in js(['hyprctl','-j','monitors']) if m.get('name')==name),None)
            if not current:raise RuntimeError('Monitor is no longer connected')
            position=f"{current['x']}x{current['y']}"
            old=self.monitor_command(name,f"{current['width']}x{current['height']}@{current['refreshRate']}",position,current['scale'])
            mode=mode.removesuffix('Hz')
            result=run(self.monitor_command(name,mode,position,scale),check=True)
            if 'ok' not in result.lower():raise RuntimeError(result or 'Monitor change failed')
            self.monitor_pending=(time.monotonic()+15,old)
            self.emit({'monitorConfirm':True})
        elif a=='monitor-keep':self.monitor_pending=None;self.emit({'monitorConfirm':False})
        elif a=='monitor-revert':self.revert_monitor()
        elif a=='night':
            if self.night:self.night.terminate();self.night.wait(timeout=3);self.night=None
            if v:self.night=subprocess.Popen(['hyprsunset','-t',str(int(extra or 3700))],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            self.emit({'nightActive':bool(v)})
        elif a=='media':
            if v in ('play-pause','next','previous'):run(['playerctl',v],check=True)
        elif a=='seek':run(['playerctl','position',str(float(v))],check=True)
        elif a=='wallpaper':
            self.emit({'wallpaperSelected':set_wallpaper(v)})
            if self.settings['theme']=='material-you':self.command({'action':'setting','value':'theme','extra':'material-you','preserveWallpaper':True})
        elif a=='lock':
            if not shutil.which('hyprlock'):raise RuntimeError('Install hyprlock to lock the session')
            CONFIG.mkdir(parents=True,exist_ok=True)
            (CONFIG/'hyprlock.conf').write_text(render_lock_config(self.settings))
            subprocess.Popen(['hyprlock','-c',str(CONFIG/'hyprlock.conf')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        elif a=='power':
            if v in ('suspend','reboot','poweroff'):run(['systemctl',v],check=True)
            elif v=='logout':run(['hyprctl','eval','hl.dispatch(hl.dsp.exit())'] if (CONFIG.parent/'hypr/hyprland.lua').exists() else ['hyprctl','dispatch','exit'],check=True)
        elif a=='open-folder':subprocess.Popen(['xdg-open',str(pathlib.Path(self.settings['wallpaperFolder']).expanduser())])
        elif a=='game':
            # Visual game mode only; no global compositor settings are overwritten.
            staged=copy.deepcopy(self.settings);staged['gameMode']=bool(v)
            save_settings(staged);self.settings=staged;self.emit({'settings':self.settings})
        else:raise ValueError('Unknown action')
    def revert_monitor(self):
        if self.monitor_pending:
            run(self.monitor_pending[1],check=True)
            self.monitor_pending=None
        self.emit({'monitorConfirm':False})
    def main(self):
        def reader():
            for line in sys.stdin:
                try:self.q.put(json.loads(line))
                except ValueError:pass
            self.stop.set()
        threading.Thread(target=reader,daemon=True).start()
        signal.signal(signal.SIGTERM,lambda *_:self.stop.set())
        signal.signal(signal.SIGINT,lambda *_:self.stop.set())
        self.clipboard_watcher=None
        if shutil.which('wl-paste') and pathlib.Path(themes.helper('cliphist')).exists():
            self.clipboard_watcher=subprocess.Popen(['wl-paste','--watch',themes.helper('cliphist'),'store'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        self.wallpaper_cache={};self.wallpaper_snapshot=();self.wallpaper_key=None
        self.wallpaper_key=self.wallpaper_settings_key(self.settings)
        self.emit({'settings':self.settings,'capabilities':{x:bool(shutil.which(x)) for x in ('nmcli','bluetoothctl','pactl','brightnessctl','ddcutil','hyprsunset','hyprlock','playerctl','swww','awww','mpv','notify-send')}})
        try:
            theme_state=json.loads((CONFIG/'theme-state.json').read_text())
            if theme_state['name']=='material-you':self.emit({'dynamicPalette':theme_state['entry']['colors']})
        except (OSError,ValueError,KeyError):pass
        polls={};last={};dirty=set();display_metadata_dirty=True;display_metadata_last=0.0;display_full_polls=set();lane_futures={};lane_queues={};lane_messages={};busy_actions={};service_invalidations={};auto_revert_queued=False;monitor_retry_at=0;monitor_retry_count=0;last_prayer_check=0
        lane_executors={'preferences':self.preference_executor,'monitor':self.monitor_executor,'night':self.night_executor}
        self.q.put({'action':'wallpaper-refresh'})
        self.events.start()
        def start_lane(lane):
            if lane in lane_futures or not lane_queues.get(lane):return
            message=lane_queues[lane].pop(0)
            snapshot={'settings':copy.deepcopy(self.settings),'wallpaper_cache':dict(self.wallpaper_cache),'wallpaper_snapshot':tuple(self.wallpaper_snapshot),'wallpaper_key':self.wallpaper_key,'monitor_pending':self.monitor_pending,'night':self.night}
            executor=lane_executors.get(lane,self.controls if lane.startswith('control:') else self.commands)
            kind='preferences' if lane=='preferences' else 'monitor' if lane=='monitor' else 'night' if lane=='night' else 'stateless'
            lane_futures[lane]=executor.submit(self.worker_outcome,message,kind,snapshot)
            lane_messages[lane]=message
            service_invalidations[lane]=self.affected_services(message)
            action=message.get('action','')
            if action.startswith(('wifi-','bluetooth-')):
                resource='wifi' if action.startswith('wifi-') else 'bluetooth'
                busy_actions[resource]=action;self.emit({'busy':list(busy_actions),'busyCommands':dict(busy_actions)})
        def enqueue_lane(lane,message):
            pending=lane_queues.setdefault(lane,[])
            if lane.startswith('command:') and message.get('action')=='brightness':
                action=message['action'];target=message.get('extra')
                if pending and pending[-1].get('action')==action and pending[-1].get('extra')==target:
                    pending[-1]=copy.deepcopy(message)
                    return
            if lane=='control:audio' and message.get('action') in ('volume','mic','app-volume'):
                action=message['action'];target=message.get('extra')
                if pending and pending[-1].get('action')==action and pending[-1].get('extra')==target:
                    pending[-1]=copy.deepcopy(message)
                    return
            if lane=='monitor' and message.get('action')=='monitor-revert':pending.insert(0,copy.deepcopy(message))
            else:pending.append(copy.deepcopy(message))
            start_lane(lane)
        def invalidate_services(services):
            nonlocal display_metadata_dirty
            services=set(services)
            dirty.update(services)
            if 'display' in services:display_metadata_dirty=True
        def invalidate(message):
            invalidate_services(self.affected_services(message))
        while not self.stop.is_set():
            if self.monitor_pending and monitor_retry_count<3 and time.monotonic()>=max(self.monitor_pending[0],monitor_retry_at) and not auto_revert_queued and 'monitor' not in lane_futures:
                enqueue_lane('monitor',{'action':'monitor-revert','_automatic_revert':True});auto_revert_queued=True
            if self.night and 'night' not in lane_futures and self.night.poll() is not None:
                self.night=None;self.emit({'nightActive':False,'error':'Night Light stopped. Another hyprsunset instance may already be running.'})
            for key,future in list(lane_futures.items()):
                if future.done():
                    message=lane_messages.pop(key,{})
                    outcome=None
                    try:
                        outcome=future.result();self.commit_outcome(outcome)
                        invalidate_services(service_invalidations.pop(key,()))
                    except Exception as e:
                        invalidate_services(service_invalidations.pop(key,()))
                        self.emit({'error':str(e)})
                    del lane_futures[key]
                    if key=='monitor':
                        if self.monitor_pending is None:auto_revert_queued=False;monitor_retry_at=0;monitor_retry_count=0
                        elif outcome and outcome.get('error') and message.get('_automatic_revert'):
                            monitor_retry_count+=1;auto_revert_queued=monitor_retry_count>=3;monitor_retry_at=time.monotonic()+1
                        elif message.get('action')=='monitor' and outcome and not outcome.get('error'):
                            monitor_retry_count=0;monitor_retry_at=0;auto_revert_queued=False
                    if key.startswith(('command:wifi','command:bluetooth')):
                        resource='wifi' if key.startswith('command:wifi') else 'bluetooth'
                        busy_actions.pop(resource,None);self.emit({'busy':list(busy_actions),'busyCommands':dict(busy_actions)})
                    start_lane(key)
            batch=[]
            while not self.q.empty():
                m=self.q.get_nowait()
                batch.append(m)
            for m in batch:
                a=m.get('action','')
                if a=='page':
                    self.page=str(m.get('value',''))
                    invalidate(m)
                    if self.page=='wallpapers':enqueue_lane('preferences',{'action':'wallpaper-refresh'})
                    elif self.page=='clipboard':enqueue_lane('command:clipboard',{'action':'clipboard-refresh'})
                    continue
                if a in ('bluetooth-pair','pair-response'):
                    try:self.command(m)
                    except Exception as e:self.emit({'error':str(e)})
                    continue
                lane=self.lane_for(m)
                if lane:
                    enqueue_lane(lane,m)
                    continue
                if a in ('prayer-due','prayer-test-reminder','prayer-test-azan','prayer-stop-azan'):
                    enqueue_lane('control:prayer',m);continue
                try:self.command(m)
                except Exception as e:self.emit({'error':str(e)})
            for service in self.events.drain():
                if service in ('audio','wifi','desktop','display','media','bluetooth','clipboard'):
                    invalidate_services((service,))
            data={}
            # Adopt finished polls before building new work so cached display
            # metadata can be used immediately and stale in-flight values drop.
            for key,future in list(polls.items()):
                if not future.done():continue
                polls.pop(key)
                was_metadata_full=key in display_full_polls
                display_full_polls.discard(key)
                try:
                    result=future.result()
                    if key in dirty:
                        continue
                    if key=='prayers' and result.get('configuration') != prayer_configuration(self.settings):
                        dirty.add('prayers')
                    else:data[key]=result
                except Exception:
                    if was_metadata_full:
                        display_metadata_dirty=True;dirty.add('display')
                    if key not in dirty:data[key]={}
            intervals=self.poll_intervals(self.events.connected('audio'),self.events.connected('desktop'),self.settings['notch'],self.page)
            sources={'media':media,'battery':battery,'audio':audio,'display':displays,'wifi':wifi,
                     'desktop':desktop,'bluetooth':bluetooth,'clipboard':clipboard_history}
            prayer_settings=dict(self.settings)
            sources['prayers']=lambda settings=prayer_settings:self.prayers.get(settings)
            jobs={key:(sources[key],interval) for key,interval in intervals.items()}
            now=time.monotonic()
            display_connected=self.events.connected('display')
            display_snapshot=data.get('display',self.state.get('display'))
            display_full=self.display_metadata_due(display_connected,display_metadata_dirty,display_metadata_last,display_snapshot is not None,now)
            if 'display' in jobs and not display_full:
                cached_monitors=copy.deepcopy(display_snapshot.get('monitors',[]))
                jobs['display']=(lambda monitors=cached_monitors:displays(monitors),2)
            min_gap={'audio':.2,'wifi':.5,'desktop':.05,'display':.2}
            for key,(fn,interval) in jobs.items():
                if key not in polls and self.poll_due(key,last,now,interval,dirty,min_gap.get(key,0)):
                    dirty.discard(key)
                    polls[key]=self.pool.submit(fn);last[key]=now
                    if key=='display' and display_full:
                        display_metadata_dirty=False;display_metadata_last=now;display_full_polls.add(key)
            # Preserve QML models when a service poll returns unchanged data.
            changed={key:value for key,value in data.items() if key not in self.state or self.state[key]!=value}
            if changed:self.state.update(changed);self.emit(changed)
            if time.monotonic()-last_prayer_check>=1:
                last_prayer_check=time.monotonic()
                try:self.check_prayer_reminders()
                except Exception as e:self.emit({'error':'Prayer reminders unavailable: '+str(e)});last_prayer_check+=59
            self.stop.wait(.05)
        self.events.close()
        for queued in lane_queues.values():queued.clear()
        for future in list(polls.values())+list(lane_futures.values()):future.cancel()
        def settle_lane(key):
            future=lane_futures.pop(key,None)
            lane_messages.pop(key,None);service_invalidations.pop(key,None)
            if future and not future.cancel():
                try:self.commit_outcome(future.result())
                except Exception as e:self.emit({'error':str(e)})
        settle_lane('monitor')
        if self.monitor_pending:
            snapshot={'settings':copy.deepcopy(self.settings),'wallpaper_cache':dict(self.wallpaper_cache),'wallpaper_snapshot':tuple(self.wallpaper_snapshot),'wallpaper_key':self.wallpaper_key,'monitor_pending':self.monitor_pending,'night':self.night}
            try:self.commit_outcome(self.monitor_executor.submit(self.worker_outcome,{'action':'monitor-revert','_automatic_revert':True},'monitor',snapshot).result())
            except Exception as e:self.emit({'error':str(e)})
        settle_lane('night')
        settle_lane('control:prayer')
        for process in (self.night,self.pair,self.clipboard_watcher):
            if process and process.poll() is None:
                try:process.terminate()
                except (OSError,ValueError):pass
                try:process.wait(timeout=.5)
                except (subprocess.TimeoutExpired,TimeoutError):
                    try:process.kill();process.wait(timeout=.5)
                    except (OSError,ValueError,subprocess.TimeoutExpired,TimeoutError):pass
        self.azan.stop()
        for key in list(lane_futures):settle_lane(key)
        for executor in (self.preference_executor,self.monitor_executor,self.night_executor,self.controls,self.commands,self.pool):executor.shutdown(wait=True,cancel_futures=True)

if __name__=='__main__':Backend().main()
