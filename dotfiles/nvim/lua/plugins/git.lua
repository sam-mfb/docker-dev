-- Git: fugitive for git commands inside the editor (:Git), gitsigns for
-- changed-line markers and hunk actions.
return {
  {
    'tpope/vim-fugitive',
    keys = {
      { '<leader>gg', '<cmd>Git<CR>', desc = 'Git status (fugitive)' },
      { '<leader>gb', '<cmd>Git blame<CR>', desc = 'Blame whole file' },
      { '<leader>gd', '<cmd>Gvdiffsplit<CR>', desc = 'Diff file against index' },
      { '<leader>gl', '<cmd>Git log --oneline -- %<CR>', desc = 'Log for this file' },
    },
    lazy = false,
  },
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      on_attach = function(buf)
        local gs = require('gitsigns')
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end

        -- ]c / [c: next / previous change. In diff mode they keep their
        -- built-in meaning.
        map('n', ']c', function()
          if vim.wo.diff then vim.cmd.normal({ ']c', bang = true }) else gs.nav_hunk('next') end
        end, 'Next git change')
        map('n', '[c', function()
          if vim.wo.diff then vim.cmd.normal({ '[c', bang = true }) else gs.nav_hunk('prev') end
        end, 'Previous git change')

        map('n', '<leader>hp', gs.preview_hunk, 'Preview change')
        map('n', '<leader>hs', gs.stage_hunk, 'Stage change')
        map('n', '<leader>hr', gs.reset_hunk, 'Undo change (reset hunk)')
        map('x', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Stage selected lines')
        map('x', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Reset selected lines')
        map('n', '<leader>hS', gs.stage_buffer, 'Stage whole file')
        map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame this line')
        map('n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle inline blame')
        map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Inside git change')
      end,
    },
  },
}
