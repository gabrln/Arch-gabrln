-- =========================================================================
-- Hyprland Lua Configuration (v0.55+)
-- Custom Scrolling Layout Setup matching Niri workflows
-- =========================================================================

-- Core compositor options
hl.config({
    general = {
        layout = "scrolling",
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        ["col.active_border"] = "rgba(33ccffee) rgba(00ff99ee) 45deg",
        ["col.inactive_border"] = "rgba(595959aa)",
    },
    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.5,
        direction = "right",
    },
    decoration = {
        rounding = 5,
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            vibrancy = 0.1696,
        },
    },
    input = {
        kb_layout = "br",
        follow_mouse = 1,
    },
    misc = {
        disable_hyprland_logo = true,
    }
})

-- Window rules for Scratchpads (Special Workspaces)
hl.window_rule({
    match = { class = "kitty-drop" },
    workspace = "special:kitty-drop",
    float = true,
    size = "1600 900"
})

hl.window_rule({
    match = { class = "btop-scratch" },
    workspace = "special:btop-scratch",
    float = true,
    size = "1600 900"
})

hl.window_rule({
    match = { class = "keyhints-scratch" },
    workspace = "special:keyhints-scratch",
    float = true,
    size = "1200 800"
})

-- General window rules (CSD, floating dialogs, browser maximize)
hl.window_rule({
    match = { class = "firefox" },
    maximize = true
})
hl.window_rule({
    match = { class = "google-chrome" },
    maximize = true
})
hl.window_rule({
    match = { class = "code" },
    maximize = true
})
hl.window_rule({
    match = { class = "obsidian" },
    maximize = true
})

-- Floating dialogs
hl.window_rule({
    match = { title = "Picture-in-Picture" },
    float = true
})
hl.window_rule({
    match = { title = "Open File" },
    float = true
})
hl.window_rule({
    match = { title = "Save File" },
    float = true
})

-- Keybindings
local mod = "SUPER"

-- Core operations
hl.bind(mod .. ", Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " SHIFT, Q", function() hl.dispatch("killactive", "") end)
hl.bind("CTRL ALT, Delete", function() hl.dispatch("exit", "") end)

-- Focus movement (Vim keys)
hl.bind(mod .. ", H", function() hl.dispatch("movefocus", "l") end)
hl.bind(mod .. ", L", function() hl.dispatch("movefocus", "r") end)
hl.bind(mod .. ", K", function() hl.dispatch("movefocus", "u") end)
hl.bind(mod .. ", J", function() hl.dispatch("movefocus", "d") end)

-- Move windows (Vim keys)
hl.bind(mod .. " SHIFT, H", function() hl.dispatch("movewindow", "l") end)
hl.bind(mod .. " SHIFT, L", function() hl.dispatch("movewindow", "r") end)
hl.bind(mod .. " SHIFT, K", function() hl.dispatch("movewindow", "u") end)
hl.bind(mod .. " SHIFT, J", function() hl.dispatch("movewindow", "d") end)

-- Scrolling layout specific binds
hl.bind(mod .. ", period", hl.dsp.layout("move +col"))
hl.bind(mod .. ", comma", hl.dsp.layout("move -col"))
hl.bind(mod .. " SHIFT, period", hl.dsp.layout("swapcol r"))
hl.bind(mod .. " SHIFT, comma", hl.dsp.layout("swapcol l"))

-- Workspaces switching and window moving (1 to 9)
for i = 1, 9 do
    hl.bind(mod .. ", " .. i, function() hl.dispatch("workspace", tostring(i)) end)
    hl.bind(mod .. " SHIFT, " .. i, function() hl.dispatch("movetoworkspace", tostring(i)) end)
end

-- Scratchpads (Toggle Special Workspaces)
hl.bind(mod .. " SHIFT, Return", function() hl.dispatch("togglespecialworkspace", "kitty-drop") end)
hl.bind(mod .. ", F1", function() hl.dispatch("togglespecialworkspace", "btop-scratch") end)
hl.bind(mod .. ", Slash", function() hl.dispatch("togglespecialworkspace", "keyhints-scratch") end)

-- Media and controls mapped through Noctalia / system tools
hl.bind(mod .. ", F2", hl.dsp.exec_cmd("noctalia msg mic-mute"))
hl.bind("CTRL ALT, L", hl.dsp.exec_cmd("noctalia msg session lock"))

-- Autostart
hl.on("hyprland.start", function()
    -- Start shell and system utilities
    hl.exec_cmd("noctalia")
    hl.exec_cmd("wl-clip-persist --clipboard regular --reconnect-tries 0")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("flatpak run com.github.wwmm.easyeffects --gapplication-service")

    -- Pre-spawn scratchpad processes inside their special workspaces
    hl.exec_cmd("kitty --class kitty-drop")
    hl.exec_cmd("kitty --class btop-scratch -e btop")
    hl.exec_cmd("kitty --class keyhints-scratch -e /home/gabrln/.config/niri/scripts/KeyHints.sh")
end)
