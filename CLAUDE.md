# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an oh-my-zsh plugin that enhances directory navigation with bookmarks, statistics, and Git integration. The plugin provides two main commands: `c` (enhanced cd) and `cb` (bookmark manager).

## Key Files

- `cdplus.plugin.zsh` - Main plugin implementation (~440 lines)
- `_c` - ZSH completion for the `c` command
- `_cb` - ZSH completion for the `cb` command
- `install.sh` - Installation script for users

## Architecture

### Core Components

1. **Navigation (`c` command)**: Lines 217-375 in cdplus.plugin.zsh
   - Handles directory changes with bookmark support
   - Two modes: synchronous (default) and asynchronous (`CDPLUS_ASYNC=1`)
   - Uses background jobs for stats computation with timeout protection

2. **Bookmark Management (`cb` command)**: Lines 378-435
   - Stores bookmarks in associative array `BOOKMARKS`
   - Persists to `~/.config/cdplus/bookmarks.zsh`
   - Commands: `ls`, `add`, `rm`/`del`/`remove`

3. **Statistics Computation**: Lines 93-121 (`_cdplus_stats`)
   - File count: current directory only (`./*(.N)`)
   - Folder count: current directory only (`./*(/N)`)
   - Repo count: uses `find` with `maxdepth` and timeout
   - Performance-critical: bounded by `CDPLUS_TIMEOUT` and `CDPLUS_MAX_DEPTH`

4. **Git Integration**: Lines 65-91
   - `_cdplus_git_branch`: Get current branch
   - `_cdplus_pretty_origin`: Convert git URL to HTTPS format
   - Fast operations, always run synchronously

5. **Performance Features**:
   - Spinner animation (lines 37-55): Braille spinner with 0.1s refresh
   - Timeout mechanism: Background job monitoring with `kill -0` checks
   - Async mode: Immediate feedback, stats computed in background
   - Cache system for directory sizes (lines 123-166)

### Execution Flow (Synchronous Mode)

1. Parse target (bookmark, path, or HOME)
2. Change directory with `builtin cd`
3. Get Git info (fast, synchronous)
4. Start background job for stats computation
5. Show spinner while waiting (up to `CDPLUS_TIMEOUT` seconds)
6. Kill spinner and background job if timeout exceeded
7. Display formatted message with stats

### Execution Flow (Async Mode)

1. Parse target and change directory
2. Get Git info and show immediate feedback
3. Start background stats computation
4. Wait with timeout
5. Update display with stats when ready (or timeout message)

## Configuration Variables

Set these in `.zshrc` **before** oh-my-zsh loads:

- `CDPLUS_USE_FZF`: Enable fzf integration
- `CDPLUS_SHOW_SIZE`: Display directory size (cached)
- `CDPLUS_SIZE_TTL`: Cache TTL in seconds (default: 300)
- `CDPLUS_TIMEOUT`: Max stats computation time (default: 5)
- `CDPLUS_MAX_DEPTH`: Max depth for repo search (default: 3, 0=disable)
- `CDPLUS_ASYNC`: Enable async mode (default: off)
- `CDPLUS_SHOW_SPINNER`: Show spinner during computation (default: 1)
- `CDPLUS_BOOKMARK_FILE`: Bookmark storage location
- `CDPLUS_CACHE_DIR`: Size cache directory

## Testing the Plugin

```bash
# Manual testing - source the plugin directly
source cdplus.plugin.zsh

# Test navigation
c ~
c ~/Projects

# Test bookmarks
cb add test ~/Projects
cb ls
c test
cb rm test

# Test with FZF (requires fzf installed)
export CDPLUS_USE_FZF=1
c  # Opens fuzzy finder

# Test async mode
export CDPLUS_ASYNC=1
c ~/some/large/directory

# Test timeout behavior in large directory
export CDPLUS_TIMEOUT=2
export CDPLUS_MAX_DEPTH=1
```

## Performance Considerations

The plugin's performance depends heavily on directory size and structure:

- **File/folder count**: Fast (current directory only, no recursion)
- **Repo count**: Can be slow (recursive search with `find`)
- **Directory size**: Can be slow (uses `du -sh`, cached with TTL)

Performance optimizations:
- Uses `find` with `-maxdepth` instead of glob patterns for repo search
- Background jobs with timeout protection prevent hanging
- Spinner provides visual feedback during computation
- Async mode provides instant feedback for large directories
- Prefers `timeout`/`gtimeout` commands when available

## Common Development Tasks

When modifying stats computation, ensure:
- Background jobs are properly cleaned up with `kill`
- Temp files are removed with `rm -f "$tmpfile"`
- Job control is disabled with `setopt local_options no_monitor no_notify`
- Background jobs use `&!` to suppress job control messages

When modifying the spinner:
- Ensure it clears the line properly with `printf "\r\033[K"` or space padding
- Use `kill -0` to check if process is still running
- Stop spinner before showing final output

When modifying bookmarks:
- Always validate directory exists before adding
- Save after modifications with `_cdplus_save_bookmarks`
- Use `${~path}` for tilde expansion
- Handle missing bookmark directory gracefully

## ZSH-Specific Patterns

- `emulate -L zsh`: Set ZSH emulation mode for function
- `setopt extendedglob null_glob`: Enable advanced glob features
- `./*(.N)`: Glob regular files, null if none found
- `./*(/N)`: Glob directories, null if none found
- `${#array}`: Array length
- `${(k)ASSOC_ARRAY}`: Keys of associative array
- `${~var}`: Force tilde expansion
- `${var:h}`: Head (dirname) of path
- `${var:t}`: Tail (basename) of path
- `&!`: Background job without job control messages
