-- External tools the config uses, kept in one place. The install step reads
-- these lists to install everything ahead of time, so the editor never
-- downloads anything on first use.
local M = {}

-- Installed by Mason into ~/.local/share/nvim/mason.
M.mason = {
  'vtsls', -- TypeScript and JavaScript
  'eslint-lsp',
  'html-lsp',
  'css-lsp', -- CSS, SCSS, Less
  'json-lsp',
  'yaml-language-server',
  'powershell-editor-services',
  'prettier', -- used only when a project has no prettier of its own
  'cspell',
  'tree-sitter-cli', -- builds the treesitter parsers below
}

-- Language servers to start (names from nvim-lspconfig). rust_analyzer comes
-- from rustup, not Mason, so it always matches the toolchain.
M.servers = {
  'vtsls',
  'eslint',
  'html',
  'cssls',
  'jsonls',
  'yamlls',
  'powershell_es',
  'rust_analyzer',
}

-- Treesitter parsers: highlighting, folding and text objects.
M.parsers = {
  'typescript', 'tsx', 'javascript', 'jsdoc',
  'json', 'yaml', 'toml',
  'html', 'css', 'scss',
  'rust', 'powershell', 'bash', 'dockerfile', 'lua',
  'markdown', 'markdown_inline',
  'diff', 'gitcommit', 'git_rebase', 'git_config', 'gitignore',
  'regex', 'vim', 'vimdoc', 'query',
}

return M
