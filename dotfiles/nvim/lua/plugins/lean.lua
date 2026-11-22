-- Lean 4: language server, infoview (proof goals at the cursor), unicode
-- input (\to -> →) and Lean highlighting. The language server comes with each
-- project's Lean toolchain (installed by elan), so Mason has nothing to add.
-- Keys are under the local leader, \ (see cheatsheet.md).
return {
  {
    'Julian/lean.nvim',
    event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },
    init = function()
      vim.g.lean_config = { mappings = true }
    end,
  },
}
