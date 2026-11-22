-- Editor settings. Leader keys are set here, before any plugin defines a map.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

local o = vim.opt

o.number = true
o.signcolumn = 'yes'
o.wrap = true
o.splitbelow = true
o.splitright = true
o.winborder = 'rounded' -- borders on hover, signature and diagnostic popups

-- Indentation: two spaces.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.smartindent = true

-- Folding by treesitter. Everything starts open; buffers without a parser
-- simply have no folds.
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.foldtext = '' -- show the folded line itself, highlighted
o.foldcolumn = '2'
o.foldlevelstart = 99

-- Reload files changed outside the editor (Claude Code, git checkout, ...).
-- A timer in autocmds.lua checks every second.
o.autoread = true

o.updatetime = 300 -- CursorHold sooner: symbol highlight, lint
o.shortmess:append('c')
o.modeline = false -- modelines have a history of security bugs

-- Yank and paste through the system clipboard.
o.clipboard = 'unnamedplus'

-- Each copy goes two ways: to the container's X clipboard through xclip
-- (noVNC, and `p`), and out to the terminal as OSC 52, which reaches the Mac
-- clipboard (see run.sh and host/osc52wrap; inside tmux, through its
-- set-clipboard). Neovim's own detection would pick only one of the two.
-- Paste never asks the terminal over OSC 52: the Mac side doesn't answer such
-- requests, so it would only wait and time out. Cmd-V pastes Mac text as
-- typed input instead.
do
  local osc52 = require('vim.ui.clipboard.osc52')
  local last = {} -- reg -> { lines, regtype }: the paste source without X

  local function copy(reg)
    local send_osc52 = osc52.copy(reg)
    return function(lines, regtype)
      last[reg] = { lines, regtype }
      if vim.env.DISPLAY and vim.fn.executable('xclip') == 1 then
        -- Detached, like Neovim's own xclip provider: xclip keeps running to
        -- hold the selection until something else takes it.
        vim.system({ 'xclip', '-quiet', '-i', '-selection', 'clipboard' }, {
          stdin = table.concat(lines, '\n'),
          detach = true,
        })
      end
      send_osc52(lines, regtype)
    end
  end

  local function paste(reg)
    return function()
      if vim.env.DISPLAY and vim.fn.executable('xclip') == 1 then
        local r = vim.system({ 'xclip', '-o', '-selection', 'clipboard' }, { text = true }):wait(2000)
        if r.code == 0 then
          return vim.split(r.stdout or '', '\n')
        end
      end
      return last[reg] or { {}, 'v' }
    end
  end

  vim.g.clipboard = {
    name = 'xclip+osc52',
    copy = { ['+'] = copy('+'), ['*'] = copy('*') },
    paste = { ['+'] = paste('+'), ['*'] = paste('*') },
  }
end

-- Every *.json is JSON with comments, so config files with comments don't
-- show errors.
vim.filetype.add({ extension = { json = 'jsonc' } })
