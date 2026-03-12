local c = vim.api.nvim_create_user_command

c('Make', function(opts)
	local cmd = '<cr> '
	local args = opts.args
	local extra = ''
	local ft = vim.bo.filetype
	local path = vim.fn.expand '%:p'
	if ft == 'rust' then -- langs which have to be compiled
		cmd = '!cargo '
		if args == '' then
			local file_name = type(path) == 'string' and path or path[1]

			args = 'r '
			if string.find(file_name, '/src/bin/') ~= nil then
				local _, l = string.find(file_name, '/src/bin/')
				local r = string.find(string.sub(file_name, l + 1), '/') or string.find(string.sub(file_name, l + 1), '%.')

				args = args .. '--bin ' .. string.sub(file_name, l + 1, l + r - 1)
			elseif vim.fn.expand '%' ~= 'main.rs' then
				args = 't '
			end
		else
			args = table.remove(opts.fargs, 1) -- insert 1st argument to `args`
		end
		table.insert(opts.fargs, 1, '-q')
		for _, a in ipairs(opts.fargs) do
			extra = extra .. ' ' .. a
		end
	elseif ft == 'haskell' then
		cmd = '!runghc '
		args = args .. ' ' .. path .. ' '
	elseif ft == 'zig' then
		cmd = '!zig '
		if args == '' then
			args = 'run '
		else
			args = args .. ' '
		end
		args = args .. path .. ' '
	elseif ft == 'go' then
		cmd = '!go '
		if args == '' then
			args = 'run'
		elseif args == 't' then
			args = 'test'
		end
		args = args .. ' ' .. path .. ' '
	elseif ft == 'lisp' then
		cmd = '!sbcl --script '
		args = path .. ' '
		extra = opts.args
	elseif ft == 'scheme' then
		cmd = '!chibi-scheme '
		args = path .. ' '
		extra = opts.args
	elseif ft == 'cpp' or ft == 'c' then
		cmd = '!NEOVIM_CXX_AUTO_RUNNED_FILE=' .. path .. ' make'
	-- elseif ft == 'java' then
	-- 	if path:find 'test' ~= nil then
	-- 		cmd = 'JavaTestRunnerCurrentClass'
	-- 	else
	-- 		if args == 's' then
	-- 			cmd = 'JavaRunnerStopMain'
	-- 		else
	-- 			cmd = 'JavaRunnerRunMain'
	-- 		end
	-- 	end
	elseif ft == 'ruby' or ft == 'swift' or ft == 'lua' or ft == 'python' or ft == 'typescript' then -- langs which has interpreter
		local interpreter = ft
		if interpreter == 'python' then
			interpreter = interpreter .. '3'
		elseif interpreter == 'typescript' then
			if args == 'html' then
				interpreter = 'tsc'
				args = '&& open ' .. vim.fn.expand '%:p:h' .. '/index.html'
			else
				interpreter = 'tsx'
			end
		end
		if args == 't' then
			path = 'test.' .. ft
			args = ''
		end
		cmd = '!' .. interpreter .. ' ' .. path .. ' '
	elseif ft == 'html' then -- markup language
		cmd = '!open ' .. path .. ' '
	elseif ft == 'markdown' then
		cmd = [[lua if require('peek').is_open() then require('peek').close() else require('peek').open() end]]
		args = ''
	end

	vim.cmd(cmd .. args .. extra)
	--vim.uv.spawn(cmd .. args .. extra)
end, { nargs = '*' })
c('RmSwap', function()
	vim.cmd '!rip ~/.local/state/nvim/swap/'
end, {})

-- NOTE: autocmd
local au_id = vim.api.nvim_create_augroup('my_au', { clear = true })
local a = vim.api.nvim_create_autocmd

a({ 'filetype', 'bufreadpost' }, {
	group = au_id,
	callback = function()
		local ft = vim.bo.ft
		if ft == 'notify' then
			vim.bo.modifiable = true
			-- elseif ft == 'noice' then
			-- 	vim.bo.ft = 'markdown'
		end
	end,
})

a({ 'winenter', 'ModeChanged' }, {
	group = au_id,
	callback = function()
		local path = vim.fn.expand '%:p'
		local home_dir = os.getenv 'HOME'
		path = path:gsub(home_dir, '~')
		vim.o.titlestring = vim.fn.mode() .. ' ' .. vim.bo.ft .. ' ' .. path
	end,
})

a('bufreadpost', {
	group = au_id,
	callback = function()
		require('colorizer').attach_to_buffer(0)
	end,
})

local function marker_comment()
	local all_bufs = vim.api.nvim_list_bufs()
	local bufs = {}
	for _, buf in pairs(all_bufs) do
		if vim.api.nvim_buf_is_loaded(buf) then
			table.insert(bufs, buf)
		end
	end

	local marks = {
		[' TODO: '] = vim.diagnostic.severity.INFO,
		[' HACK: '] = vim.diagnostic.severity.HINT,
		[' WARN: '] = vim.diagnostic.severity.WARN,
		[' PERF: '] = vim.diagnostic.severity.INFO,
		[' NOTE: '] = vim.diagnostic.severity.HINT,
		[' TEST: '] = vim.diagnostic.severity.INFO,
		[' FIXME: '] = vim.diagnostic.severity.ERROR,
	}

	local ns = vim.api.nvim_create_namespace 'marker_comment'
	for _, buf in pairs(bufs) do
		local comments_pos = require('my_lua_api.ts').get_comment_positions(buf)

		if #comments_pos == 0 then
			goto continue
		end

		local diags = {}
		for _, comment_pos in ipairs(comments_pos) do
			local comment_lines = vim.api.nvim_buf_get_lines(buf, comment_pos.start_row, comment_pos.end_row, true)

			for _, line in ipairs(comment_lines) do
				for mark, severity in pairs(marks) do
					local column_start, column_end = line:find(mark)
					if column_end ~= nil then
						local diag = {
							lnum = comment_pos.start_row,
							col = column_end,
							message = line:sub(column_start, -1),
							severity = severity,
							source = 'marker comment',
						}
						diags[#diags + 1] = diag
					end
				end
			end
		end

		vim.diagnostic.set(ns, buf, diags, { virtual_text = false, float = false })
		::continue::
	end
end

a({ 'bufwritepost' }, {
	group = au_id,
	callback = marker_comment,
})

-- a('LspAttach', {
-- 	callback = function(args)
-- 		local client = vim.lsp.get_client_by_id(args.data.client_id)
-- 		if client and client.server_capabilities.codeLensProvider then
-- 			vim.lsp.codelens.refresh()
-- 		end
-- 	end,
-- })

-- a({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
-- 	callback = function()
-- 		vim.lsp.codelens.refresh()
-- 	end,
-- })

a('filetype', {
	group = vim.api.nvim_create_augroup('vim-treesitter-start', {}),
	callback = function(_ctx)
		pcall(vim.treesitter.start)
	end,
})

a('termopen', {
	group = au_id,
	callback = function()
		vim.o.number = true
		vim.o.relativenumber = true
	end,
})

a({ 'bufenter' }, {
	group = au_id,
	callback = function()
		vim.opt.listchars = { tab = '│ ' }
	end,
})

-- a({ 'vimenter' }, {
-- 	group = au_id,
-- 	callback = function()
-- 		if vim.fn.expand '%:p' == '' and vim.bo.ft ~= 'lazy' then
-- 			vim.cmd 'terminal'
-- 		end
-- 	end,
-- })
