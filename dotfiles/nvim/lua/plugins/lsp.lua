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
--
-- The rustup calls run in the background while the project root is found,
-- never while the editor waits: rust_analyzer_exe holds the answer per
-- project root, and the server's start command just looks it up.
local rust_analyzer_exe = {}

-- rustup_which ROOT ARGS CALLBACK -- path of the program, or nil, to CALLBACK.
local function rustup_which(root, args, callback)
  vim.system(vim.list_extend({ 'rustup', 'which' }, args), { cwd = root, text = true }, function(r)
    local path = vim.trim(r.stdout or '')
    callback(r.code == 0 and path ~= '' and vim.uv.fs_access(path, 'X') and path or nil)
  end)
end

-- Decide which rust-analyzer ROOT uses, then call DONE.
local function choose_rust_analyzer(root, done)
  if rust_analyzer_exe[root] or vim.fn.executable('rustup') == 0 then
    return done()
  end
  rustup_which(root, { 'rust-analyzer' }, function(own)
    if own then
      rust_analyzer_exe[root] = 'rust-analyzer'
      return done()
    end
    vim.system({ 'rustup', 'default' }, { text = true }, function(r)
      local default = vim.trim(r.stdout or ''):match('^(%S+)')
      if not default then
        return done()
      end
      rustup_which(nil, { '--toolchain', default, 'rust-analyzer' }, function(fallback)
        -- Neither has one: leave the shim, so its error lands in the LSP log.
        rust_analyzer_exe[root] = fallback or 'rust-analyzer'
        if fallback then
          vim.schedule(function()
            vim.notify(('rust-analyzer: this project pins a Rust version without it, so using the one from %s'):format(default))
          end)
        end
        done()
      end)
    end)
  end)
end

-- nvim-lspconfig's own root finder (it asks cargo for the workspace root),
-- saved before ours replaces it.
local lspconfig_rust_root_dir

local function rust_analyzer_root_dir(bufnr, on_dir)
  lspconfig_rust_root_dir(bufnr, function(root)
    if not root then
      return vim.schedule(function() on_dir(root) end)
    end
    choose_rust_analyzer(root, function()
      vim.schedule(function() on_dir(root) end)
    end)
  end)
end

local function rust_analyzer_cmd(dispatchers, config)
  return vim.lsp.rpc.start({ rust_analyzer_exe[config.root_dir] or 'rust-analyzer' }, dispatchers, {
    cwd = config.cmd_cwd or config.root_dir,
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

      -- Keep nvim-lspconfig's root finder (it asks cargo for the workspace)
      -- and add the rust-analyzer choice after it.
      lspconfig_rust_root_dir = vim.lsp.config.rust_analyzer.root_dir
      vim.lsp.config('rust_analyzer', {
        root_dir = rust_analyzer_root_dir,
        cmd = rust_analyzer_cmd,
      })

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
