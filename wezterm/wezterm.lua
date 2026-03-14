local wz = require 'wezterm' ---@type Wezterm
local act = wz.action

local function get_appearance()
	if wz.gui then return wz.gui.get_appearance() end
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

---@generic T
---@param value table
---@return T
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

---@class RGB
---@field r integer
---@field g integer
---@field b integer

---@param color_code string
---@return RGB
local function extract_rgb(color_code)
	local r = color_code:sub(2, 3)
	local g = color_code:sub(4, 5)
	local b = color_code:sub(6, 7)
	return { r = tonumber(r, 16), g = tonumber(g, 16), b = tonumber(b, 16) }
end

---@param a RGB
---@param b RGB
---@param ratio decimal
---@return RGB
local function mix_rgb_class(a, b, ratio)
	return {
		r = math.floor(a.r * (1 - ratio) + b.r * ratio),
		g = math.floor(a.g * (1 - ratio) + b.g * ratio),
		b = math.floor(a.b * (1 - ratio) + b.b * ratio),
	}
end

---@param rgb RGB
local function stringify_rgb(rgb)
	return '#' .. string.format('%02x', rgb.r) .. string.format('%02x', rgb.g) .. string.format('%02x', rgb.b)
end

---@param base string
---@param texture string
---@param ratio decimal
---@return string
local function mix_color_code(base, texture, ratio)
	local base_head = base:sub(1, 1)
	local texture_head = texture:sub(1, 1)
	if base_head ~= '#' and texture_head ~= '#' and ratio > 0 and ratio < 1 then return base end

	local base_rgb = extract_rgb(base)
	local texture_rgb = extract_rgb(texture)
	local mixed = mix_rgb_class(base_rgb, texture_rgb, ratio)
	local rslt = stringify_rgb(mixed)
	return rslt
end

local nullable_background = wz.color.get_builtin_schemes()[scheme_for_appearance(get_appearance())].background
local background_color = nullable_background and nullable_background or '#ffffff'

local conf = wz.config_builder()
conf.animation_fps = 60
conf.allow_win32_input_mode = false
conf.check_for_updates = false
conf.cell_width = 0.9
conf.color_scheme = scheme_for_appearance(get_appearance())
conf.disable_default_key_bindings = true
conf.font = wz.font { family = 'Maple Mono NF CN' }
conf.font_size = conf_per_os { aarch64_linux = 11, aarch64_darwin = 14 }
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
conf.window_background_gradient = {
	orientation = 'Horizontal',
	colors = { mix_color_code(background_color, '#66aaff', 0.17), mix_color_code(background_color, '#ff6a43', 0.15) },
}
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
