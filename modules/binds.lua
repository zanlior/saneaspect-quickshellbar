local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local shellPath = config .. "/hypr/quickshell"
local function shellQuote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
local qs = "quickshell -p " .. shellQuote(shellPath) .. " ipc call island "

-- binds.lua

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local mod = "ALT"

-- ── Kill / Session ────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + K",                hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + C",                hl.dsp.window.close())
hl.bind(mainMod .. " + CTRL + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + M",                hl.dsp.exec_cmd(qs .. "toggle power"))

-- ── Terminals ─────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + Return",                hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + CTRL + SHIFT + Return", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + SHIFT + Return",        hl.dsp.exec_cmd("foot"))

-- ── Screenshots ───────────────────────────────────────────────────────────────
hl.bind("Print",       hl.dsp.exec_cmd("grim ~/Pictures/screenshot-$(date +'%Y%m%d-%H%M%S').png"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | satty --filename - --initial-tool brush --copy-command wl-copy'))


-- ── File Managers ─────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus"))

-- ── App Launcher ──────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qs .. "toggle launcher"))

-- ── Bar ───────────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(qs .. "bar"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(qs .. "game"))


-- ── Titlebars (hyprbars plugin) ───────────────────────────────────────────────
local hyprbars = "/var/cache/hyprpm/" .. assert(os.getenv("USER"), "USER is required") .. "/hyprland-plugins/hyprbars.so"
hl.bind(mainMod .. " + Y",         hl.dsp.exec_cmd("hyprctl plugin load "   .. hyprbars))
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("hyprctl plugin unload " .. hyprbars))

-- ── Layout switching ──────────────────────────────────────────────────────────
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.exec_cmd("hyprctl keyword general:layout master"))

-- ── Browser ───────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("brave-origin-beta"))

-- ── Wallpaper / Theme ─────────────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(qs .. "toggle wallpapers"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(qs .. "toggle themes"))

-- ── Notification Center (swaync) ──────────────────────────────────────────────
hl.bind(mainMod .. " + A",                hl.dsp.exec_cmd(qs .. "toggle control"))
hl.bind(mainMod .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd(qs .. "refresh"))

-- ── Color picker ──────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprpicker -a"))

-- ── Lock screen/ Logout menu ───────────────────────────────────────────────────────────────
-- NOTE: Both were bound to SUPER+L originally — pick one and remove the other
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(qs .. "lock"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd(qs .. "toggle power"))

-- ── Night mode ────────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(qs .. "night"))

-- ── Blitz Mode ────────────────────────────────────────────────────────────────
hl.bind("SUPER + F1", hl.dsp.exec_cmd(qs .. "game"))

-- ── Volume ────────────────────────────────────────────────────────────────────
hl.bind(mod .. " + F2", hl.dsp.exec_cmd(qs .. "volumeStep -5"), { locked = true, repeating = true })
hl.bind(mod .. " + F3", hl.dsp.exec_cmd(qs .. "volumeStep 5"), { locked = true, repeating = true })

-- ── Brightness ────────────────────────────────────────────────────────────────
hl.bind(mod .. " + F11", hl.dsp.exec_cmd(qs .. "brightnessStep -5"), { locked = true, repeating = true })
hl.bind(mod .. " + F12", hl.dsp.exec_cmd(qs .. "brightnessStep 5"), { locked = true, repeating = true })

-- ── Music panel ─────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(qs .. "toggle media"))

-- ── Media ─────────────────────────────────────────────────────────────────────
hl.bind(mod .. " + F9",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind(mod .. " + F10", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- ALT+F11 conflicts with brightness above; reassign if needed:
-- hl.bind(mod .. " + F11", hl.dsp.exec_cmd("playerctl next"), { locked = true })

-- ── OBS: pass recording shortcut ─────────────────────────────────────────────
hl.bind("CTRL + SUPER + R", hl.dsp.pass({ window = "class:^(com\\.obsproject\\.Studio)$" }))

-- ── Clipboard history ─────────────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + V",
    hl.dsp.exec_cmd(qs .. "toggle clipboard"))

-- ── Window management ─────────────────────────────────────────────────────────
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- ── Focus movement ────────────────────────────────────────────────────────────
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- ── Workspaces ────────────────────────────────────────────────────────────────
for i = 1, 10 do
    local key = i % 10  -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- ── Special workspace (scratchpad) ────────────────────────────────────────────
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- ── Scroll through workspaces ─────────────────────────────────────────────────
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ── Move / resize windows with mouse ─────────────────────────────────────────
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Binds config ──────────────────────────────────────────────────────────────
hl.config({
    binds = {
        allow_pin_fullscreen = true,
    },
})

-- Island settings
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(qs .. "settings"))

-- Island calendar
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(qs .. "toggle calendar"))

-- Island bar style
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(qs .. "toggle bars"))

-- Prayer times
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(qs .. "toggle prayers"))
