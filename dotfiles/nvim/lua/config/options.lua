-- Editor settings. Leader keys are set here, before any plugin defines a map.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

local o = vim.opt

o.number = true
o.signcolumn = 'yes'
o.wrap = true
o.splitbelow = true
o.splitright = true
o.winborder = 'rounded' -- borders on hover, signature and diagnostic popups

-- Indentation: two spaces.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.smartindent = true

-- Folding by treesitter. Everything starts open; buffers without a parser
-- simply have no folds.
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.foldtext = '' -- show the folded line itself, highlighted
o.foldcolumn = '2'
o.foldlevelstart = 99

-- Reload files changed outside the editor (Claude Code, git checkout, ...).
-- A timer in autocmds.lua checks every second.
o.autoread = true

o.updatetime = 300 -- CursorHold sooner: symbol highlight, lint
o.shortmess:append('c')
o.modeline = false -- modelines have a history of security bugs

-- Yank and paste through the system clipboard. Neovim finds xclip when
-- DISPLAY is set (see dotfiles/bashrc and the desktop step).
o.clipboard = 'unnamedplus'

-- Every *.json is JSON with comments, so config files with comments don't
-- show errors.
vim.filetype.add({ extension = { json = 'jsonc' } })
