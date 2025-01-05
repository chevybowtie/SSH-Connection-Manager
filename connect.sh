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
SSH_TIMEOUT=5  # Set timeout to 5 seconds (adjust as needed)
VERSION=0.0.1

function display_menu {
    echo "Select a server to connect to:"
    declare -A servers
    index=1

    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            server_name="${BASH_REMATCH[1]}"
            connection_details="${BASH_REMATCH[2]}"
            servers[$index]="$connection_details"
            echo "$index) $server_name"
            index=$((index + 1))
        fi
    done < "$CONFIG_FILE"

    echo "A) Add a new server"
    echo "B) Scan bash history for SSH connections"
    echo "Enter your choice: "
    read choice

    if [[ "$choice" == "A" || "$choice" == "a" ]]; then
        connect_new_server
    elif [[ "$choice" == "B" || "$choice" == "b" ]]; then
        scan_bash_history
    elif [[ ! -z "${servers[$choice]}" ]]; then
        ssh -o ConnectTimeout=$SSH_TIMEOUT ${servers[$choice]}
    else
        echo "Invalid choice!"
    fi
}

function connect_new_server {
    echo "Enter the connection details (e.g., user@hostname): "
    read new_server
    ssh -o ConnectTimeout=$SSH_TIMEOUT $new_server

    if [ $? -eq 0 ]; then
        echo "Connection successful! Would you like to save this connection? (y/n)"
        read save_choice
        if [ "$save_choice" == "y" ]; then
            echo "Enter a name for this connection: "
            read new_server_name
            echo "$new_server_name=$new_server" >> "$CONFIG_FILE"
            echo "Connection saved."
        else
            echo "Connection not saved."
        fi
    else
        echo "Connection failed."
    fi
}

function scan_bash_history {
    unique_connections=$(strings "$HISTORY_FILE" | grep -E "^ssh [^ ]+@[^ ]+" | awk '{print $2}' | sort -u)

    # Read existing connections from the config file
    declare -A existing_connections
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            connection_details="${BASH_REMATCH[2]}"
            existing_connections["$connection_details"]=1
        fi
    done < "$CONFIG_FILE"

    echo "Scanning bash history for SSH connections..."
    for connection in $unique_connections; do
        echo "Found connection: $connection"
        # Skip if the connection is already in the config file
        if [[ -n "${existing_connections[$connection]}" ]]; then
            echo "Skipping already existing connection: $connection"
            continue
        fi

        echo "Attempting to connect to $connection..."
        ssh -o ConnectTimeout=$SSH_TIMEOUT $connection

        if [ $? -eq 0 ]; then
            echo "Connection to $connection successful! Would you like to save this connection? (y/n)"
            read save_choice
            if [ "$save_choice" == "y" ]; then
                echo "Enter a name for this connection: "
                read new_server_name
                echo "$new_server_name=$connection" >> "$CONFIG_FILE"
                echo "Connection saved."
            else
                echo "Connection not saved."
            fi
        else
            echo "Connection to $connection failed."
        fi
    done

    echo "Finished scanning and processing bash history."
}

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    touch "$CONFIG_FILE"
    echo "Config file not found! A new one has been created at $CONFIG_FILE. Please add your server details."
    exit 1
fi

display_menu
