-- Spell checking in code with cspell, run through nvim-lint. Misspellings
-- show as "info" diagnostics with the other diagnostics.
--
-- Word lists, in ~/.config/cspell/ (cspell reads cspell.json there on its own,
-- merged with any cspell.json the project has):
--   docker-dev-words.txt  from the repo (dotfiles/cspell); edit it there
--   my-words.txt          words added with <leader>z; not managed by the repo,
--                         so copy any you want to keep into the repo's list
local filetypes = {
  'typescript', 'typescriptreact', 'javascript', 'javascriptreact',
  'json', 'jsonc', 'yaml', 'html', 'css', 'scss', 'markdown',
  'rust', 'ps1', 'lua', 'sh', 'gitcommit', 'text',
}

local my_words = vim.fn.expand('~/.config/cspell/my-words.txt')

return {
  {
    'mfussenegger/nvim-lint',
    config = function()
      local lint = require('lint')
      lint.linters_by_ft = {}
      for _, ft in ipairs(filetypes) do
        lint.linters_by_ft[ft] = { 'cspell' }
      end

      -- cspell is a node program, so don't start it on every keystroke: wait
      -- until typing pauses.
      local timer = assert(vim.uv.new_timer())
      local function lint_soon()
        timer:stop()
        timer:start(500, 0, vim.schedule_wrap(function() lint.try_lint() end))
      end
      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave', 'TextChanged' }, {
        group = vim.api.nvim_create_augroup('docker-dev-lint', { clear = true }),
        callback = lint_soon,
      })

      -- Add the word under the cursor to my-words.txt and check again.
      vim.keymap.set('n', '<leader>z', function()
        local word = vim.fn.expand('<cword>')
        if word == '' then return end
        vim.fn.mkdir(vim.fn.fnamemodify(my_words, ':h'), 'p')
        local f = assert(io.open(my_words, 'a'))
        f:write(word .. '\n')
        f:close()
        vim.notify('Added "' .. word .. '" to ' .. vim.fn.fnamemodify(my_words, ':~'))
        lint.try_lint()
      end, { desc = 'Add word to spelling dictionary' })
    end,
  },
}
