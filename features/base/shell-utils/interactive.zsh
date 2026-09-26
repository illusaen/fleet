WORDCHARS=${WORDCHARS:s#/#}

bindkey '^[b' backward-word
bindkey '^[f' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^W' backward-kill-word

zmodload zsh/terminfo
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}" ]] && bindkey "${terminfo[kend]}" end-of-line
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line
bindkey '^[[3~' delete-char

# Function to fetch env variables, preview values, and insert with $
fzf-env-widget() {
  local selected=$(printenv | cut -d= -f1 | fzf \
    --height 40% \
    --layout=reverse \
    --preview 'printenv {1}' \
    --preview-window=right:60%:wrap)
    
  if [ -n "$selected" ]; then
    LBUFFER+="\$$selected"
  fi
  zle reset-prompt
}
zle -N fzf-env-widget
bindkey '^V' fzf-env-widget

dot_cd_accept_line() {
  emulate -L zsh

  if [[ "$BUFFER" =~ '^[[:space:]]*(\.{2,})[[:space:]]*$' ]]; then
    local cmd="$match[1]"
    local levels=$((${#cmd} - 1))
    local target="$PWD"

    while ((levels > 0)) && [[ "$target" != "/" ]]; do
      target="${target:h}"
      ((levels--))
    done

    BUFFER="cd -- ${(q)target}"
  fi

  zle .accept-line
}
zle -N accept-line dot_cd_accept_line

git_commit_with_message() {
  git commit -m "$1"
}

dev() {
  emulate -L zsh

  if (( $# != 2 )); then
    print -u2 -- "Usage: dev <folder> <template>"
    return 2
  fi

  local project_name="$1"
  local template_name="$2"
  local templates_dir="$NIX_CONFIG_FOLDER/templates"
  local project_dir="$PROJECTS_FOLDER/$project_name"
  local template_dir="$templates_dir/$template_name"
  local shared_dir="$templates_dir/shared"

  if [[ "$project_name" == */* || "$project_name" == "." || "$project_name" == ".." ]]; then
    print -u2 -- "Error: project must be a folder name, not a path: $project_name"
    return 2
  fi

  if [[ "$template_name" == */* || "$template_name" == "." || "$template_name" == ".." ]]; then
    print -u2 -- "Error: template must be a template name, not a path: $template_name"
    return 2
  fi

  if ! cd -- "$PROJECTS_FOLDER"; then
    print -u2 -- "Error: Projects folder does not exist: $PROJECTS_FOLDER"
    return 1
  fi

  if [[ -e "$project_dir" ]]; then
    print -u2 -- "Error: project folder already exists: $project_dir"
    return 1
  fi

  if [[ ! -d "$template_dir" ]]; then
    print -u2 -- "Error: template does not exist: $template_name"
    return 1
  fi

  if [[ ! -d "$shared_dir" ]]; then
    print -u2 -- "Error: shared template folder does not exist: $shared_dir"
    return 1
  fi

  mkdir -- "$project_name" || return
  cd -- "$project_dir" || return

  nix flake init --template "github:illusaen/fleet#$template_name" || return
  cp "$shared_dir/envrc" .envrc
  cp "$shared_dir/gitignore" .gitignore
  git init
  git add -A

  if [[ "$template_name" == "node" ]]; then
    pnpm init
  elif [[ "$template_name" == "python" ]]; then
    uv init
  fi
}

nix_store_for_command() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: nix_store_for_command <command>" >&2
    return 2
  fi

  local command_path resolved_path store_name store_dir
  if ! command_path="$(command -v -- "$1" 2>/dev/null)"; then
    echo "Command not found: $1" >&2
    return 1
  fi

  resolved_path="$(readlink -f -- "$command_path")" || return

  if [[ "$resolved_path" != /nix/store/* ]]; then
    echo "$1 resolves outside /nix/store: $resolved_path" >&2
    return 1
  fi

  store_name="${resolved_path#/nix/store/}"
  store_name="${store_name%%/*}"
  store_dir="/nix/store/$store_name"

  command eza --icons=auto --git "$store_dir"
  echo "Store dir: $store_dir"
}

open_editor() {
  for editor in code nvim vim; do
    if command -v "$editor" >/dev/null 2>&1; then
      "$editor" .
      return
    fi
  done

  echo "Error: no supported editor found (code, nvim, or vim)." >&2
  return 1
}

autoload -Uz add-zsh-hook
cd_ls_hook() {
  emulate -L zsh
  local file_count=(*(ND))
  if (($#file_count <= 50)); then
    eza --icons=always --group-directories-first
  else
    echo "Large directory ($#file_count files). Skipped auto-ls."
  fi
}
add-zsh-hook chpwd cd_ls_hook

reload_noctalia_fzf() {
    local target="${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh"
    
    # 1. Fast escape if the file doesn't exist
    [[ -f "$target" ]] || return 0
    
    # 2. Extract the modification time (works natively on Linux/NixOS)
    local current_mtime=$(stat -c %Y "$target" 2>/dev/null)
    
    # 3. Only source the file if the mtime is different from our last check
    if [[ "$current_mtime" != "$_NOCTALIA_FZF_LAST_MTIME" ]]; then
        source "$target"
        export _NOCTALIA_FZF_LAST_MTIME="$current_mtime"
    fi
}
add-zsh-hook precmd reload_noctalia_fzf