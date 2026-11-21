-- nvim-treesitter installs parsers; Neovim itself does the highlighting and
-- folding (see config/autocmds.lua and config/options.lua). Parsers are
-- compiled with tree-sitter-cli (from Mason) and a C compiler.
return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate', -- parsers must match the plugin version
  },
}
