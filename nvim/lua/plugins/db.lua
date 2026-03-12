return {
	'kndndrj/nvim-dbee',
	dependencies = {
		'MunifTanjim/nui.nvim',
	},
	build = function()
		require('dbee').install()
	end,
	config = function()
		require('dbee').setup {
			sources = {
				require('dbee.sources').EnvSource:new 'DBEE_CONNECTIONS',
			},
		}
	end,
}
