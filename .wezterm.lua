local wezterm = require("wezterm")

return {
	default_domain = "WSL:Ubuntu",
	font = wezterm.font_with_fallback({
		"MesloLGS NF",
		"JetBrains Mono",
	}),
	warn_about_missing_glyphs = false,
	font_size = 10.5,
	enable_scroll_bar = false,
	window_padding = {
		top = 0,
		right = 0,
		left = 0,
		bottom = 0,
	},
	enable_tab_bar = false,
	window_close_confirmation = "NeverPrompt",
}
