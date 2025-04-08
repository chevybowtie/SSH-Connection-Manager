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
    echo "Select a server to connect to:"
    servers=()  # Indexed array to store server details
    index=1  # Index for menu options

    # Read saved connections from the configuration file
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            server_name="${BASH_REMATCH[1]}"  # Extract server name
            connection_details="${BASH_REMATCH[2]}"  # Extract connection details
            servers+=("$server_name=$connection_details")  # Store key-value pair
            echo "$index) $server_name"  # Display server name with index
            index=$((index + 1))
        fi
    done < "$CONFIG_FILE"

    # Display additional menu options
    echo "A) Add a new server"
    echo "B) Scan bash history for SSH connections"
    echo "Q) Quit"
    read -p "Enter your choice: " choice

    # Handle user choice
    if [[ "$choice" == "A" || "$choice" == "a" ]]; then
        connect_new_server  # Add a new server
    elif [[ "$choice" == "B" || "$choice" == "b" ]]; then
        scan_bash_history  # Scan bash history for SSH connections
    elif [[ "$choice" == "Q" || "$choice" == "q" ]]; then
        echo "Exiting..."
        exit 0
    elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -le "${#servers[@]}" ]]; then
        connection_details="${servers[$((choice - 1))]#*=}"  # Extract connection details
        ssh -o ConnectTimeout=$SSH_TIMEOUT "$connection_details"  # Connect to the selected server
    else
        echo "Invalid choice!"
    fi
}

# Function to add and save a new SSH connection
function connect_new_server {
    echo "Enter the connection details (e.g., user@hostname): "
    read new_server
    validate_input "$new_server" || return  # Validate input

    ssh -o ConnectTimeout=$SSH_TIMEOUT $new_server  # Attempt to connect

    if [ $? -eq 0 ]; then  # Check if the connection was successful
        echo "Connection successful! Would you like to save this connection? (y/n)"
        read save_choice
        if [ "$save_choice" == "y" ]; then
            echo "Enter a name for this connection: "
            read new_server_name
            validate_input "$new_server_name" || return  # Validate input

            # Check if the server name already exists in the configuration file
            if grep -q "^$new_server_name=" "$CONFIG_FILE"; then
                echo "A connection with this name already exists. Please choose a different name."
                return
            fi

            # Save the new connection to the configuration file
            echo "$new_server_name=$new_server" >> "$CONFIG_FILE" || { log "Failed to save connection."; echo "Failed to save connection."; return; }
            echo "Connection saved."
            log "Connection '$new_server_name' saved successfully."
        else
            echo "Connection not saved."
        fi
    else
        echo "Connection failed."
        log "Connection attempt to '$new_server' failed."
    fi
}

# Function to scan bash history for SSH commands and offer to save them
function scan_bash_history {
    # Dynamically determine the history file location
    if [ -z "$HISTFILE" ]; then
        if [ -f "$HOME/.bash_history" ]; then
            HISTORY_FILE="$HOME/.bash_history"
            log "Using default bash history file at $HISTORY_FILE."
        elif [ -f "$HOME/.zsh_history" ]; then
            HISTORY_FILE="$HOME/.zsh_history"
            log "Using default zsh history file at $HISTORY_FILE."
        else
            echo "No history file found (bash or zsh)."
            log "No history file found (bash or zsh)."
            return
        fi
    else
        HISTORY_FILE="$HISTFILE"
        log "Using history file from HISTFILE environment variable: $HISTORY_FILE."
    fi

    # Extract unique SSH commands from the history file
    unique_connections=$(grep -E "^ssh [^ ]+@[^ ]+" "$HISTORY_FILE" | awk '{print $2}' | sort -u)

    # Read existing connections from the configuration file into an indexed array
    existing_connections=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            connection_details="${BASH_REMATCH[2]}"
            existing_connections+=("$connection_details")
        fi
    done < "$CONFIG_FILE"

    echo "Scanning history file for SSH connections..."
    log "Scanning history file for SSH connections."
    for connection in $unique_connections; do
        echo "Found connection: $connection"
        # Skip if the connection is already saved
        if [[ " ${existing_connections[*]} " == *" $connection "* ]]; then
            echo "Skipping already existing connection: $connection"
            continue
        fi

        # Attempt to connect to the found connection
        echo "Attempting to connect to $connection..."
        ssh -o ConnectTimeout=$SSH_TIMEOUT $connection

        if [ $? -eq 0 ]; then  # Check if the connection was successful
            echo "Connection to $connection successful! Would you like to save this connection? (y/n)"
            read -r save_choice
            if [ "$save_choice" == "y" ]; then
                echo "Enter a name for this connection: "
                read -r new_server_name
                validate_input "$new_server_name" || continue  # Validate input
                echo "$new_server_name=$connection" >> "$CONFIG_FILE" || { log "Failed to save connection '$connection'."; echo "Failed to save connection."; continue; }
                echo "Connection saved."
                log "Connection '$new_server_name' saved successfully."
            else
                echo "Connection not saved."
            fi
        else
            echo "Connection to $connection failed."
            log "Connection attempt to '$connection' failed."
        fi
    done

    echo "Finished scanning and processing history file."
    log "Finished scanning and processing history file."
}

# Ensure the configuration file exists, creating it if necessary
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR" || { log "Failed to create config directory!"; echo "Failed to create config directory!"; exit 1; }
    touch "$CONFIG_FILE" || { log "Failed to create config file!"; echo "Failed to create config file!"; exit 1; }
    chmod 600 "$CONFIG_FILE"  # Restrict access to the config file
    echo "Config file not found! A new one has been created at $CONFIG_FILE. Please add your server details."
    log "Created new config file at $CONFIG_FILE."
    exit 1
fi

chmod 600 "$CONFIG_FILE"  # Restrict access to the config file

# Use `mktemp` for temporary files if needed 
TEMP_FILE=$(mktemp) || { log "Failed to create temporary file."; echo "Failed to create temporary file."; exit 1; }
trap "rm -f $TEMP_FILE" EXIT  # Ensure temporary file is cleaned up

# Display the main menu
display_menu
