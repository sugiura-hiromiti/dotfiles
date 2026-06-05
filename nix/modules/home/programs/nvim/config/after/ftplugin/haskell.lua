vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.expandtab = true
-- vim.bo.autoindent = false
-- vim.opt.listchars = { multispace = '| ' }

local m = vim.keymap.set
local ht = require 'haskell-tools'
local bufnr = vim.api.nvim_get_current_buf()
local opts = { buffer = bufnr }

m('n', 'H', ht.hoogle.hoogle_signature, opts)
