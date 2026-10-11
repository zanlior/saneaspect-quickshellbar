# saneAspect Quickshell Bar

Island is a dynamic desktop bar for Hyprland, built with Quickshell and QML. It brings media, notifications, system controls, themes and prayer times into expandable panels, with a choice of **Dock** and **Notch** layouts.

This repository includes the shell, Hyprland keybindings, autostart modules and theme integration. Island is an independent implementation inspired by the saneAspect desktop design.

## Features

- **Media controls:** artwork, playback and seeking for individual MPRIS players; swipe between cards or use arrow keys. Opening the panel selects the most recently active player. Individual browser tabs are supported through the optional mprisence bridge.
- **Control center:** Wi-Fi, Bluetooth, audio devices, per-app volume, brightness, night light and display settings. Display changes revert automatically unless confirmed.
- **Desktop tools:** application launcher, notifications and history, calendar, clipboard shortcuts, lock screen and power menu.
- **Appearance:** Dock and Notch layouts, 21 theme palettes, wallpaper selection and adjustable fonts, sizing and animations. Themes update Island, GTK, Kitty and Hyprland borders.
- **Prayer times:** daily timetable, Hijri date, next-prayer countdown, reminders and optional azan playback from local MP3 collections.
- **Customization:** persistent settings and a control-center layout editor with drag, resize, undo and reset.

## Requirements

- Hyprland with the Lua `hl` configuration API for the included desktop modules.
- Quickshell 0.3.1 or newer and Python 3.
- Rubik and JetBrains Mono Nerd Font Mono for the default typography.
- Feature-specific tools such as NetworkManager, BlueZ, `pactl`, `playerctl`, `brightnessctl`, `ddcutil`, `hyprsunset`, `hyprlock` and `mpv`.
- A running `awww-daemon` or `swww-daemon` for wallpaper switching.

See the [feature dependency table](quickshell/README.md#dependencies-by-feature) for details. On Arch Linux or CachyOS, `quickshell/install-dependencies.sh` installs the main runtime tools. Review the application shortcuts in `modules/binds.lua` and adjust them to the programs you use; titlebar shortcuts require the hyprbars plugin.

## Installation

1. Back up your existing Hyprland files before copying anything.
2. Copy `quickshell/` and the included files from `modules/` into `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/`.
3. Merge these lines into your existing Lua configuration:

   ```lua
   require("modules.binds")
   require("modules.autostart")
   require("modules.island")
   ```

   Load each module once and remove equivalent bindings or autostart entries. The root `hyprland.lua` is an integration example; retain your own monitor, input, window-rule and decoration settings.
4. Review `modules/autostart.lua` for your session. It starts `awww-daemon` through `uwsm` and selects the Bibata-Modern-Ice cursor. Adapt those entries if you use different tools.
5. Stop any other bar or notification daemon, then start Island:

   ```sh
   "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell/scripts/start.sh"
   ```

`modules/island.lua` starts Island on future Hyprland sessions and loads the generated border palette. Use this module integration for the full package; the standalone installer described in the [shell guide](quickshell/README.md#hyprland-integration) replaces `modules/island.lua` and is intended for separate bar installations.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Super + D | Application launcher |
| Super + A | Control center |
| Super + Q | Media controls |
| Super + U | Calendar |
| Super + Z | Prayer times |
| Super + T | Themes |
| Super + Shift + T | Wallpapers |
| Super + Alt + T | Dock / Notch selector |
| Super + comma | Settings |
| Super + R | Show or hide the bar |
| Super + L | Lock screen |
| Super + M or Alt + L | Power menu |

The complete binding set in `modules/binds.lua` also covers workspaces, window actions, application launchers, screenshots, media keys, volume and brightness. See the [interaction guide](quickshell/README.md#interaction) for mouse and keyboard controls inside panels.

## Prayer setup

The prayer API endpoint, city and country are **blank by default**. Open **Settings → Prayer Times** and enter an HTTPS endpoint and your location, then select the calculation method suitable for your timetable. The [prayer setup guide](quickshell/PRAYER-SETUP.md) explains endpoint compatibility and configuration.

For azan playback, choose your own Fajr and other-prayer MP3 folders in the same settings page. Audio paths also start blank. Settings are stored locally under `${XDG_CONFIG_HOME:-$HOME/.config}/island-shell/`.

## Themes and assets

GTK theme sources are included under `quickshell/vendor/colloid`, alongside GTK assets and Kitty palettes. Wallpapers and music artwork come from your own files and media players. Set your wallpaper folder in **Settings → System**.

Third-party assets and helpers retain their licenses: [Colloid](quickshell/vendor/colloid/LICENSE), [Lucide icons](quickshell/assets/icons/LICENSE), [libsass](quickshell/scripts/vendor/LIBSASS-LICENSE) and [mprisence](quickshell/scripts/vendor/mprisence/LICENSE).

For detailed setup, customization, browser-tab media integration and troubleshooting, see the [Island shell guide](quickshell/README.md).
