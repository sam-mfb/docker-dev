-- Keys that don't belong to a plugin. Plugin keys are defined next to the
-- plugin in lua/plugins/. Every map has a desc, which which-key shows.
local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- The cheat sheet, opened read-only on the right. q closes it.
local function cheatsheet()
  vim.cmd('botright vsplit ' .. vim.fn.fnameescape(vim.fn.stdpath('config') .. '/cheatsheet.md'))
  vim.bo.readonly = true
  vim.bo.modifiable = false
  map('n', 'q', '<cmd>close<CR>', { buffer = true, desc = 'Close cheat sheet' })
end
vim.api.nvim_create_user_command('Cheatsheet', cheatsheet, { desc = 'Open the Neovim cheat sheet' })
map('n', '<leader>?', cheatsheet, { desc = 'Cheat sheet' })
