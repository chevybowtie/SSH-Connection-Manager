#!/bin/bash

# This script is an SSH connection manager that allows the user to easily connect to and manage SSH connections. 
# It provides the following features:
# 1. Displays a menu of saved SSH connections from a JSON configuration file (`config.json`).
# 2. Allows the user to add new SSH connections and save them with a custom name for future use.
# 3. Scans the user's bash history for previously used SSH connections and offers to save them if they are successful.
# 4. Automatically creates a configuration directory and JSON config if they do not exist.
#
# Connection details are saved in the user's home directory under
# `$XDG_CONFIG_HOME/ssh_connection_manager/config.json` (or `~/.config/ssh_connection_manager/config.json`).
# The script uses JSON and `jq` to manage categories and entries.


CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ssh_connection_manager"
CONFIG_FILE="$CONFIG_DIR/config.json"
HISTORY_FILE="$HOME/.bash_history"
SSH_TIMEOUT=5  # Timeout for SSH connections in seconds
LOG_FILE="$CONFIG_DIR/ssh_manager.log"
VERSION=0.0.6

# ANSI color codes
RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
CYAN='\033[36m'
YELLOW='\033[33m'
RESET='\033[0m'
if [[ ! -t 1 || "$NO_COLOR" == "1" ]]; then
    RED=''
    GREEN=''
    BLUE=''
    CYAN=''
    YELLOW=''
    RESET=''
fi

# Add logging for errors and actions
function log {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Script started."

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
    declare -a categories
    local index=0

    echo -e "${CYAN}========================================${RESET}"
    echo -e "${CYAN}       SSH Connection Manager v$VERSION       ${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Parse the JSON config file to get categories
    while IFS= read -r category; do
        categories["$index"]="$category"
        index=$((index + 1))
    done < <(jq -r 'keys[]' "$CONFIG_FILE")

    # Add Utility menu and Cancel options
    categories["$index"]="Utility menu"
    categories["$((index + 1))"]="Cancel and exit"

    local current_index=0

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${CYAN}       SSH Connection Manager v$VERSION       ${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select, or B to go back:${RESET}"

        # Display the menu options with highlights
        for i in "${!categories[@]}"; do
            if [[ "$i" == "$current_index" ]]; then
                echo -e "${GREEN} > ${categories[$i]}${RESET}"
            else
                echo "   ${categories[$i]}"
            fi
        done

        # Read user input
        read -rsn1 mode
        case $mode in
            '') # Enter pressed
                if [[ "$current_index" -lt $index ]]; then
                    display_entries "${categories[$current_index]}"
                elif [[ "${categories[$current_index]}" == "Utility menu" ]]; then
                    utility_menu
                elif [[ "${categories[$current_index]}" == "Cancel and exit" ]]; then
                    echo -e "${RED}Exiting. Goodbye!${RESET}"
                    exit 0
                fi
                ;;
            $'\e') # Escape sequence
                read -rsn2 mode
                case $mode in
                    '[A') # Up arrow
                        ((current_index--))
                        if [[ "$current_index" -lt 0 ]]; then
                            current_index=$((${#categories[@]} - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((current_index++))
                        if [[ "$current_index" -ge "${#categories[@]}" ]]; then
                            current_index=0
                        fi
                        ;;
                esac
                ;;
            "B"|"b")
                return
                ;;
            *)
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
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select, or B to go back:${RESET}"

        # Display the menu options with highlights
        for i in "${!options[@]}"; do
            if [[ "$i" == "$current_index" ]]; then
                echo -e "${GREEN} > ${options[$i]}${RESET}"
            else
                echo "   ${options[$i]}"
            fi
        done

        # Read user input
        read -rsn1 mode
        case $mode in
            '') # Enter pressed
                if [[ "${options[$current_index]}" == "Add a new server" ]]; then
                    add_server
                elif [[ "${options[$current_index]}" == "Delete a server" ]]; then
                    delete_server
                elif [[ "${options[$current_index]}" == "Back to main menu" ]]; then
                    return
                fi
                ;;
            $'\e') # Escape sequence
                read -rsn2 mode
                case $mode in
                    '[A') # Up arrow
                        ((current_index--))
                        if [[ "$current_index" -lt 0 ]]; then
                            current_index=$((${#options[@]} - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((current_index++))
                        if [[ "$current_index" -ge "${#options[@]}" ]]; then
                            current_index=0
                        fi
                        ;;
                esac
                ;;
            "B"|"b")
                return
                ;;
        esac
    done
}


# Function to add a new server to the JSON config file
function add_server {
    backup_config  # Create a backup before modifying the file

    echo -e "${CYAN}Enter the category for this server (e.g., 'LAN' or 'Azure'): ${RESET}"
    read new_category
    echo -e "${CYAN}Enter a name for this server (e.g., 'MyServer'): ${RESET}"
    read new_server_name
    echo -e "${CYAN}Enter the connection details (e.g., user@hostname): ${RESET}"
    read new_connection_details

    if [[ -z "$new_category" || -z "$new_server_name" || -z "$new_connection_details" ]]; then
        echo -e "${RED}Invalid input. All fields are required!${RESET}"
        log "Failed to add server: Missing required fields."
        return
    fi

    # Add the new server to the JSON config file
    jq --arg category "$new_category" --arg name "$new_server_name" --arg details "$new_connection_details" \
       'if .[$category] == null then .[$category] = {} else . end | .[$category][$name] = $details' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo -e "${GREEN}Server added successfully!${RESET}"
    log "Server added: Category='$new_category', Name='$new_server_name', Details='$new_connection_details'"
}

# Function to delete a server from the JSON config file
function delete_server {
    backup_config  # Create a backup before modifying the file

    declare -a entries
    index=1

    echo -e "${CYAN}========================================${RESET}"
    echo -e "${BLUE}         Delete a Server                ${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Parse the JSON config file
    while IFS= read -r line; do
        category=$(echo "$line" | awk -F'=' '{print $1}')
        entry_name=$(echo "$line" | awk -F'=' '{print $2}')
        entries["$index"]="$category=$entry_name"
        echo -e "${CYAN}$index) ($category) $entry_name${RESET}"
        index=$((index + 1))
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value | keys[])"' "$CONFIG_FILE")

    echo -e "${YELLOW}Enter the number of the server to delete (or B to go back): ${RESET}"
    read delete_choice

    if [[ "$delete_choice" == "B" || "$delete_choice" == "b" ]]; then
        utility_menu
    elif [[ -n "${entries[$delete_choice]}" ]]; then
        category=$(echo "${entries[$delete_choice]}" | awk -F'=' '{print $1}')
        entry_name=$(echo "${entries[$delete_choice]}" | awk -F'=' '{print $2}')

        # Remove the entry from the JSON config file
        jq --arg category "$category" --arg name "$entry_name" 'del(.[$category][$name])' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

        echo -e "${GREEN}Server deleted successfully!${RESET}"
        log "Server deleted: Category='$category', Name='$entry_name'"
    else
        echo -e "${RED}Invalid choice!${RESET}"
        log "Failed to delete server: Invalid choice '$delete_choice'"
    fi
}

# Function to display entries in a category
function display_entries {
    local selected_category="$1"
    local entry_keys=( )
    local entry_index=0

    # Collect entries for the selected category
    mapfile -t entry_keys < <(jq -r --arg category "$selected_category" '.[$category] | keys[]' "$CONFIG_FILE")

    if [[ ${#entry_keys[@]} -eq 0 ]]; then
        echo -e "${RED}No entries found in this category.${RESET}"
        read -n 1 -s -r "Press any key to continue..."
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${BLUE}  Entries in category: ${selected_category}${RESET}"
        echo -e "${CYAN}========================================${RESET}"
        echo -e "${YELLOW}Use arrow keys to navigate, Enter to select, or B to go back:${RESET}"

        for i in "${!entry_keys[@]}"; do
            if [[ "$i" == "$entry_index" ]]; then
                echo -e "${GREEN} > ${entry_keys[$i]}${RESET}"
            else
                echo "   ${entry_keys[$i]}"
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
                local connection_details
                connection_details=$(jq -r --arg category "$selected_category" --arg key "${entry_keys[$entry_index]}" '.[$category][$key]' "$CONFIG_FILE")
                ssh -o ConnectTimeout=$SSH_TIMEOUT "$connection_details"
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}Error: Failed to connect to $connection_details.${RESET}"
                    log "SSH connection failed: $connection_details"
                fi
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
    for tool in jq ssh awk; do  # Added awk to the list of required tools
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Error: The following required tools are missing:${RESET}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED} - $tool${RESET}"
            log "Missing tool: $tool"
        done
        echo -e "${YELLOW}Please install the missing tools and try again.${RESET}"
        exit 1
    fi
}


# Function to create a backup of the configuration file
function backup_config {
    local backup_file="$CONFIG_FILE.bak.$(date '+%Y%m%d%H%M%S')"
    cp "$CONFIG_FILE" "$backup_file"
    echo -e "${GREEN}Backup created: $backup_file${RESET}"
    log "Backup created: $backup_file"
}



# Ensure the configuration directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo -e "${GREEN}Configuration directory created at $CONFIG_DIR.${RESET}"
fi

# Ensure the configuration file exists and is valid JSON
if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
    echo '{}' > "$CONFIG_FILE"
    echo -e "${GREEN}Config file not found or empty! A new one has been initialized at $CONFIG_FILE.${RESET}"
fi

check_required_tools

display_menu
