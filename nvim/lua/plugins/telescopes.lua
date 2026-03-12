local yank_path_selected = function()
	local entry = require('telescope.actions.state').get_selected_entry()
	local cb_opts = vim.opt.clipboard:get()
	if vim.tbl_contains(cb_opts, 'unnamed') then
		vim.fn.setreg('*', entry.path)
	end
	if vim.tbl_contains(cb_opts, 'unnamedplus') then
		vim.fn.setreg('+', entry.path)
	end
	vim.fn.setreg('', entry.path)
end

return {
	{
		'nvim-telescope/telescope.nvim',
		config = function()
			local t = require 'telescope'
			local a = require 'telescope.actions'
			t.setup {
				defaults = {
					layout_strategy = 'vertical',
					layout_config = {
						flex = {
							flip_columns = 160,
							horizontal = {
								preview_width = 0.7,
							},
						},
					},
					mappings = {
						i = {
							['<C-j>'] = a.preview_scrolling_down,
							['<C-k>'] = a.preview_scrolling_up,
							['<C-d>'] = a.nop,
							['<C-u>'] = a.nop,
						},
					},
					winblend = 40,
					dynamic_preview_title = true,
					vimgrep_arguments = {
						'rg',
						'--color=never',
						'--no-heading',
						'--with-filename',
						'--line-number',
						'--column',
						'--smart-case',
						'--hidden',
					},
				},
				pickers = {
					buffers = {
						mappings = {
							i = {
								['<C-d>'] = a.delete_buffer,
							},
						},
					},
				},
				extensions = {
					file_browser = {
						grouped = true,
						select_buffer = true,
						hidden = true,
						respect_gitignore = false,
						follow_symlinks = true,
						collapse_dirs = true,
						mappings = {
							['i'] = {
								-- C have to be upper case to work
								['<C-t>'] = a.select_tab,
								['<C-y>'] = yank_path_selected,
							},
						},
					},
					smart_open = {
						show_scores = true,
						mappings = {
							['i'] = {
								['<C-y>'] = yank_path_selected,
							},
						},
					},
					['ui-select'] = {
						require('telescope.themes').get_dropdown {},
					},
					fzf = {
						fuzzy = true,
						override_generic_sorter = true,
						override_file_sorter = true,
						case_mode = 'smart_case',
					},
				},
			}
			t.load_extension 'smart_open'
			t.load_extension 'ui-select'
			t.load_extension 'fzf'
		end,
	},
}
