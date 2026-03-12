local mod = {}
---@class CommentMap
---@field normal {line:string,block:{pre:string,post:string}}
---@field doc {line:{inner:string,outer:string},block:{inner:{pre:string,post:string},outer:{pre:string,post:string}}}

---@return CommentMap
---@param comments string
mod.comment_indicators = function(comments)
	---@type CommentMap
	local rslt = {
		normal = { line = "", block = { pre = "", post = "" } },
		doc = {
			line = { inner = "", outer = "" },
			block = {
				inner = { pre = "", post = "" },
				outer = { pre = "", post = "" },
			},
		},
	}

	local idctrs = vim.split(comments, ",", { plain = true, trimempty = true })

	for _, idctr in pairs(idctrs) do
		local cmt_w_optnl_flg = vim.split(idctr, ":", { plain = true, trimempty = true })
		if #cmt_w_optnl_flg == 0 then -- this case might be unreachable
			return rslt
		elseif #cmt_w_optnl_flg == 1 then
			-- #tmp==1 means all format-comment flags are off
			-- it must be line comment

			if #rslt.doc.line.outer > #cmt_w_optnl_flg[1] then
				rslt.normal.line = cmt_w_optnl_flg[1]
			elseif #rslt.doc.line.outer == #cmt_w_optnl_flg[1] then
				if rslt.doc.line.outer:find("!") then
					rslt.doc.line.inner = rslt.doc.line.outer
					rslt.doc.line.outer = cmt_w_optnl_flg[1]
				else
					rslt.doc.line.inner = cmt_w_optnl_flg[1]
				end
			else
				rslt.normal.line = rslt.doc.line.outer
				rslt.doc.line.outer = cmt_w_optnl_flg[1]
			end
		elseif #cmt_w_optnl_flg == 2 then
			local flag = cmt_w_optnl_flg[1]
			local cmt_str = cmt_w_optnl_flg[2]

			if flag:find("s") then
				if #rslt.doc.block.outer.pre < #cmt_str then
					rslt.normal.block.pre = rslt.doc.block.outer.pre
					rslt.doc.block.outer.pre = cmt_str
				elseif #rslt.doc.block.outer.pre == #cmt_str then
					if cmt_str:find("!") then
						rslt.doc.block.inner.pre = cmt_str
					else
						rslt.doc.block.inner.pre = rslt.doc.block.outer.pre
						rslt.doc.block.outer.pre = cmt_str
					end
				else
					rslt.normal.block.pre = cmt_str
				end
			elseif flag:find("e") then
				rslt.normal.block.post = cmt_str
				rslt.doc.block.inner.post = cmt_str
				rslt.doc.block.outer.post = cmt_str
			end
		end
	end

	if rslt.doc.block.inner.pre == "" then
		rslt.doc.block.inner.pre = rslt.doc.block.outer.pre
	end
	if rslt.normal.block.pre == "" then
		rslt.normal.block.pre = rslt.doc.block.outer.pre
	end
	if rslt.doc.line.inner == "" then
		rslt.doc.line.inner = rslt.doc.line.outer
	end

	-- format
	rslt.doc.block.inner.pre = rslt.doc.block.inner.pre .. " "
	rslt.doc.block.outer.pre = rslt.doc.block.outer.pre .. " "
	rslt.doc.line.inner = rslt.doc.line.inner .. " "
	rslt.doc.line.outer = rslt.doc.line.outer .. " "
	rslt.normal.block.pre = rslt.normal.block.pre .. " "
	rslt.normal.line = rslt.normal.line .. " "

	rslt.doc.block.inner.post = " " .. rslt.doc.block.inner.post
	rslt.doc.block.outer.post = " " .. rslt.doc.block.outer.post
	rslt.normal.block.post = " " .. rslt.normal.block.post

	return rslt
end

return mod
