return {
	{
		'lewis6991/gitsigns.nvim',
		config = function() require('gitsigns').setup {} end,
	},
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
		'nicolasgb/jj.nvim',
		opts = {},
	},
}
