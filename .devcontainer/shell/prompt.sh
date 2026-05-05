#!/usr/bin/env bash
# Devcontainer shell prompt.
# Sourced by ~/.bashrc — sets a PS1 of the form:
#   git_repo | git_branch | /current/path $
# Outside a git repo both fields show a dash.

__ps1_repo() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf '-'; return; }
  basename "$top"
}

__ps1_branch() {
  local branch
  branch="$(git branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then
    printf '%s' "$branch"
  elif git rev-parse --git-dir >/dev/null 2>&1; then
    # Detached HEAD — show the short SHA instead
    printf '%.7s' "$(git rev-parse HEAD 2>/dev/null)"
  else
    printf '-'
  fi
}

# cyan repo | yellow branch | green path
PS1='\[\e[0;36m\]$(__ps1_repo)\[\e[0m\] | \[\e[0;33m\]$(__ps1_branch)\[\e[0m\] | \[\e[0;32m\]\w\[\e[0m\] \$ '
