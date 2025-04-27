#!/bin/bash

# This script is an SSH connection manager that allows the user to easily connect to and manage SSH connections. 
# It provides the following features:
# 1. Displays a menu of saved SSH connections from a configuration file (`ssh_config.txt`).
# 2. Allows the user to add new SSH connections and save them with a custom name for future use.
# 3. Scans the user's bash history for previously used SSH connections and offers to save them if they are successful.
# 4. Automatically creates a configuration directory and file if they do not exist.
#
# Connection details are saved in the user's home directory under `.ssh_connection_manager/ssh_config.txt`,
# and the script uses a simple key-value format to store server names and connection details.


CONFIG_DIR="$HOME/.ssh_connection_manager"
CONFIG_FILE="$CONFIG_DIR/ssh_config.txt"
HISTORY_FILE="$HOME/.bash_history"
SSH_TIMEOUT=5  # Timeout for SSH connections in seconds
VERSION=0.0.2  # Script version
LOG_FILE="$CONFIG_DIR/ssh_manager.log"
CONFIG_DIR="$HOME/.ssh_connection_manager"
CONFIG_FILE="$CONFIG_DIR/ssh_config.txt"
SSH_TIMEOUT=5  # Set timeout to 5 seconds
VERSION=0.0.4

# ANSI color codes
RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
CYAN='\033[36m'
YELLOW='\033[33m'
RESET='\033[0m'

# Add logging for errors and actions
function log {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Script started."

# Check if required commands are available
for cmd in ssh grep awk sort mktemp; do
    if ! command -v $cmd &> /dev/null; then
        log "Error: Required command '$cmd' is not installed."
        echo "Error: Required command '$cmd' is not installed. Please install it and try again."
        exit 1
    fi
done

# Display version information if the --version flag is passed
if [[ "$1" == "--version" ]]; then
    echo "SSH Connection Manager, version $VERSION"
    exit 0
fi

# Allow user to configure SSH timeout dynamically
if [[ "$1" == "--set-timeout" ]]; then
    echo "Enter new SSH timeout (in seconds): "
    read new_timeout
    if [[ "$new_timeout" =~ ^[0-9]+$ ]]; then
        SSH_TIMEOUT=$new_timeout
        echo "SSH timeout updated to $SSH_TIMEOUT seconds."
        log "SSH timeout updated to $SSH_TIMEOUT seconds."
    else
        echo "Invalid timeout value. Please enter a positive integer."
        log "Invalid timeout value entered: $new_timeout."
    fi
    exit 0
fi

# Validate user input for server name and connection details
function validate_input {
    local input="$1"
    if [[ -z "$input" || "$input" =~ [^a-zA-Z0-9@._-] ]]; then
        echo "Invalid input. Please use only alphanumeric characters, '@', '.', '_', or '-'."
        return 1
    fi
    return 0
}

# Function to display the main menu and handle user input
function display_menu {
    declare -A categories
    declare -A entries
    index=1

    echo -e "${CYAN}========================================${RESET}"
    echo -e "${CYAN}       SSH Connection Manager v$VERSION       ${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Parse the configuration file
    while IFS= read -r line; do
        category=$(echo "$line" | grep -oP "^\(\K[^)]+(?=\))")
        entry_name=$(echo "$line" | awk -F'[)=]' '{print $2}' | xargs)
        connection_details=$(echo "$line" | awk -F'=' '{print $2}')
        
        if [[ -n "$category" && -n "$entry_name" && -n "$connection_details" ]]; then
            categories["$category"]=1
            entries["$category,$entry_name"]="$connection_details"
        fi
    done < "$CONFIG_FILE"

    # Dynamic menu navigation
    local options=("${!categories[@]}" "Utility menu" "Cancel and exit")
    local current_index=0

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${CYAN}       SSH Connection Manager v$VERSION       ${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select:${RESET}"

        # Display the menu options with highlights
        for i in "${!options[@]}"; do
            if [[ "$i" == "$current_index" ]]; then
                echo -e "${GREEN} > ${options[$i]}${RESET}"
            else
                echo "   ${options[$i]}"
            fi
        done

        # Read user input
        read -s -n 1 key
        case "$key" in
        $'\x1b')  # Handle arrow keys
            read -s -n 2 key
            case "$key" in
            "[A")  # Up arrow
                ((current_index--))
                if [[ "$current_index" -lt 0 ]]; then
                    current_index=$((${#options[@]} - 1))
                fi
                ;;
            "[B")  # Down arrow
                ((current_index++))
                if [[ "$current_index" -ge "${#options[@]}" ]]; then
                    current_index=0
                fi
                ;;
            esac
            ;;
        "")  # Enter key
            if [[ "$current_index" -lt $((${#options[@]} - 2)) ]]; then
                display_entries "${options[$current_index]}"
            elif [[ "${options[$current_index]}" == "Utility menu" ]]; then
                utility_menu
            elif [[ "${options[$current_index]}" == "Cancel and exit" ]]; then
                echo -e "${RED}Exiting. Goodbye!${RESET}"
                exit 0
            fi
            ;;
        esac
    done
}


function utility_menu {
    local options=("Add a new server" "Delete a server" "Back to main menu")
    local current_index=0

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${BLUE}          Utility Menu                  ${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select:${RESET}"

        # Display the menu options with highlights
        for i in "${!options[@]}"; do
            if [[ "$i" == "$current_index" ]]; then
                echo -e "${GREEN} > ${options[$i]}${RESET}"
            else
                echo "   ${options[$i]}"
            fi
        done

        # Read user input
        read -s -n 1 key
        case "$key" in
        $'\x1b')  # Handle arrow keys
            read -s -n 2 key
            case "$key" in
            "[A")  # Up arrow
                ((current_index--))
                if [[ "$current_index" -lt 0 ]]; then
                    current_index=$((${#options[@]} - 1))
                fi
                ;;
            "[B")  # Down arrow
                ((current_index++))
                if [[ "$current_index" -ge "${#options[@]}" ]]; then
                    current_index=0
                fi
                ;;
            esac
            ;;
        "")  # Enter key
            if [[ "${options[$current_index]}" == "Add a new server" ]]; then
                add_server
            elif [[ "${options[$current_index]}" == "Delete a server" ]]; then
                delete_server
            elif [[ "${options[$current_index]}" == "Back to main menu" ]]; then
                display_menu
            fi
            ;;
        esac
    done
}


function add_server {
    echo -e "${CYAN}Enter the category for this server (e.g., 'lan' or 'Azure'): ${RESET}"
    read new_category
    echo -e "${CYAN}Enter a name for this server (e.g., 'MyServer'): ${RESET}"
    read new_server_name
    echo -e "${CYAN}Enter the connection details (e.g., user@hostname): ${RESET}"
    read new_connection_details

    if [[ -z "$new_category" || -z "$new_server_name" || -z "$new_connection_details" ]]; then
        echo -e "${RED}Invalid input. All fields are required!${RESET}"
        return
    fi

    # Add the new server to the config file
    echo "(${new_category}) $new_server_name=$new_connection_details" >> "$CONFIG_FILE"
    echo -e "${GREEN}Server added successfully!${RESET}"
}


function delete_server {
    declare -A entries
    index=1

    echo -e "${CYAN}========================================${RESET}"
    echo -e "${BLUE}         Delete a Server                ${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Parse the configuration file
    while IFS= read -r line; do
        category=$(echo "$line" | grep -o "^\([^)]*\)" | tr -d '()')
        entry_name=$(echo "$line" | awk -F'[)=]' '{print $2}' | xargs)
        connection_details=$(echo "$line" | awk -F'=' '{print $2}')

        if [[ -n "$category" && -n "$entry_name" && -n "$connection_details" ]]; then
            entries["$index"]="$line"
            echo -e "${CYAN}$index) (${category}) $entry_name${RESET}"
            index=$((index + 1))
        fi
    done < "$CONFIG_FILE"

    echo -e "${YELLOW}Enter the number of the server to delete (or B to go back): ${RESET}"
    read delete_choice

    if [[ "$delete_choice" == "B" || "$delete_choice" == "b" ]]; then
        utility_menu
    elif [[ -n "${entries[$delete_choice]}" ]]; then
        # Use the exact line content to delete the entry
        line_to_delete="${entries[$delete_choice]}"
        # Portable sed command for in-place editing
        sed "/$(echo "$line_to_delete" | sed 's/[\/&]/\\&/g')/d" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${GREEN}Server deleted successfully!${RESET}"
    else
        echo -e "${RED}Invalid choice!${RESET}"
    fi
}


function display_entries {
    local selected_category="$1"
    local entry_keys=( )
    local entry_index=0

    # Collect entries for the selected category
    for key in "${!entries[@]}"; do
        IFS=',' read -r category entry_name <<< "$key"
        if [[ "$category" == "$selected_category" ]]; then
            entry_keys+=("$key")
        fi
    done

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${BLUE}  Entries in category: ${selected_category}${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select, or B to go back:${RESET}"

        for i in "${!entry_keys[@]}"; do
            if [[ "$i" == "$entry_index" ]]; then
                IFS=',' read -r _ entry_name <<< "${entry_keys[$i]}"
                echo -e "${GREEN} > $entry_name${RESET}"
            else
                IFS=',' read -r _ entry_name <<< "${entry_keys[$i]}"
                echo "   $entry_name"
            fi
        done

        # Read user input
        read -s -n 1 key
        case "$key" in
        $'\x1b')  # Handle arrow keys
            read -s -n 2 key
            case "$key" in
            "[A")  # Up arrow
                ((entry_index--))
                if [[ "$entry_index" -lt 0 ]]; then
                    entry_index=$((${#entry_keys[@]} - 1))
                fi
                ;;
            "[B")  # Down arrow
                ((entry_index++))
                if [[ "$entry_index" -ge "${#entry_keys[@]}" ]]; then
                    entry_index=0
                fi
                ;;
            esac
            ;;
        "")  # Enter key
            if [[ -n "${entry_keys[$entry_index]}" ]]; then
                ssh -o ConnectTimeout=$SSH_TIMEOUT "${entries[${entry_keys[$entry_index]}]}"
                return
            fi
            ;;
        "B"|"b")  # Back to categories
            return
            ;;
        esac
    done
}


function navigate_menu {
    local options=("$@")  # Capture all arguments as an array
    local prompt="${options[0]}"  # First argument is the prompt
    unset options[0]  # Remove the prompt from the options array
    options=("${options[@]}")  # Re-index the array
    local current_index=0

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${BLUE}$prompt${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select:${RESET}"

        for i in "${!options[@]}"; do
            if [[ "$i" == "$current_index" ]]; then
                echo -e "${GREEN} > ${options[$i]}${RESET}"
            else
                echo "   ${options[$i]}"
            fi
        done

        # Read user input
        read -s -n 1 key
        case "$key" in
        $'\x1b')  # Handle arrow keys
            read -s -n 2 key
            case "$key" in
            "[A")  # Up arrow
                ((current_index--))
                if [[ "$current_index" -lt 0 ]]; then
                    current_index=$((${#options[@]} - 1))
                fi
                ;;
            "[B")  # Down arrow
                ((current_index++))
                if [[ "$current_index" -ge "${#options[@]}" ]]; then
                    current_index=0
                fi
                ;;
            esac
            ;;
        "")  # Enter key
            return "$current_index"
            ;;
        esac
    done
}


function check_required_tools {
    local missing_tools=()
    for tool in grep awk sed ssh; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Error: The following required tools are missing:${RESET}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED} - $tool${RESET}"
        done
        echo -e "${YELLOW}Please install the missing tools and try again.${RESET}"
        exit 1
    fi
}


if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    touch "$CONFIG_FILE"
    echo -e "${GREEN}Config file not found! A new one has been created at $CONFIG_FILE.${RESET}"
    exit 1
fi

check_required_tools

display_menu
