local symbols = require 'my_lua_api.symbols'

return {
	-- NOTE: Library
	'kkharji/sqlite.lua',
	{ 'echasnovski/mini.nvim', version = false },
	'nvim-lua/plenary.nvim',
	'MunifTanjim/nui.nvim',
	'nvim-tree/nvim-web-devicons',

	-- NOTE: appearance
	{ 'nvim-zh/colorful-winsep.nvim', config = true, event = { 'WinLeave' } },
	{ 'OXY2DEV/helpview.nvim', lazy = false },
	'chrisgrieser/nvim-spider',
	{
		'catppuccin/nvim',
		name = 'catppuccin',
		config = function()
			require('catppuccin').setup {
				transparent_background = true,
				term_colors = true,
				background = { dark = 'frappe' },
				-- dim_inactive = { enabled = true },
				styles = {
					keywords = { 'bold' },
					properties = { 'italic', 'bold' },
				},
			}
			-- Force transparency everywhere
			-- local groups = {
			-- 	'Normal',
			-- 	'NormalNC',
			-- 	'NormalFloat',
			-- 	'FloatBorder',
			-- 	'SignColumn',
			-- 	'LineNr',
			-- 	'CursorLineNr',
			-- 	'CursorLine',
			-- 	'CursorColumn',
			-- 	'EndOfBuffer',
			-- 	'StatusLine',
			-- 	'StatusLineNC',
			-- 	'VertSplit',
			-- 	'WinSeparator',
			-- 	'TabLine',
			-- 	'TabLineFill',
			-- }
			--
			-- for _, group in ipairs(groups) do
			-- 	vim.api.nvim_set_hl(0, group, { bg = 'none' })
			-- end
			vim.cmd 'colo catppuccin-nvim'
		end,
	},
	-- {
	-- 	'f-person/auto-dark-mode.nvim',
	-- 	opts = {
	-- 		-- your configuration comes here
	-- 		-- or leave it empty to use the default settings
	-- 		-- refer to the configuration section below
	-- 	},
	-- },
	-- NOTE: LSP
	{
		'onsails/lspkind.nvim',
		config = function()
			require('lspkind').init {
				symbol_map = symbols,
			}
		end,
	},
	{
		'nvimtools/none-ls.nvim',
		config = function()
			local h = require 'null-ls.helpers'
			local null_ls = require 'null-ls'
			local nufmt_source = {
				name = 'nufmt',
				filetypes = { 'nu' },
				method = null_ls.methods.FORMATTING,
				generator = h.generator_factory {
					command = 'nufmt',
					args = { '$FILENAME' },
					on_output = function(_) end,
				},
			}

			local b = null_ls.builtins
			-- null_ls.register { nufmt_source }
			null_ls.setup {
				sources = {
					b.formatting.stylua, --.with { args = { '--config-path ~/.stylua.toml' } },
					b.formatting.ocamlformat,
					-- b.diagnostics.sqlfluff.with { extra_args = { '--dialect', 'postgres' } },
					b.formatting.sqlfluff.with { extra_args = { '--dialect', 'postgres' } },
					-- nufmt_source,
				},
			}
		end,
	},

	-- NOTE: utility
	-- {
	-- 	'3rd/image.nvim',
	-- 	build = false, -- so that it doesn't build the rock https://github.com/3rd/image.nvim/issues/91#issuecomment-2453430239
	-- 	opts = {
	-- 		processor = 'magick_cli',
	-- 	},
	-- },
	{ 'akinsho/toggleterm.nvim', config = true },
	{ 'mikavilpas/yazi.nvim', event = 'VeryLazy' },
	{ 'willothy/flatten.nvim', opts = { window = { open = 'tab' } }, lazy = false, priority = 1001 },
	{ 'rcarriga/nvim-notify', opts = { background_colour = '#000000' } },
	{
		'folke/noice.nvim',
		event = 'VeryLazy',
		opts = {
			lsp = {
				override = {
					['vim.lsp.util.convert_input_to_markdown_lines'] = true,
					['vim.lsp.util.stylize_markdown'] = true,
					['cmp.entry.get_documentation'] = true,
				},
			},
			presets = { bottom_search = true },
			routes = {
				{
					filter = {
						event = 'msg_show',
						find = 'Unable to find native fzy native lua dep file. Pit)probably need to update submodules!',
					},
					opts = { skip = true },
				},
			},
		},
	},
	{
		'folke/todo-comments.nvim',
		config = true,
	},
	{
		'norcalli/nvim-colorizer.lua',
		config = function() require('colorizer').setup() end,
	},
	'stevearc/dressing.nvim',
	{
		'RaafatTurki/hex.nvim',
		config = function() require('hex').setup() end,
	},
	{
		'aaronik/treewalker.nvim',
		opts = {},
	},
	'danilamihailov/beacon.nvim',
	{
		'amitds1997/remote-nvim.nvim',
		config = true,
	},
	{
		'nvim-neotest/neotest',
		dependencies = {
			'nvim-neotest/nvim-nio',
			'nvim-lua/plenary.nvim',
			'antoinemadec/FixCursorHold.nvim',
			'nvim-treesitter/nvim-treesitter',
		},
		opts = {
			adapters = { require 'rustaceanvim.neotest' },
			status = { virtual_text = true },
			output = { open_on_run = true },
		},
	},

	-- NOTE: edit
	{
		'LunarVim/bigfile.nvim',
		lazy = false,
		opts = {
			filesize = 1,
		},
	},
	{
		'windwp/nvim-ts-autotag',
		config = function() require('nvim-ts-autotag').setup {} end,
	},
	{
		'windwp/nvim-autopairs',
		config = function()
			require('nvim-autopairs').setup {
				check_ts = true,
				map_bs = false,
				map_c_h = true,
				enable_check_bracket_line = false,
			}
		end,
	},
	{
		'folke/flash.nvim',
		event = 'VeryLazy',
		opts = {
			-- mode = "exact"
			modes = {
				search = {
					enabled = true,
				},
				char = {
					keys = { 'f', 'F' },
				},
			},
		},
	},
	{
		'Bekaboo/dropbar.nvim',
		dependencies = { 'nvim-telescope/telescope-fzf-native.nvim' },
	},

	-- NOTE: telescope
	{
		'danielfalk/smart-open.nvim',
		branch = '0.3.x',
	},
	'nvim-telescope/telescope-ui-select.nvim',
	{
		'nvim-telescope/telescope-fzf-native.nvim',
		build = 'make',
	},
}
