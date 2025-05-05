#!/bin/sh
# Script to find git repositories in the current directory tree,
# present them as a selection menu, and create a tmux session with 3 windows
#
# Flags:
#   -a   Attach to existing session without prompting
#   -k   Kill existing session and create new one without prompting
#   -c   Create new custom session configuration

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Find all git repositories in the current directory (recursively)
find_git_repos() {
  find . -type d -name ".git" | sed 's/\/\.git$//' | sort
}

# Check if directory is a git repository
is_git_repo() {
  [ -d "$1/.git" ]
}

# Create a new custom session configuration
create_custom_session() {
  echo -e "${BOLD}${GREEN}Creating new custom session configuration${NC}"

  # Step 1: Get session name
  printf "${CYAN}Enter a name for this session:${NC} "
  read session_name

  if [ -z "$session_name" ]; then
    echo -e "${RED}Session name cannot be empty. Exiting.${NC}"
    exit 1
  fi

  # Check if session name already exists
  if [ -f "$CONFIG_DIR/$session_name.session" ]; then
    echo -e "${YELLOW}A session with this name already exists.${NC}"
    printf "${CYAN}Overwrite? (y/N):${NC} "
    read overwrite

    case "$overwrite" in
    [Yy]*) ;;
    *)
      echo -e "${RED}Cancelled. Exiting.${NC}"
      exit 0
      ;;
    esac
  fi

  # Initialize variables to store window configurations
  window_configs=""
  window_count=0

  # Keep adding windows until the user says no
  while true; do
    window_count=$((window_count + 1))

    # Step 2: Get directory for this window
    if [ $window_count -eq 1 ] || [ "$add_window" = "2" ]; then
      printf "${CYAN}Enter directory path for window #$window_count:${NC} "
      read window_dir

      # Handle path expansion
      if [ -z "$window_dir" ]; then
        # Empty input, use current directory
        window_dir="$(pwd)"
      elif [ "$(echo "$window_dir" | cut -c1)" = "~" ]; then
        # Expand ~ to $HOME
        window_dir="$HOME$(echo "$window_dir" | cut -c2-)"
      elif [ "$(echo "$window_dir" | cut -c1)" != "/" ]; then
        # If not an absolute path, make it relative to current directory
        window_dir="$(pwd)/$window_dir"
      fi

      # Clean up the path (resolve .., ., //, etc.)
      window_dir=$(cd "$(dirname "$window_dir")" 2>/dev/null && pwd -P 2>/dev/null)/"$(basename "$window_dir")"
      # Remove trailing /. if present, in a POSIX-compatible way
      case "$window_dir" in
      */.) window_dir=$(echo "$window_dir" | sed 's|/\.$||') ;;
      esac

      # Validate directory exists
      if [ ! -d "$window_dir" ]; then
        echo -e "${YELLOW}Directory doesn't exist. Create it?${NC}"
        printf "${CYAN}Create directory? (y/N):${NC} "
        read create_dir

        case "$create_dir" in
        [Yy]*)
          mkdir -p "$window_dir"
          echo -e "${GREEN}Directory created.${NC}"
          ;;
        *)
          echo -e "${RED}Directory is required. Exiting.${NC}"
          exit 1
          ;;
        esac
      fi
    else
      # Use the same directory as previous window
      window_dir=$(echo "$prev_config" | cut -d'|' -f1)
      echo -e "${CYAN}Using directory: ${NC}$window_dir"
    fi

    # Step 3: Get command to run in this window
    echo -e "${CYAN}Select command to run in this window:${NC}"
    echo "1) nvim"
    echo "2) git status"
    echo "3) No command"
    echo "4) Custom command..."
    printf "${CYAN}Enter your choice [1-4]:${NC} "
    read cmd_choice

    case "$cmd_choice" in
    1)
      window_command="nvim"
      ;;
    2)
      window_command="git status"
      ;;
    3)
      window_command=""
      ;;
    4)
      printf "${CYAN}Enter custom command:${NC} "
      read window_command
      ;;
    *)
      window_command=""
      ;;
    esac

    # Step 4: Get window name (optional)
    printf "${CYAN}Enter name for this window (optional, press Enter to skip):${NC} "
    read window_name

    # Add window configuration
    current_config="${window_dir}|${window_command}|${window_name}"
    if [ -z "$window_configs" ]; then
      window_configs="$current_config"
    else
      window_configs="$window_configs
$current_config"
    fi
    prev_config="$current_config"

    # Step 5: Ask if user wants another window
    echo -e "${CYAN}Add another window?${NC}"
    echo "1) Yes (in same directory)"
    echo "2) Yes (in new directory)"
    echo "3) No, I'm done"
    printf "${CYAN}Enter your choice [1-3]:${NC} "
    read add_window_choice

    case "$add_window_choice" in
    1)
      add_window="1"
      ;;
    2)
      add_window="2"
      ;;
    *)
      break
      ;;
    esac
  done

  # Save the configuration
  save_session_config "$session_name" "$window_configs" "$window_count"

  # Ask user if they want to open the session now
  echo -e "${CYAN}Session configuration saved.${NC}"
  printf "${CYAN}Would you like to open this session now? (Y/n):${NC} "
  read open_now

  case "$open_now" in
  [Nn]*)
    echo -e "${GREEN}Configuration saved. You can start it later with:${NC}"
    echo -e "  ${BOLD}./sessionizer.sh${NC} and selecting 🔖 Custom: $session_name"
    ;;
  *)
    load_custom_session "$session_name"
    ;;
  esac
}

# Save session configuration to a file
save_session_config() {
  local session_name="$1"
  local window_configs="$2"
  local window_count="$3"

  # Create configuration file
  echo "# Session configuration created $(date)" >"$CONFIG_DIR/$session_name.session"
  echo "session_name=\"$session_name\"" >>"$CONFIG_DIR/$session_name.session"

  # Save each window configuration
  i=0
  echo "$window_configs" | while IFS= read -r config; do
    if [ -n "$config" ]; then
      echo "window_config_$i=\"$config\"" >>"$CONFIG_DIR/$session_name.session"
      i=$((i + 1))
    fi
  done

  echo "window_count=$window_count" >>"$CONFIG_DIR/$session_name.session"

  echo -e "${GREEN}Session configuration saved to $CONFIG_DIR/$session_name.session${NC}"
}

# Load and start a custom session
load_custom_session() {
  local session_name="$1"
  local config_file="$CONFIG_DIR/$session_name.session"

  if [ ! -f "$config_file" ]; then
    echo -e "${RED}Session configuration not found: $config_file${NC}"
    exit 1
  fi

  # Source the configuration file
  . "$config_file"

  # Check if a session with this name already exists
  if tmux has-session -t "$session_name" 2>/dev/null; then
    if [ "$attach_flag" = "true" ]; then
      # Auto-attach to existing session
      tmux attach-session -t "$session_name"
      exit 0
    elif [ "$kill_flag" = "true" ]; then
      # Auto-kill existing session
      tmux kill-session -t "$session_name"
      echo "Killed existing session. Creating new session..."
    else
      echo -e "${YELLOW}Session '${BOLD}$session_name${NC}${YELLOW}' already exists.${NC}"

      echo "What would you like to do?"
      echo "1) Attach to existing session"
      echo "2) Kill and create new session"
      echo "3) Cancel"
      printf "${CYAN}Enter your choice [1-3]:${NC} "
      read choice_num

      case "$choice_num" in
      1)
        # Attach to existing session
        tmux attach-session -t "$session_name"
        exit 0
        ;;
      2)
        # Kill the existing session
        tmux kill-session -t "$session_name"
        echo -e "${GREEN}Killed existing session. Creating new session...${NC}"
        ;;
      *)
        # Any other input will cancel
        echo -e "${YELLOW}Cancelled. Exiting.${NC}"
        exit 0
        ;;
      esac
    fi
  fi

  # Process the first window configuration
  eval "first_config=\"\$window_config_0\""
  first_dir=$(echo "$first_config" | cut -d'|' -f1)
  first_command=$(echo "$first_config" | cut -d'|' -f2)
  first_name=$(echo "$first_config" | cut -d'|' -f3)

  # Create the first window with the name if provided
  if [ -n "$first_name" ]; then
    tmux new-session -d -s "$session_name" -c "$first_dir" -n "$first_name"
  else
    tmux new-session -d -s "$session_name" -c "$first_dir"
  fi

  # Send command to first window if provided
  if [ -n "$first_command" ]; then
    tmux send-keys -t "$session_name:0" "$first_command" C-m
  fi

  # Create additional windows
  i=1
  while [ "$i" -lt "$window_count" ]; do
    config_var="window_config_$i"
    eval "window_config=\"\$$config_var\""

    dir=$(echo "$window_config" | cut -d'|' -f1)
    command=$(echo "$window_config" | cut -d'|' -f2)
    name=$(echo "$window_config" | cut -d'|' -f3)

    # Create window with name if provided
    if [ -n "$name" ]; then
      tmux new-window -t "$session_name:$i" -c "$dir" -n "$name"
    else
      tmux new-window -t "$session_name:$i" -c "$dir"
    fi

    # Send command if provided
    if [ -n "$command" ]; then
      tmux send-keys -t "$session_name:$i" "$command" C-m
    fi

    i=$((i + 1))
  done

  # Select the first window and attach to session
  tmux select-window -t "$session_name:0"
  echo -e "${GREEN}Attaching to custom session: ${BOLD}$session_name${NC}"
  tmux attach-session -t "$session_name"
}

# Simple menu function for selecting options
show_menu() {
  local prompt="$1"
  shift
  echo -e "${BOLD}${BLUE}$prompt${NC}"
  echo -e "${YELLOW}───────────────────────────────────${NC}"

  i=1
  while [ "$i" -le "$#" ]; do
    eval "option=\$$i"
    echo "$i) $option"
    i=$((i + 1))
  done

  printf "${BOLD}Enter your choice [1-$#]:${NC} "
  read choice_num

  if [ -n "$choice_num" ] && [ "$choice_num" -ge 1 ] 2>/dev/null && [ "$choice_num" -le "$#" ] 2>/dev/null; then
    eval "echo \$$choice_num"
    return 0
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
    return 1
  fi
}

# Function to check and offer to install dependencies
check_and_install_dependency() {
  local dep=$1
  local install_cmd=$2

  if ! command -v "$dep" >/dev/null 2>&1; then
    echo -e "${YELLOW}$dep is not installed.${NC}"
    printf "Would you like to install $dep now? [y/N] "
    read response

    case "$response" in
    [Yy]*)
      echo -e "${CYAN}Installing $dep...${NC}"
      if eval "$install_cmd"; then
        echo -e "${GREEN}$dep has been successfully installed.${NC}"
      else
        echo -e "${RED}Failed to install $dep. Please install it manually.${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}$dep is required for this script to work. Exiting.${NC}"
      exit 1
      ;;
    esac
  fi
}

# Detect package manager
get_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    echo "sudo apt update && sudo apt install -y"
  elif command -v dnf >/dev/null 2>&1; then
    echo "sudo dnf install -y"
  elif command -v yum >/dev/null 2>&1; then
    echo "sudo yum install -y"
  elif command -v pacman >/dev/null 2>&1; then
    echo "sudo pacman -S --noconfirm"
  elif command -v zypper >/dev/null 2>&1; then
    echo "sudo zypper install -y"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew install"
  else
    echo ""
  fi
}

# Get the appropriate package manager
PKG_MGR=$(get_package_manager)

# Check if required tools are installed
if [ -z "$PKG_MGR" ]; then
  echo -e "${RED}Could not detect package manager. Please install dependencies manually.${NC}"
fi

# Check tmux
check_and_install_dependency "tmux" "$PKG_MGR tmux"

# Check git
check_and_install_dependency "git" "$PKG_MGR git"

# Check for fzf (optional but recommended)
if ! command -v fzf >/dev/null 2>&1; then
  echo -e "${YELLOW}fzf is not installed.${NC}"
  echo -e "${CYAN}fzf provides a much better selection interface with:${NC}"
  echo -e " ${GREEN}•${NC} Fuzzy search for repositories"
  echo -e " ${GREEN}•${NC} Preview window showing git status and recent commits"
  echo -e " ${GREEN}•${NC} Interactive navigation"

  if [ -n "$PKG_MGR" ]; then
    printf "${CYAN}Would you like to install fzf for a better experience? [y/N] ${NC}"
    read response

    case "$response" in
    [Yy]*)
      echo -e "${CYAN}Installing fzf...${NC}"
      if eval "$PKG_MGR fzf"; then
        echo -e "${GREEN}fzf has been successfully installed.${NC}"
        echo -e "${CYAN}You may need to restart the script to use fzf.${NC}"
        printf "${CYAN}Continue with basic menu for now? [Y/n] ${NC}"
        read continue_response
        case "$continue_response" in
        [Nn]*)
          exit 0
          ;;
        esac
      else
        echo -e "${YELLOW}Failed to install fzf. Will continue with basic selection menu.${NC}"
      fi
      ;;
    *)
      echo -e "${BLUE}Continuing with basic selection menu...${NC}"
      ;;
    esac
  fi
fi

# Configuration directory for custom sessions
CONFIG_DIR="$HOME/.config/sessionizer"
mkdir -p "$CONFIG_DIR"

# Show help information
show_help() {
  echo -e "${BOLD}${BLUE}Tmux Sessionizer - Easily manage tmux sessions${NC}"
  echo
  echo -e "${YELLOW}Usage:${NC}"
  echo -e "  $(basename "$0") [OPTIONS] [REPOSITORY_NAME]"
  echo
  echo -e "${YELLOW}Options:${NC}"
  echo -e "  ${GREEN}-a${NC}         Attach to existing session without prompting"
  echo -e "  ${GREEN}-k${NC}         Kill existing session and create new one without prompting"
  echo -e "  ${GREEN}-c${NC}         Create new custom session configuration"
  echo -e "  ${GREEN}-h, --help${NC} Show this help message and exit"
  echo
  echo -e "${YELLOW}Arguments:${NC}"
  echo -e "  ${GREEN}REPOSITORY_NAME${NC}  Optional name of a git repository to create/attach session for"
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  $(basename "$0")               # Interactive repository selection"
  echo -e "  $(basename "$0") dotfiles      # Find and open the 'dotfiles' repository"
  echo -e "  $(basename "$0") -c            # Create a custom session configuration"
  echo -e "  $(basename "$0") -a dotfiles   # Attach to existing 'dotfiles' session"
  echo
}

# Process flags
attach_flag=false
kill_flag=false
create_flag=false

while getopts "akch" opt; do
  case $opt in
  a) attach_flag=true ;;
  k) kill_flag=true ;;
  c) create_flag=true ;;
  h)
    show_help
    exit 0
    ;;
  \?)
    echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
    show_help
    exit 1
    ;;
  esac
done

# Shift to remove processed flags
shift $((OPTIND - 1))

selected=""

# Check if help flag is explicitly provided
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  exit 0
fi

# Check if a directory name was provided as an argument
if [ $# -eq 1 ]; then
  # First, check exact match
  if [ -d "./$1" ] && is_git_repo "./$1"; then
    selected="./$1"
  else
    # Try to find directories that match the input
    matching_repos=$(find . -type d -path "*$1*" -not -path "*/\.*" | grep -v "node_modules" | while read -r dir; do
      if is_git_repo "$dir"; then
        echo "$dir"
      fi
    done)

    # If exactly one match is found, use it
    match_count=$(echo "$matching_repos" | grep -v '^$' | wc -l | tr -d ' ')
    if [ "$match_count" -eq 1 ]; then
      selected=$matching_repos
      echo "Found matching repository: $selected"
    elif [ "$match_count" -gt 1 ]; then
      echo "Multiple matching repositories found:"
      i=1
      options=""

      echo "$matching_repos" | while IFS= read -r repo; do
        if [ -n "$repo" ]; then
          echo "$i) $repo"
          i=$((i + 1))
        fi
      done

      printf "Select a repository [1-$((i - 1))]: "
      read repo_choice

      if [ -n "$repo_choice" ] && [ "$repo_choice" -ge 1 ] 2>/dev/null && [ "$repo_choice" -lt "$i" ] 2>/dev/null; then
        selected=$(echo "$matching_repos" | sed -n "${repo_choice}p")
        echo "Selected repository: $selected"
      fi
    else
      # No matching repositories found
      echo -e "${YELLOW}No matching git repository found for '${BOLD}$1${NC}${YELLOW}'.${NC}"
      echo -e "${CYAN}Would you like to:${NC}"
      echo "1) Clone a git repository with this name"
      echo "2) Continue with repository selection"
      echo "3) Exit"
      printf "${CYAN}Choose an option [1-3]:${NC} "
      read choice_num

      case "$choice_num" in
      1)
        printf "Enter the git repository URL: "
        read repo_url
        printf "Enter the directory to clone into [$(pwd)]: "
        read clone_dir
        clone_dir=${clone_dir:-$(pwd)}
        printf "Enter the directory name for the repository [$1]: "
        read dir_name
        dir_name=${dir_name:-$1}

        mkdir -p "$clone_dir"
        if git clone "$repo_url" "$clone_dir/$dir_name"; then
          selected="$clone_dir/$dir_name"
          echo "Successfully cloned repository to $selected"
        else
          echo -e "${RED}Failed to clone repository. Exiting.${NC}"
          exit 1
        fi
        ;;
      3)
        echo -e "${YELLOW}Exiting sessionizer.${NC}"
        exit 0
        ;;
      *)
        echo -e "${BLUE}Continuing with repository selection...${NC}"
        ;;
      esac
    fi
  fi
fi

# Create custom session if the flag is set
if [ "$create_flag" = "true" ]; then
  create_custom_session
  exit 0
fi

# If no directory was provided or no match was found and user didn't clone
if [ -z "$selected" ]; then
  # Find git repositories
  repos=$(find_git_repos)

  if [ -z "$repos" ]; then
    echo -e "${RED}No git repositories found in the current directory tree.${NC}"
    exit 1
  fi

  # Prepare all options (repos + custom session option + saved sessions)
  all_options=""

  # Add git repositories
  all_options="$repos"

  # Add "Create new custom session" option
  all_options="$all_options
✨ Create new custom session"

  # Add saved custom sessions if they exist
  if [ -d "$CONFIG_DIR" ] && [ "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
    for file in "$CONFIG_DIR"/*.session; do
      if [ -f "$file" ]; then
        session_name=$(basename "$file" .session)
        all_options="$all_options
🔖 Custom: $session_name"
      fi
    done
  fi

  # Use fzf if available, otherwise fall back to basic menu
  if command -v fzf >/dev/null 2>&1; then
    # Set FZF_DEFAULT_OPTS for this run only
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --ansi"

    # Use fzf with preview window showing git status for repositories
    selected=$(echo "$all_options" | fzf --header="Select repository or session" \
      --preview="if ! echo {} | grep -q '^✨\\|^🔖' && [ -d {} ]; then 
          echo -e '${GREEN}Git Status:${NC}' && git -C {} status -s; 
          echo -e '\n${BLUE}Last 5 commits:${NC}' && git -C {} log --oneline -n 5; 
        fi")
  else
    # Fall back to basic menu if fzf is not available
    repo_count=0
    menu_options=""

    # Number all options for the menu
    echo "$all_options" | while IFS= read -r option; do
      if [ -n "$option" ]; then
        repo_count=$((repo_count + 1))
        echo "$repo_count) $option"
        menu_options="${menu_options}${option}
"
      fi
    done

    # Get user selection through basic menu
    if [ "$repo_count" -gt 0 ]; then
      printf "${CYAN}Select a repository or custom session [1-$repo_count]:${NC} "
      read selection_num

      if [ -n "$selection_num" ] && [ "$selection_num" -ge 1 ] 2>/dev/null && [ "$selection_num" -le "$repo_count" ] 2>/dev/null; then
        selected=$(echo "$menu_options" | sed -n "${selection_num}p")
      fi
    fi
  fi

  # Exit if no repository was selected
  if [ -z "$selected" ]; then
    echo -e "${YELLOW}No repository or session selected. Exiting.${NC}"
    exit 0
  fi

  # Check if the user selected "Create new custom session"
  if [ "$selected" = "✨ Create new custom session" ]; then
    create_custom_session
    exit 0
  fi

  # Check if the user selected a custom session
  case "$selected" in
  "🔖 Custom: "*)
    custom_name=$(echo "$selected" | sed 's/^🔖 Custom: //')
    load_custom_session "$custom_name"
    exit 0
    ;;
  esac
fi

# Get the basename of the repository for the session name
repo_name=$(basename "$selected")

# Check if a session with this name already exists
if tmux has-session -t "$repo_name" 2>/dev/null; then
  if [ "$attach_flag" = "true" ]; then
    # Auto-attach to existing session
    tmux attach-session -t "$repo_name"
    exit 0
  elif [ "$kill_flag" = "true" ]; then
    # Auto-kill existing session
    tmux kill-session -t "$repo_name"
    echo "Killed existing session. Creating new session..."
    # Continue with the script to create a new session
  else
    echo -e "${YELLOW}Session '${BOLD}$repo_name${NC}${YELLOW}' already exists.${NC}"

    echo "What would you like to do?"
    echo "1) Attach to existing session"
    echo "2) Kill and create new session"
    echo "3) Cancel"
    printf "${CYAN}Enter your choice [1-3]:${NC} "
    read choice_num

    case "$choice_num" in
    1)
      # Attach to existing session
      tmux attach-session -t "$repo_name"
      exit 0
      ;;
    2)
      # Kill the existing session
      tmux kill-session -t "$repo_name"
      echo -e "${GREEN}Killed existing session. Creating new session...${NC}"
      # Continue with the script to create a new session
      ;;
    *)
      # Any other input will cancel
      echo -e "${YELLOW}Cancelled. Exiting.${NC}"
      exit 0
      ;;
    esac
  fi
fi

# Create a new tmux session with the repository name
echo -e "${GREEN}Creating new tmux session: ${BOLD}$repo_name${NC}"
tmux new-session -d -s "$repo_name" -c "$selected" -n "nvim"

# Start nvim in the first window
tmux send-keys -t "$repo_name:0" "nvim" C-m

# Create and name additional windows
tmux new-window -t "$repo_name:1" -c "$selected" -n "server"
tmux new-window -t "$repo_name:2" -c "$selected" -n "term"

# Switch back to window 0 (nvim) before attaching
tmux select-window -t "$repo_name:0"

# Attach to the session
echo -e "${GREEN}Attaching to session: ${BOLD}$repo_name${NC}"
tmux attach-session -t "$repo_name"
