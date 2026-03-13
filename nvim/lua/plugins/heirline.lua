return {
	'rebelot/heirline.nvim',
	config = function()
		local symbols = require 'my_lua_api.symbols'
		local hl = require('heirline.utils').get_highlight
		local cond = require 'heirline.conditions'
		local lsp_symbol = require('lspsaga.symbol.winbar').get_bar
		--		local gps = require 'nvim-gps'

		local base_hl_color = {
			bg = '#181825',
		}

		local light_bg = '#335599'
		local space = { provider = ' ' }
		local base_hl = { provider = '', hl = base_hl_color }
		local align = { { provider = '%=' }, base_hl }

		local mode = {
			hl = {
				fg = '#ffffff',
			},
			{
				provider = vim.fn.mode(),
				update = 'ModeChanged',
				condition = function() return not require('hydra.statusline').is_active() end,
			},
			{
				provider = function() return require('hydra.statusline').get_name() end,
				condition = function() return require('hydra.statusline').is_active() end,
			},
			space,
		}

		local diag = {
			condition = cond.has_diagnostics,
			static = {
				error_icon = symbols.DiagnosticError,
				warn_icon = symbols.DiagnosticWarn,
				info_icon = symbols.DiagnosticInfo,
				hint_icon = symbols.DiagnosticHint,
			},
			init = function(self)
				self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
				self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
				self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
				self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
			end,
			update = { 'DiagnosticChanged', 'BufEnter' },
			{
				provider = function(self)
					-- 0 is just another output, we can decide to print it or not!
					return self.errors > 0 and (self.error_icon .. ' ' .. self.errors .. ' ')
				end,
				hl = hl '@comment.error',
			},
			{
				provider = function(self) return self.warnings > 0 and (self.warn_icon .. ' ' .. self.warnings .. ' ') end,
				hl = hl '@comment.warning',
			},
			{
				provider = function(self) return self.info > 0 and (self.info_icon .. ' ' .. self.info .. ' ') end,
				hl = hl '@comment.note',
			},
			{
				provider = function(self) return self.hints > 0 and (self.hint_icon .. ' ' .. self.hints .. ' ') end,
				hl = hl '@comment.hint',
			},
		}

		local git = {
			condition = cond.is_git_repo,

			init = function(self)
				self.status_dict = vim.b.gitsigns_status_dict
				self.has_changes = self.status_dict.added ~= 0
					or self.status_dict.removed ~= 0
					or self.status_dict.changed ~= 0
			end,
			hl = { bg = light_bg },
			{
				provider = function(self) return ' ' .. self.status_dict.head end,
				hl = { bold = true },
			},
			{
				condition = function(self) return self.has_changes end,
				provider = ' ',
			},
			{
				provider = function(self)
					local count = self.status_dict.added or 0
					return count > 0 and ('+' .. count)
				end,
				hl = { fg = hl('GitSignsAdd').fg },
			},
			{
				provider = function(self)
					local count = self.status_dict.changed or 0
					return count > 0 and ('~' .. count)
				end,
				hl = { fg = hl('GitSignsChange').fg },
			},
			{
				provider = function(self)
					local count = self.status_dict.removed or 0
					return count > 0 and ('-' .. count)
				end,
				hl = { fg = hl('GitSignsDelete').fg },
			},
			{
				condition = function(self) return self.has_changes end,
				provider = ' ',
			},
		}

		local tab_page = {
			update = { 'BufEnter' },
			hl = function(self)
				if self.is_active then
					return 'TabLineSel'
				else
					return 'TabLine'
				end
			end,
			provider = function(self)
				local wins = vim.api.nvim_tabpage_list_wins(self.tabpage)
				local buf = vim.api.nvim_win_get_buf(wins[1])

				local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
				return '%' .. self.tabnr .. 'T ' .. name .. ' %T'
			end,
		}

		local tab_pages = {
			require('heirline.utils').make_tablist(tab_page),
		}

		-- I take no credits for this! 🦁
		local scroll = {
			static = {
				sbar = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' },
				-- Another variant, because the more choice the better.
				-- sbar = { '🭶', '🭷', '🭸', '🭹', '🭺', '🭻' }
			},
			provider = function(self)
				local curr_line = vim.api.nvim_win_get_cursor(0)[1]
				local lines = vim.api.nvim_buf_line_count(0)
				local i = math.floor((curr_line - 1) / lines * #self.sbar) + 1
				return string.rep(self.sbar[i], 2)
			end,
			hl = { fg = 'blue' },
		}
		-- We're getting minimalist here!
		local ruler = {
			-- %l = current line number
			-- %L = number of lines in the buffer
			-- %c = column number
			-- %P = percentage through file of displayed window
			provider = '%7(%l/%3L%):%2c %P',
		}

		require('heirline').setup {
			-- tabline = { mode, git, diag, symbol_bar_or_ft, align, tab_pages },
			statusline = { mode, git, diag, align, tab_pages, ruler, scroll },
		}
	end,
}
