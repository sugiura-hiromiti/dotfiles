local on_attach = function(client, bufnr)
	-- if client.server_capabilities.inlayHintProvider then
	-- 	vim.lsp.inlay_hint.enable()
	-- 	vim.notify(vim.lsp.inlay_hint.is_enabled(), vim.log.levels.INFO, {})
	-- else
	-- 	vim.notify 'inlay_hint not'
	-- end
end

return {
	{
		'neovim/nvim-lspconfig',
		dependencies = {
			'saghen/blink.cmp',
			'folke/lazydev.nvim',
		},
		config = function()
			vim.lsp.config('*', {
				on_attach = on_attach,
			})

			local cap = require('blink.cmp').get_lsp_capabilities()
			vim.lsp.config('lua_ls', {
				settings = {
					Lua = {
						runtime = { version = 'LuaJIT' },
						diagnostics = { globals = { 'vim', 'hs' } },
						workspace = {
							-- library = vim.api.nvim_get_runtime_file('', true),
							-- checkThirdParty = 'Apply',
						},
						format = { enable = false },
					},
				},
			})
			vim.lsp.config('markdown_oxide', {
				-- capabilities = vim.tbl_deep_extend('force', capabilities, {
				-- 	workspace = {
				-- 		didChangeWatchedFiles = {
				-- 			dynamicRegistration = true,
				-- 		},
				-- 	},
				-- }),
			})
			vim.lsp.config('sourcekit', {
				filetypes = { 'swift', 'objective-c', 'objective-cpp' },
				single_file_support = true,
			})
			vim.lsp.config('dprint', {
				filetypes = {
					'javascript',
					'typescript',
					'javascriptreact',
					'typescriptreact',
					'json',
					'jsonc',
					'markdown',
					'toml',
					'yaml',
				},
			})
			vim.lsp.config('html', { init_options = { embeddedLanguages = { markdown = true } } })
			vim.lsp.config('scheme_languserver', {
				cmd = { 'scheme-langserver', '~/.cache/scheme-langserver.log' },
				root_markers = { 'flake.nix', '.gitignore' },
			})

			vim.lsp.config('jsonls', {
				settings = {
					json = {
						schemas = require('schemastore').json.schemas(),
						validate = { enable = true },
					},
				},
			})

			vim.lsp.config('yamlls', {
				settings = {
					yaml = {
						schemaStore = {
							enable = false,
						},
					},
					schemas = require('schemastore').yaml.schemas(),
				},
			})

			vim.lsp.config('nil_ls', { settings = { ['nil'] = {
				flake = {
					autoEvalInputs = true,
				},
			} } })

			vim.lsp.enable {
				-- 'rust_analyzer',
				'lua_ls',
				'asm_lsp',
				'zls',
				'clangd',
				'nil_ls',
				'cssls',
				'taplo',
				'sourcekit',
				'marksman',
				'markdown_oxide',
				'jsonls',
				'dprint',
				'html',
				'yamlls',
				'fish_lsp',
				-- 'terraformls',
				-- 'terraform_lsp',
				'graphql',
				'ts_ls',
				'eslint',
				'scheme_languserver',
				'ocamllsp',
				'nushell',
				-- 'gh_actions_ls',
			}
		end,
	},
	{
		'nvimdev/lspsaga.nvim',
		event = 'LspAttach',
		config = function()
			require('lspsaga').setup {
				symbol_in_winbar = {
					enable = false,
				},
				scroll_preview = {
					scroll_down = '<c-j>',
					scroll_up = '<c-k>',
				},
				callhierarchy = {
					keys = {
						edit = 'e',
						vsplit = 'v',
						split = 'x',
						shuttle = 'e',
					},
				},
				code_action = {
					show_server_name = true,
					extend_gitsigns = true,
				},
				diagnostic = {
					max_height = 0.8,
					extend_relatedInformation = true,
					keys = {
						exec_action = 'e',
						toggle_or_jump = 'o',
					},
				},
				finder = {
					max_height = 0.8,
					right_width = 0.6,
					default = 'def+ref+imp',
					keys = {
						shuttle = 'e',
						toggle_or_open = '<cr>',
						vsplit = 'v',
						split = 'x',
					},
				},
				hover = {
					--					open_link = 'o',
				},
				lightbulb = { enable = false },
				beacon = { enable = true },
			}
		end,
	},
	-- {
	-- 	'luckasRanarison/tailwind-tools.nvim',
	-- 	name = 'tailwind-tools',
	-- 	build = 'UpdateRemotePlugins',
	-- 	opts = {
	-- 		server = { settings = { includeLanguages = { rust = 'html' } }, on_attach = on_attach },
	-- 		extension = {
	-- 			patterns = {
	-- 				rust = { 'class:%s*["\']([^"\']+)["\']' },
	-- 			},
	-- 		},
	-- 	},
	-- },
	{
		'mrcjkb/rustaceanvim',
		dependencies = { 'nvim-neotest/neotest', 'nvim-neotest/nvim-nio' },
		lazy = false,
		init = function()
			vim.g.rustaceanvim = {
				tools = { float_win_config = { auto_focus = true } },
				server = {
					default_settings = {
						['rust-analyzer'] = {
							assist = {
								preferSelf = true,
							},

							buildScripts = {
								enable = true,
							},

							cargo = {
								targetDir = vim.fn.expand '~/.cache/rust-analyzer/target/',
							},

							check = {
								command = 'clippy',
							},

							checkOnSave = {
								enable = true,
							},

							completion = {
								fullFunctionSignatures = { enable = true },
								termSearch = { enable = true },
							},

							diagnostics = {
								experimental = { enable = true },
								styleLints = { enable = true },
							},

							hover = {
								actions = {
									enable = true,
									reference = { enable = true },
								},
								maxSubstitutionLength = 40,
								memoryLayout = {
									niches = true,
								},
								show = {
									traitAssocItems = 5,
								},
							},

							inlayHints = {
								enable = true,
								bindingModeHints = { enable = true },
								closureCaptureHints = { enable = true },
								closureReturnTypeHints = { enable = 'always' },
								discriminantHints = { enable = 'always' },
								expressionAdjustmentHints = { enable = 'always' },
								implicitDrops = { enable = true },
								lifetimeElisionHints = {
									enable = 'always',
									useParameterNames = true,
								},
							},

							interpret = {
								tests = true,
							},

							lens = {
								enable = true,
								references = {
									adt = { enable = true },
									enumVariant = { enable = true },
									method = { enable = true },
									trait = { enable = true },
								},
								updateTest = { enable = true },
							},

							procMacro = {
								enable = true,
								attributes = { enable = true },
							},

							rustfmt = {
								rangeFormatting = { enable = true },
							},

							workspace = {
								symbol = {
									search = { kind = 'all_symbols' },
								},
							},
						},
					},
				},
			}
		end,
	},
	{
		'folke/lazydev.nvim',
		dependencies = { 'DrKJeff16/wezterm-types' },
		ft = 'lua',
		opts = {
			library = {
				{ path = '${3rd}/luv/library', words = { 'vim%.uv' } },
				'lazy.nvim',
				{ path = 'wezterm-types', mods = { 'wezterm' } },
			},
		},
	},
	{
		'saecki/crates.nvim',
		config = function()
			require('crates').setup {
				lsp = {
					enabled = true,
					actions = true,
					completion = true,
					hover = true,
				},
			}
		end,
	},
	{
		'mrcjkb/haskell-tools.nvim',
		lazy = false, -- This plugin is already lazy
		config = function()
			require('telescope').load_extension 'ht'
		end,
	},
	'b0o/schemastore.nvim',
	-- { 'nanotee/sqls.nvim' },
}
