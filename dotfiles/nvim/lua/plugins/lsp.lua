-- Language servers, through Neovim's built-in LSP client.
--
-- Mason installs the servers (list in config/tools.lua), nvim-lspconfig
-- supplies each server's default command and settings, and vim.lsp.enable()
-- starts them. Neovim's own LSP keys (grr, grn, gra, gri, grt, gO, K, [d, ]d)
-- work as soon as a server attaches; the few extra keys are below.
local tools = require('config.tools')

-- Only start servers whose program exists: rust-analyzer comes from the
-- optional rust step, and the PowerShell server needs pwsh.
local requires = { rust_analyzer = 'rust-analyzer', powershell_es = 'pwsh' }

return {
  {
    'mason-org/mason.nvim',
    opts = { ui = { border = 'rounded' } },
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
      ensure_installed = tools.mason,
      -- Tools are installed when the image is built. Don't hit the network on
      -- every start; :MasonToolsInstall adds anything newly listed.
      run_on_start = false,
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = { 'mason-org/mason.nvim', 'b0o/SchemaStore.nvim', 'saghen/blink.cmp' },
    config = function()
      vim.lsp.config('vtsls', {
        settings = {
          -- Use the project's own TypeScript from node_modules when it has one.
          vtsls = { autoUseWorkspaceTsdk = true },
          typescript = { preferences = { preferTypeOnlyAutoImports = true } },
        },
      })

      -- Schemas for package.json, tsconfig.json, compose files, CI configs, ...
      vim.lsp.config('jsonls', {
        settings = {
          json = { schemas = require('schemastore').json.schemas(), validate = { enable = true } },
        },
      })
      vim.lsp.config('yamlls', {
        settings = {
          yaml = {
            schemaStore = { enable = false, url = '' }, -- SchemaStore.nvim supplies them
            schemas = require('schemastore').yaml.schemas(),
          },
        },
      })

      -- Finds the project without freezing the editor while rustup installs
      -- a pinned Rust version, and picks a rust-analyzer that exists. See
      -- config/rust_analyzer.lua.
      local rust_analyzer = require('config.rust_analyzer')
      vim.lsp.config('rust_analyzer', { root_dir = rust_analyzer.root_dir, cmd = rust_analyzer.cmd })

      vim.lsp.config('powershell_es', {
        bundle_path = vim.fn.stdpath('data') .. '/mason/packages/powershell-editor-services',
        settings = {
          powershell = { codeFormatting = { preset = 'Allman', useCorrectCasing = true } },
        },
      })

      for _, server in ipairs(tools.servers) do
        local exe = requires[server]
        if not exe or vim.fn.executable(exe) == 1 then
          vim.lsp.enable(server)
        end
      end

      vim.diagnostic.config({
        severity_sort = true,
        virtual_text = { current_line = true }, -- message for the cursor's line only
        float = { source = 'if_many' },
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('docker-dev-lsp', { clear = true }),
        callback = function(ev)
          local function map(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc })
          end
          map('gd', vim.lsp.buf.definition, 'Go to definition')
          map('<leader>dv', function()
            vim.cmd('vsplit')
            vim.lsp.buf.definition()
          end, 'Definition in a vertical split')
          map('<leader>dt', function()
            vim.cmd('tab split')
            vim.lsp.buf.definition()
          end, 'Definition in a new tab')

          -- Highlight other uses of the symbol under the cursor.
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', ev.buf) then
            local hl = vim.api.nvim_create_augroup('docker-dev-lsp-hl-' .. ev.buf, { clear = true })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              group = hl, buffer = ev.buf, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, {
              group = hl, buffer = ev.buf, callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })
    end,
  },
  { 'b0o/SchemaStore.nvim', lazy = true, version = false },
}
