local augend = require 'dial.augend'
local elements = {}
local mod = {}

---@param line string
---@param cursor number
---comment find switchable case literals
mod.inline_constant_find = function(line, cursor)
	local pattern = 'case: (.+)$'
	local match = line:match(pattern)
	if not match then
		return
	end

	elements = {}
	for option in match:gmatch '^%s*(.-)%s*$' do
		table.insert(elements, option:match '^s*(.-)%s*$')
	end

	local regex_ptn = ([[\V\(%s\)]]):format(table.concat(elements, [[\|]]))
	return require('dial.augend.common').find_pattern_regex(regex_ptn, false)(line, cursor)
end

mod.inline_constant_add = function(txt, addend, cursor)
	local n_patterns = #elements
	local n = 1

	for i, elem in ipairs(elements) do
		if txt == elem then
			n = i
		end
	end
	n = (n + addend - 1) % n_patterns + 1
	txt = elements[n]
	cursor = #txt
	return { text = txt, cursor = cursor }
end

return mod
