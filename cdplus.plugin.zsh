# cdplus — smart cd with bookmarks, stats, git context, and bookmark manager

# ---------------- User config (override in .zshrc BEFORE OMZ loads) ----------------
# typeset -A BOOKMARKS
# BOOKMARKS=(
#   proj ~/Projects
#   docs ~/Documents
#   work ~/Clients
# )
# export CDPLUS_USE_FZF=1         # enable fzf picker when running `c` with no args
# export CDPLUS_SHOW_SIZE=1       # include directory size in the message (uses cache)
# export CDPLUS_SIZE_TTL=300      # seconds; recalc size when cache older than this
# export CDPLUS_TIMEOUT=5         # seconds; max time for stats calculation (default: 5)
# export CDPLUS_MAX_DEPTH=3       # max depth for repo search (default: 3, 0=disable)
# export CDPLUS_ASYNC=1           # enable async stats (updates in background)
# export CDPLUS_SHOW_SPINNER=1    # show spinner while calculating (default: 1)

# ---------------- Internals / defaults ----------------
typeset -A BOOKMARKS 2>/dev/null || true
: "${CDPLUS_BOOKMARK_FILE:=$HOME/.config/cdplus/bookmarks.zsh}"
: "${CDPLUS_SIZE_TTL:=300}"
: "${CDPLUS_CACHE_DIR:=$HOME/.cache/cdplus/sizes}"
: "${CDPLUS_TIMEOUT:=5}"
: "${CDPLUS_MAX_DEPTH:=3}"
: "${CDPLUS_SHOW_SPINNER:=1}"

# Load persisted bookmarks (merged; user-defined keys win)
if [[ -f "$CDPLUS_BOOKMARK_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CDPLUS_BOOKMARK_FILE"
fi

# ---------------- Helpers ----------------
_cdplus_color() { printf "\e[%sm%s\e[0m" "$1" "$2"; }
_cdplus_bold()  { _cdplus_color "1" "$1"; }

_cdplus_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local msg="${2:-Computing stats}"

  if [[ "$CDPLUS_SHOW_SPINNER" != "1" ]]; then
    return
  fi

  printf "\r%s... " "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\r%s %s " "${spinstr:0:1}" "$msg"
    spinstr=$temp${spinstr:0:1}
    sleep $delay
  done
  printf "\r%s\r" "$(printf ' %.0s' {1..60})"  # Clear the line
}

_cdplus_count() {
  emulate -L zsh
  setopt extendedglob null_glob
  local -a arr
  arr=($~1)
  print ${#arr}
}

_cdplus_git_branch() {
  git rev-parse --is-inside-work-tree &>/dev/null || return
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

_cdplus_git_origin_raw() {
  git rev-parse --is-inside-work-tree &>/dev/null || return
  git config --get remote.origin.url 2>/dev/null
}

_cdplus_pretty_origin() {
  local raw="$(_cdplus_git_origin_raw)" ; [[ -z "$raw" ]] && return
  local out="$raw"
  if [[ "$raw" == git@*:* ]]; then
    local host="${raw%%:*}"; host="${host#git@}"
    local path="${raw#*:}"; path="${path%.git}"
    out="https://${host}/${path}"
  elif [[ "$raw" == ssh://* ]]; then
    local tmp="${raw#ssh://}"
    local host="${tmp%%/*}"; host="${host#git@}"
    local path="${tmp#*/}";  path="${path%.git}"
    out="https://${host}/${path}"
  else
    out="${out%.git}"
  fi
  print -- "$out"
}

_cdplus_stats() {
  emulate -L zsh
  setopt extendedglob
  local files dirs repos=0

  # Fast file/dir count (only current level)
  files=$(_cdplus_count "./*(.N)")
  dirs=$(_cdplus_count "./*(/N)")

  # Repo count with depth limit and timeout
  if (( CDPLUS_MAX_DEPTH > 0 )); then
    local depth_flag=""
    [[ $CDPLUS_MAX_DEPTH -gt 0 ]] && depth_flag="-maxdepth $CDPLUS_MAX_DEPTH"

    # Use find with timeout for better performance
    local repo_count
    if command -v timeout >/dev/null 2>&1; then
      repo_count=$(timeout "${CDPLUS_TIMEOUT}s" find . $depth_flag -type d -name .git 2>/dev/null | wc -l | tr -d ' ')
    elif command -v gtimeout >/dev/null 2>&1; then
      repo_count=$(gtimeout "${CDPLUS_TIMEOUT}s" find . $depth_flag -type d -name .git 2>/dev/null | wc -l | tr -d ' ')
    else
      # Fallback: use find with limited depth, no timeout
      repo_count=$(find . $depth_flag -type d -name .git 2>/dev/null | wc -l | tr -d ' ')
    fi
    repos="${repo_count:-0}"
  fi

  print "$files|$dirs|$repos"
}

_cdplus_md5() {
  local s="$1"
  if command -v md5sum >/dev/null 2>&1; then
    print -n -- "$s" | md5sum | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    print -n -- "$s" | md5 | awk '{print $4}'
  else
    print -n -- "$s" | shasum -a 256 | awk '{print $1}'
  fi
}

_cdplus_dir_size_calculate() {
  # portable-ish directory size (human readable)
  # BSD & GNU: `du -sh .` works
  command du -sh . 2>/dev/null | awk '{print $1}'
}

_cdplus_dir_size_cached() {
  emulate -L zsh
  local sz
  # If no cache dir, compute and return without writing.
  if [[ ! -d "$CDPLUS_CACHE_DIR" ]]; then
    sz="$(_cdplus_dir_size_calculate)"
    print -r -- "$sz"
    return
  fi

  local key="$(_cdplus_md5 "$PWD")"
  local cache="${CDPLUS_CACHE_DIR}/${key}.size"
  local now epoch=0 ttl="${CDPLUS_SIZE_TTL}"
  now=$(date +%s)

  if [[ -f "$cache" ]]; then
    epoch=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)
    if (( now - epoch < ttl )); then
      cat "$cache"
      return
    fi
  fi

  sz="$(_cdplus_dir_size_calculate)"
  [[ -n "$sz" ]] && print -r -- "$sz" >| "$cache"
  print -r -- "$sz"
}

_cdplus_enter_msg() {
  local dir_name="$1" files="$2" dirs="$3" repos="$4" branch="$5" origin="$6" size="$7"

  if [[ -n "$branch" ]]; then
    print "📂 Changed to 🟢 $(_cdplus_bold "$dir_name")"
    local line="📊 Files: $files | Folders: $dirs | Branch: 🌿 $branch"
    [[ -n "$origin" ]] && line+=" | Remote: 🔗 $origin"
    [[ -n "$size"   ]] && line+=" | Size: 📦 $size"
    print -- "$line"
  else
    print "📂 Changed to 🟣 $(_cdplus_bold "$dir_name")"
    local line="📊 Files: $files | Folders: $dirs"
    [[ "$repos" != "?" ]] && line+=" | Repos inside: $repos"
    [[ -n "$size"   ]] && line+=" | Size: 📦 $size"
    print -- "$line"
  fi
}

_cdplus_compute_stats_async() {
  local target_dir="$1"
  local tmpfile="$2"

  {
    cd "$target_dir" 2>/dev/null || exit 1
    local stats="$(_cdplus_stats)"
    print -r -- "$stats" > "$tmpfile"
  } &!
}

_cdplus_save_bookmarks() {
  emulate -L zsh
  local parent="${CDPLUS_BOOKMARK_FILE:h}"
  if [[ ! -d "$parent" ]]; then
    print "⚠️  Bookmark file dir missing (${parent}); skipping persistence."
    return 0
  fi
  {
    print 'typeset -A BOOKMARKS'
    print 'BOOKMARKS=('
    local k
    for k in ${(k)BOOKMARKS}; do
      local p="${~BOOKMARKS[$k]}"
      print "  $k ${(q)p}"
    done
    print ')'
  } >| "$CDPLUS_BOOKMARK_FILE"
}

# ---------------- Main command: c ----------------
c() {
  emulate -L zsh
  setopt extendedglob

  local target="$1"

  if [[ -z "$target" ]]; then
    if [[ -n "$CDPLUS_USE_FZF" && -n "$commands[fzf]" ]]; then
      local picked
      if [[ -n "$commands[fd]" ]]; then
        picked="$(fd -t d -H -E .git . | fzf --prompt='cd> ' --height=40%)" || return 1
      else
        picked="$(command find . -type d -not -path '*/.git/*' -print 2>/dev/null \
          | sed -e 's#^\./##' | fzf --prompt='cd> ' --height=40%)" || return 1
      fi
      target="$picked"
    else
      target="$HOME"
    fi
  fi

  # Bookmark jump (strict: do not create anything)
  if [[ -n "${BOOKMARKS[$target]}" ]]; then
    local bm="${BOOKMARKS[$target]}"
    local expanded=${~bm}
    if [[ ! -d "$expanded" ]]; then
      print "❌ Bookmark exists but directory not found: $bm"
      return 1
    fi
    builtin cd -- "$expanded" || { print "❌ Failed to cd to bookmark: $target"; return 1; }
  elif [[ "$target" == "-" ]]; then
    builtin cd - || return 1
  elif [[ -d "$target" ]]; then
    builtin cd -- "$target" || return 1
  else
    print "❌ Directory or bookmark not found: $target"
    return 1
  fi

  local dir_name="${PWD:t}"

  # Git info is fast, get it synchronously
  local branch origin
  branch="$(_cdplus_git_branch)"
  origin="$(_cdplus_pretty_origin)"

  # Disable job control messages for cleaner output
  setopt local_options no_monitor no_notify

  # Async mode: show instant feedback, compute stats in background
  if [[ -n "$CDPLUS_ASYNC" ]]; then
    # Show immediate feedback
    if [[ -n "$branch" ]]; then
      print "📂 Changed to 🟢 $(_cdplus_bold "$dir_name")"
      local line="Branch: 🌿 $branch"
      [[ -n "$origin" ]] && line+=" | Remote: 🔗 $origin"
      print "⏳ $line | Computing stats..."
    else
      print "📂 Changed to 🟣 $(_cdplus_bold "$dir_name")"
      print "⏳ Computing stats..."
    fi

    # Compute in background and update when done
    local tmpfile="$(mktemp)"
    _cdplus_compute_stats_async "$PWD" "$tmpfile"
    local bg_pid=$!

    # Wait with timeout
    local elapsed=0
    while kill -0 "$bg_pid" 2>/dev/null && (( elapsed < CDPLUS_TIMEOUT )); do
      sleep 0.1
      elapsed=$((elapsed + 1))
    done

    # Kill if still running
    if kill -0 "$bg_pid" 2>/dev/null; then
      kill "$bg_pid" 2>/dev/null
      wait "$bg_pid" 2>/dev/null
      print "⏱️  Stats computation timed out after ${CDPLUS_TIMEOUT}s"
    else
      wait "$bg_pid" 2>/dev/null
      if [[ -f "$tmpfile" ]]; then
        local stats files dirs repos
        stats="$(cat "$tmpfile")"
        files="${stats%%|*}"
        dirs="${stats#*|}"; dirs="${dirs%%|*}"
        repos="${stats##*|}"

        local size=""
        if [[ -n "$CDPLUS_SHOW_SIZE" ]]; then
          size="$(_cdplus_dir_size_cached)"
        fi

        # Show updated stats
        printf "\r\033[K"  # Clear line
        _cdplus_enter_msg "$dir_name" "$files" "$dirs" "$repos" "$branch" "$origin" "$size"
      fi
    fi
    rm -f "$tmpfile"

  else
    # Synchronous mode with spinner and timeout
    local tmpfile="$(mktemp)"

    # Start stats computation in background
    _cdplus_compute_stats_async "$PWD" "$tmpfile"
    local bg_pid=$!

    # Show spinner (suppress job control with &!)
    {
      _cdplus_spinner "$bg_pid" "Computing stats"
    } &!
    local spinner_pid=$!

    # Wait with timeout
    local elapsed=0
    while kill -0 "$bg_pid" 2>/dev/null && (( elapsed < CDPLUS_TIMEOUT )); do
      sleep 0.1
      elapsed=$((elapsed + 1))
    done

    # Stop spinner
    kill "$spinner_pid" 2>/dev/null
    wait "$spinner_pid" 2>/dev/null

    # Kill stats if still running
    if kill -0 "$bg_pid" 2>/dev/null; then
      kill "$bg_pid" 2>/dev/null
      wait "$bg_pid" 2>/dev/null

      # Show what we have with "?" for unknown
      local files="?" dirs="?" repos="?"
      local size=""
      print "📂 Changed to $(_cdplus_bold "$dir_name")"
      print "⏱️  Stats computation timed out after ${CDPLUS_TIMEOUT}s"
    else
      wait "$bg_pid" 2>/dev/null

      local stats files dirs repos
      if [[ -f "$tmpfile" ]]; then
        stats="$(cat "$tmpfile")"
        files="${stats%%|*}"
        dirs="${stats#*|}"; dirs="${dirs%%|*}"
        repos="${stats##*|}"
      else
        files="?" dirs="?" repos="?"
      fi

      local size=""
      if [[ -n "$CDPLUS_SHOW_SIZE" ]]; then
        size="$(_cdplus_dir_size_cached)"
      fi

      _cdplus_enter_msg "$dir_name" "$files" "$dirs" "$repos" "$branch" "$origin" "$size"
    fi

    rm -f "$tmpfile"
  fi
}

# ---------------- Bookmark manager: cb ----------------
cb() {
  emulate -L zsh
  local cmd="$1"
  shift || true

  case "$cmd" in
    ls|"")
      if (( ${#BOOKMARKS} == 0 )); then
        print "ℹ️  No bookmarks yet. Add one with: cb add <key> <path>"
        return 0
      fi
      print "🔖 Bookmarks:"
      local k
      for k in ${(ok)BOOKMARKS}; do
        print "  $k → ${BOOKMARKS[$k]}"
      done
      ;;

    add)
      local key="$1" path="$2"
      if [[ -z "$key" || -z "$path" ]]; then
        print "Usage: cb add <key> <path>"
        return 1
      fi
      path=${~path}
      if [[ ! -d "$path" ]]; then
        print "❌ Not a directory (and won’t create it): $path"
        return 1
      fi
      BOOKMARKS[$key]="$path"
      _cdplus_save_bookmarks
      print "✅ Added: $key → $path"
      ;;

    rm|del|remove)
      local key="$1"
      if [[ -z "$key" ]]; then
        print "Usage: cb rm <key>"
        return 1
      fi
      if [[ -z "${BOOKMARKS[$key]}" ]]; then
        print "❌ No such bookmark: $key"
        return 1
      fi
      unset "BOOKMARKS[$key]"
      _cdplus_save_bookmarks
      print "🗑️  Removed: $key"
      ;;

    *)
      print "cb commands:"
      print "  cb ls                # list bookmarks"
      print "  cb add <key> <path>  # add a bookmark (path must already exist)"
      print "  cb rm  <key>         # remove a bookmark"
      return 1
      ;;
  esac
}

# Convenience alias
alias cdp='c'
