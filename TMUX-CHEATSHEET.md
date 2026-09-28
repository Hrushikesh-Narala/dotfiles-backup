# tmux reference — this machine

Generated from the live server (`tmux list-keys`) on tmux **3.7c**, so it describes what
actually runs, not what the config intends.

- Prefix: **`Ctrl-a`** (changed from the default `Ctrl-b`)
- Config: `~/.config/tmux/tmux.conf` → sources `~/.config/tmux/tmux.reset.conf`
- Plugins: `~/.tmux/plugins/` (TPM-managed)
- Shell inside panes: zsh, `TERM=tmux-256color`, truecolor

**Your config is defaults-plus-overrides, not a clean slate.** `unbind-key -a` is commented
out in `tmux.reset.conf:2`, so every stock tmux binding still exists unless you overrode it.
Anything not listed here is a default binding and works as it does in vanilla tmux.

Notation: `C-a` = prefix, then the key. `M-x` = Alt, `C-x` = Ctrl.

---

## Panes

| Keys | Action |
|---|---|
| `C-a` `s` | Split **vertically** (pane below) |
| `C-a` `v` | Split **horizontally** (pane beside) |
| `C-a` `\|` | Split vertically (default) |
| `C-a` `%` | Split horizontally (default) |
| `C-a` `h` `j` `k` `l` | Move focus left / down / up / right |
| `C-a` `←↑↓→` | Move focus (default, with `escape-time 0` so no delay) |
| `C-a` `C-o` | Rotate panes through empty slots |
| `C-a` `c` | Kill pane |
| `C-a` `z` | Zoom / unzoom pane to fill window |
| `C-a` `x` | Swap pane with the one below |
| `C-a` `{` / `}` | Swap pane up / down (defaults) |
| `C-a` `m` | Mark pane (marks survive pane-killing moves) |
| `C-a` `M` | Move focus to marked pane |
| `C-a` `;` | Jump to last active pane |
| `C-a` `q` | Show pane numbers, press a number to jump |
| `C-a` `!` | Break pane into its own window |

`s` and `v` both inherit the current directory (`-c "#{pane_current_path}"`), unlike
`|` and `%`. `C-a` `C-c` (new window in `~`) is under Windows.

### Resize

| Keys | Action |
|---|---|
| `C-a` `M-←↑↓→` | Resize by **5** cells, repeatable (no timeout — hold Alt+arrow) |
| `C-a` `C-←↑↓→` | Resize by **1** cell |
| `C-a` `,` | Shrink left by 20 |
| `C-a` `.` | Grow right by 20 |
| `C-a` `-` | Shrink down by 7 |
| `C-a` `=` | Grow up by 7 |
| `C-a` `Shift-↑↓←→` | Move the *client window* itself, 10 cells — for detached/nested clients |
| drag border | Resize (mouse is on) |
| `C-a` `F` → pane → resize | Fuzzy resize by direction and size |

From the command line: `C-a` `:` then `resize-pane -R 10` (`-L` left, `-U` up, `-D` down).
`resize-pane -A 20` resizes every pane in the window. `-t %3` targets a pane id.

### Layouts

`C-a` `Space` cycles the next layout. `C-a` `E` applies even-horizontal. `C-a` `M-1` … `M-7`:

| Key | Layout |
|---|---|
| `M-1` | even-horizontal (all side by side) |
| `M-2` | even-vertical (all stacked) |
| `M-3` | main-horizontal (one big on top) |
| `M-4` | main-vertical (one big left) |
| `M-5` | tiled |
| `M-6` | main-horizontal-mirrored |
| `M-7` | main-vertical-mirrored |

### Synchronize panes

`C-a` `*` toggles synchronize-panes for the current window. Type in one pane and it
repeats in all of them. Best used with a new empty window, then a layout, then run the
command once.

---

## Windows

| Keys | Action |
|---|---|
| `C-a` `1`…`9`, `0` | Jump to window by number |
| `C-a` `n` | Next window |
| `C-a` `H` | Previous window |
| `C-a` `L` | Next window |
| `C-a` `C-p` | Previous window (default) |
| `C-a` `C-n` | Next window (default) |
| `C-a` `M-n` / `M-p` | Next / previous window, but **at the end** (move pane across windows) |
| `C-a` `a` or `C-a` `C-a` | Jump to last window |
| `C-a` `r` | Rename window (prompts) |
| `C-a` `w` | List windows |
| `C-a` `C-w` | List windows (same) |
| `C-a` `&` | Kill window, with y/n confirm |
| `C-a` `S` | **choose-tree -s** (see dead bindings below) |
| `C-a` `"` | **choose-tree -w** (see dead bindings below) |
| `C-a` `f` | Find window by name (prompts, `-Z` zooms match) |
| `C-a` `'` | Move to window by index (prompts) |
| `C-a` `C-o` | Rotate windows in the session |
| `C-a` `M-o` | Rotate the bottom window up |
| `C-a` `C-c` | New window starting in `~` |

Windows are numbered from **1** (`base-index 1`) and renumber on close, so there is
no `0` in normal use — `C-a` `0` still means window 10.

---

## Sessions

| Keys | Action |
|---|---|
| `C-a` `d` / `C-a` `C-d` | Detach (client keeps running) |
| `C-a` `C-z` | Suspend client |
| `C-a` `$` | Rename session (prompts) |
| `C-a` `(` / `)` | Previous / next attached client |
| `C-a` `D` | choose-client -Z (zoom, detach others) |
| `C-a` `*` | list-clients — **overridden**, see dead bindings |
| `C-a` `o` | **sessionx** fuzzy session manager |
| `C-a` `F` → session | fzf-tmux session switcher/new/rename/kill |
| `C-a` `C-x` | Lock the server |

`detach-on-destroy` is **off**, so closing the last window keeps the session alive.
Reconnect with `tmux attach` (or `tmux a -t main`).

---

## Copy mode (vi keys, `mode-keys vi`)

Enter with `C-a` `[`, or `C-a` `Shift-PgUp` to start at the bottom of history, or start
a selection from a mouse drag. The scroll wheel enters copy-mode directly. `Enter`
copies with `copy-pipe`, so it lands in your system clipboard (no middle-click paste
needed) and cancels the mode.

| Key | Action |
|---|---|
| `h` `j` `k` `l` / arrows | Move cursor |
| `w` / `b` | Next / previous word |
| `e` | End of word |
| `^` | Back to indentation |
| `0` / `$` | Start / end of line |
| `g` / `G` | Top / bottom of history |
| `Ctrl-d` / `Ctrl-u` | Half page down / up |
| `Ctrl-f` / `Ctrl-b` | Page down / up |
| `Ctrl-j` | Copy and exit (same as `Enter`) |
| `J` / `K` | Scroll down / up (pane scrollback, no selection) |
| `H` / `L` | Top / bottom line |
| `M` | Middle line |
| `z` | Centre the view |
| `r` | Refresh from pane (pull in new output) |
| `/` | Search down (prompts) |
| `?` | Search up (prompts) |
| `n` / `N` | Next / previous match |
| `,` | Jump to last match |
| `;` | Jump again |
| `*` / `#` | Search forward/backward for the word under the cursor |
| `f` / `t` / `F` / `T` | Jump forward/backward to char (prompts) |
| `%` | Next matching bracket |
| `Ctrl-Alt-f` / `Ctrl-Alt-b` | Jump to forward / backward jump point |
| `Ctrl-Alt-t` / `Ctrl-Alt-T` | Jump forward / backward to a character (prompts) |
| `v` | Begin visual selection (your override) |
| `Space` | Begin selection |
| `V` | Select whole line |
| `A` | Copy selection and exit |
| `y` | **Not bound** — does nothing. Use `Enter` or `Ctrl-j` |
| `q` / `Esc` | Cancel |
| `X` | Set a mark here |
| `` ` `` | Jump to mark |
| `{` / `}` | Previous / next paragraph |
| `M-Up` / `M-Down` | Half page up / down |
| `1`…`9` | Prompt for a repeat count |

Double-click selects a word, triple-click a line; both auto-copy on release.

> Several vi habits are missing from copy-mode-vi on this setup: `y`, `C-l` recentre,
> `M-<` / `M->`, `M-w`, `M-l`, and `(` / `)` for matching brackets. Only `%` and
> `M-x` (jump to mark) exist alongside `X` (set mark). `Ctrl-Alt-f` / `-b` are the jump
> keys, not `Ctrl-Alt-←` / `→`.

---

## Fzf pickers

`C-a` `F` opens the fzf-tmux front end. It first asks which category, then acts:

| Path | Offers |
|---|---|
| copy-mode | Search and copy from scrollback (only listed while in copy-mode) |
| session | switch · new · rename · detach · kill, with a preview pane |
| window | switch · link · move · swap · rename · kill, with a preview |
| pane | switch · break · join · swap · layout · kill · resize, shows `[WxH]` and history size |
| command | Run a tmux command, with completion |
| keybinding | Browse and re-run any key binding |
| clipboard | Pick from tmux buffer list |
| process | display · tree · terminate · kill · interrupt · continue · stop · quit · hangup |

`C-a` `u` is fzf-url: picks from the 2000 most recent URLs across your shell history
and opens the choice. Options are in `@fzf-url-fzf-options` / `@fzf-url-history-limit`.
It also hooks into fzf pickers, so URLs in the buffer become openable.

---

## Plugins

### FloaX — floating scratch session

`C-a` `p` toggles a popup attached to a hidden session named `scratch`. It floats
over your current window at 80% size, magenta border, blue text, and `cd`s to
whatever directory you're in (that's `@floax-change-path 'true'`).

`C-a` `p` again closes it. Inside the popup there is no prefix — these are global:

| Keys | Action |
|---|---|
| `C-M-s` | Shrink by 5 cells |
| `C-M-b` | Grow by 5 cells |
| `C-M-f` | Full size (100%) |
| `C-M-r` | Reset to 80% |
| `C-M-e` | Embed: dock the scratch window into your real session |
| `C-M-d` | **Lock** — unbinds everything above, leaving only `C-M-u` |
| `C-M-u` | Unlock (works in both states) |

`C-a` `P` is the FloaX menu: pop the current window back out, size down/up, full
screen, reset size, embed in session.

Two behaviours worth knowing:

- Every resize calls `tmux detach-client` then re-opens the popup, so the popup flickers
  and the client briefly detaches. It is scripted, not a bug.
- `C-M-d` unbinds the other keys so you cannot fat-finger a resize mid-command. The
  popup title changes to "Bindings locked. Unlock with [Ctrl-Alt-u]". If the popup
  feels frozen, press `C-M-u`.

### sessionx — fuzzy session manager

`C-a` `o`. Fuzzy-find sessions with a preview pane on top, then rename, kill, or open
new windows. It opens in a 75%×85% popup, lists most-recently-used first, and shows the
current session name in the border label. `@sessionx-auto-accept` is **off**, so
picking an existing session prompts for confirmation.

Inside the popup:

| Keys | Action |
|---|---|
| `Enter` | Accept / replace the query |
| `Ctrl-t` | Switch preview to a live tab |
| `Ctrl-w` | List **windows** across all sessions, preview them |
| `Ctrl-x` | List directories under `~/dotfiles` (your custom path) |
| `Ctrl-e` | List directories under `~` |
| `Ctrl-y` | List zoxide history — jump to a directory you `z`'d to |
| `Ctrl-r` | Rename the highlighted session (prompts for the new name) |
| `Alt-Backspace` | **Kill** the highlighted session |
| `?` | Toggle the preview pane |
| `Ctrl-u` / `Ctrl-d` | Preview half page up / down |
| `Ctrl-p` / `Ctrl-n` | Query up / down |
| `Esc` | Abort |

`@sessionx-zoxide-mode 'on'` enables the `Ctrl-y` zoxide list. `@sessionx-x-path` points
at `~/dotfiles-backup/.config`, so `Ctrl-x` lists your config directories: `bat`,
`btop`, `fastfetch`, `fontconfig`, `gtk-3.0`, `gtk-4.0`, `keyd`, `kitty`, `nvim`,
`opencode`, `sxhkd`, `tmux`, `xsettingsd`. (It previously pointed at `~/dotfiles`, which
does not exist, so the list came up empty.)

`@sessionx-filter-current 'false'` keeps the current session in the list.
`@sessionx-auto-accept 'off'` is why picking an existing session still asks to confirm.

### resurrect / continuum — session persistence

- `C-a` `C-s` saves your session to a resurrect script.
- `C-a` `C-r` restores it.
- continuum is on with a 1-minute interval, so it auto-saves constantly; a restore
  effectively picks up the last auto-save.
- `@resurrect-strategy-nvim 'session'` makes saved Neovim panes reopen as `:session`
  (restores an existing session if one is on disk) rather than as a bare nvim.

### TPM — plugin manager

- `C-a` `I` install plugins listed in `@plugin`
- `C-a` `U` update installed plugins
- `C-a` `M-u` clean unused plugins

### Others installed

`tmux-sensible` (sensible splits/history), `catppuccin-tmux` (status bar theme),
`tmux-battery` (battery in the status bar).

---

## Mouse

Mouse is on, so most things need no keys at all.

| Action | How |
|---|---|
| Focus pane | Click |
| Scroll | Wheel (enters copy-mode) |
| Scroll status bar | Wheel up/down switches windows |
| Resize | Drag the pane border |
| Resize window | Drag the outer edge |
| Select text | Drag inside a pane |
| Copy word / line | Double-click / triple-click |
| Zoom pane | Ctrl + click its border (`resize-pane -Z`) |
| Pane menu (split, swap, kill, zoom…) | Right-click a pane |
| Window menu | Right-click the status bar |
| Paste | Middle-click, or right-click |
| Switch client | Click another client's status entry |

Hold **Shift** while clicking/dragging/wheeling to bypass tmux and let the
underlying app see the event. `mouse_any_flag` is set, so Shift-drag always selects.

---

## Command line and meta

| Keys | Action |
|---|---|
| `C-a` `:` | Run a tmux command (prompts) |
| `C-a` `/` | Search key bindings by name (prompts) |
| `C-a` `?` | Full key list |
| `C-a` `i` | Show a message (displays time, session, etc.) |
| `C-a` `~` | Show recent messages |
| `C-a` `t` | Clock mode (large clock in the pane) |
| `C-a` `R` | Reload `tmux.conf` |
| `C-a` `C-l` | `refresh-client` (this is the only way to reach it) |
| `C-a` `K` | Clear the pane and press Enter |
| `C-a` `#` | List paste buffers |
| `C-a` `]` | Paste buffer, preserving trailing newline |
| `C-a` `<` / `C-a` `>` | Status-bar menu / pane menu (click or key equivalent) |

> Note: there is **no** run-shell prompt bound. `C-a` `C-r` is resurrect's *restore*, not a
> command prompt. To run a one-off command, type it into a pane or use `C-a` `F` → command.

Handy commands to paste after `C-a` `:`:

```
resize-pane -A 20                 resize all panes in the window
swap-pane -t %1 -t %2            swap two panes by id
join-pane -s %0 -t %1            merge a pane into another
break-pane -t %2                 promote a pane to its own window
move-pane -r                     rotate the window's panes
setw synchronize-panes on        type once, run everywhere
list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}'
list-windows -a -F '#{session_name}:#{window_index} #{window_name} #{window_active}'
```

---

## Status bar and options

- Status bar is at the **top**. Left: session name. Right: current directory, clock
  (`%H:%M`), battery icon + percentage.
- Active pane border is **blue** (`#89b4fa`), inactive borders dark grey (`#313244`).
  Your `tmux.conf` sets magenta/brightblack, but catppuccin-tmux loads *after* it and
  overwrites both, so the config values are dead. Change them in the catppuccin section
  of `tmux.conf` or via `:set -g pane-active-border-style fg=magenta` after a reload.
- `pane-border-indicators colour`, so the active pane's number is highlighted. Border
  format shows pane index, title, and a zoom marker.
- status-left-length and status-right-length are both 100 (cap on what's shown).
- Backgrounds are forced transparent at startup by
  `~/.config/tmux/scripts/transparent-status.sh`, which rewrites catppuccin's
  hardcoded `bg=#1e1e2e` to `default` and applies it to status and window styles.
  If a reload ever leaves a coloured bar, re-running that script fixes it.
- `history-limit 1000000` — a million lines of scrollback per pane.
- `escape-time 0` — no delay after a key, so vim/readline in panes stay responsive
  to arrow keys and `Ctrl-a`.
- `allow-passthrough` on, so apps like nvim can pass their own escape sequences
  through to tmux.
- `set-clipboard on` — OSC 52, so copying inside a pane reaches your system clipboard.
- Catppuccin is the theme; a zoomed window shows a marker next to its name.

---

## Dead and shadowed bindings

Six bindings in `tmux.reset.conf` never do what the file says. Knowing these prevents
wasted time:

| You would expect | Reality |
|---|---|
| `C-a` `P` → `set pane-border-status` | FloaX binds `P` after your config loads, so it's the FloaX menu. To get pane border status, run `:setw -g pane-border-status top` yourself. |
| `C-a` `*` → `list-clients` | `*` is bound twice in `tmux.reset.conf` (line 7 then line 33); the last wins, so it toggles synchronize-panes. Use `C-a` `D` to choose a client, or `:list-clients`. |
| `C-a` `"` → `choose-window` | Resolves to `choose-tree -w`, not `choose-window`. Same end result, different UI: a full tree instead of a window list. |
| `C-a` `S` → `choose-session` | Resolves to `choose-tree -s`, not `choose-session`. Again a tree UI. |
| `C-a` `l` → `refresh-client` | Bound at `tmux.reset.conf:19` and again at `:27` as `select-pane -R`; the last wins. So `C-a` `l` moves focus right, and `refresh-client` is only reachable as `C-a` `C-l`. |
| `C-a` `p` → `previous-window` | FloaX takes `p`. Previous window is `C-a` `H` or `C-a` `C-p`. |

### Resolved

`scripts/cal.sh` has been removed. It was a macOS leftover: it shelled out to
`icalBuddy` (macOS-only, no Linux build) and used BSD `date -j -f` syntax that GNU
`date` rejects, and it hardcoded a personal Google account. It had never been wired
into `tmux.conf` at any point in the repo's history, so it never ran. If you ever want
meeting alerts in the status bar, that is a new feature to build for Linux, not a
repair. Keep `scripts/transparent-status.sh` — that one *is* wired up and does real work.

`@sessionx-x-path` now points at `~/dotfiles-backup/.config`, so sessionx's `Ctrl-x`
list works. It previously pointed at `~/dotfiles`, which does not exist.

Note for future commits: `~/dotfiles-backup` (branch `main`) and `~/.dotfiles.git`
(branch `reinstall`) are the **same GitHub remote**, and both are checked out. Decide
which is canonical before committing, or your work can land on the branch you don't
intend.

`~/.dotfiles.git` is a **bare** mirror (`core.bare true`), not a second working tree, so
it cannot conflict with a push from `~/dotfiles-backup` the way a second checkout
would. It is worth a `git fetch` after pushing so it does not go stale.

Line 12 of `tmux.conf` (`# set -g default-terminal "${TERM}"`) is commented out and
inert; `tmux-256color` on line 2 is the setting that actually applies.

---

## Quick lookup for the things that bite people

| I want to… | Keys |
|---|---|
| Make a pane bigger | `C-a` `M-Right` (hold to repeat) |
| Scroll back | wheel, or `C-a` `[` then `q` |
| Copy from scrollback | `C-a` `F` → copy-mode, `Enter` to copy |
| Paste the last copy | middle-click, or `C-a` `]` |
| Split and run a command | `C-a` `s` then type, or `:split-window 'cmd'` |
| Rename a session | `C-a` `$` |
| Find a session | `C-a` `o` |
| Detach and come back | `C-a` `d`, then `tmux attach` |
| Full screen one pane | `C-a` `z` |
| Fix a broken config | `C-a` `R` |
| Apply a change to the config | edit, then `C-a` `R` |
| See every binding | `C-a` `?` |
| Look up a binding by name | `C-a` `/` |
| Save my layout | `C-a` `C-s` |
| Clear a messy pane | `C-a` `K` |
