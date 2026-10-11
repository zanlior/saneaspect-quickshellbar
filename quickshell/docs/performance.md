# Runtime performance

The backend keeps slower work away from the UI command loop. Preference changes run in order on a dedicated lane: each worker receives a settings snapshot, and the main thread adopts its result only when that operation completes. Monitor and night-light changes have their own ordered lanes. Other blocking commands run asynchronously by resource, so a theme update does not hold up controls, service polling, or reminder ticks.

Wallpaper paths are kept as a snapshot for the active theme and folder. The list is refreshed when either setting changes, after reset changes the effective selection, and whenever the wallpaper page opens. Opening the page also discovers files added outside Island; equal lists do not trigger another list update.

Commands invalidate the service data they can change. Entering a detail page refreshes only that page’s data. Audio, Wi-Fi, desktop, and display event subscriptions trigger prompt refreshes, with polling as a fallback and periodic reconciliation. Connected audio state and workspace state (when the notch is enabled) reconcile every 30 seconds. Display metadata is also cached between full reads; brightness continues at 2 seconds, media at 1 second, and Wi-Fi at 5 seconds. See the [Hyprland IPC reference](https://wiki.hypr.land/IPC/) and [PulseAudio command-line reference](https://wiki.freedesktop.org/www/Software/PulseAudio/Documentation/User/CLI/).

Destination verification passed all 56 Python tests with `ResourceWarning` treated as an error. The offscreen QML suite passed all 53 tests. A baseline run from the backed-up test file reproduced three stale assertions against the unchanged runtime; those checks now cover the current prayer preview, side panel width, and theme selection behavior. Use the current commands in [Verification](../README.md#verification) to repeat these checks.

The standalone benchmark `python3 tests/benchmark_polling.py` compares a fixed pre-change schedule (audio 1 s, desktop 0.5 s, display 2 s, Wi-Fi 5 s, media 1 s) with the optimized polling helpers. In 30 simulated idle seconds with notch enabled, event streams connected, and no active player, it counted 348 baseline queries and 71 optimized queries, a 79.6% reduction in this mock workload. It excludes DDC and persistent watcher startup. This measures mocked query counts only; live CPU and frame-time measurements were unavailable.

Hyprland autostart and keybindings use `"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell"`, so restart the running instance to load backend edits:

```sh
quickshell kill -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell"
"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/quickshell"/scripts/start.sh
```
