# dotfiles-backup

Personal dotfiles for **Nobara Linux 41** (KDE Plasma 6 / Wayland).

Managed with a **bare git repo** at `~/.dotfiles.git` — the working tree is `$HOME` itself, so all tracked files live exactly where they belong.

```sh
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
```

---

## Table of Contents

- [Initial Setup (bare git repo)](#initial-setup-bare-git-repo)
- [SSH Key & Remote](#ssh-key--remote)
- [Branch Rename: master → main](#branch-rename-master--main)
- [Conflict Resolution During Restore](#conflict-resolution-during-restore)
- [Packages](#packages)
  - [DNF Packages](#dnf-packages)
  - [GitHub Release Installs](#github-release-installs)
- [Shell: Zsh](#shell-zsh)
  - [Plugins & Sources](#plugins--sources)
  - [Key Bindings](#key-bindings)
  - [Aliases](#aliases)
  - [Completion System](#completion-system)
- [Terminal: Kitty](#terminal-kitty)
- [Tmux](#tmux)
  - [Prefix, Options, Key Bindings](#prefix-options-key-bindings)
  - [TPM Plugins](#tpm-plugins)
  - [tmux-sessionx Issue & Fix](#tmux-sessionx-issue--fix)
  - [Transparent Status Bar Script](#transparent-status-bar-script)
- [Keyboard: Keyd](#keyboard-keyd)
- [Hotkeys: Sxhkd](#hotkeys-sxhkd)
- [X Settings Daemon: xsettingsd](#x-settings-daemon-xsettingsd)
- [KDE Autostart Entries](#kde-autostart-entries)
- [KWin Script: Move Follow](#kwin-script-move-follow)
- [Post-Install Actions](#post-install-actions)
  - [Bat Theme Cache](#bat-theme-cache)
  - [Fontconfig Cache](#fontconfig-cache)
  - [Zsh Completions Compile](#zsh-completions-compile)
  - [Local Bin Scripts](#local-bin-scripts)
  - [thefuck Python 3.14 Patch](#thefuck-python-314-patch)
- [Excluded Files](#excluded-files)
- [Tracked Files (Full List)](#tracked-files-full-list)

---

## Initial Setup (bare git repo)

The repo was **not cloned normally**. Instead it was restored from a bare git init:

```sh
git init --bare ~/.dotfiles.git
git --git-dir=$HOME/.dotfiles.git remote add origin git@github.com:Hrushikesh-Narala/dotfiles-backup.git
git --git-dir=$HOME/.dotfiles.git fetch origin
git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME reset origin/main
```

Because the working tree is `$HOME`, `reset` overwrites existing config files in place. If a file already exists locally and is tracked in the repo, it gets overwritten by the version from the repo.

The `dotfiles` alias lives in `~/.zshrc`:

```sh
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
```

Usage examples:

| Command | What it does |
|---------|--------------|
| `dotfiles status` | Check what's changed |
| `dotfiles add ~/.zshrc` | Stage a file |
| `dotfiles commit -m "msg"` | Commit staged changes |
| `dotfiles push` | Push to GitHub |
| `dotfiles pull` | Pull from GitHub |
| `dotfiles log --oneline` | View history |

---

## SSH Key & Remote

Generated a new Ed25519 key pair:

```sh
ssh-keygen -t ed25519 -C "github"
```

The public key was added to GitHub under the **Hrushikesh-Narala** account so the remote `origin` uses the SSH URL:

```
git@github.com:Hrushikesh-Narala/dotfiles-backup.git
```

---

## Branch Rename: master → main

The local branch was `master` but the remote is `main`. Fixed with:

```sh
git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME branch -m master main
```

---

## Conflict Resolution During Restore

When running `reset origin/main`, tracked files that already existed locally were automatically overwritten by the bare repo version. There were no manual conflicts.

Existing files that were **not** in the repo were left untouched. The backup of any files that were overwritten was **not needed** since the repo versions are authoritative. However, a precautionary backup directory was created:

```sh
mkdir -p ~/dotfiles-orig
# Copy any file you want to preserve before overwriting
```

---

## Packages

### DNF Packages

Installed via `sudo dnf install`:

| Package | Purpose |
|---------|---------|
| `zsh` | Primary shell (replaces bash) |
| `bat` | `cat` replacement with syntax highlighting |
| `eza` | `ls` replacement with icons, git status |
| `fd-find` | `find` replacement (used by fzf) |
| `tmux` | Terminal multiplexer |
| `thefuck` | Auto-corrects mistyped commands |
| `keyd` | Keyboard remapping daemon (system-wide) |
| `sxhkd` | Simple X hotkey daemon (Wayland via XWayland) |
| `jetbrains-mono-fonts-all` | Nerd Font patched JetBrains Mono |
| `xsettingsd` | X Settings Daemon (GTK theming on Wayland) |

Some packages were **pre-installed** on Nobara: `eza`, `fd-find`, `tmux`, `thefuck`.

### GitHub Release Installs

These were downloaded directly from GitHub releases (not via dnf) for newer versions:

**fzf** — 0.73.1 (full install, includes `fzf-tmux`)
```sh
# Initial attempt (binary-only tarball — missing fzf-tmux):
curl -LO https://github.com/junegunn/fzf/releases/download/v0.73.1/fzf-0.73.1-linux_amd64.tar.gz
tar xzf fzf-0.73.1-linux_amd64.tar.gz
sudo install fzf /usr/local/bin/
rm fzf fzf-0.73.1-linux_amd64.tar.gz

# Later replaced with full install (includes fzf-tmux script):
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
cd ~/.fzf && ./install --bin           # downloads binary to ~/.fzf/bin/
sudo ln -s ~/.fzf/bin/fzf /usr/local/bin/fzf
sudo ln -s ~/.fzf/bin/fzf-tmux /usr/local/bin/fzf-tmux
```

The `fzf-tmux` script is a shell wrapper that opens fzf in a tmux popup window. The binary-only release tarballs don't ship it — only the full source repo has it. Simlink both into `/usr/local/bin/` for system-wide access.

**git-delta** — 0.19.2
```sh
curl -LO https://github.com/dandavison/delta/releases/download/0.19.2/delta-0.19.2-x86_64-unknown-linux-gnu.tar.gz
tar xzf delta-0.19.2-x86_64-unknown-linux-gnu.tar.gz
sudo install delta-0.19.2-x86_64-unknown-linux-gnu/delta /usr/local/bin/
rm -rf delta-0.19.2-x86_64-unknown-linux-gnu*
```

**zoxide** — 0.9.9
```sh
curl -LO https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.9/zoxide-0.9.9-x86_64-unknown-linux-musl.tar.gz
tar xzf zoxide-0.9.9-x86_64-unknown-linux-musl.tar.gz
sudo install zoxide /usr/local/bin/
rm zoxide zoxide-0.9.9-x86_64-unknown-linux-musl.tar.gz
```

---

## Shell: Zsh

### Plugins & Sources

All cloned with `--depth=1` for speed:

| Plugin | Source | Installed To |
|--------|--------|-------------|
| Powerlevel10k | `https://github.com/romkatv/powerlevel10k.git` | `~/powerlevel10k/` |
| zsh-autosuggestions | `https://github.com/zsh-users/zsh-autosuggestions.git` | `~/.zsh/zsh-autosuggestions/` |
| zsh-syntax-highlighting | `https://github.com/zsh-users/zsh-syntax-highlighting.git` | `~/.zsh/zsh-syntax-highlighting/` |
| zsh-history-substring-search | `https://github.com/zsh-users/zsh-history-substring-search.git` | `~/.zsh/zsh-history-substring-search/` |
| zsh-completions | `https://github.com/zsh-users/zsh-completions.git` | `~/.zsh/zsh-completions/` |
| zsh-you-should-use | `https://github.com/zsh-users/zsh-you-should-use.git` | `~/.zsh/zsh-you-should-use/` |
| fzf-git.sh | `https://github.com/junegunn/fzf-git.sh.git` | `~/.zsh/fzf-git.sh/` |

**Powerlevel10k** is the main theme. The config file is at `~/.p10k.zsh` (1719 lines, generated by `p10k configure`). Instant prompt is enabled (quiet mode).

**fzf integration** uses `fd` for file searching:
```sh
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
```

**Bat** theme is set to `tokyonight_night`:
```sh
export BAT_THEME=tokyonight_night
```

**Eza** is the default `ls`:
```sh
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"
```

**Zoxide** replaces `cd`:
```sh
eval "$(zoxide init zsh)"
alias cd="z"
```

### Key Bindings

| Keys | Action |
|------|--------|
| Home / End | Beginning / end of line |
| Ctrl+Left / Ctrl+Right | Word navigation |
| Ctrl+Delete | Kill word forward |
| Alt+Enter (in kitty: Shift+Enter via `\e\r`) | Insert literal newline |
| Up / Down (history-substring-search) | Search history by prefix |
| Ctrl+Shift+Left / Ctrl+Shift+Right | Select word (set mark + move) |

### Aliases

| Alias | Expands To |
|-------|-----------|
| `oc` | `opencode` |
| `nv` | `nvim` |
| `tm` | `tmux attach -t main` |
| `rt` | Restart touchpad via I2C unbind/bind |
| `ports` | `ss -tulpn` |
| `soff` | `screenoff` (lock + turn off screen) |
| `son` | `screenon` (unlock screen) |
| `rb` | `source ~/.zshrc` |
| `myip` | Show local IP |
| `ram` | `free -h` |
| `disks` | `df -h` |
| `c` / `cls` | `clear` |
| `dotfiles` | Git command for bare repo |
| `gui` | Switch to graphical.target + chvt 1 |
| `ttyon` | Switch to multi-user.target + chvt 2 |
| `rgui` | Reboot into graphical |
| `rtty` | Reboot into TTY |

**Clipboard helpers** (`cl` and `cln N`): Capture the last command block(s) from tmux and copy to clipboard via `wl-copy`.

The `thefuck` alias is sourced with `eval $(thefuck --alias)`.

### Completion System

`zsh-completions` is added to `fpath`:
```sh
fpath=(~/.zsh/zsh-completions/src $fpath)
```

Compinit is called conditionally (skips recompilation if `.zcompdump` exists).

---

## Terminal: Kitty

**Config file**: `~/.config/kitty/kitty.conf`

Key settings:

```sh
font_family JetBrainsMono Nerd Font
font_size 12.0
hide_window_decorations yes

shell zsh -c 'tmux attach -t main 2>/dev/null || exec zsh'

background_blur 1
background_image /home/alienx/Pictures/aaa.jpg
background_image_layout tiled
background_tint 0.99
background_opacity 0.90
dynamic_background_opacity yes
```

**Key mappings** are configured to pass through to zsh properly:
- `ctrl+c` → copy_or_interrupt
- `ctrl+v` → paste_from_clipboard
- `ctrl+backspace` → `\x17` (Ctrl+W — delete word backward)
- `ctrl+delete` → `\e[3;5~` (kill word forward)
- `ctrl+left` / `ctrl+right` → word navigation
- `ctrl+shift+left` / `ctrl+shift+right` → word selection
- `shift+enter` → `\e\r` (Alt+Enter for newline in shell)

**Shell on startup**: Kitty launches `zsh` which immediately tries to `tmux attach -t main`. If the tmux session doesn't exist, it falls back to plain `zsh`. This means you need to create the "main" tmux session manually first:

```sh
tmux new-session -d -s main
```

---

## Tmux

### Prefix, Options, Key Bindings

| Setting | Value |
|---------|-------|
| Prefix | `Ctrl+A` (rebound from default `Ctrl+B`) |
| Base index | 1 (not 0) |
| History limit | 1,000,000 lines |
| Renumber windows | On |
| Status position | Top |
| Default terminal | `tmux-256color` |
| Mouse | On |
| Pane borders | Bright black (inactive), magenta (active) |

Selected custom key bindings (prefix table):

| Key | Action |
|-----|--------|
| `o` | **tmux-sessionx** — session switcher (fzf-based) |
| `p` | **tmux-floax** — floating/popup terminal |
| `F` | **tmux-fzf** — fuzzy menu |
| `u` | **tmux-fzf-url** — select URL to open |
| `s` | Split pane vertically |
| `v` | Split pane horizontally |
| `a` | Last window |
| `H` / `L` | Previous / next window |
| `S` | Choose session tree |
| `Ctrl+S` | tmux-resurrect: save |
| `Ctrl+R` | tmux-resurrect: restore |
| `C` | Customize mode |
| `R` | Reload config |

The reset config (`~/.config/tmux/tmux.reset.conf`) is sourced first to set base pane/window navigation and then the main config overrides.

### TPM Plugins

Installed via Tmux Plugin Manager at `~/.tmux/plugins/`.

| Plugin | Key Bind / Purpose |
|--------|--------------------|
| `tmux-plugins/tpm` | Plugin manager itself |
| `tmux-plugins/tmux-sensible` | Sensible defaults |
| `tmux-plugins/tmux-resurrect` | Save/restore tmux sessions (`Ctrl+S` / `Ctrl+R`) |
| `tmux-plugins/tmux-continuum` | Auto-save every 1 min, auto-restore on start |
| `sainnhe/tmux-fzf` | FZF-based menu (`prefix + F`) |
| `wfxr/tmux-fzf-url` | Select URL from history (`prefix + U`) |
| `tmux-plugins/tmux-battery` | Battery indicator in status bar |
| `omerxx/catppuccin-tmux` | Catppuccin theme (fork with meetings script) |
| `omerxx/tmux-sessionx` | Session switcher (`prefix + O`) |
| `omerxx/tmux-floax` | Floating/popup terminal (`prefix + P`) |

**Install new plugins**: `prefix + I` (capital I, inside tmux).

### tmux-sessionx Issue & Fix

**The symptom**: Pressing `prefix + o` did nothing.

**Root cause**: tmux-sessionx defaults to using `fzf-tmux` (a helper script that opens fzf in a tmux popup). However, `fzf-tmux` is a shell script that **only ships with the fzf source repository** — the GitHub binary release tarballs (`fzf-0.73.1-linux_amd64.tar.gz`) only contain the `fzf` binary, not `fzf-tmux`. Since fzf was initially installed from the binary release, `fzf-tmux` was never on the system.

The plugin's internal option `@sessionx-_fzf-builtin-tmux` defaults to `off`, which causes `sessionx.sh` (line 154) to call `fzf-tmux` instead of plain `fzf`.

**The fix**: Replaced the binary-only fzf install with the full fzf repository, which includes `fzf-tmux` in its `bin/` directory. Symlinked both `fzf` and `fzf-tmux` into `/usr/local/bin/`.

```sh
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
cd ~/.fzf && ./install --bin
sudo ln -s ~/.fzf/bin/fzf /usr/local/bin/fzf
sudo ln -s ~/.fzf/bin/fzf-tmux /usr/local/bin/fzf-tmux
```

The `@sessionx-fzf-builtin-tmux` option is left at its default (`off`) since `fzf-tmux` is now available.

### Transparent Status Bar Script

`~/.config/tmux/scripts/transparent-status.sh` runs after TPM loads. It strips hardcoded background colors from the Catppuccin theme and sets all status elements to `bg=default`, making the tmux status bar transparent. This allows the kitty terminal's background image to show through.

---

## Keyboard: Keyd

**Service**: `sudo systemctl enable --now keyd`

Keyd intercepts key combinations at the kernel level (`/etc/keyd/default.conf`) and translates them system-wide (not limited to a single DE).

**Config** (`/etc/keyd/default.conf`):

| Layer | Key Combo | Produces |
|-------|-----------|----------|
| `[alt]` | h/j/k/l | Arrow keys (Vim-style navigation) |
| `[alt]` | n | `Ctrl+Z` (undo) |
| `[alt]` | w | `Ctrl+Right` (next word) |
| `[alt]` | b | `Ctrl+Left` (prev word) |
| `[alt]` | u | `Ctrl+A` (select all) |
| `[alt]` | i | `Ctrl+C` (copy) |
| `[alt]` | o | `Ctrl+V` (paste) |
| `[alt]` | m | `Ctrl+S` (save) |
| `[alt]` | r | `Ctrl+Backspace` (delete word backward) |
| `[alt]` | e | `Ctrl+Delete` (delete word forward) |
| `[alt+shift]` | h/j/k/l | Shift+Arrow (select) |
| `[alt+shift]` | w/b | `Ctrl+Shift+Right` / `Ctrl+Shift+Left` (select word) |
| `[alt+control]` | h/j/k/l | Ctrl+Arrow (word navigation) |
| `[alt+control+shift]` | h/j/k/l | Ctrl+Shift+Arrow (select word) |

---

## Hotkeys: Sxhkd

**Config**: `~/.config/sxhkd/sxhkdrc`

A simple keybind daemon. Currently has one binding:

| Shortcut | Action |
|----------|--------|
| `Super + F12` | Restart I2C touchpad (unbind/bind SYNA32A0:00) with sudo + notify-send |

Autostarted via KDE `.desktop` entry (see [KDE Autostart Entries](#kde-autostart-entries)).

---

## X Settings Daemon: xsettingsd

**Config**: `~/.config/xsettingsd/xsettingsd.conf`

Provides GTK settings on Wayland (where `xsettings` is typically not running). Key settings:

| Setting | Value |
|---------|-------|
| Net/ThemeName | `Breeze-Dark` |
| Net/IconThemeName | `Papirus-Dark` |
| Gtk/CursorThemeName | `breeze_cursors` |
| Gtk/CursorThemeSize | 30 |
| Gdk/UnscaledDPI | 122880 |
| Gtk/FontName | `Noto Sans, 11` |

Autostarted via KDE `.desktop` entry.

---

## KDE Autostart Entries

Two `.desktop` files in `~/.config/autostart/`:

**sxhkd.desktop**
```ini
[Desktop Entry]
Name=sxhkd
Comment=Simple X hotkey daemon
Exec=/usr/bin/sxhkd
Terminal=false
Type=Application
```

**xsettingsd.desktop**
```ini
[Desktop Entry]
Name=xsettingsd
Comment=X Settings Daemon
Exec=/usr/bin/xsettingsd
Terminal=false
Type=Application
```

---

## KWin Script: Move Follow

**Location**: `~/.local/share/kwin/scripts/movefollow/`

A KWin script that enables "focus follows mouse" behavior — windows get focus when the mouse hovers over them without requiring a click. This is a common tiling-WM-like behavior on KDE.

**Enabled** in `~/.config/kwinrc`:
```ini
[Plugins]
movefollowEnabled=true
```

---

## Post-Install Actions

### Bat Theme Cache

The `tokyonight_night` theme file is at `~/.config/bat/themes/tokyonight_night.tmTheme`. It must be compiled into bat's cache:

```sh
bat cache --build
```

Without this, `bat` falls back to the default theme.

### Fontconfig Cache

JetBrains Mono Nerd Font was installed via the `jetbrains-mono-fonts-all` package. Fontconfig needs to rebuild its cache:

```sh
fc-cache -fv
```

The fontconfig config (`~/.config/fontconfig/fonts.conf`) contains any custom font rules. The font is used by Kitty, terminal applications, and any GTK/Qt apps.

### Zsh Completions Compile

After cloning `zsh-completions`, the completion files should be compiled for faster loading:

```sh
# Inside zsh:
rm -f ~/.zcompdump
compinit
```

Or manually:
```sh
zsh -c 'rm -f ~/.zcompdump && autoload -Uz compinit && compinit'
```

### Local Bin Scripts

Three scripts in `~/.local/bin/` (made executable with `chmod +x`):

| Script | Purpose |
|--------|---------|
| `lid-wifi-fix.sh` | Re-enables WiFi after lid close (rfkill + nmcli) |
| `screenoff` | Lock session + turn off screen (Wayland) or blank framebuffer (TTY) |
| `screenon` | Unlock session (Wayland) or unblank framebuffer (TTY) |

### thefuck Python 3.14 Patch

**thefuck** is installed via dnf (version 3.32-19 on Fedora 43). Python 3.14 removed the `distutils` module, which thefuck previously used for `distutils.spawn.find_executable()`.

The file `/usr/lib/python3.14/site-packages/thefuck/system/unix.py` was patched:

```diff
- from distutils.spawn import find_executable
+ from shutil import which as find_executable
```

`shutil.which` is the direct replacement (same API, same behaviour) and is available in all Python 3.x versions.

---

## Excluded Files

The bare repo tracks files in `$HOME`. One file was intentionally excluded from tracking:

- **`~/.fbtermrc`** — this config file is auto-generated and machine-specific (FBterm settings for TTY sessions). It was removed from the index:

```sh
dotfiles rm --cached .fbtermrc
echo ".fbtermrc" >> ~/.gitignore  # or tracked in .dotfiles.git/info/exclude
```

---

## Tracked Files (Full List)

These are the files managed by the bare git repo as of the last commit:

```
.bash_profile
.bashrc
.config/Trolltech.conf
.config/bat/themes/tokyonight_night.tmTheme
.config/btop/btop.conf
.config/fastfetch/config.jsonc
.config/fontconfig/fonts.conf
.config/gtk-3.0/settings.ini
.config/gtk-4.0/settings.ini
.config/keyd/default.conf
.config/kglobalshortcutsrc
.config/kitty/current-theme.conf
.config/kitty/kitty.conf
.config/kwinrc
.config/nvim/ (entire nvim/LazyVim config)
.config/opencode/opencode.jsonc
.config/opencode/themes/transparent.json
.config/opencode/tui.json
.config/starship.toml
.config/sxhkd/sxhkdrc
.config/tmux/scripts/cal.sh
.config/tmux/scripts/transparent-status.sh
.config/tmux/tmux.conf
.config/tmux/tmux.reset.conf
.config/xsettingsd/xsettingsd.conf
.fbtermrc          ← excluded from tracking via `dotfiles rm --cached`
```

---

## Restoring From Scratch (Full Procedure)

If setting up a new machine:

1. Install a distro (Nobara/KDE or similar)
2. Run updates: `sudo dnf upgrade`
3. Install base packages: `sudo dnf install zsh bat eza fd-find tmux thefuck keyd sxhkd jetbrains-mono-fonts-all xsettingsd`
4. Set zsh as default: `sudo chsh -s $(which zsh) $(whoami)`
5. Install GitHub-release packages: fzf, git-delta, zoxide (see [GitHub Release Installs](#github-release-installs))
6. Generate SSH key and add to GitHub
7. Bare git restore:
   ```sh
   git init --bare ~/.dotfiles.git
   git --git-dir=$HOME/.dotfiles.git remote add origin git@github.com:Hrushikesh-Narala/dotfiles-backup.git
   git --git-dir=$HOME/.dotfiles.git fetch origin
   git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME reset origin/main
   ```
8. Install TPM + plugins: start tmux, press `prefix + I`
9. Restart keyd: `sudo systemctl enable --now keyd`
10. Rebuild caches: `bat cache --build`, `fc-cache -fv`
11. Create main tmux session: `tmux new-session -d -s main`
12. Start kitty
13. Place wallpaper at `~/Pictures/aaa.jpg`
