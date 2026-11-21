-- Neovim config for docker-dev. Installed to ~/.config/nvim by
-- install/steps/terminal/30-nvim-plugins.sh; edit it in the repo, not in place.
--
--   lua/config/   editor settings, keys and autocommands (no plugins)
--   lua/plugins/  one file per area, each returning lazy.nvim plugin specs
--
-- Keys are listed in cheatsheet.md (:Cheatsheet, or <space>?).

require('config.options')
require('config.lazy')
require('config.keymaps')
require('config.autocmds')
