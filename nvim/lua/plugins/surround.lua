local my_util = require("my_lua_api.util")
local my_string = require("my_lua_api.string")
local function block_comment()
	local cmt_idctr = my_util.comment_indicators(vim.bo.comments)
	return { { cmt_idctr.normal.block.pre }, { cmt_idctr.normal.block.post } }
end

local function block_pair()
	local pairs = block_comment()
	local pre = my_string.escape_escape_sequence(pairs[1][1])
	local post = my_string.escape_escape_sequence(pairs[2][1])
	return pre, post
end

return {
	-- TODO: configure to manipulate surround comment block
	"kylechui/nvim-surround",
	version = "*",
	event = "VeryLazy",
	config = function()
		local config = require("nvim-surround.config")
		require("nvim-surround").setup({
			surrounds = {
				["c"] = {
					add = block_comment,
					delete = function()
						local pre, post = block_pair()
						return config.get_selections({
							char = "c",
							pattern = "^(" .. pre .. ")().-(" .. post .. ")()$",
						})
					end,
					find = function()
						local pre, post = block_pair()
						return config.get_selection({
							pattern = pre .. ".-" .. post,
						})
					end,
					change = {
						target = function()
							local pre, post = block_pair()
							return config.get_selections({
								char = "c",
								pattern = "^(" .. pre .. ")().-(" .. post .. ")()$",
							})
						end,
					},
				},
			},
		})
	end,
}
