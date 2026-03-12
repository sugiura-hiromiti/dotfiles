return {
	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		lazy = false,
		config = true,
		-- config = function()
		-- 	vim.treesitter.language.register('markdown', 'octo')
		-- 	require('nvim-treesitter.configs').setup {
		-- 		auto_install = true,
		-- 		highlight = { enable = true, additional_vim_regex_highlighting = false },
		-- 		textsubjects = {
		-- 			enable = true,
		-- 			prev_selection = '/',
		-- 			keymaps = {
		-- 				['.'] = 'textsubjects-smart',
		-- 				[','] = 'textsubjects-container-outer',
		-- 				['i,'] = 'textsubjects-container-inner',
		-- 			},
		-- 		},
		-- 	}
		-- end,
	},
	-- {
	-- 	'cshuaimin/ssr.nvim',
	-- 	config = function()
	-- 		require('ssr').setup {
	-- 			max_height = 50,
	-- 			keymaps = {
	-- 				replace_all = '<s-cr>',
	-- 			},
	-- 		}
	-- 	end,
	-- },
	-- "RRethy/nvim-treesitter-textsubjects",
}
