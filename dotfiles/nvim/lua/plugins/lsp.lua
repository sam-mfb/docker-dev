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

-- rust-analyzer in ~/.cargo/bin is rustup's shim: it runs the copy that
-- belongs to the project's Rust version (rust-toolchain.toml). A project that
-- pins a version without the rust-analyzer component (profile = "minimal",
-- say) makes the shim exit at once, which Neovim reports as a crash. There,
-- use the default Rust version's rust-analyzer instead. It still builds and
-- checks the project with the project's own Rust version.
local function rust_analyzer_cmd(dispatchers, config)
  local root = config.root_dir
  local function which(args)
    local r = vim.system(vim.list_extend({ 'rustup', 'which' }, args), { cwd = root, text = true }):wait()
    local path = vim.trim(r.stdout or '')
    if r.code == 0 and path ~= '' and vim.fn.executable(path) == 1 then
      return path
    end
  end

  local exe = 'rust-analyzer'
  if vim.fn.executable('rustup') == 1 and not which({ 'rust-analyzer' }) then
    local default = vim.trim(vim.fn.system({ 'rustup', 'default' })):match('^(%S+)')
    local fallback = default and which({ '--toolchain', default, 'rust-analyzer' })
    if fallback then
      exe = fallback
      vim.schedule(function()
        vim.notify(('This project\'s Rust version has no rust-analyzer; using the one from %s'):format(default))
      end)
    end
    -- Neither has one: start the shim anyway, so its error lands in the LSP log.
  end
  return vim.lsp.rpc.start({ exe }, dispatchers, {
    cwd = config.cmd_cwd or root,
    env = config.cmd_env,
    detached = config.detached,
  })
end

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

      vim.lsp.config('rust_analyzer', { cmd = rust_analyzer_cmd })

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
