local select = require 'my_lua_api.select'
local ui = require 'my_lua_api.ui'

return {
	'nvimtools/hydra.nvim',
	config = function()
		local te = require('telescope').extensions
		local tb = require 'telescope.builtin'
		local h = require 'hydra'
		local dropbar = require 'dropbar.api'
		local l = vim.lsp.buf

		h {
			name = 'palette',
			mode = { 'n', 'x' },
			body = '<space>',
			config = { color = 'teal', hint = { type = 'window', position = 'middle' } },
			hint = [[
_a_ code action _r_ rename
_d_ diagnostic  _o_ symbol
_h_ hover       _l_ list
_b_ builtin     _n_ notify
_f_ smart open  _x_ term
_c_ codelens    _e_ explorer
_g_ dropbar

<esc> exit
]],
			heads = {
				{
					'a',
					function()
						if vim.bo.ft == 'rust' then
							vim.cmd.RustLsp 'codeAction'
						else
							l.code_action()
						end
					end,
				},
				{ 'r', l.rename },
				{
					'h',
					function()
						if vim.bo.ft == 'rust' then
							vim.cmd.RustLsp { 'hover', 'actions' }
						elseif vim.bo.ft == 'haskell' then
							vim.cmd.Haskell 'hover'
						else
							l.hover()
						end
					end,
				},
				{ 'l', '<cmd>Lspsaga finder<cr>' },
				{ 'd', tb.diagnostics },
				{ 'o', select.symbols },
				{ 'b', tb.builtin },
				{ 'f', te.smart_open.smart_open },
				{ 'n', te.notify.notify },
				{ 'e', '<cmd>Yazi<cr>' },
				{ 'x', select.terminal },
				{
					'c',
					function() vim.lsp.codelens.run() end,
				},
				{ 'g', dropbar.pick },
				{ '<esc>', nil, { exit = true } },
			},
		}

		h {
			name = 'window',
			mode = { 'n', 'x' },
			body = '<tab>',
			config = { invoke_on_body = true, hint = { type = 'window', position = 'middle' } },
			hint = [[
_q_ _w_ tab
_n_ _p_ next prev
_h_ _j_ _k_ _l_ focus
_H_ _J_ _K_ _L_ move
_<up>_ _<down>_ _<left>_ _<right>_ resize
_t_ split new tab _c_ close _x_ exit
]],
			heads = {
				{ 'q', '<cmd>tabprevious<cr>' },
				{ 'w', '<cmd>tabnext<cr>' },
				{ 'n', '<c-w>w' },
				{ 'p', '<c-w>q' },
				{ 'h', '<c-w>h' },
				{ 'j', '<c-w>j' },
				{ 'k', '<c-w>k' },
				{ 'l', '<c-w>l' },
				{ 'H', '<c-w>H' },
				{ 'J', '<c-w>J' },
				{ 'K', '<c-w>K' },
				{ 'L', '<c-w>L' },
				{ '<left>', '<c-w><' },
				{ '<up>', '<c-w>+' },
				{ '<down>', '<c-w>-' },
				{ '<right>', '<c-w>>' },
				--{ 't', '<cmd>tab split<cr>' },
				{
					't',
					function() ui.split_win_to_tab() end,
				},
				{ 'c', 'ZZ' },
				{
					'x',
					function() vim.cmd 'wqa' end,
				},
			},
		}
		--h : jump
	end,
}
