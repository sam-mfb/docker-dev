# tmux cheat sheet

The prefix is **Ctrl-a**. Press it, let go, then press the key.

## Sessions

| Keys | Action |
| --- | --- |
| Ctrl-a N | New session: type a name, Enter. Starts in the current folder. An existing name switches to it. |
| Ctrl-a Tab | Back to the previous session |
| Ctrl-a s | Choose a session (arrows, Enter; → expands a session's windows) |
| Ctrl-a $ | Rename this session |
| Ctrl-a d | Detach (the sessions keep running) |

## Windows

| Keys | Action |
| --- | --- |
| Ctrl-a c | New window in the current folder |
| Ctrl-a n / p | Next / previous window |
| Ctrl-a 0–9 | Go to window by number |
| Ctrl-a , | Rename this window |
| Ctrl-a & | Close this window |

## Panes

| Keys | Action |
| --- | --- |
| Ctrl-a " | Split, new pane below |
| Ctrl-a % | Split, new pane to the right |
| Ctrl-h / j / k / l | Move to the pane left / down / up / right (works across vim splits) |
| Ctrl-\ | Back to the previous pane |
| Ctrl-a Ctrl-h / j / k / l | Resize (hold Ctrl and repeat) |
| Ctrl-a z | Zoom this pane in and out |
| Ctrl-a x | Close this pane |

## Copying

| Keys | Action |
| --- | --- |
| Ctrl-a [ | Enter copy mode (vi keys to move) |
| Space | Start selecting (v switches to a block selection) |
| y | Copy to the clipboard and leave copy mode |
| q | Leave copy mode |

## Reading the status bar

- **[name]** on the left is the current session. Each session has its own bar color.
- The **inverted** window (color on black) is the current one.
- **●** before a window's name means its program rang the bell, for example Claude Code finishing. The `!` after the name means the same.
- **-** after a window's name marks the last window you were in. **Z** marks a zoomed pane.
