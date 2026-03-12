vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browser_split = 4
vim.g.netrw_winsize = 25

local function map(mode, l, r)
	vim.keymap.set(mode, l, r, { buffer = true, remap = true })
end

map("n", "h", "-")
map("n", "l", "<cr>")
map("n", "<c-v>", "v")
map("n", "<c-x>", "o")
map("n", "n", "%")
