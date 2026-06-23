#!/bin/bash
for opt in status-left status-right window-status-format window-status-current-format; do
  val=$(tmux show-option -gv "$opt" 2>/dev/null)
  if [ -n "$val" ]; then
    new_val=$(echo "$val" | sed -E 's/bg=#1e1e2e/bg=default/g; s/bg=#1E1E2E/bg=default/g')
    tmux set-option -g "$opt" "$new_val"
  fi
done

tmux set-option -g status-style bg=default
tmux set-option -g status-bg default
tmux set-option -g window-status-style bg=default
tmux set-option -g window-status-activity-style bg=default
tmux set-option -g window-status-current-style bg=default
tmux set-option -g message-style bg=default
tmux set-option -g message-command-style bg=default
