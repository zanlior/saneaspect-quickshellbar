# Hyprland configuration with Island Quickshell

A portable copy of the keybindings, autostart and Island Quickshell files. Copy `quickshell/` and the included modules into `${XDG_CONFIG_HOME:-$HOME/.config}/hypr` after backing up any files they replace. Merge the requires from `hyprland.lua` into your existing Lua configuration; do not replace your full configuration with this integration example. Load each module once and remove equivalent existing bindings and autostart entries. Other monitor, input, window-rule, decoration and environment settings are outside this package. It requires a Hyprland build with the Lua `hl` configuration API.

All active reference keybindings are in `modules/binds.lua`, including bar styles (Super+Alt+T), prayer times (Super+Z), volume and brightness shortcuts, media, workspaces, window actions, screenshots and application launchers. The configuration loads them once. Paths use the current user's config directory and plugin cache. Start the bar with `quickshell/scripts/start.sh`; the included `modules/island.lua` handles desktop autostart. Do not run the standalone bar installer over these modules: it would replace the included module.

See `quickshell/README.md` for runtime dependencies and features. Some shortcuts require optional installed applications or the hyprbars plugin. Wallpaper files, artwork, personal settings, credentials, local backups and editor configuration dumps are excluded. Set your wallpaper folder and prayer location/audio folders in the bar settings. Personal runtime state remains on the installing user's machine.

GTK theme source assets are under `quickshell/vendor/colloid` with their original license. Extra GTK assets and Kitty palettes are included separately so theme generation does not depend on private configuration dumps. Third-party icon and helper licenses remain included.

This package has a reconstructed commit sequence, not a complete original development history. See [Development reconstruction](DEVELOPMENT.md) for the evidence, scope and verification limits. Commits use a GitHub noreply identity; publication requires a separate push approval.

For replaceable prayer API and location settings, see [Prayer setup](quickshell/PRAYER-SETUP.md).
