-- Formatting with conform.nvim. Prettier comes from the project's
-- node_modules when it has one (so the project's version and config apply),
-- otherwise from Mason. Filetypes without a formatter here fall back to the
-- language server's formatting (YAML, HTML, PowerShell, ...).
local prettier = { 'prettier' }

-- Format these on save; the same list coc used.
local on_save = {
  typescript = true, typescriptreact = true, javascript = true, javascriptreact = true,
  json = true, jsonc = true, css = true, scss = true, markdown = true, rust = true,
}

return {
  {
    'stevearc/conform.nvim',
    lazy = false, -- `keys` would otherwise delay loading, and format on save with it
    opts = {
      formatters_by_ft = {
        typescript = prettier, typescriptreact = prettier,
        javascript = prettier, javascriptreact = prettier,
        json = prettier, jsonc = prettier,
        css = prettier, scss = prettier, less = prettier,
        markdown = prettier,
        rust = { 'rustfmt' },
      },
      default_format_opts = { lsp_format = 'fallback' },
      format_on_save = function(buf)
        if vim.g.disable_autoformat or not on_save[vim.bo[buf].filetype] then
          return
        end
        return { timeout_ms = 2000 }
      end,
    },
    keys = {
      {
        '<leader>f',
        function() require('conform').format({ async = true }) end,
        mode = { 'n', 'x' },
        desc = 'Format file or selection',
      },
      {
        '<leader>tf',
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify('Format on save ' .. (vim.g.disable_autoformat and 'off' or 'on'))
        end,
        desc = 'Toggle format on save',
      },
    },
  },
}
