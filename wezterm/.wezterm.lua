local wezterm = require("wezterm")
local config = {}

config.default_domain = "WSL:Ubuntu"
config.font = wezterm.font_with_fallback({
	"MesloLGS NF",
	"JetBrains Mono",
})
config.warn_about_missing_glyphs = false
config.font_size = 10.5

return config
