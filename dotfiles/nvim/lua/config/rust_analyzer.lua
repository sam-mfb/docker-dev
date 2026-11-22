-- How rust-analyzer starts for a project. Replaces nvim-lspconfig's root_dir
-- and cmd for it (see plugins/lsp.lua), for two reasons:
--
-- 1. Nothing may wait on Rust tools with the editor frozen. A project can pin
--    a Rust version (rust-toolchain.toml) that isn't installed yet; the first
--    cargo, rustc or rustup call in it then makes rustup download that version,
--    which can take a minute. nvim-lspconfig ran `rustc --print sysroot` and
--    waited for it, freezing the editor for the whole download. Here every
--    call runs in the background, and a progress message says what is going
--    on (rustup's own "syncing channel updates", "downloading component" lines).
--
-- 2. rust-analyzer in ~/.cargo/bin is rustup's shim: it runs the copy that
--    belongs to the project's Rust version. A project that pins a version
--    without the rust-analyzer component (profile = "minimal", say) makes the
--    shim exit at once, which Neovim reports as a crash. There, use the default
--    Rust version's rust-analyzer instead. It still builds and checks the
--    project with the project's own Rust version.
local M = {}

local workspace_root = {} -- Cargo.toml folder -> workspace root, from cargo metadata
local analyzer_exe = {} -- workspace root -> rust-analyzer program to start

-- Cut TEXT to fit the message line after a prefix of RESERVED characters.
-- A message longer than the line makes Neovim stop at "Press ENTER", which
-- looks like a hang.
local function fit(text, reserved)
  local room = math.max(vim.v.echospace - reserved - 1, 10)
  return vim.fn.strchars(text) <= room and text or vim.fn.strcharpart(text, 0, room - 3) .. '...'
end

-- progress KEY TEXT STATUS -- create or update one progress message per KEY.
-- STATUS is 'running', 'success' or 'failed'; the last two stay in :messages.
local function progress(key, text, status)
  vim.schedule(function()
    vim.api.nvim_echo({ { fit(text, #'Rust: ') } }, status ~= 'running', {
      kind = 'progress',
      id = 'docker-dev.rust.' .. key,
      source = 'docker-dev',
      title = 'Rust',
      status = status,
    })
  end)
end

-- Ask cargo for the workspace root of the crate in CRATE, then call
-- DONE(root), or DONE(nil) if cargo fails. If this takes more than a second
-- (usually rustup installing the project's Rust version), say so.
local function find_workspace(crate, done)
  if workspace_root[crate] then
    return done(workspace_root[crate])
  end
  local name = vim.fs.basename(crate)
  local finished, shown = false, false
  local function show(text, status)
    shown = true
    progress(crate, name .. ': ' .. text, status)
  end
  vim.defer_fn(function()
    if not finished then show('preparing (cargo metadata)', 'running') end
  end, 1000)

  local stderr, partial = {}, ''
  vim.system({ 'cargo', 'metadata', '--no-deps', '--format-version', '1' }, {
    cwd = crate,
    text = true,
    stderr = function(_, data)
      if not data then return end
      partial = partial .. data
      for line in partial:gmatch('([^\r\n]*)[\r\n]') do
        table.insert(stderr, line)
        local info = line:match('^info:%s*(.+)') -- rustup's progress lines
        if info then show(info, 'running') end
      end
      partial = partial:match('[^\r\n]*$')
    end,
  }, function(out)
    finished = true
    local root
    if out.code == 0 then
      local ok, meta = pcall(vim.json.decode, out.stdout or '')
      root = ok and meta.workspace_root and vim.fs.normalize(meta.workspace_root) or crate
      workspace_root[crate] = root
      if shown then show('ready', 'success') end
    else
      if shown then show('failed', 'failed') end
      vim.schedule(function()
        vim.notify(('rust-analyzer not started: `cargo metadata` failed in %s\n%s')
          :format(crate, table.concat(stderr, '\n')), vim.log.levels.WARN)
      end)
    end
    done(root)
  end)
end

-- rustup_which ROOT ARGS CALLBACK -- path of the program, or nil, to CALLBACK.
local function rustup_which(root, args, callback)
  vim.system(vim.list_extend({ 'rustup', 'which' }, args), { cwd = root, text = true }, function(r)
    local path = vim.trim(r.stdout or '')
    callback(r.code == 0 and path ~= '' and vim.uv.fs_access(path, 'X') and path or nil)
  end)
end

-- Decide which rust-analyzer ROOT uses, then call DONE.
local function choose_analyzer(root, done)
  if analyzer_exe[root] or vim.fn.executable('rustup') == 0 then
    return done()
  end
  rustup_which(root, { 'rust-analyzer' }, function(own)
    if own then
      analyzer_exe[root] = 'rust-analyzer'
      return done()
    end
    vim.system({ 'rustup', 'default' }, { text = true }, function(r)
      local default = vim.trim(r.stdout or ''):match('^(%S+)')
      if not default then return done() end
      rustup_which(nil, { '--toolchain', default, 'rust-analyzer' }, function(fallback)
        -- Neither has one: leave the shim, so its error lands in the LSP log.
        analyzer_exe[root] = fallback or 'rust-analyzer'
        if fallback then
          -- "stable", not "stable-aarch64-unknown-linux-gnu".
          local short = default:gsub('%-[%w_]+%-unknown%-linux%-gnu$', '')
          vim.schedule(function()
            vim.api.nvim_echo({ { fit(("rust-analyzer: using %s's (this project's Rust has none)"):format(short), 0) } }, true, {})
          end)
        end
        done()
      end)
    end)
  end)
end

-- root_dir for vim.lsp.config: the same roots nvim-lspconfig picks, found
-- without blocking.
function M.root_dir(bufnr, on_dir)
  if vim.fn.executable('cargo') == 0 then return end
  local fname = vim.api.nvim_buf_get_name(bufnr)

  local function start(root)
    if not root then return end
    choose_analyzer(root, function()
      vim.schedule(function() on_dir(root) end)
    end)
  end

  -- Library sources (Rust's own under rustup's toolchains, crates.io and git
  -- dependencies) join the server that is already running, as in
  -- nvim-lspconfig; that needs no `rustc --print sysroot`.
  local home = vim.fs.normalize('~')
  local cargo_home = vim.env.CARGO_HOME or (home .. '/.cargo')
  local rustup_home = vim.env.RUSTUP_HOME or (home .. '/.rustup')
  for _, dir in ipairs({ rustup_home .. '/toolchains', cargo_home .. '/registry/src', cargo_home .. '/git/checkouts' }) do
    if vim.fs.relpath(dir, fname) then
      local clients = vim.lsp.get_clients({ name = 'rust_analyzer' })
      if #clients > 0 then
        return on_dir(clients[#clients].config.root_dir)
      end
    end
  end

  local crate = vim.fs.root(fname, { 'Cargo.toml' })
  if not crate then
    return start(vim.fs.root(fname, { 'rust-project.json' }) or vim.fs.root(fname, { '.git' }))
  end
  find_workspace(crate, start)
end

-- cmd for vim.lsp.config: start the rust-analyzer chosen for the project.
function M.cmd(dispatchers, config)
  return vim.lsp.rpc.start({ analyzer_exe[config.root_dir] or 'rust-analyzer' }, dispatchers, {
    cwd = config.cmd_cwd or config.root_dir,
    env = config.cmd_env,
    detached = config.detached,
  })
end

return M
