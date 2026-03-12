local m = {}

m.split_win_to_tab = function()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()

	-- saves the buffer
	vim.api.nvim_buf_call(buf, function()
		vim.cmd 'update'
	end)

	-- split window
	vim.api.nvim_win_close(win, true)
	vim.cmd 'tabnew'
	vim.api.nvim_set_current_buf(buf)
end

return m
