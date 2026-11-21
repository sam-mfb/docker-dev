-- Completion menu. Ctrl-y accepts, Ctrl-n / Ctrl-p move, Ctrl-e closes,
-- Ctrl-Space opens it (or its documentation), Ctrl-b / Ctrl-f scroll the
-- documentation, Ctrl-k toggles the signature help.
return {
  {
    'saghen/blink.cmp',
    -- Release tags come with a prebuilt fuzzy matcher (downloaded at install
    -- time); the main branch would need a Rust build.
    version = '1.*',
    opts = {
      keymap = { preset = 'default' },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
        -- Kind as a word rather than an icon, so no Nerd Font is needed.
        menu = { draw = { columns = { { 'label', 'label_description', gap = 1 }, { 'kind' } } } },
      },
      signature = { enabled = true },
      sources = { default = { 'lsp', 'path', 'buffer' } },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
  },
}
