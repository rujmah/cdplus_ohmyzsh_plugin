# cdplus - Smart CD with Bookmarks & Stats

A powerful oh-my-zsh plugin that enhances your directory navigation experience with bookmarks, directory statistics, Git integration, and optional fzf support.

## Features

- **Smart Navigation**: Enhanced `cd` command with bookmark support
- **Directory Bookmarks**: Save and manage favorite directories
- **Directory Statistics**: Displays file count, folder count, and nested repos
- **Git Integration**: Shows current branch and remote origin when in a Git repository
- **Optional Directory Size**: Display cached directory sizes with configurable TTL
- **FZF Integration**: Optional fuzzy finder for directory navigation
- **Tab Completion**: ZSH completions for both `c` and `cb` commands
- **Persistent Bookmarks**: Bookmarks are saved across sessions

## Commands

### `c` - Enhanced CD Command

Navigate to directories with enhanced feedback and stats.

```bash
# Go to home directory
c

# Go to a directory
c ~/Projects

# Go to a bookmark
c work

# Go to previous directory
c -

# With FZF enabled: fuzzy search directories
c
```

### `cb` - Bookmark Manager

Manage your directory bookmarks.

```bash
# List all bookmarks
cb
cb ls

# Add a bookmark (directory must exist)
cb add work ~/Projects/work
cb add docs ~/Documents

# Remove a bookmark
cb rm work
cb del work
cb remove work
```

### `cdp` - Alias

Convenience alias for the `c` command.

## Installation

### Method 1: Oh-My-Zsh Custom Plugin (Recommended)

1. Clone this repository into your oh-my-zsh custom plugins directory:

```bash
git clone https://github.com/yourusername/cdplus.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/cdplus
```

2. Add `cdplus` to your plugins array in `~/.zshrc`:

```bash
plugins=(
  # ... other plugins
  cdplus
)
```

3. Reload your shell:

```bash
source ~/.zshrc
```

### Method 2: Manual Installation

1. Copy the plugin files to your oh-my-zsh custom plugins directory:

```bash
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/cdplus
cp cdplus.plugin.zsh ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/cdplus/
cp _c ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/cdplus/
cp _cb ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/cdplus/
```

2. Add `cdplus` to your plugins in `~/.zshrc`
3. Reload your shell

### Method 3: Standalone (No Oh-My-Zsh)

Source the plugin directly in your `~/.zshrc`:

```bash
source /path/to/cdplus.plugin.zsh
```

## Configuration

Add these configuration options to your `~/.zshrc` **before** oh-my-zsh is sourced:

```bash
# Enable FZF integration (requires fzf to be installed)
export CDPLUS_USE_FZF=1

# Show directory size in the output
export CDPLUS_SHOW_SIZE=1

# Cache TTL in seconds (default: 300 = 5 minutes)
export CDPLUS_SIZE_TTL=600

# ===== Performance Options (NEW) =====
# Maximum time to wait for stats computation (default: 5 seconds)
export CDPLUS_TIMEOUT=5

# Maximum depth for repo search (default: 3, set to 0 to disable repo counting)
export CDPLUS_MAX_DEPTH=3

# Enable async mode: show immediate feedback, compute stats in background (default: off)
export CDPLUS_ASYNC=1

# Show spinner while computing stats (default: 1 = enabled)
export CDPLUS_SHOW_SPINNER=1

# Custom bookmark file location (optional)
export CDPLUS_BOOKMARK_FILE="$HOME/.config/cdplus/bookmarks.zsh"

# Custom cache directory (optional)
export CDPLUS_CACHE_DIR="$HOME/.cache/cdplus/sizes"

# Pre-define bookmarks in .zshrc (optional)
typeset -A BOOKMARKS
BOOKMARKS=(
  proj ~/Projects
  docs ~/Documents
  work ~/Clients
  config ~/.config
)
```

### Configuration Order in .zshrc

```bash
# 1. Configuration (BEFORE oh-my-zsh)
export CDPLUS_USE_FZF=1
export CDPLUS_SHOW_SIZE=1

# 2. Oh-My-Zsh initialization
plugins=(... cdplus)
source $ZSH/oh-my-zsh.sh

# 3. Additional customizations (AFTER oh-my-zsh)
```

## Optional Dependencies

- **fzf** - For fuzzy directory searching when `CDPLUS_USE_FZF=1`
  ```bash
  # macOS
  brew install fzf

  # Linux
  sudo apt install fzf  # Debian/Ubuntu
  sudo dnf install fzf  # Fedora
  ```

- **fd** - Faster alternative to `find` (optional, used with fzf if available)
  ```bash
  # macOS
  brew install fd

  # Linux
  sudo apt install fd-find  # Debian/Ubuntu
  sudo dnf install fd-find  # Fedora
  ```

## Examples

### Basic Navigation

```bash
# Navigate to a directory and see stats
$ c ~/Projects/my-app
📂 Changed to 🟢 my-app
📊 Files: 45 | Folders: 12 | Branch: 🌿 main | Remote: 🔗 https://github.com/user/my-app

# Navigate to a non-Git directory
$ c ~/Documents
📂 Changed to 🟣 Documents
📊 Files: 23 | Folders: 8 | Repos inside: 0
```

### Using Bookmarks

```bash
# Add bookmarks
$ cb add proj ~/Projects
✅ Added: proj → /Users/you/Projects

$ cb add work ~/Clients/current-client
✅ Added: work → /Users/you/Clients/current-client

# List bookmarks
$ cb ls
🔖 Bookmarks:
  proj → /Users/you/Projects
  work → /Users/you/Clients/current-client

# Jump to a bookmark
$ c proj
📂 Changed to 🟣 Projects
📊 Files: 156 | Folders: 34 | Repos inside: 12

# Remove a bookmark
$ cb rm work
🗑️  Removed: work
```

### With FZF Integration

```bash
# Run 'c' with no arguments to get fuzzy finder
$ c
# Opens interactive fuzzy finder
# Type to search, Enter to select, Esc to cancel
```

### With Directory Size

```bash
# Enable size display
$ export CDPLUS_SHOW_SIZE=1

$ c ~/Projects/large-app
📂 Changed to 🟢 large-app
📊 Files: 234 | Folders: 56 | Branch: 🌿 develop | Remote: 🔗 https://github.com/user/large-app | Size: 📦 2.3G
```

## Output Format

### Git Repository (Synchronous Mode)
```
⠋ Computing stats
📂 Changed to 🟢 <directory-name>
📊 Files: X | Folders: Y | Branch: 🌿 <branch> | Remote: 🔗 <url> [| Size: 📦 <size>]
```

### Non-Git Directory (Synchronous Mode)
```
⠋ Computing stats
📂 Changed to 🟣 <directory-name>
📊 Files: X | Folders: Y | Repos inside: Z [| Size: 📦 <size>]
```

### Async Mode
```
📂 Changed to 🟢 <directory-name>
⏳ Branch: 🌿 main | Remote: 🔗 https://github.com/user/repo | Computing stats...
📂 Changed to 🟢 <directory-name>
📊 Files: X | Folders: Y | Branch: 🌿 main | Remote: 🔗 <url>
```

### Timeout
```
⠋ Computing stats
📂 Changed to <directory-name>
⏱️  Stats computation timed out after 5s
```

## Bookmark Persistence

Bookmarks are automatically saved to `~/.config/cdplus/bookmarks.zsh` and persist across shell sessions. The bookmark file is created automatically when you add your first bookmark.

You can also define bookmarks directly in your `~/.zshrc` before oh-my-zsh loads - these will be merged with persisted bookmarks (persisted ones take precedence).

## Tab Completion

The plugin includes ZSH completion functions:

- **`c`** command: Completes bookmarks and directories
- **`cb`** command: Completes subcommands (`ls`, `add`, `rm`) and bookmark keys

## Performance

### Performance Improvements (v2.0)

The plugin now includes several performance optimizations for directories with many subdirectories and repos:

- **Timeout Protection**: Operations automatically timeout after 5 seconds (configurable)
- **Depth Limiting**: Repo search limited to 3 levels deep by default (configurable)
- **Visual Feedback**: Spinner shows progress during computation
- **Async Mode**: Optional instant feedback with background computation
- **Optimized Search**: Uses `find` with timeouts instead of slow glob patterns

### Performance Settings

```bash
# Recommended for large directories (many subdirs/repos)
export CDPLUS_TIMEOUT=3        # Fail fast
export CDPLUS_MAX_DEPTH=2      # Don't search too deep
export CDPLUS_ASYNC=1          # Show instant feedback
export CDPLUS_SHOW_SPINNER=1   # Visual progress indicator

# Recommended for smaller directories (fast)
export CDPLUS_TIMEOUT=5
export CDPLUS_MAX_DEPTH=3
# CDPLUS_ASYNC not needed
export CDPLUS_SHOW_SPINNER=1
```

### How It Works

- **Synchronous Mode** (default): Shows a spinner while computing stats, times out after 5s
- **Async Mode** (`CDPLUS_ASYNC=1`): Shows immediate feedback, updates stats when ready
- **Timeout Handling**: If stats take longer than `CDPLUS_TIMEOUT`, operation is cancelled
- **Depth Limiting**: Repo search only goes `CDPLUS_MAX_DEPTH` levels deep
- **Git Info**: Fast operations (branch/remote) always run immediately

## Troubleshooting

### Bookmarks not persisting

Ensure the bookmark directory exists:
```bash
mkdir -p ~/.config/cdplus
```

### Size cache not working

Create the cache directory:
```bash
mkdir -p ~/.cache/cdplus/sizes
```

### FZF not working

Ensure fzf is installed and `CDPLUS_USE_FZF` is set before oh-my-zsh loads:
```bash
which fzf  # Should return a path
echo $CDPLUS_USE_FZF  # Should return 1
```

### Completions not working

Ensure the completion files (`_c` and `_cb`) are in the same directory as the plugin and oh-my-zsh is properly initialized.

### Still too slow in large directories

If the plugin is still slow even with timeouts:

1. **Disable repo counting entirely**:
   ```bash
   export CDPLUS_MAX_DEPTH=0
   ```

2. **Use async mode for instant feedback**:
   ```bash
   export CDPLUS_ASYNC=1
   export CDPLUS_TIMEOUT=2
   ```

3. **Disable size calculation** (if enabled):
   ```bash
   unset CDPLUS_SHOW_SIZE
   ```

4. **Install `timeout` command** (for better timeout support):
   ```bash
   # macOS
   brew install coreutils  # provides gtimeout

   # Linux - usually pre-installed
   ```

### Timeout command not found

On macOS, the GNU `timeout` command may not be available. The plugin will:
- Try `timeout` first (Linux/GNU coreutils)
- Fall back to `gtimeout` (macOS with coreutils installed)
- Fall back to `find` without timeout as last resort

For best performance on macOS:
```bash
brew install coreutils
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use and modify as needed.

## Credits

Developed as an enhanced `cd` replacement for oh-my-zsh users who want more context and control over their directory navigation.
