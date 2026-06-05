return {
	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		lazy = false,
		config = function()
			require('nvim-treesitter').install {
				'rust',
				'typescript',
				'haskell',
				'json',
				'toml',
				'nu',
				'csv',
				'diff',
				'gitcommit',
				'gitignore',
				'json',
				'kdl',
				'lua',
				'markdown',
				'markdown_inline',
				'nix',
				'sql',
				'yaml',
				'tsx',
				'vimdoc',
				'html',
				'html_tags',
			}
		end,
	},
}
