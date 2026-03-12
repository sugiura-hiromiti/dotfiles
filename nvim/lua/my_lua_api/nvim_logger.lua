local m = {}

---comment
---@param level integer
---@param title string
---@param filetype string
---@param body string
local function notify_with_level(level, title, filetype, body)
	vim.notify(body, level, {
		title = title,
		on_open = function(win)
			local buf = vim.api.nvim_win_get_buf(win)
			vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
		end,
	})
end

---comment
---@param title string
---@param filetype string
---@param body string
m.info = function(title, filetype, body)
	notify_with_level(vim.log.levels.INFO, title, filetype, body)
end

---comment
---@param title string
---@param filetype string
---@param body string
m.warn = function(title, filetype, body)
	notify_with_level(vim.log.levels.WARN, title, filetype, body)
end

---comment
---@param title string
---@param filetype string
---@param body string
m.error = function(title, filetype, body)
	notify_with_level(vim.log.levels.ERROR, title, filetype, body)
end

return m
