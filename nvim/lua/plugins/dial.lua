return {
	{
		'monaqa/dial.nvim',
		config = function()
			local augend = require 'dial.augend'
			local my_dial_api = require 'my_lua_api.dial'
			--  TODO: add ft support
			require('dial.config').augends:register_group {
				default = {
					augend.integer.alias.decimal_int,
					augend.integer.alias.hex,
					augend.integer.alias.octal,
					augend.integer.alias.binary,
					augend.date.alias['%Y/%m/%d'],
					augend.constant.alias.bool,
					augend.constant.new { elements = { 'let', 'const' }, cyclic = true },
					augend.constant.new { elements = { 'and', 'or' }, word = true, cyclic = true },
					augend.constant.new { elements = { '&&', '||' }, word = true, cyclic = true },
					augend.constant.new { elements = { '- [ ]', '- [x]' }, word = true, cyclic = true },
					augend.hexcolor.new { case = 'lower' },
					augend.user.new {
						find = my_dial_api.inline_constant_find,
						add = my_dial_api.inline_constant_add,
					},
				},
			}
		end,
	},
}
