-- lazy.nvim: plugin manager. Plugin versions are pinned in lazy-lock.json,
-- which lives in the repo (dotfiles/nvim/lazy-lock.json). After :Lazy update,
-- copy ~/.config/nvim/lazy-lock.json back to the repo to keep the new versions.
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error('Could not clone lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = { { import = 'plugins' } },
  -- A small config: load everything at startup rather than tune lazy-loading.
  defaults = { lazy = false },
  install = { colorscheme = { 'vscode' } },
  checker = { enabled = false }, -- update on purpose, with :Lazy update
  change_detection = { notify = false },
  rocks = { enabled = false }, -- no plugin here needs luarocks
  ui = { border = 'rounded' },
})
