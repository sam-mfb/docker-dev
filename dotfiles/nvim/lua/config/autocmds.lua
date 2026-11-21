local group = vim.api.nvim_create_augroup('docker-dev', { clear = true })
local autocmd = vim.api.nvim_create_autocmd

-- Treesitter highlighting for every filetype that has a parser installed.
-- Filetypes without one keep Vim's regex syntax highlighting.
autocmd('FileType', {
  group = group,
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang then
      pcall(vim.treesitter.start, ev.buf, lang)
    end
  end,
})

-- Check for files changed outside the editor once a second, so edits made by
-- Claude Code or git show up without leaving the buffer. checktime can't run
-- while the command line or command-line window is open.
local timer = vim.uv.new_timer()
if timer then
  timer:start(1000, 1000, vim.schedule_wrap(function()
    if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
      vim.cmd('silent! checktime')
    end
  end))
end

-- Briefly highlight yanked text.
autocmd('TextYankPost', {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

-- Hand the terminal a blinking bar cursor on exit, as the shell expects.
autocmd('VimLeave', {
  group = group,
  callback = function() vim.opt.guicursor = 'a:ver25-blinkon500-blinkoff500' end,
})
