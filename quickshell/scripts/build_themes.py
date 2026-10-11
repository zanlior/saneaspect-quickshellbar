#!/usr/bin/env python3
"""Compile isolated Colloid GTK3/4 variants; never run its destructive installer."""
import json,pathlib,shutil,tempfile,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
REGISTRY=json.loads((ROOT/'themes/registry.json').read_text())

def build(name, entry, destination, compiler):
    colors=entry['colors'];bg,panel,card,fg,muted,accent=colors
    with tempfile.TemporaryDirectory(prefix='island-colloid-') as temp:
        source=pathlib.Path(temp)/'src'
        shutil.copytree(ROOT/'vendor/colloid/src',source)
        tweaks=(source/'sass/_tweaks.scss').read_text().replace("$colortype: 'system'", "$colortype: 'fixed'")
        (source/'sass/_tweaks-temp.scss').write_text(tweaks)
        # Override palette variables before Colloid derives its widget colors.
        p=source/'sass/_color-palette-default.scss'
        additions={'white':fg if name!='e-ink' else bg,'black':bg if name!='e-ink' else fg,'default-light':accent,'default-dark':accent,'links':accent}
        for n in range(50,1000,50):
            additions[f'grey-{n:03}']=card if n<=650 else panel if n<=750 else bg
        if name=='e-ink':
            for n in range(50,300,50):additions[f'grey-{n:03}']=panel if n<200 else card
        for label,color in zip(['red','green','yellow','blue','purple','teal'],entry['samples']):
            additions[label+'-light']=color;additions[label+'-dark']=color
        p.write_text(p.read_text()+'\n'+''.join(f'${key}: {value};\n' for key,value in additions.items()))
        target=destination/entry['gtk'];target.mkdir(parents=True,exist_ok=True)
        for version in ('3.0','4.0'):
            folder=target/('gtk-'+version);folder.mkdir(exist_ok=True)
            assets=source/'assets'/('gtk-'+version)
            if assets.exists():shutil.copytree(assets,folder/'assets',dirs_exist_ok=True)
            shutil.copytree(ROOT/'assets/gtk',folder/'assets',dirs_exist_ok=True)
            # Colloid references scalable SVGs relative to its CSS.
            original=ROOT/'vendor/colloid-extra'/('gtk-'+version)/'assets'
            if original.exists():shutil.copytree(original,folder/'assets',dirs_exist_ok=True)
            for filename,variant in [('gtk.css','Light' if name=='e-ink' else 'Dark'),('gtk-dark.css','Dark')]:
                css=compiler.compile(filename=str(source/'main'/('gtk-'+version)/f'gtk-{variant}.scss'),output_style='expanded')
                (folder/filename).write_text(css)
        (target/'index.theme').write_text(f'[Desktop Entry]\nType=X-GNOME-Metatheme\nName={entry["gtk"]}\n[X-GNOME-Metatheme]\nGtkTheme={entry["gtk"]}\n')
        return target

if __name__=='__main__':
    import sass
    dest=ROOT/'themes/gtk';dest.mkdir(exist_ok=True)
    for name,entry in REGISTRY.items():
        build(name,entry,dest,sass);print(name,flush=True)
