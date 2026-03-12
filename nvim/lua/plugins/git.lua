return {
	{
		'lewis6991/gitsigns.nvim',
		config = function()
			require('gitsigns').setup {}
		end,
	},
	{ 'sindrets/diffview.nvim', opts = {} },
	{
		'shellRaining/hlchunk.nvim',
		event = { 'BufReadPre', 'BufNewFile' },
		opts = {
			chunk = { enable = true },
			-- indent = { enable = true },
			line_num = { enable = true },
		},
	},
	{
		'swaits/lazyjj.nvim',
		dependencies = 'nvim-lua/plenary.nvim',
	},
}
