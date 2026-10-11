# Development reconstruction

These commits were prepared from the sanitized package and selected local
snapshots. They are a reconstruction, not the original Git history. No local
Git history was available in the package, its working parent, or the active
Hyprland configuration. Commit timestamps record this publication work; no
historical author dates have been invented.

The earliest coherent baseline retains the shell, panels and controls, theme
assets, prayer support and performance implementation together. The older
snapshots are partial and do not establish safe independent stages for those
features. Desktop integration is grouped separately as a logical packaging
step, using the final sanitized modules rather than copying private bindings.

The subsequent media sequence is supported by saved before-change files:

| Reference snapshot | Reconstructed change |
| --- | --- |
| `media-player-drag-20261011` → `browser-tab-drag-20261011` | Enumerate MPRIS players, select by swipe/keyboard, target transport and seeking |
| `browser-tab-drag-20261011` → `media-carousel-20261011` and later backend snapshot | Recognize browser-tab players, suppress duplicate shared cards, smooth switching |
| `media-carousel-20261011` → `latest-media-first-20261011` | Slide complete cards alongside each other and settle on release |
| `latest-media-first-20261011` → sanitized final package | Track playback recency and select the latest player each time the menu opens |

The final package also contains notch workspace and width refinements absent
from the older snapshots. They are grouped after the media work for review;
the snapshots do not establish their exact development time. The final setup
commit corrects public installation guidance and exposes the already supported
local azan paths while keeping the endpoint, location and audio paths blank.

Only selected source changes were reconstructed. Private snapshots, settings,
editor dumps, timetables and captured artwork are not distributed. Every staged
tree is reviewed for personal paths, secrets, blank prayer defaults, portable
integration and excluded local state. Licenses and upstream attribution remain
included. See [Publication checks](PUBLICATION-CHECKS.md) for validation and
limits. Pushing requires separate approval and inspection of the intended
repository's existing history.
