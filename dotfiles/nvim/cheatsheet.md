# Neovim cheat sheet

The leader key is **Space**. Press Space and wait a moment: a popup lists
every key that follows it. The same happens after `g`, `gr`, `[`, `]` and
other prefixes.

- **Space ?** opens this sheet (or `:Cheatsheet`). `q` closes it.
- **Space k** searches every key mapping by name.

## Learn these first

| Keys | Action |
| --- | --- |
| **Ctrl-y** | **Accept the completion** (Tab no longer does; it just inserts a tab) |
| Ctrl-n / Ctrl-p | Move down / up the completion menu |
| gd | Go to definition (Ctrl-o jumps back) |
| K | Documentation for the word under the cursor |
| gra | Code actions and quick fixes |
| grn | Rename |
| ]d / [d | Next / previous error or warning |
| Ctrl-p | Find a file |
| Space / | Search text in the project |

## Coming from the old vim setup

| Old (vim + coc) | Now | What it does |
| --- | --- | --- |
| `gd` | `gd` | Go to definition |
| `gdv` / `gdt` | `Space dv` / `Space dt` | Definition in a vertical split / new tab |
| `gr` | `grr` | References |
| `gi` | `gri` | Implementations |
| `gy` | `grt` | Type definition |
| `\rn` | `grn` | Rename symbol |
| `\do`, `\a`, `\qf` | `gra` | Code actions and quick fixes (Visual mode too) |
| `\f` | `Space f` | Format file or selection |
| `[g` / `]g` | `[d` / `]d` | Previous / next diagnostic |
| `K` | `K` | Documentation. Press `K` again to step into the popup and scroll it |
| `Ctrl-d` / `Ctrl-u` on a popup | `K K`, then scroll | Step into the popup and scroll; `q` closes it |
| `Tab` in the menu | `Ctrl-y` | Accept a completion |
| `Ctrl-p` | `Ctrl-p` | Find a file |
| `Space a` | `Space a` | All diagnostics |
| `Space o` | `Space o` (or `gO`) | Symbols in this file |
| `Space s` | `Space s` | Symbols in the project |
| `Space c` | `Space c` | Commands |
| `Space p` | `Space p` | Reopen the last list |
| `Space j` / `Space k` | `]q` / `[q` | Next / previous quickfix item |
| `Space e` (extensions) | `:Mason` | Language servers and tools |
| `:Prettier` | `Space f` | Format |
| coc "add word to dictionary" | `Space z` | Add the word under the cursor to the spelling list |

Gone: arrow keys work again, there are no snippets, and `\d` (doc comment
generation) has been removed. C# is not set up yet.

## Finding things

| Keys | Action |
| --- | --- |
| Ctrl-p | Find file |
| Space / | Search text in the project (ripgrep, live) |
| Space * | Search the word under the cursor |
| Space b | Open buffers |
| Space r | Recent files |
| Space H | Search Neovim's help |
| Space k | Search key mappings |
| Space p | Reopen the last list where you left it |

Inside a list: type to filter, **Ctrl-n / Ctrl-p** move, **Enter** opens,
**Ctrl-v** / **Ctrl-s** / **Ctrl-t** open in a vertical split / split / tab,
**Tab** marks several, **Alt-q** sends the marked ones to the quickfix list,
**Esc** closes.

## Code navigation

These work once a language server has started for the file.

| Keys | Action |
| --- | --- |
| gd | Go to definition |
| Space dv / Space dt | Definition in a vertical split / new tab |
| grr | References |
| gri | Implementations |
| grt | Type definition |
| gO or Space o | Symbols in this file |
| Space s | Symbols in the project |
| K | Documentation popup. **K** again steps into it; **q** closes it |
| Ctrl-s (Insert mode) | Signature help for the function call |
| Ctrl-o / Ctrl-i | Jump back / forward (after `gd` and the like) |

## Changing code

| Keys | Action |
| --- | --- |
| grn | Rename the symbol everywhere |
| gra | Code actions: quick fixes, imports, refactors (Normal or Visual) |
| Space f | Format file, or the selection in Visual mode |
| Space tf | Turn format-on-save off / on |
| gcc | Comment / uncomment line |
| gc{motion}, gc (Visual) | Comment / uncomment lines |
| ]Space / [Space | Add a blank line below / above |

Files format on save with Prettier (TS/JS, JSON, CSS/SCSS, Markdown) or
rustfmt (Rust). Prettier comes from the project's `node_modules` when it has
one, so the project's version and config apply.

## Diagnostics and spelling

| Keys | Action |
| --- | --- |
| ]d / [d | Next / previous diagnostic |
| ]D / [D | Last / first diagnostic in the file |
| Ctrl-w d | Show the full diagnostic message under the cursor |
| Space a | List all diagnostics in the project |
| Space z | Add the word under the cursor to the spelling list |

The message for the line you are on shows at the end of that line. Spelling
mistakes are "info" diagnostics (`I` in the margin) and suggest a fix.

## Completion

The menu opens as you type.

| Keys | Action |
| --- | --- |
| Ctrl-y | Accept the selected item |
| Ctrl-n / Ctrl-p | Next / previous item |
| Ctrl-e | Close the menu |
| Ctrl-Space | Open the menu; again to show or hide the documentation |
| Ctrl-f / Ctrl-b | Scroll the documentation |
| Ctrl-k | Show / hide the function signature |

## Git

| Keys | Action |
| --- | --- |
| ]c / [c | Next / previous changed block (hunk) |
| Space hp | Preview the change |
| Space hs | Stage the change (or the selected lines) |
| Space hr | Undo the change (or the selected lines) |
| Space hS | Stage the whole file |
| Space hb | Blame this line, with the full commit |
| Space tb | Toggle blame at the end of every line |
| ih | Text object: the change under the cursor (`vih`, `dih`) |
| Space gg | Git status (fugitive). There: `s` stage, `u` unstage, `=` diff, `cc` commit, `g?` help |
| Space gb | Blame the whole file |
| Space gd | Diff the file against the index, side by side |
| Space gl | Log for this file |

Any git command works as `:Git <args>`, for example `:Git push`.

## Windows, tmux and folds

| Keys | Action |
| --- | --- |
| Ctrl-h / j / k / l | Move to the split or tmux pane left / down / up / right |
| :vs / :sp | Split vertically / horizontally |
| Ctrl-w q | Close the split |
| ]b / [b | Next / previous buffer |
| za | Open / close the fold under the cursor |
| zM / zR | Close / open every fold |
| Esc | Clear search highlighting |

## Commands

| Command | Use |
| --- | --- |
| :Lazy | Plugins: status, `U` to update |
| :Mason | Language servers and tools |
| :MasonToolsUpdate | Update every Mason tool |
| :TSUpdate | Update treesitter parsers (needed after updating nvim-treesitter) |
| :checkhealth vim.lsp | Which language servers are running for this file, and why not |
| :lsp restart | Restart the language servers |
| :LspEslintFixAll | Apply every ESLint fix in the file |
| :ConformInfo | Which formatter runs for this file |

## Where things live

- Config: `dotfiles/nvim/` in the docker-dev repo, installed to
  `~/.config/nvim/`. Edit the repo copy and rerun
  `install/install.sh --only nvim-plugins`; edits made in `~/.config/nvim`
  are overwritten.
- Plugin versions: `dotfiles/nvim/lazy-lock.json`. After `:Lazy update`, copy
  `~/.config/nvim/lazy-lock.json` back to the repo to keep the new versions.
- Language servers, parsers and tools to install: `lua/config/tools.lua`.
- Spelling: words shared through the repo go in
  `dotfiles/cspell/docker-dev-words.txt`. `Space z` adds to
  `~/.config/cspell/my-words.txt`, which is local to the container; copy
  anything worth keeping into the repo's list. A project's own `cspell.json`
  is read too.
