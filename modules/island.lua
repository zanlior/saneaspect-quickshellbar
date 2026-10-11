-- Start Island from the user's config directory and load generated palette.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local function shellQuote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
hl.on("hyprland.start", function()
    hl.exec_cmd(shellQuote(config .. "/hypr/quickshell/scripts/start.sh"))
end)
dofile(config .. "/hypr/modules/island-colors.lua")
