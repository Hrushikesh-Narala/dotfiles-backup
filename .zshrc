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

# opencode
export PATH=/home/alienx/.opencode/bin:$PATH

# Aliases
alias oc='opencode'
alias gui='sudo systemctl isolate graphical.target && sudo chvt 1'
alias ttyonly='sudo systemctl isolate multi-user.target && sudo chvt 2'
alias rgui='sudo systemctl set-default graphical.target && sudo reboot'
alias rtty='sudo systemctl set-default multi-user.target && sudo reboot'
alias tm='tmux attach -t main || tmux new -s ai'
alias ollamastatus='ollama ps'
alias ollamamodels='ollama list'

alias rt='echo "i2c-SYNA32A0:00" | sudo tee /sys/bus/i2c/drivers/i2c_hid_acpi/unbind && sleep 1 && echo "i2c-SYNA32A0:00" | sudo tee /sys/bus/i2c/drivers/i2c_hid_acpi/bind'
alias ports='ss -tulpn'
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

# thefuck alias
eval $(thefuck --alias)

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

# ---- Zsh plugins ----
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Auto-start fbterm on TTY ----
if [ "$(tty | head -c 8)" = "/dev/tty" ]; then
  exec fbterm
fi
