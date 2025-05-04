#!/usr/bin/env bash

# Script to find git repositories in the current directory tree,
# present them as a selection menu, and create a tmux session with 3 windows
#
# Flags:
#   -a   Attach to existing session without prompting
#   -k   Kill existing session and create new one without prompting

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

# Interactive menu function for selecting options
show_menu() {
  local prompt="$1"
  shift
  local options=("$@")
  local selection

  # Check if we have fzf for a nice menu
  if command -v fzf &>/dev/null; then
    # Create a temporary file for the formatted options
    local temp_file=$(mktemp)

    # Build options with numbers and colors
    for i in "${!options[@]}"; do
      printf "${CYAN}%2d${NC}) ${options[$i]}\n" $((i + 1)) >>"$temp_file"
    done

    # Clear screen before showing fzf menu
    clear

    # Use fzf for interactive selection with the file as input
    selection=$(cat "$temp_file" | fzf --ansi --prompt="$prompt " \
      --header="Use arrow keys to navigate, Enter to select" \
      --layout=reverse --border rounded --margin=1,2 \
      --color=bg:#1e1e1e,bg+:#303030,fg:#d0d0d0,fg+:#ffffff,border:#4b5263 \
      --color=info:#98c379,prompt:#61afef,pointer:#e06c75,marker:#e5c07b,header:#61afef |
      sed -E 's/^[[:space:]]*[0-9]+\) //')

    # Clean up temporary file
    rm -f "$temp_file"

    if [ -n "$selection" ]; then
      echo "$selection"
      return 0
    fi

  else
    # Fall back to a prettier select menu
    echo -e "${BOLD}${BLUE}$prompt${NC}"
    echo -e "${YELLOW}───────────────────────────────────${NC}"

    PS3="$(echo -e "${BOLD}Enter your choice [1-${#options[@]}]:${NC} ")"
    select choice in "${options[@]}"; do
      if [ -n "$choice" ]; then
        echo "$choice"
        return 0
      else
        echo -e "${RED}Invalid selection. Please try again.${NC}"
      fi
    done
  fi

  return 1
}

# Function to check and offer to install dependencies
check_and_install_dependency() {
  local dep=$1
  local install_cmd=$2

  if ! command -v "$dep" &>/dev/null; then
    echo -e "${YELLOW}$dep is not installed.${NC}"
    read -p "Would you like to install $dep now? [y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo -e "${CYAN}Installing $dep...${NC}"
      if eval "$install_cmd"; then
        echo -e "${GREEN}$dep has been successfully installed.${NC}"
      else
        echo -e "${RED}Failed to install $dep. Please install it manually.${NC}"
        exit 1
      fi
    else
      echo -e "${RED}$dep is required for this script to work. Exiting.${NC}"
      exit 1
    fi
  fi
}

# Detect package manager
get_package_manager() {
  if command -v apt &>/dev/null; then
    echo "sudo apt update && sudo apt install -y"
  elif command -v dnf &>/dev/null; then
    echo "sudo dnf install -y"
  elif command -v yum &>/dev/null; then
    echo "sudo yum install -y"
  elif command -v pacman &>/dev/null; then
    echo "sudo pacman -S --noconfirm"
  elif command -v zypper &>/dev/null; then
    echo "sudo zypper install -y"
  elif command -v brew &>/dev/null; then
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
if ! command -v fzf &>/dev/null; then
  echo -e "${YELLOW}fzf is not installed.${NC}"
  echo -e "${CYAN}fzf provides a better selection interface but is not required.${NC}"

  if [ -n "$PKG_MGR" ]; then
    read -p "Would you like to install fzf for a better experience? [y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo -e "${CYAN}Installing fzf...${NC}"
      if eval "$PKG_MGR fzf"; then
        echo -e "${GREEN}fzf has been successfully installed.${NC}"
      else
        echo -e "${YELLOW}Failed to install fzf. Will continue with basic selection menu.${NC}"
      fi
    else
      echo -e "${BLUE}Continuing with basic selection menu...${NC}"
    fi
  fi
fi

# Process flags
attach_flag=false
kill_flag=false

while getopts "ak" opt; do
  case $opt in
  a) attach_flag=true ;;
  k) kill_flag=true ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Shift to remove processed flags
shift $((OPTIND - 1))

selected=""

# Check if a directory name was provided as an argument
if [ $# -eq 1 ]; then
  # First, check exact match
  if [ -d "./$1" ] && is_git_repo "./$1"; then
    selected="./$1"
  else
    # Try to find directories that match the input
    matching_repos=$(find . -type d -path "*$1*" -not -path "*/\.*" | grep -v "node_modules" | while read dir; do
      if is_git_repo "$dir"; then
        echo "$dir"
      fi
    done)

    # If exactly one match is found, use it
    match_count=$(echo "$matching_repos" | grep -v '^$' | wc -l)
    if [ "$match_count" -eq 1 ]; then
      selected=$matching_repos
      echo "Found matching repository: $selected"
    elif [ "$match_count" -gt 1 ]; then
      echo "Multiple matching repositories found:"
      matching_repos_array=()
      while IFS= read -r repo; do
        [ -n "$repo" ] && matching_repos_array+=("$repo")
      done <<<"$matching_repos"

      if [ ${#matching_repos_array[@]} -gt 0 ]; then
        selected=$(show_menu "Select a repository:" "${matching_repos_array[@]}")
        # If a repository was selected, we're done
        if [ -n "$selected" ]; then
          echo "Selected repository: $selected"
        fi
      fi
    else
      # No matching repositories found
      echo -e "${YELLOW}No matching git repository found for '${BOLD}$1${NC}${YELLOW}'.${NC}"
      echo -e "${CYAN}Would you like to:${NC}"
      options=("Clone a git repository with this name" "Continue with repository selection" "Exit")
      choice=$(show_menu "Choose an option:" "${options[@]}")

      if [[ "$choice" == "Clone a git repository with this name" ]]; then
        read -p "Enter the git repository URL: " repo_url
        read -p "Enter the directory to clone into [$(pwd)]: " clone_dir
        clone_dir=${clone_dir:-$(pwd)}
        read -p "Enter the directory name for the repository [$1]: " dir_name
        dir_name=${dir_name:-$1}

        mkdir -p "$clone_dir"
        if git clone "$repo_url" "$clone_dir/$dir_name"; then
          selected="$clone_dir/$dir_name"
          echo "Successfully cloned repository to $selected"
        else
          echo -e "${RED}Failed to clone repository. Exiting.${NC}"
          exit 1
        fi
      elif [[ "$choice" == "Exit" ]]; then
        echo -e "${YELLOW}Exiting sessionizer.${NC}"
        exit 0
      else
        echo -e "${BLUE}Continuing with repository selection...${NC}"
      fi
    fi
  fi
fi

# If no directory was provided or no match was found and user didn't clone
if [ -z "$selected" ]; then
  # Find git repositories
  repos=$(find_git_repos)

  if [ -z "$repos" ]; then
    echo "No git repositories found in the current directory tree."
    exit 1
  fi

  repos_array=()
  while IFS= read -r repo; do
    [ -n "$repo" ] && repos_array+=("$repo")
  done <<<"$repos"

  if [ ${#repos_array[@]} -gt 0 ]; then
    selected=$(show_menu "Select a repository:" "${repos_array[@]}")
  fi

  # Exit if no repository was selected
  if [ -z "$selected" ]; then
    echo "No repository selected. Exiting."
    exit 0
  fi
fi

# Get the basename of the repository for the session name
repo_name=$(basename "$selected")

# Check if a session with this name already exists
if tmux has-session -t "$repo_name" 2>/dev/null; then
  if $attach_flag; then
    # Auto-attach to existing session
    tmux attach-session -t "$repo_name"
    exit 0
  elif $kill_flag; then
    # Auto-kill existing session
    tmux kill-session -t "$repo_name"
    echo "Killed existing session. Creating new session..."
    # Continue with the script to create a new session
  else
    echo -e "${YELLOW}Session '${BOLD}$repo_name${NC}${YELLOW}' already exists.${NC}"

    options=(
      "Attach to existing session"
      "Kill and create new session"
      "Cancel"
    )

    choice=$(show_menu "What would you like to do?" "${options[@]}")

    case "$choice" in
    "Attach to existing session")
      # Attach to existing session
      tmux attach-session -t "$repo_name"
      exit 0
      ;;
    "Kill and create new session")
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
