#!/usr/bin/env python3
"""Focused migration. Run --prepare, review migration/, then --apply; --rollback PATH restores backups."""
import argparse,json,os,pathlib,re,shutil,subprocess,time,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
HOME=pathlib.Path.home();CONFIG=HOME/'.config';STATE=HOME/'.local/state/island-shell'
STAGE=ROOT/'migration'

def prepare():
    STAGE.mkdir(exist_ok=True)
    qs='quickshell -p '+str(CONFIG/'hypr/quickshell')+' ipc call island '
    binds=(CONFIG/'hypr/modules/binds.lua').read_text()
    mappings={
        'command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit':'toggle power',
        'pkill rofi || rofi -show drun -theme ~/.config/rofi/app-launcher.rasi':'toggle launcher',
        '~/.config/waybar/scripts/launch.sh':'bar',
        '~/.config/waybar/scripts/waybar-layout-switcher':'game',
        'pkill rofi || ~/.config/colorschemes/wallpaper-selector.sh':'toggle wallpapers',
        'pkill rofi || ~/.config/colorschemes/main-menu.sh':'toggle themes',
        'swaync-client -t -sw':'toggle control',
        'swaync-client -R && swaync-client -rs':'refresh',
        'wlogout':'toggle power',
        '~/.config/hypr/scripts/night-mode.sh':'night',
        '~/.config/hypr/scripts/blitz-mode.sh':'game',
        '~/.config/hypr/scripts/volume.sh --dec':'volumeStep -5',
        '~/.config/hypr/scripts/volume.sh --inc':'volumeStep 5',
        '~/.config/hypr/scripts/brightness.sh --dec':'brightnessStep -5',
        '~/.config/hypr/scripts/brightness.sh --inc':'brightnessStep 5',
        'quickshell -p '+str(ROOT)+' ipc call island lock':'lock',
        'cliphist list | rofi -dmenu -display-columns 2 -p "Search Clipboard" -theme .local/share/rofi/themes/minimal.rasi | cliphist decode | wl-copy':'toggle clipboard',
    }
    for before,after in mappings.items():
        if before not in binds and qs+after not in binds:raise RuntimeError('Binding changed since inventory: '+before)
        binds=binds.replace(before,qs+after)
    binds='\n'.join(line for line in binds.splitlines() if not (line.lstrip().startswith('-- hl.bind') and 'rofi' in line))+'\n'
    settings='hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd('+json.dumps(qs+'settings')+'))\n'
    if qs+'settings' not in binds:binds+='\n-- Island settings\n'+settings
    (STAGE/'binds.lua').write_text(binds)
    island=(CONFIG/'hypr/modules/island.lua').read_text().replace(str(ROOT),str(CONFIG/'hypr/quickshell'))
    island='\n'.join(line for line in island.splitlines() if not line.startswith(('hl.bind(', 'local qs =')))+'\n'
    if 'island-colors.lua' not in island:
        island+='\n-- Read each reload so palette changes are never cached by require().\ndofile(os.getenv("HOME") .. "/.config/hypr/modules/island-colors.lua")\n'
    (STAGE/'island.lua').write_text(island)
    (STAGE/'plan.json').write_text(json.dumps({'files':{'hypr/modules/binds.lua':'binds.lua','hypr/modules/island.lua':'island.lua'},'workspace':str(ROOT)},indent=2)+'\n')
    print('Prepared',STAGE)

def snapshot(path, backup, manifest):
    key=str(path)
    if key in manifest['paths']:return
    if path.is_symlink():record={'kind':'link','target':os.readlink(path)}
    elif path.exists():
        target=backup/'files'/str(len(manifest['paths']))
        target.parent.mkdir(parents=True,exist_ok=True)
        if path.is_dir():shutil.copytree(path,target,symlinks=True)
        else:shutil.copy2(path,target)
        record={'kind':'directory' if path.is_dir() else 'file','backup':str(target)}
    else:record={'kind':'missing'}
    manifest['paths'][key]=record
    (backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

def rollback(backup):
    manifest=json.loads((backup/'manifest.json').read_text())
    for key,record in reversed(list(manifest['paths'].items())):
        path=pathlib.Path(key)
        if path.is_symlink() or path.is_file():path.unlink()
        elif path.is_dir():shutil.rmtree(path)
        if record['kind']=='link':path.symlink_to(record['target'])
        elif record['kind']=='file':shutil.copy2(record['backup'],path)
        elif record['kind']=='directory':shutil.copytree(record['backup'],path,symlinks=True)
    for key,value in manifest.get('gsettings',{}).items():subprocess.run(['gsettings','set','org.gnome.desktop.interface',key,value],check=False)
    subprocess.run(['hyprctl','reload'],check=False)
    print('Restored',backup)

def apply():
    import themes
    plan=json.loads((STAGE/'plan.json').read_text())
    backup=STATE/('migration-'+time.strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True)
    manifest={'paths':{},'gsettings':{}}
    targets=[CONFIG/k for k in plan['files']]+[CONFIG/'hypr/quickshell',CONFIG/'kitty/colors.conf',CONFIG/'hypr/modules/island-colors.lua',CONFIG/'island-shell/theme-state.json',HOME/'.local/share/island-shell/bin']
    for version in ('3.0','4.0'):targets.append(CONFIG/('gtk-'+version)/'settings.ini')
    targets += [CONFIG/'gtk-4.0/gtk.css',CONFIG/'gtk-4.0/gtk-dark.css']
    targets += [HOME/'.local/share/themes'/entry['gtk'] for entry in themes.REGISTRY.values()]
    for path in targets:snapshot(path,backup,manifest)
    for key in ('gtk-theme','color-scheme'):
        p=subprocess.run(['gsettings','get','org.gnome.desktop.interface',key],capture_output=True,text=True)
        if p.returncode==0:manifest['gsettings'][key]=p.stdout.strip()
    (backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    try:
        link=CONFIG/'hypr/quickshell'
        if link.exists() or link.is_symlink():
            if link.resolve()!=ROOT:raise RuntimeError('Hypr Quickshell path already exists')
        else:link.symlink_to(ROOT,target_is_directory=True)
        for target,source in plan['files'].items():shutil.copy2(STAGE/source,CONFIG/target)
        bindir=HOME/'.local/share/island-shell/bin';bindir.mkdir(parents=True,exist_ok=True)
        for name in ('cliphist','matugen'):
            src=pathlib.Path('/tmp/island-packages')/name/'usr/bin'/name
            if src.exists():shutil.copy2(src,bindir/name)
            elif not shutil.which(name) and not (bindir/name).exists():raise RuntimeError('Missing helper: '+name)
        name=json.loads((CONFIG/'island-shell/settings.json').read_text())['theme']
        from backend import current_wallpaper
        themes.apply(name,CONFIG,current_wallpaper())
    except Exception:
        rollback(backup);raise
    (STAGE/'applied-backup.txt').write_text(str(backup)+'\n')
    print('Migration applied. Backup:',backup)

if __name__=='__main__':
    parser=argparse.ArgumentParser();group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare',action='store_true');group.add_argument('--apply',action='store_true');group.add_argument('--rollback',type=pathlib.Path)
    args=parser.parse_args()
    if args.prepare:prepare()
    elif args.apply:apply()
    else:rollback(args.rollback)
