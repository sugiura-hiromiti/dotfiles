return {
	{
		'DrKJeff16/wezterm-types',
		version = false,
	},
	'xzbdmw/colorful-menu.nvim',
	{ 'saghen/blink.compat', lazy = true },
	{
		'saghen/blink.cmp',
		dependencies = {
			'folke/lazydev.nvim',
		},
		build = 'nix run .#build-plugin',
		---@module 'blink.cmp'
		opts = {
			completion = {
				menu = {
					auto_show = true,
					draw = {
						columns = {
							{ 'kind_icon' },
							{ 'colorful_label', gap = 1 },
						},
						align_to = 'none',
						components = {
							colorful_label = {
								text = function(ctx) return require('colorful-menu').blink_components_text(ctx) end,
								highlight = function(ctx) return require('colorful-menu').blink_components_highlight(ctx) end,
							},
						},
					},
				},
				documentation = { window = { border = 'single', winblend = 15 }, auto_show = true, auto_show_delay_ms = 80 },
				ghost_text = { enabled = true },
				list = { selection = { preselect = false, auto_insert = true } },
			},
			keymap = {
				preset = 'none',
				['<C-h>'] = {
					function(cmp)
						-- if snp.expand_or_locally_jumpable() then
						-- 	log.info('snippet', 'markdown', 'luasnip jump')
						-- 	snp.jump(1)
						if cmp.snippet_active() then
							return cmp.snippet_forward()
						else
							return false
						end
					end,
					'fallback',
				},
				['<Down>'] = {
					'select_next',
					'fallback',
				},
				['<Up>'] = {
					'select_prev',
					'fallback',
				},
			},
			signature = { enabled = true },
			fuzzy = { implementation = 'prefer_rust_with_warning' },
			sources = {
				providers = {
					lazydev = {
						name = 'LazyDev',
						module = 'lazydev.integrations.blink',
					},
				},
				default = {
					'lsp',
					'snippets',
					'buffer',
					'path',
					'lazydev',
				},
			},
			snippets = { preset = 'luasnip' },
			cmdline = {
				keymap = { preset = 'inherit', ['<cr>'] = {
					'accept_and_enter',
					'fallback',
				} },
				completion = { menu = { auto_show = true } },
			},
			term = { enabled = true, keymap = { preset = 'inherit' }, completion = { menu = { auto_show = true } } },
		},
	},
}
