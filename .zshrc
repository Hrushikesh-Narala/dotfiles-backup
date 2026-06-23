# Show system info with Nobara logo on terminal start
fastfetch

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ---- History configuration (shared across all zsh sessions) ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS

# opencode
export PATH=/home/alienx/.opencode/bin:$PATH

# Aliases
alias oc='opencode'
alias gui='sudo systemctl isolate graphical.target && sudo chvt 1'
alias ttyon='sudo systemctl isolate multi-user.target && sudo chvt 2'
alias rgui='sudo systemctl set-default graphical.target && sudo reboot'
alias rtty='sudo systemctl set-default multi-user.target && sudo reboot'
alias tm='tmux attach -t main'

alias nv='nvim'
alias rt='echo "shrek" | sudo -S bash -c '\''echo i2c-SYNA32A0:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind && sleep 1 && echo i2c-SYNA32A0:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind'\'' && echo OK'
alias ports='ss -tulpn'
alias soff='screenoff'
alias son='screenon'
alias rb='source ~/.zshrc'
alias myip='ip -4 addr show | grep -oP "(?<=inet\\s)\\d+(\\.\\d+){3}" | grep -v 127.0.0.1'
alias ram='free -h'
alias disks='df -h'
alias c='clear'
alias cls='clear'
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'

export PATH="$HOME/.var/app/ai.lmstudio.lm-studio/.lmstudio/bin:$PATH"

# Powerlevel10k
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---- FZF -----
eval "$(fzf --zsh)"

# -- Use fd instead of fzf --
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# ---- fzf-git -----
source ~/fzf-git.sh/fzf-git.sh

# ----- Bat (better cat) -----
export BAT_THEME=tokyonight_night

# ---- Eza (better ls) -----
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"
#--no-filsize
# ---- FZF previews ----
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo $'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# ---- Key bindings ----
bindkey '\e[3~' delete-char
bindkey '\e[H'  beginning-of-line
bindkey '\e[F'  end-of-line
bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line

bindkey '\e[1;5D' backward-word       # Ctrl+Left
bindkey '\e[1;5C' forward-word        # Ctrl+Right
bindkey '\e[3;5~' kill-word           # Ctrl+Delete
# Ctrl+Backspace is handled by zsh's built-in Ctrl+W binding

# Word selection (set mark + move)
select-backward-word() { zle set-mark-command; zle backward-word }
select-forward-word()  { zle set-mark-command; zle forward-word }
zle -N select-backward-word
zle -N select-forward-word
bindkey '\e[1;6D' select-backward-word  # Ctrl+Shift+Left
bindkey '\e[1;6C' select-forward-word   # Ctrl+Shift+Right

# Shift+Enter: kitty sends \e\r (ESC+CR = ^[^M)
# Handled by zsh's built-in: ^[^M → self-insert-unmeta (same as Alt+Enter)

# thefuck alias
eval $(thefuck --alias)

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

# ---- Zsh plugins ----
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Clipboard helpers (tmux-based) ----
# Adjust PROMPT_CHAR if your prompt uses a different character (e.g. "$" or "%").
# The default works for Powerlevel10k where each prompt line contains "❯ ".
PROMPT_CHAR='❯ '

# Copy the most recent command block (starting at the prompt line,
# ending before the next top‑border line).
cl() {
  [[ -z "$TMUX" ]] && { echo "Not in a tmux session"; return 1; }
  tmux capture-pane -pS -2000 |
    awk -v p="$PROMPT_CHAR" '
      { lines[NR] = $0 }
      $0 ~ p { prompts[++pc] = NR }
      END {
        if (pc < 2) { print "Not enough command history" > "/dev/stderr"; exit }
        start = prompts[pc-1]            # prompt line of the command we want
        end   = prompts[pc] - 2          # line before the next top‑border line
        if (end < start) end = start    # safety: always print at least the prompt line
        for (i = start; i <= end; i++) print lines[i]
      }
    ' | wl-copy
  echo "Last command (with output) copied to clipboard"
}

# Copy the last N command blocks (starting at each prompt line,
# ending before the next top‑border line).
cln() {
  [[ -z "$TMUX" ]] && { echo "Not in a tmux session"; return 1; }
  local n=${1:-1}
  tmux capture-pane -pS -2000 |
    awk -v p="$PROMPT_CHAR" -v N=$n '
      { lines[NR] = $0 }
      $0 ~ p { prompts[++pc] = NR }
      END {
        if (pc < 2) { print "Not enough command history" > "/dev/stderr"; exit }
        total = pc - 1                     # exclude the helper'\''s own prompt
        start_idx = total - N + 1
        if (start_idx < 1) start_idx = 1
        start = prompts[start_idx]          # first prompt we want
        end   = prompts[pc] - 2            # line before the next top‑border line
        if (end < start) end = start
        for (i = start; i <= end; i++) print lines[i]
      }
    ' | wl-copy
  echo "Last $n command block(s) copied to clipboard"
}

# ---- Auto-start fbterm on TTY ----
if [ "$(tty | head -c 8)" = "/dev/tty" ]; then
  exec fbterm
fi
