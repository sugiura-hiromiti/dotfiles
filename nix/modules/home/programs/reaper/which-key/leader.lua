local menus = {
	main = {
		i = {
			label = 'Insert',
			children = {
				m = {
					label = 'midi item',
					command = 40214,
				},
				e = {
					label = 'empty item',
					command = 40142,
				},
			},
		},
	},
	midiEditor = {},
}

local _, _, section = reaper.get_action_context()

-- 今のセクションを調べる
local midi = section == 32060
local editor = midi and reaper.MIDIEditor_GetActive() or nil

if midi and not editor then return end

local current = midi and menus.midiEditor or menus.main
local stack = {}

local function execute(command)
	if midi then
		reaper.MIDIEditor_OnCommand(editor, command)
	else
		reaper.Main_OnCommand(command, 0)
	end
end

local function handle_key(key)
	if key == 27 then return 'quit' end
	if key == 8 then
		if #stack > 0 then
			current = table.remove(stack)
		else
			return 'quit'
		end
		return 'continue'
	end
	if key < 32 or key > 126 then return 'continue' end

	local name = string.char(key):lower()
	local entry = current[name]
	if not entry then return 'quit' end

	if entry.children then
		stack[#stack + 1] = current
		current = entry.children
		return 'continue'
	end

	if entry.command then return 'execute', entry.command end

	return 'continue'
end

local function draw()
	gfx.set(0.10, 0.10, 0.12, 1)
	gfx.rect(0, 0, gfx.w, gfx.h)

	gfx.setfont(1, 'sans-serif', 16)
	gfx.set(1, 1, 1, 1)

	local keys = {}
	for key in pairs(current) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	for i, key in ipairs(keys) do
		local entry = current[key]
		gfx.x = 20
		gfx.y = 16 + (i - 1) * 28
		gfx.drawstr(key .. '\t' .. entry.label)
	end

	gfx.update()
end

gfx.init('which key', 420, 260)

local function loop()
	local key = gfx.getchar()

	if key == -1 then return end

	if key > 0 then
		local result, command = handle_key(key)
		if result == 'quit' then
			gfx.quit()
			return
		elseif result == 'execute' then
			gfx.quit()
			execute(command)
			return
		end
	end

	draw()
	reaper.defer(loop)
end

loop()
