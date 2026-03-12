local mod = {}

---@return string escaped, integer count
---@param text string
mod.escape_escape_sequence = function(text)
	return text:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

---@param text string|nil
---@param width integer
---@return string truncated
mod.truncate_end = function(text, width)
	local truncated = ''
	if text ~= nil then
		-- truncated = vim.fn.strcharpart(text, 0, width)
		truncated = string.sub(text, 0, width)
		if truncated ~= text then
			truncated = string.sub(truncated, 0, width - 1) .. '…'
		end
	end
	return truncated
end

return mod
