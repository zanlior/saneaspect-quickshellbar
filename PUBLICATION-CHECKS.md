# Publication checks

Scope: active keybindings and autostart modules plus Quickshell and its required
palette integration. Other desktop configuration modules are excluded. The root
`hyprland.lua` is an integration example to merge into an existing Lua config.

The eight local commits are explicitly reconstructed. The initial shell retains
panels, controls, themes, prayer support and runtime scheduling together because
partial snapshots do not establish reliable independent stages. Selected media
snapshots support the later refinement sequence. See [Development
reconstruction](DEVELOPMENT.md) for evidence and placement limits. No historical
author dates or original-history claims were invented.

Validation:

- All eight stages passed the 61 included Python tests with `ResourceWarning`
  treated as an error and the 53 included offscreen QML checks.
- Stage-specific mocked checks verified single-player controls, MPRIS instance
  selection, targeted transport/seeking, browser duplicate suppression and
  playback recency. Focused offscreen checks verified keyboard/swipe selection,
  adjacent carousel pages, latest-player reopening and stable open-menu order.
  The final focused QML run passed all eight checks, including occupied notch
  workspaces, reserved clock space, blank defaults and configurable audio fields.
- The existing Wi-Fi timing test failed on one intermediate full run, then the
  full stage suite passed on retry. No desktop or device actions were used to
  resolve it. The final full Python run passed all 61 tests.
- All 75 expanded bindings match the live reference, including dispatcher
  options. Autostart matches byte-for-byte. All included Lua and Python source
  passed syntax checks; launcher shell scripts passed `bash -n`.
- JSON and JavaScript defaults agree. The prayer API URL, city, country and
  audio paths are blank in every intermediate tree.
- `qmllint` reported no errors but emitted warnings, including unresolved
  Quickshell Polkit types and QML property/type diagnostics. It is not a clean
  lint pass. The offscreen runtime tests passed; live session behavior remains
  outside this publication check.

Privacy review: each staged Git index was exported and reviewed before its
commit, including source and binary bytes. Scans found no current-user paths or
identifiers, common access-token patterns, private-key headers or captured
personal prayer location. Named network and media preview samples were replaced
with generic examples in every stage. Public calculation-method labels and
upstream author/license attribution remain. The upstream media-helper binary
contains its original build path; it is not a current-user path.

Private snapshots, runtime settings, timetables, credentials, wallpapers,
artwork, editor dumps, nested repositories and cached bytecode are excluded.
Local publication metadata and verification logs are excluded too. Existing
vendor source and licenses remain intact, including two reviewed source assets
that upstream ignore rules would otherwise omit. Original relative vendor asset links are preserved in every stage; every
target stays inside the package. Imported vendor whitespace and the exact
reference autostart formatting are preserved.

The final commit is checked against the sanitized package for identical file
contents and executable modes. Commit author and committer metadata use a
GitHub noreply identity. Commits are local; nothing has been uploaded. The
intended repository's existing history must be inspected before proposing a
push, and pushing requires separate approval.

Limits: pattern scans cannot establish the absence of every kind of private
information. Automated checks use mocks and offscreen rendering; they do not
start the live shell, install modules, apply settings, lock the desktop or
change devices. Prayer functionality requires the installing user's API,
location and optional audio configuration; see [Prayer setup](quickshell/PRAYER-SETUP.md).
External applications, compositor Lua API support and hardware capabilities
remain installation requirements.
