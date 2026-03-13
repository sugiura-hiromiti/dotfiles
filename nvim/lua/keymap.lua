vim.cmd 'smapclear'

local m = vim.keymap.set
-- local tsb = require 'telescope.builtin'
local log = require 'my_lua_api.nvim_logger'
local select = require 'my_lua_api.select'

local function table_contains(table, elem)
	for _, v in pairs(table) do
		if v == elem then return true end
	end
	return false
end

local function is_url(path) return path:match '^https?://' end

-- NOTE: better defaults
vim.keymap.set('n', '<c-a>', function() require('dial.map').manipulate('increment', 'normal') end)
vim.keymap.set('n', '<c-x>', function() require('dial.map').manipulate('decrement', 'normal') end)
vim.keymap.set('n', 'g<c-a>', function() require('dial.map').manipulate('increment', 'gnormal') end)
vim.keymap.set('n', 'g<c-x>', function() require('dial.map').manipulate('decrement', 'gnormal') end)
vim.keymap.set('x', '<c-a>', function() require('dial.map').manipulate('increment', 'visual') end)
vim.keymap.set('x', '<c-x>', function() require('dial.map').manipulate('decrement', 'visual') end)
vim.keymap.set('x', 'g<c-a>', function() require('dial.map').manipulate('increment', 'gvisual') end)
vim.keymap.set('x', 'g<c-x>', function() require('dial.map').manipulate('decrement', 'gvisual') end)

m('i', '<esc>', function()
	vim.cmd 'stopinsert'

	local cur_buf = vim.api.nvim_get_current_buf()
	local has_format_ability = false
	local lsp_clients = vim.lsp.get_clients { bufnr = cur_buf }
	for _, client in pairs(lsp_clients) do
		if client.server_capabilities.documentFormattingProvider then
			has_format_ability = true
			break
		else
		end
	end

	if has_format_ability then vim.lsp.buf.format { async = false } end

	-- if vim.api.nvim_buf_get_option(0, 'modifiable') then
	if vim.api.nvim_get_option_value('modifiable', { buf = 0 }) then
		vim.cmd 'wa'
	else
		log.info('change did not saved', 'markdown', 'unmodifiable buffer')
	end
end)
m('n', '<esc>', function()
	require('notify').dismiss { pending = true, silent = true }
	vim.cmd 'noh'
end)
m({ 'n', 'x' }, '$', '^')
m({ 'n', 'x' }, '^', '$')
m({ 'n', 'x' }, '<cr>', function()
	local special_ft = { 'ssr', 'qf' }
	if table_contains(special_ft, vim.bo.ft) then
		return '<cr>'
	elseif vim.bo.ft == 'rust' then
		return ':RustLsp '
	else
		return ':Make '
	end
end, { expr = true })
m({ 'n', 'x' }, '<s-cr>', function()
	if vim.bo.ft == 'ssr' then
		return '<s-cr>'
	else
		return ':!'
	end
end, { expr = true })
m({ 'n', 'x' }, '<del>', '<c-d>')
m('t', '<esc>', '<c-\\><c-n>')
m('n', 'gf', function()
	local cfile = vim.fn.expand '<cfile>'

	if is_url(cfile) then
		vim.ui.open(cfile)
	else
		select.file_nav()
	end
end)
m({ 'n', 'v' }, '{', '<c-b>')
m({ 'n', 'v' }, '}', '<c-f>')
m({ 'n', 'o', 'x' }, 'w', function() require('spider').motion 'w' end)
m({ 'n', 'o', 'x' }, 'e', function() require('spider').motion 'e' end)
m({ 'n', 'o', 'x' }, 'b', function() require('spider').motion 'b' end)
m({ 'n', 'x' }, '<end>', '<c-e>')
m({ 'n', 'x' }, '<home>', '<c-a>')

-- NOTE: emacs keybind
-- m('!', '<c-a>', '<home>')
-- m('!', '<c-e>', '<end>')
m('c', '<c-k>', '<right><c-c>v$hs')
m('!', '<c-u>', '<c-c>v^s')
m('!', '<a-d>', '<right><c-c>ves')
-- m('!', '<a-f>', '<c-right>')
-- m('!', '<a-b>', '<c-left>')

-- NOTE: navigate
m({ 'n', 'v' }, '<up>', '<cmd>Treewalker Up<cr>')
m({ 'n', 'v' }, '<down>', '<cmd>Treewalker Down<cr>')
m({ 'n', 'v' }, '<right>', '<cmd>Treewalker Right<CR>')
m({ 'n', 'v' }, '<left>', '<cmd>Treewalker Left<CR>')

-- swapping items (treesitter)
m({ 'n', 'v' }, '<c-p>', '<cmd>Treewalker SwapUp<cr>')
m({ 'n', 'v' }, '<c-n>', '<cmd>Treewalker SwapDown<cr>')
m({ 'n', 'v' }, '<c-f>', '<cmd>Treewalker SwapRight<cr>')
m({ 'n', 'v' }, '<c-b>', '<cmd>Treewalker SwapLeft<cr>')

m({ 'n', 'x' }, '<c-j>', function() vim.diagnostic.jump { count = 1 } end)
m({ 'n', 'x' }, '<c-k>', function() vim.diagnostic.jump { count = -1 } end)
m({ 'n', 'x' }, 'J', '<cmd>Gitsigns next_hunk<cr>')
m({ 'n', 'x' }, 'K', '<cmd>Gitsigns prev_hunk<cr>')

-- m({ 'n', 'i', 'c', 'x' }, '<c-tab>', '<cmd>tabnext<cr>')
-- m({ 'n', 'i', 'c', 'x' }, '<c-s-tab>', '<cmd>tabprevious<cr>')

-- NOTE: select ui
m({ 'n', 'x' }, '/', select.text_search)
m({ 'n', 'x' }, '?', select.references)
-- m({ 'n', 'x' }, '"', select.terminal)
m({ 'n', 'x' }, ';', '<cmd>ToggleTerm direction=float<cr>')
m({ 'n', 'x' }, "'", '<cmd>Lazyjj<cr>')

-- NOTE: completion
local blnk = require 'blink.cmp'
local snp = require 'luasnip'
m({ 'i', 'c' }, '<up>', function()
	if snp.choice_active() then
		return '<Plug>luasnip-next-choice'
	else
		return '<up>'
	end
end, { expr = true })
m({ 'i', 'c' }, '<down>', function()
	if snp.choice_active() then
		return '<Plug>luasnip-prev-choice'
	else
		return '<down>'
	end
end, { expr = true })
m({ 'i', 'c' }, '<tab>', function()
	if blnk.is_visible() then
		blnk.select_and_accept()
	else
		return '<tab>'
	end
end, { expr = true })
m({ 'i', 'c' }, '<c-j>', function()
	if blnk.is_documentation_visible() then
		blnk.scroll_documentation_down()
	else
		return '<c-j>'
	end
end, { expr = true })
m({ 'i', 'c' }, '<c-k>', function()
	if blnk.is_documentation_visible() then
		blnk.scroll_documentation_up()
	else
		return '<right><c-c>v$hs'
	end
end, { expr = true })

m({ 'i', 'c' }, '<s-bs>', function()
	if snp.expand_or_locally_jumpable() then
		snp.jump(-1)
	elseif blnk.snippet_active() then
		blnk.snippet_backward()
	else
		return '<s-bs>'
	end
end, { expr = true })
