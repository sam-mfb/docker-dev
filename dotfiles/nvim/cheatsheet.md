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

Inside the Ctrl-p list and the other file lists:

| Old | Now | Action |
| --- | --- | --- |
| Ctrl-x | **Ctrl-s** | Open in a horizontal split |
| | Ctrl-v | Open in a vertical split (unchanged) |
| | Ctrl-t | Open in a new tab (unchanged) |
| | Tab, then Alt-q | Mark several, send them to the quickfix list |

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

## Lean (new)

Open any `.lean` file. The infoview on the right shows the proof goals at
the cursor; proofs are checked as you type. Lean keys use `\` (the local
leader), not Space.

| Keys | Action |
| --- | --- |
| `\i` | Show / hide the infoview |
| `\` Tab | Jump into the infoview (and back) |
| `\x` / `\c` | Pin the current goal / clear pins |
| `\r` | Restart Lean for this file (after changing imports or dependencies) |
| `\\` | Show how to type the symbol under the cursor |
| `\to`, `\forall`, `\N`, `\alpha`, ... then Space | Type `→`, `∀`, `ℕ`, `α`, ... in Insert mode |

Go to definition, `K`, `grn`, `gra`, `]d` and completion work as for other
languages. In the margin, a 🎉 marks a finished proof.

| Command | Use |
| --- | --- |
| `lake new myproj` | New project (`lake new myproj math` for one using Mathlib) |
| `lake build` | Check the whole project. Run it before trusting a result |
| `lake exe cache get` | In a Mathlib project: download prebuilt Mathlib (about 5 GB). Do this once per project, or Mathlib compiles for an hour or more |
| `elan show` | Which Lean version this project uses (from its `lean-toolchain` file) |

## Colour scheme

The default is tokyonight. To switch for the current session:

| Command | Look |
| --- | --- |
| `:colorscheme vscode` | VS Code's Dark+ |
| `:colorscheme tokyonight` | Back to the default (blue-grey) |
| `:colorscheme tokyonight-night` / `-moon` / `-day` | Other tokyonight variants |

To make one the default, change `vim.cmd.colorscheme('tokyonight')` in
`dotfiles/nvim/lua/plugins/ui.lua` to the name you want, then rerun
`install/install.sh --only nvim-plugins`.

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
