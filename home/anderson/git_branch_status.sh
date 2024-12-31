# ~/git_prompt.sh

# Function to display the current Git branch
git_branch() {
  if branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
    printf "\e[0m(%s\e[0m" "$branch"  # Purple for the branch
  fi
}

# Function to display the current Git sync status with inline colors
git_status() {
  git rev-parse --is-inside-work-tree &>/dev/null || return 0
  ahead=$(git rev-list --count HEAD..origin/$(git rev-parse --abbrev-ref HEAD) 2>/dev/null || echo 0)
  behind=$(git rev-list --count origin/$(git rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null || echo 0)
  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    printf "\e[01;34m ↓%d\e[0m\e[01;31m ↑%d\e[0m" "$ahead" "$behind"
  elif [ "$ahead" -gt 0 ]; then
    printf "\e[01;34m ↓%d\e[0m)" "$ahead"
  elif [ "$behind" -gt 0 ]; then
    printf "\e[01;31m ↑%d\e[0m)" "$behind"
  else
    printf "\e[01;32m ≡\e[0m)"
  fi
}

# Combine everything into the prompt
export PS1='\[\e[01;32m\]\u@\h\[\e[0m\]:\[\e[01;34m\]\w\[\e[0m\] $(git_branch)$(git_status)\$ '

