vim.keymap.set('n', 'ZZ', function()
	require('oil').close {
		exit_if_last_buf = false,
	}
end, { buffer = true })
