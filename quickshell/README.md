# Island — Quickshell for CachyOS / Hyprland

A dynamic desktop bar built with Quickshell and QML, inspired by the saneAspect desktop design. Island offers Workspace and Dock bar themes, each with floating and Notch modes, plus expandable media, system, calendar and prayer panels. Wallpapers and album artwork come from your own files and media players.

## Start

```sh
./scripts/start.sh
```

Quickshell 0.3.1 or newer is required. Install missing integrations from a terminal:

```sh
./install-dependencies.sh
```

The wallpaper picker requires a running `awww-daemon` or `swww-daemon`. Put your images in `~/Pictures/wallpapers`, or change the folder in Settings → System.

## Interaction

- Hover the clock, media circle or Wi-Fi circle for a small lift; hover keeps panels closed. Click the clock to toggle the small date preview. Click the preview to open prayer times; Shift-click the preview for the full month calendar. Shift-click the bar clock to open prayer times directly.
- Click the album circle for media, or the Wi-Fi circle for the control center. When several players are open, hold and drag the artwork or track details left/right to reveal the adjacent player card alongside the current card. Release to settle on that player, or drag back to keep the current one. The slide settles over 420 ms. Each opening starts with the most recently started or resumed audio, with the others available by swiping. The dots show the selected player; transport and seeking control that player. Left/Right arrow keys switch players, and Space toggles playback for the displayed card. See [keyboard controls](docs/keyboard-controls.md) for media and power-menu shortcuts.
- Right-click the clock/status circle for settings. Middle-click the clock for apps.
- Scroll over the clock to change volume. Volume and brightness changes show an OSD.
- Click the control center's lock button to lock immediately. Super + L locks this desktop; Super + M or Alt + L toggles the separate power menu.
- Escape or click outside an expanded panel to close it.
- In the power menu, use arrow keys to select an action and Enter to activate it. Lock runs immediately; other actions require a second distinct Enter press or click. Display changes automatically revert after 15 seconds unless kept.
- Settings save immediately under `~/.config/island-shell/settings.json`.

## Hyprland integration

For this full package, follow the [root integration instructions](../README.md).
Do not run the standalone installer over the included modules: it replaces
`modules/island.lua`. The commands below are for a standalone bar installation
into a separately backed-up desktop configuration.

Review the install plan, then install:

```sh
python3 scripts/install.py
python3 scripts/install.py --apply
```

The installer supports Lua configurations and traditional `hyprland.conf`. It backs up every changed file, adds a small Island module, disables only Waybar/SwayNC autostart lines, and creates `~/.config/quickshell/island` as a link to this directory. Keep this directory in place after installation.

Log out and back in, or stop Waybar and SwayNC and run `./scripts/start.sh`. Only one notification server can own desktop notifications. Quickshell waits for SwayNC to release the service.

Shortcuts are defined only in `~/.config/hypr/modules/binds.lua`. The Island module starts the shell and loads theme colors; it does not register additional shortcuts.

| Shortcut | Surface |
| --- | --- |
| Super + D | Applications |
| Super + Q | Music panel |
| Super + U | Calendar |
| Super + Z | Prayer times |
| Super + A | Control center |
| Super + M or Alt + L | Power menu |
| Super + T | Themes |
| Super + Shift + T | Wallpapers |
| Super + Shift + V | Clipboard history |
| Super + comma | Toggle settings |
| Super + L | Lock screen |
| Super + R | Show/hide bar |

Pressing a panel shortcut again closes it. Switching to another panel finishes the closing animation before opening the next. Click the clock for the date preview, then Shift-click the preview for the calendar. Right-click the clock or status circle to open settings. Wi-Fi, Bluetooth, Sound, and Display details stay inside the control-center frame. Sound and Display use inset rounded sheets; their back buttons return to the existing controls.

The launcher searches names, descriptions, generic names and keywords. Up/Down select and scroll through results; Enter launches the selected application, and Escape closes the panel. Each opening starts a fresh search.

Wi-Fi scans when its sheet opens. The connected network appears first with a Disconnect button, and a mint dot marks Scanning while discovery is running.

All commands are also accessible through IPC:

```sh
quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell" ipc call island toggle control
quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell" ipc call island settings
quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell" ipc call island close
```

To undo installation:

```sh
python3 scripts/install.py --uninstall
```

This restores the backed-up files. If you have subsequently edited those files, save those changes before restoring. Your Island settings remain available.

## Included

Clock and navigable calendar; MPRIS artwork, transport and seek; Wi-Fi scanning and connection; Bluetooth discovery, pairing with PIN/passkey confirmation, connection and disconnection; default audio inputs/outputs and per-app volume; monitor mode/scale with rollback; backlight and night light; focus mode; notifications and history; app launcher; session actions; 21 theme palettes with keyboard browsing; wallpaper picker; persistent settings; a live control-center layout editor with drag, corner resize, keyboard sizing, undo and reset; optional native Polkit authentication agent.

Game Mode changes the visual bar layout. It does not invoke Feral GameMode or alter GPU/CPU policies. Themes recolor Island, GTK, Kitty and Hyprland borders. Monitor settings are session-local. Notification history lasts for the current shell process. Brightness follows the focused monitor: internal panels use `brightnessctl`, and external displays use `ddcutil` when DDC/CI is enabled and accessible. Unsupported displays show an unavailable control.

The Polkit agent is disabled by default to avoid conflicting with an existing session agent. Disable the old agent, then enable it in Settings → System. Authentication uses Quickshell's native Polkit flow; passwords are not sent to the Python bridge. Lock uses Hyprlock and PAM, with the included layout.

## Dependencies by feature

| Feature | Dependency |
| --- | --- |
| Network | NetworkManager (`nmcli`), running service |
| Bluetooth | BlueZ, `bluetoothctl`, `python-dbus`, `python-gobject`, running Bluetooth service |
| Audio | PipeWire/PulseAudio compatibility (`pactl`) |
| Media | `playerctl` and an MPRIS-capable player |
| Prayer reminders and azan | Reminders appear directly in Island; `mpv` for audio playback |
| Backlight | `brightnessctl` and a supported backlight |
| External monitor brightness | `ddcutil`, monitor DDC/CI support and I²C permissions |
| Night light | `hyprsunset` |
| Lock | `hyprlock` |
| Wallpaper | running `awww-daemon` or `swww-daemon` |
| Fonts | Rubik for interface text and clocks; JetBrains Mono Nerd Font Mono for numeric readouts |

Power menu vector icons come from [Lucide](https://lucide.dev/); their license is included in `assets/icons/LICENSE`.

Missing tools produce a visible error when that control is used. Bluetooth PIN pairing, Wi-Fi credentials, suspend/reboot, and display switching require testing with the actual target devices; the automated checks deliberately do not change those devices or power state.

## Verification

Runtime performance notes are in `docs/performance.md`.

```sh
python3 -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml shell.qml Island.qml Settings.qml Authentication.qml
QT_QPA_PLATFORM=offscreen dbus-run-session -- quickshell -p Preview.qml
```

`Preview.qml` contains clearly separated sample data, sends no system commands, and renders 22 views, including the settings sections, into `/tmp/island-preview-*.png`. The actual `shell.qml` uses live services.

Display command syntax follows Hyprland’s [Lua API](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/); brightness uses the [DDC VCP format](https://www.ddcutil.com/command_getvcp/).

Fonts can be changed in Settings → Appearance. Both the Display card and its monitor details control hardware brightness on the focused external monitor. DDC/CI writes run in the background and retain the latest slider position. Monitor sliders keep their identity during polls, and late intermediate readings do not interrupt dragging. Hardware brightness depends on a monitor with DDC/CI support.

## Appearance and bar styles

When the status circle is disabled, control and connection panels expand from the centered clock. When the album circle is disabled, the music panel expands from the clock. Settings can be closed with Super+C and reopened with Super+comma.

Bar themes: **Super+Alt+T** opens the Workspace and Dock theme selector. Search, arrow keys, click, or Enter to choose a theme. Workspace shows workspace indicators, a clock, network signal, and a wide clock overview; Dock shows a clock with separate media and Wi-Fi circles and a compact clock preview. Settings → Bar & Island has a separate Notch mode switch that attaches either theme to the top edge without changing its design.

## Prayer widget

Click the clock, then the date preview to open the prayer widget. Shift-click the
bar clock opens it directly. In Notch mode, click the expanded clock. The month
calendar remains available through Shift-click on the date preview or Super+U.
IPC also accepts `island prayers` or `island toggle prayers`.

The center keeps the clock and Gregorian date. Five orbit cards show Fajr,
Dhuhr, Asr, Maghrib, and Isha with dawn, sun, afternoon, sunset, and moon icons.
An additional sixth orbit card labeled "Passed" shows the most recent prayer's
name, scheduled time, and elapsed time. Before Fajr, it shows yesterday's Isha.
The next prayer is highlighted, and its name, time and countdown appear on the
right. The Hijri date uses a crescent-and-mosque vector.

Prayer API and location start unconfigured. Follow [Prayer API and location setup](PRAYER-SETUP.md) to replace the endpoint and enter your city, country, calculation method and audio folders.
See [AlAdhan's calculation methods](https://aladhan.com/calculation-methods).

The service downloads yesterday, today and tomorrow's timetables over HTTPS, refreshes
after six hours, and caches them under `~/.cache/island-shell/prayers/`. The
countdown updates every second without another request. After Isha, the orbit
and countdown use tomorrow's Fajr; the Hijri row retains today's date until
midnight in the timetable's timezone. An expired cache shows unavailable times
instead of presenting an old timetable. On connection failure, the service
retries each minute and uses any valid saved timetable.

The live prayer panel uses your configured API data and the current time.

Prayer reminders are enabled by default: a notification appears 15 minutes
before, 5 minutes before, and at each of the five prayer times. Prayer
notifications appear directly in Island for ten seconds and remain in its
notification history. They work during Focus mode and when another notification
app has Do Not Disturb enabled. Test reminder uses the same delivery path.
Keep Island running and the
computer awake for reminders; missed alerts more than one minute old are
skipped after startup or resume. A journal in
`~/.config/island-shell/prayer-reminders.json` prevents duplicate alerts across
restarts, overlapping shell instances, or refreshed timetables.

Audio folders start blank. In Settings → Prayer Times, set **Fajr MP3 folder**
and **Other prayers MP3 folder** to your own local collections. No upload is
needed. Fajr chooses from its folder; Dhuhr, Asr, Maghrib, and Isha choose from
the other prayers folder (or its fallback MP3 file). Each prayer makes a fresh
random selection, so the same recording may occasionally be chosen again.
Only MP3 files directly inside the selected folder are included; filenames
ending in .MP3 are supported too. Adding or removing recordings takes effect
at the next prayer without restarting Island. An empty Fajr collection waits
for Fajr recordings; it does not use the other prayers' collection.

Azan playback is enabled by default and starts at each prayer time using
`mpv` without opening a player window. Volume defaults to 75%. The settings
show collection counts and provide Test Fajr, Test other prayers, Test
reminder, and Stop azan buttons. Tests do not consume scheduled reminders.
Exiting Island stops playback. An empty collection skips audio for that prayer; reminders continue normally.

## Individual browser tab cards

Zen/Firefox normally publishes a single shared media player. Individual tab
cards require the [mprisence bridge extension](https://addons.mozilla.org/en-US/firefox/addon/mprisence-bridge/)
and its native host. The installed shell includes the upstream mprisence 1.9.1
binary under `scripts/vendor/mprisence/`; it runs as a native messaging host
when the browser extension connects. Register the native host for your own
installation before using the extension. From the installed `quickshell/` folder:

```sh
python3 - <<'PY'
import json
from pathlib import Path
host = (Path.cwd() / "scripts/vendor/mprisence/mprisence").resolve()
assert host.is_file(), "Run this from the installed quickshell directory"
manifest = Path.home() / ".mozilla/native-messaging-hosts/mprisence.web.bridge.json"
manifest.parent.mkdir(parents=True, exist_ok=True)
manifest.write_text(json.dumps({
    "name": "mprisence.web.bridge", "description": "Mprisence native messaging host",
    "path": str(host), "type": "stdio",
    "allowed_extensions": ["mprisence-bridge@lazykern.foo"]
}, indent=2) + "\n")
PY
```

This creates a local manifest containing your installation path; keep it out
of the repository. The bundled binary is for Linux x86_64.

YouTube, YouTube Music, SoundCloud, Bandcamp, Tidal and Apple Music are supported
by default. After installing the extension, refresh media tabs if they do not
appear. For other sites, enable the extension's generic media option and grant
its requested site access. Native apps continue to use their own media players.
The menu suppresses the shared browser card when a tab card has the same URL.

The binary comes from the official
[mprisence 1.9.1 release](https://github.com/lazykern/mprisence/releases/tag/v1.9.1);
its downloaded archive was verified against SHA-256
`5c42efd84275d0114a9d49a070d6dd0f44242d38daa25c64ee3de54de072c000`.
