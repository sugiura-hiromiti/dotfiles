local logger = require 'my_lua_api.nvim_logger'
local tb = require 'telescope.builtin'
local ui = require 'my_lua_api.ui'

local m = {}

m.text_search = function()
	vim.ui.select({
		'current buffer',
		'live grep',
		'live grep (only open files)',
		'grep string under cursor',
		'text on screen',
		'select',
		'select by search',
	}, { prompt = 'search by' }, function(choice)
		if choice == nil then
			logger.info('text_search', 'markdown', 'no candidate selected')
			return
		end
		if choice:find 'live grep' then
			local opt = {}
			if choice:find 'only open files' then opt.grep_open_files = true end
			tb.live_grep(opt)
		elseif choice == 'current buffer' then
			tb.current_buffer_fuzzy_find()
			-- vim.api.nvim_feedkeys('/', 'n', false)
		elseif choice == 'grep string under cursor' then
			tb.grep_string()
		elseif choice == 'text on screen' then
			require('flash').jump()
		elseif choice == 'select' then
			require('flash').treesitter()
		elseif choice == 'select by search' then
			require('flash').treesitter_search()
		else
			logger.warn('fallback', 'markdown', 'you selected' .. choice .. '\nthere is nothing to match\ndo nothing')
		end
	end)
end

m.file_nav = function()
	vim.ui.select({ 'normal', 'vertical', 'horizontal', 'tab' }, { prompt = 'file navigation style' }, function(choice)
		if choice == 'vertical' then
			vim.cmd 'vsplit'
		elseif choice == 'horizontal' then
			vim.cmd 'split'
		elseif choice == 'tab' then
			vim.cmd 'tab split'
		end

		vim.cmd 'normal! gF'
	end)
end

m.terminal = function()
	vim.ui.select({ 'tab', 'vertical', 'horizontal', 'in place' }, { prompt = 'how to open terminal' }, function(choice)
		local bufnr = 0
		local conf = {}
		-- local bufnr = vim.api.nvim_create_buf(true, true)
		if choice == 'in place' then
			--do nothing
			-- vim.api.nvim_open_win(0, true, {})
		else
			conf = { split = 'above', win = 0 }
			bufnr = vim.api.nvim_create_buf(true, true)

			if choice == 'vertical' then conf = { split = 'right', win = 0 } end
		end

		if choice ~= 'in place' then vim.api.nvim_open_win(bufnr, true, conf) end

		vim.cmd 'term'

		if choice == 'tab' then ui.split_win_to_tab() end
	end)
end

m.symbols = function()
	vim.ui.select({
		'doc',
		'ws',
		'dyn ws',
		'ts',
		'hoogle (Haskell)',
	}, { prompt = 'symbol search' }, function(choice)
		local opt = { show_line = true }
		if choice == 'doc' then
			tb.lsp_document_symbols(opt)
		elseif choice == 'ws' then
			tb.lsp_workspace_symbols(opt)
		elseif choice == 'dyn ws' then
			tb.lsp_dynamic_workspace_symbols(opt)
		elseif choice == 'ts' then
			tb.treesitter(opt)
		elseif choice == 'hoogle (Haskell)' then
			vim.cmd.Telescope { 'hoogle', 'list' }
		end
	end)
end

m.references = function()
	vim.ui.select(
		{ 'help', 'keymap', 'man page', 'highlight', 'command history', 'search history' },
		{ prompt = 'reference and history' },
		function(choice)
			if choice == 'help' then
				tb.help_tags()
			elseif choice == 'keymap' then
				tb.keymaps()
			elseif choice == 'man page' then
				tb.man_pages()
			elseif choice == 'highlight' then
				tb.highlights()
			elseif choice == 'command history' then
				tb.command_history()
			elseif choice == 'search history' then
				tb.search_history()
			else
				logger.warn('fallback', 'markdown', choice .. ' does not match any branch')
			end
		end
	)
end

return m
