-- fzf-lua: fuzzy pickers for files, text, buffers, symbols and diagnostics,
-- driven by the same fzf as the shell. Inside a picker: type to filter,
-- Ctrl-n / Ctrl-p (or arrows) move, Enter opens, Ctrl-v / Ctrl-s / Ctrl-t
-- open in a vertical split / split / tab, Esc closes.
local function pick(name, opts)
  return function() require('fzf-lua')[name](opts) end
end

return {
  {
    'ibhagwan/fzf-lua',
    lazy = false, -- also replaces vim.ui.select (code action menus and the like)
    opts = {
      defaults = { file_icons = false, git_icons = false },
    },
    config = function(_, opts)
      local fzf = require('fzf-lua')
      fzf.setup(opts)
      fzf.register_ui_select()
    end,
    keys = {
      { '<C-p>', pick('files'), desc = 'Find file' },
      { '<leader>/', pick('live_grep'), desc = 'Search text in project' },
      { '<leader>*', pick('grep_cword'), desc = 'Search word under cursor' },
      { '<leader>b', pick('buffers'), desc = 'Open buffers' },
      { '<leader>r', pick('oldfiles'), desc = 'Recent files' },
      { '<leader>a', pick('diagnostics_workspace'), desc = 'All diagnostics' },
      { '<leader>o', pick('lsp_document_symbols'), desc = 'Symbols in file (outline)' },
      { '<leader>s', pick('lsp_live_workspace_symbols'), desc = 'Symbols in project' },
      { '<leader>c', pick('commands'), desc = 'Commands' },
      { '<leader>k', pick('keymaps'), desc = 'Search key mappings' },
      { '<leader>H', pick('help_tags'), desc = 'Search help' },
      { '<leader>p', pick('resume'), desc = 'Reopen last picker' },
    },
  },
}
