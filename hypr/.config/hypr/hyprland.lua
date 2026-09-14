-- #######################################################################################
-- HYPRLAND CONFIG (Lua)
-- Migrated from hyprland.conf + colors.conf — hyprlang is deprecated as of 0.55 and is
-- dropped in 0.57. Refer to the wiki: https://wiki.hypr.land/Configuring/Start/
-- #######################################################################################

----------------
---- COLORS ----
----------------

-- Previously ~/.config/hypr/colors.conf, sourced as hyprlang $variables. In Lua these are
-- ordinary locals, so the separate file buys nothing and is folded in here.
local activeBorderColor = "rgba(600fd0aa)"
local inactiveBorderColor = "rgba(595959aa)"

------------------
---- MONITORS ----
------------------

-- Monitor name aliases
local left = "HDMI-A-1"
local center = "DP-2"
local right = "DP-3"

-- Home office — Left | Center | Right
hl.monitor({ output = left, mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = center, mode = "2560x1440@144", position = "2560x0", scale = 1 })
hl.monitor({ output = right, mode = "2560x1440@144", position = "5120x0", scale = 1 })

-- Place cursor on center monitor at startup
hl.config({
	cursor = {
		default_monitor = center,
	},
})

-- Workspaces 1-5 on left, 6-10 on center, 11-15 on right.
-- The first two of each group are persistent so the bar always shows them.
local workspaceMonitors = {
	[left] = { first = 1, persistent = { 1, 2 } },
	[center] = { first = 6, persistent = { 6, 7 }, default = 6 },
	[right] = { first = 11, persistent = { 11, 12 } },
}

for _, monitor in ipairs({ left, center, right }) do
	local group = workspaceMonitors[monitor]
	for id = group.first, group.first + 4 do
		local persistent = false
		for _, p in ipairs(group.persistent) do
			if p == id then
				persistent = true
			end
		end

		hl.workspace_rule({
			workspace = tostring(id),
			monitor = monitor,
			persistent = persistent or nil,
			default = (group.default == id) or nil,
		})
	end
end

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "ghostty"
local fileManager = "dolphin"
local menu = "wofi --show drun"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("hypridle")
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/random-hyprpaper.sh")
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-waybar-with-mouse.sh")

	-- Dunst requires XWayland. Only one notification daemon may run at a time — make sure
	-- mako/swaync are not also autostarting.
	hl.exec_cmd("dunst")

	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/caps-lock.sh watch")

	-- Holds a systemd idle inhibitor while audio plays, so hypridle's 300s lock
	-- and 330s blank listeners can't straddle a track ending — which previously
	-- skipped the lock but blanked the screens anyway. See the script.
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/audio-idle-inhibit.sh")

	-- Force Zoom to fully quit when its last window closes (it otherwise hides-not-quits
	-- and lingers in the background with no tray to quit it). See the script for details.
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/zoom-autoquit.sh")

	hl.exec_cmd("sunshine")
	hl.exec_cmd("spotify-launcher", { workspace = "12 silent" })
	hl.exec_cmd("ghostty", { workspace = "7 silent" })

	-- Static GTK theme preferences. These were `exec` (re-run on every reload) in the old
	-- config; once at startup is enough.
	hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"')
	hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require a Hyprland restart and are not applied on-the-fly.

-- hl.config({ ecosystem = { enforce_permissions = true } })

-- hl.permission({ binary = "/usr/(bin|local/bin)/grim", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 2,

		border_size = 2,

		col = {
			active_border = activeBorderColor,
			inactive_border = inactiveBorderColor,
		},

		-- Resize windows by clicking and dragging on borders and gaps
		resize_on_border = true,

		-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before enabling
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 4,
		rounding_power = 2.0,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
	dwindle = {
		-- NOTE: dwindle:pseudotile was removed in a recent Hyprland release; pseudotiling
		-- is now purely dispatcher-driven via `pseudo` (bound to mainMod + P below).
		-- preserve_split kept a split's orientation locked once created; with a tall
		-- window (e.g. Steam) that wedged a neighbor into a partial-height pane. Off =
		-- dwindle re-balances splits automatically so panes fill their container.
		preserve_split = false,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = -1, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo = true, -- Disables the random hyprland logo / anime girl background
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = 0.85, -- -1.0 - 1.0, 0 means no modification.

		accel_profile = "flat",

		touchpad = {
			natural_scroll = false,
		},
	},
})

-- Example per-device config
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))

-- Smart close: normal window close for most apps, but fully quit known-problematic apps
-- (currently just Zoom, whose home window re-spawns instead of quitting on a plain close).
-- The app list + kill logic lives in the script. See kill-focused-app.sh for the why.
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(scripts .. "/kill-focused-app.sh"))

hl.bind(mainMod .. " + X", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("spotify-launcher"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("helium-browser"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"))

-- Toggle waybar (hide/show by process)
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("pkill -x waybar || (waybar & disown)"))
-- Restart waybar
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("pkill waybar && sleep 1 && hyprctl dispatch exec waybar"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd('notify-send "Workspace $(hyprctl activeworkspace -j | jq -r .id)"'))

hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(scripts .. "/lock-and-pause.sh"))

-- Suspend keybind disabled: this machine (RX 7900 XT / Navi 31) hits an amdgpu SMU
-- suspend/resume bug — "suspend of IP block <smu> failed -22", the GPU reset fails and
-- the card wedges (fans 100%, power button dead, requires a forced power-off).
-- Intermittent; s2idle reduced but did not eliminate it. It's a kernel/driver bug, not
-- fixable from scripts. Use mainMod + L to just lock. Re-enable once amdgpu is fixed.
-- hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(scripts .. "/sleep.sh"))

for i = 1, 3 do
	hl.bind(mainMod .. " + CTRL + " .. i, hl.dsp.exec_cmd(scripts .. "/change-monitor-scaling.sh " .. i))
end

-- Localhost apps — open as dedicated app windows (Chromium --app)
-- Convention: config/admin apps share the primary app's key with an extra CTRL modifier.
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("helium-browser --app=http://localhost:7000")) -- Odysseus
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("helium-browser --app=http://localhost:8080")) -- ollama (admin)

-- Single-monitor toggle — collapse onto Left/Center/Right; press again to restore
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(scripts .. "/single-monitor-toggle.sh L"))
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd(scripts .. "/single-monitor-toggle.sh C"))
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd(scripts .. "/single-monitor-toggle.sh R"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [1-5] (relative to focused monitor), and move the
-- active window there with mainMod + SHIFT + [1-5]. Both go through the helper script,
-- which resolves the slot against whichever monitor currently has focus.
for i = 1, 5 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.exec_cmd(scripts .. "/workspace-switch.sh " .. i))
	hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.exec_cmd(scripts .. "/workspace-switch.sh " .. i .. " move"))
end

-- Screenshot region to clipboard (click and drag to select)
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- Special workspace (scratchpad) — moved off Super+S to make room for screenshots
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Global mic mute: toggles ALL real input sources at once (mixed state -> mute all)
hl.bind("ALT + CTRL + SUPER + SHIFT + F1", hl.dsp.exec_cmd(scripts .. "/mic-mute.sh toggle"))

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Zoom popup fix: Zoom's menus and confirm dialogs self-close when they lose focus.
-- This rule was unavailable on 0.55/0.56 hyprlang (the `windowrule` keyword was removed
-- when window rules moved to the Lua API) and was deferred until this migration.
hl.window_rule({
	name = "zoom-menu-stay-focused",
	match = { class = "zoom", title = "menu window" },

	stay_focused = true,
})

hl.window_rule({
	name = "zoom-confirm-stay-focused",
	match = { class = "zoom", title = "confirm window" },

	stay_focused = true,
})

-- "Smart gaps" / "No gaps when only" — uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
