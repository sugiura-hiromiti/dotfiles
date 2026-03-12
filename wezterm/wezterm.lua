local wz = require 'wezterm' ---@type Wezterm
local act = wz.action

local function get_appearance()
	if wz.gui then
		return wz.gui.get_appearance()
	end
end

local function scheme_for_appearance(appearance)
	if appearance:find 'Light' then
		return 'Catppuccin Latte'
	else
		return 'Catppuccin Frappe'
	end
end

local cp_mode
if wz.gui then
	cp_mode = wz.gui.default_key_tables().copy_mode
	local meta_ops = {
		{ key = 'LeftArrow', mods = 'NONE', action = act.AdjustPaneSize { 'Left', 1 } },
		{ key = 'RightArrow', mods = 'NONE', action = act.AdjustPaneSize { 'Right', 1 } },
		{ key = 'UpArrow', mods = 'NONE', action = act.AdjustPaneSize { 'Up', 1 } },
		{ key = 'DownArrow', mods = 'NONE', action = act.AdjustPaneSize { 'Down', 1 } },
	}

	for i = 1, 4 do
		table.insert(cp_mode, meta_ops[i])
	end
end

local function conf_per_os(value)
	local target_tuple = wz.target_triple
	local is_aarch64 = target_tuple:find 'aarch64' ~= nil
	local is_linux = target_tuple:find 'linux' ~= nil

	if is_aarch64 then
		if is_linux then
			return value.aarch64_linux
		else
			return value.aarch64_darwin
		end
	else
		if is_linux then
			return value.x86_64_linux
		else
			return value.x86_64_darwin
		end
	end
end

-- wz.on('opacity', function(window, _)
-- 	local overrides = window:get_config_overrides() or {}
-- 	if not overrides.window_background_opacity then
-- 		overrides.window_background_opacity = 0.55
-- 		overrides.text_background_opacity = 8.0
-- 	else
-- 		overrides.window_background_opacity = nil
-- 		overrides.text_background_opacity = nil
-- 	end
-- 	window:set_config_overrides(overrides)
-- end)

-- local palette = wz.color.get_builtin_schemes()[scheme_for_appearance(get_appearance())]

local conf = wz.config_builder()
conf.animation_fps = 60
conf.allow_win32_input_mode = false
conf.check_for_updates = false
conf.cell_width = 0.9
conf.color_scheme = scheme_for_appearance(get_appearance())
conf.disable_default_key_bindings = true
conf.font = wz.font { family = 'PlemolJP Console NF' }
conf.font_size = conf_per_os { aarch64_linux = 12, aarch64_darwin = 16 }
conf.foreground_text_hsb = { saturation = 1.1, brightness = 1.1 }
conf.freetype_load_target = 'Light'
conf.front_end = 'WebGpu'
conf.hide_tab_bar_if_only_one_tab = true
conf.keys = {
	-- { key = 'o', mods = 'CMD|SHIFT', action = act.EmitEvent 'opacity' },
	{ key = 'c', mods = 'SHIFT|CMD', action = act.ActivateCopyMode },
	{ key = 'Tab', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev' },
	-- { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
	-- { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1) },
	{ key = 'c', mods = 'CMD', action = act.CopyTo 'Clipboard' },
	{ key = 'w', mods = 'CMD', action = act.CloseCurrentPane { confirm = false } },
	-- { key = 'b', mods = 'CMD', action = act.EmitEvent 'bg' },
	{ key = 'v', mods = 'CMD', action = act.PasteFrom 'Clipboard' },
	-- { key = 'q', mods = 'CMD', action = act.QuitApplication },
	{ key = 'r', mods = 'CMD', action = act.ReloadConfiguration },
	{ key = 'f', mods = 'CMD', action = act.Search { CaseSensitiveString = '' } },
	-- { key = 't', mods = 'CMD', action = act.SpawnTab 'DefaultDomain' },
	-- { key = 'n', mods = 'CMD', action = act.SpawnTab 'DefaultDomain' },
	{
		key = 'd',
		mods = 'CMD',
		action = act.SplitHorizontal {},
	},
	{
		key = 'd',
		mods = 'CMD|SHIFT',
		action = act.SplitVertical {},
	},
}
conf.key_tables = { copy_mode = cp_mode }
conf.max_fps = 120
conf.pane_focus_follows_mouse = true
conf.prefer_to_spawn_tabs = true
conf.send_composed_key_when_left_alt_is_pressed = true
conf.send_composed_key_when_right_alt_is_pressed = true
conf.scrollback_lines = 400
conf.use_ime = true
conf.tab_bar_at_bottom = true
-- conf.window_background_gradient = { orientation = 'Horizontal', colors = { '#66aaff88', '#ff553388' } }
conf.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
conf.window_decorations = conf_per_os { aarch64_linux = 'NONE', aarch64_darwin = 'RESIZE' }
conf.window_close_confirmation = 'NeverPrompt'
conf.macos_window_background_blur = 128
conf.kde_window_background_blur = true

return conf

-- return {
-- 	animation_fps = 60,
-- 	allow_win32_input_mode = false,
-- 	check_for_updates = false,
-- 	cell_width = 0.9,
-- 	color_scheme = scheme_for_appearance(get_appearance()),
-- 	disable_default_key_bindings = true,
-- 	-- dpi = 110,
-- 	-- enable_csi_u_key_encoding=false,
-- 	font = wz.font { family = 'PlemolJP Console NF' },
-- 	font_size = conf_per_os { aarch64_linux = 12, aarch64_darwin = 16 },
-- 	-- foreground_text_hsb = { saturation = 1.1, brightness = 1.1 },
-- 	freetype_load_target = 'Light',
-- 	front_end = 'WebGpu',
-- 	hide_tab_bar_if_only_one_tab = true,
-- 	-- this does not take effects on macOS: ime_preedit_rendering = 'System',
-- 	-- line_height = 0.95,
-- 	keys = {
-- 		-- { key = 'o', mods = 'CMD|SHIFT', action = act.EmitEvent 'opacity' },
-- 		{ key = 'c', mods = 'SHIFT|CMD', action = act.ActivateCopyMode },
-- 		{ key = 'Tab', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev' },
-- 		-- { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
-- 		-- { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1) },
-- 		{ key = 'c', mods = 'CMD', action = act.CopyTo 'Clipboard' },
-- 		{ key = 'w', mods = 'CMD', action = act.CloseCurrentPane { confirm = false } },
-- 		-- { key = 'b', mods = 'CMD', action = act.EmitEvent 'bg' },
-- 		{ key = 'v', mods = 'CMD', action = act.PasteFrom 'Clipboard' },
-- 		-- { key = 'q', mods = 'CMD', action = act.QuitApplication },
-- 		{ key = 'r', mods = 'CMD', action = act.ReloadConfiguration },
-- 		{ key = 'f', mods = 'CMD', action = act.Search { CaseSensitiveString = '' } },
-- 		-- { key = 't', mods = 'CMD', action = act.SpawnTab 'DefaultDomain' },
-- 		-- { key = 'n', mods = 'CMD', action = act.SpawnTab 'DefaultDomain' },
-- 		{
-- 			key = 'd',
-- 			mods = 'CMD',
-- 			action = act.SplitHorizontal {},
-- 		},
-- 		{
-- 			key = 'd',
-- 			mods = 'CMD|SHIFT',
-- 			action = act.SplitVertical {},
-- 		},
-- 		-- { key = 'f', mods = 'CTRL|CMD', action = act.ToggleFullScreen },
-- 	},
-- 	key_tables = { copy_mode = cp_mode },
-- 	max_fps = 120,
-- 	--native_macos_fullscreen_mode = false,
-- 	pane_focus_follows_mouse = true,
-- 	prefer_to_spawn_tabs = true,
-- 	scrollback_lines = 400,
-- 	use_ime = true,
-- 	tab_bar_at_bottom = true,
-- 	window_background_opacity = conf_per_os { aarch64_linux = 1.0, aarch64_darwin = 0.85 },
-- 	window_padding = { left = 0, right = 0, top = 0, bottom = 0 },
-- 	window_decorations = conf_per_os { aarch64_linux = 'NONE', aarch64_darwin = 'RESIZE' },
-- 	window_close_confirmation = 'NeverPrompt',
-- 	macos_window_background_blur = 35,
-- 	--window_background_image='/path/to/img.jpg' png, gif also vaild extensiton
-- }
