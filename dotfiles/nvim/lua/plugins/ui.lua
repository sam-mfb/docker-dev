-- Look and feel: colour scheme, status line, key hints. Nothing here needs a
-- Nerd Font; icons are turned off.
return {
  {
    'folke/tokyonight.nvim',
    priority = 1000, -- before other plugins, so they pick up its colours
    opts = { style = 'storm' }, -- blue-grey, close to OceanicNext
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme('tokyonight')
    end,
  },

  -- Installed but not the default: VS Code's Dark+ look (the Lua successor to
  -- vim-code-dark). `:colorscheme vscode` switches to it; see cheatsheet.md.
  -- lazy.nvim loads it when that command names it.
  { 'Mofiqul/vscode.nvim', lazy = true },

  {
    'nvim-lualine/lualine.nvim',
    opts = {
      options = {
        theme = 'auto', -- follows whichever colour scheme is active
        icons_enabled = false,
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  {
    'folke/which-key.nvim',
    opts = {
      preset = 'modern',
      delay = 400, -- ms before the popup appears after a prefix key
      icons = {
        mappings = false,
        breadcrumb = '>',
        separator = '->',
        group = '+',
        ellipsis = '...',
        -- Key names as text; the defaults are Nerd Font glyphs.
        keys = {
          Up = 'Up ', Down = 'Down ', Left = 'Left ', Right = 'Right ',
          C = 'Ctrl-', M = 'Alt-', D = 'Cmd-', S = 'Shift-',
          CR = 'Enter ', NL = 'Enter ', Esc = 'Esc ', BS = 'Bksp ', Space = 'Space ', Tab = 'Tab ',
          ScrollWheelDown = 'WheelDown ', ScrollWheelUp = 'WheelUp ',
          F1 = 'F1', F2 = 'F2', F3 = 'F3', F4 = 'F4', F5 = 'F5', F6 = 'F6',
          F7 = 'F7', F8 = 'F8', F9 = 'F9', F10 = 'F10', F11 = 'F11', F12 = 'F12',
        },
      },
      spec = {
        { '<leader>g', group = 'git' },
        { '<leader>h', group = 'git hunks' },
        { '<leader>t', group = 'toggle' },
        { '<leader>d', group = 'definition in split/tab' },
        { 'gr', group = 'LSP' },
        { '[', group = 'previous' },
        { ']', group = 'next' },
      },
    },
  },
}
