# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# opencode
export PATH=/home/alienx/.opencode/bin:$PATH

# Aliases
alias gui='sudo systemctl isolate graphical.target'
alias ttyonly='sudo systemctl isolate multi-user.target'
alias rebootgui='sudo systemctl set-default graphical.target && sudo reboot'
alias reboottty='sudo systemctl set-default multi-user.target && sudo reboot'
alias tm='tmux attach -t ai || tmux new -s ai'
alias ollamastatus='ollama ps'
alias ollamamodels='ollama list'

alias reloadbash='source ~/.bashrc'
alias ports='ss -tulpn'
alias myip='ip -4 addr show | grep -oP "(?<=inet\\s)\\d+(\\.\\d+){3}" | grep -v 127.0.0.1'
alias ram='free -h'
alias disks='df -h'
alias c='clear'
alias cls='clear'
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
export PATH="$HOME/.var/app/ai.lmstudio.lm-studio/.lmstudio/bin:$PATH"
export PATH="$HOME/.var/app/ai.lmstudio.lm-studio/.lmstudio/bin:$PATH"
