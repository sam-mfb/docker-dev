# Neovim cheat sheet: what changed

Only what differs from the old vim + coc setup. Everything not listed works
as before: `gd`, `K`, `Ctrl-p`, the `Space a/o/s/c/p` lists, `Ctrl-h/j/k/l`,
folds, `:Git`.

The leader is now **Space** (was `\`). Press Space and pause: a popup lists
every key that follows. **Space ?** opens this sheet; `q` closes it.

## Completion

| Old | Now | Action |
| --- | --- | --- |
| Tab | **Ctrl-y** | Accept the selected item. Tab now just inserts a tab |
| | Ctrl-n / Ctrl-p | Next / previous item |
| | Ctrl-e | Close the menu |
| | Ctrl-Space | Open the menu; again to show or hide documentation |
| | Ctrl-f / Ctrl-b | Scroll the documentation |
| | Ctrl-k | Show / hide the function signature |
| | Ctrl-s (Insert mode) | Signature help |

## Code

| Old | Now | Action |
| --- | --- | --- |
| `gdv` / `gdt` | Space dv / Space dt | Definition in a vertical split / new tab |
| `gr` | grr | References |
| `gi` | gri | Implementations |
| `gy` | grt | Type definition |
| `\rn` | grn | Rename |
| `\do`, `\a`, `\qf` | gra | Code actions and quick fixes (Normal or Visual) |
| `\f` | Space f | Format file or selection |
| `:Prettier` | Space f | Format |
| | Space tf | Turn format-on-save off / on |
| `Ctrl-d` / `Ctrl-u` on a popup | K again, then scroll | Step into the documentation popup; `q` closes it |
| `Space j` / `Space k` | ]q / [q | Next / previous item in the quickfix list |
| `Space e` | :Mason | Language servers and tools |

## Diagnostics and spelling

| Old | Now | Action |
| --- | --- | --- |
| `[g` / `]g` | [d / ]d | Previous / next diagnostic |
| | [D / ]D | First / last diagnostic in the file |
| | Ctrl-w d | Full message for the diagnostic under the cursor |
| coc "add to dictionary" | Space z | Add the word under the cursor to the spelling list |

## Finding things (new)

| Keys | Action |
| --- | --- |
| Space / | Search text in the project |
| Space * | Search the word under the cursor |
| Space b | Open buffers |
| Space r | Recent files |
| Space k | Search key mappings |
| Space H | Search Neovim's help |

Inside any list, **Ctrl-v** / **Ctrl-s** / **Ctrl-t** open the item in a
vertical split / split / tab, and **Tab** then **Alt-q** sends marked items
to the quickfix list.

## Git (new)

| Keys | Action |
| --- | --- |
| ]c / [c | Next / previous changed block |
| Space hp | Preview the change |
| Space hs / Space hr | Stage / undo the change (or the selected lines) |
| Space hS | Stage the whole file |
| Space hb | Blame this line |
| Space tb | Toggle blame at the end of every line |
| Space gg | Git status (fugitive) |
| Space gb / Space gd / Space gl | Blame file / diff against index / log for file |

## Editing (new built-ins)

| Keys | Action |
| --- | --- |
| gcc, gc{motion} | Comment / uncomment |
| ]Space / [Space | Add a blank line below / above |
| ]b / [b | Next / previous buffer |
| Esc | Clear search highlighting |

## Gone

Arrow-key blocking, snippets, `\d` doc comments (vim-doge), and C# (coming
back later).

## Changed commands and files

| Old | Now |
| --- | --- |
| `:CocList extensions`, `:CocInstall` | `:Mason`, `:MasonToolsUpdate` |
| `:PlugUpdate` | `:Lazy`, then `U`. Copy `~/.config/nvim/lazy-lock.json` back to the repo to keep the versions |
| `:CocRestart` | `:lsp restart` |
| `:CocInfo` | `:checkhealth vim.lsp`, `:ConformInfo` |
| `~/.vimrc`, `coc-settings.json` | `dotfiles/nvim/` in the repo, installed to `~/.config/nvim/` |
| `cSpell.userWords` | `dotfiles/cspell/docker-dev-words.txt` (shared), `~/.config/cspell/my-words.txt` (Space z, this container only) |
