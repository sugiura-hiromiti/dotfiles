return {
	'mrcjkb/haskell-snippets.nvim',
	{
		'L3MON4D3/LuaSnip',
		dependencies = {
			{ 'rafamadriz/friendly-snippets' },
		},
		build = 'make install_jsregexp',
		config = function()
			require('luasnip').setup { updateevents = 'TextChanged,TextChangedI' }
			require('luasnip.loaders.from_vscode').lazy_load()

			local my_lua_api = require 'my_lua_api.util'
			local ls = require 'luasnip'
			local s, i, c, t, f, d, sn =
				ls.s, ls.insert_node, ls.choice_node, ls.text_node, ls.function_node, ls.dynamic_node, ls.snippet_node

			ls.add_snippets('all', {
				s('td', {
					d(1, function(_)
						local cmt_str = vim.split(vim.bo.commentstring, '%s', { plain = true, trimempty = true })

						local todo_labels = { t 'TODO', t 'NOTE', t 'FIX', t 'WARN', t 'TEST', t 'HACK', t 'PERF' }
						local rslt_nodes = { t(cmt_str[1] .. ' '), c(1, todo_labels), t ': ', i(2) }
						if #cmt_str == 1 then
							return sn(nil, rslt_nodes)
						else
							rslt_nodes[#rslt_nodes + 1] = t(' ' .. cmt_str[2])
							return sn(nil, rslt_nodes)
						end
					end),
				}),
				s('cb', {
					d(1, function(_)
						local cmt_map = my_lua_api.comment_indicators(vim.bo.comments)
						local all = { cmt_map.doc.block.outer }

						if all[1].pre ~= cmt_map.doc.block.inner.pre then
							all[2] = cmt_map.doc.block.inner
						end
						if all[1].pre ~= cmt_map.normal.block.pre and all[2].pre ~= cmt_map.normal.block.pre then
							all[3] = cmt_map.normal.block
						end

						local choice_arg = {}
						for idx, p in pairs(all) do
							choice_arg[idx] = t(p.pre)
						end

						local expand_at_new_line = false

						local pbpaste_hndlr = io.popen('pbpaste', 'r')
						---@type string
						local pbpaste = ''
						if pbpaste_hndlr ~= nil then
							pbpaste = pbpaste_hndlr:read '*a'
						end

						if pbpaste:find '\n' then
							expand_at_new_line = true
							if pbpaste:sub(1, 1) == '\n' then
								pbpaste = pbpaste:sub(2)
							end
							if pbpaste:sub(#pbpaste) ~= '\n' then
								pbpaste = pbpaste .. '\n'
							end
						end

						local lines = {}
						local lines_with_nl = { '' }
						local idx = pbpaste:find '\n'
						while idx do
							local sub = pbpaste:sub(1, idx - 1)
							lines[#lines + 1] = sub
							lines_with_nl[#lines_with_nl + 1] = sub
							pbpaste = pbpaste:sub(idx + 1)
							idx = pbpaste:find '\n'
						end
						lines_with_nl[#lines_with_nl + 1] = ''

						local yanked_list = {}
						if expand_at_new_line then
							yanked_list[1] = t(lines_with_nl)
							yanked_list[2] = t(lines)
						else
							yanked_list[1] = t(lines)
							yanked_list[2] = t(lines_with_nl)
						end
						yanked_list[3] = t ''
						local yanked_code = c(1, yanked_list)

						local pre_idx = 2
						local cb_pre = c(pre_idx, choice_arg)
						local cb_post = f(function(pre)
							local post = ''
							for _, p in pairs(all) do
								if pre[1][1] == p.pre then
									post = p.post
									break
								end
							end
							return post
						end, { pre_idx })

						return sn(nil, { cb_pre, yanked_code, cb_post })
					end, nil),
				}),
			})

			local haskell_snippets = require('haskell-snippets').all
			ls.add_snippets('haskell', haskell_snippets, { key = 'haskell' })
		end,
	},
}
