# SSH Connection Manager

## Version: 0.0.1

### Description

The SSH Connection Manager is a simple and efficient shell script to manage and add SSH connections. It allows you to select from pre-configured servers, add new servers, and scan your bash history for SSH connections to offer saving them.

### Features

- **Select SSH Server:** Choose from a list of pre-configured servers to connect to.
- **Add New Server:** Easily add new SSH connection details and save them to the configuration file.
- **Scan Bash History:** Scan your bash history for SSH connections and offer to save any new ones.
- **Connection Timeout:** Set a timeout for SSH connections to reduce delays when an IP address is not responding.


## Setting Up SSH Configuration

1. **Create your personal `ssh_config.txt` file**:

   The configuration file is located in `~/.ssh_connection_manager/ssh_config.txt`. If it doesn't exist, the script will create it for you.

2. **Edit `ssh_config.txt`**:

   Open `~/.ssh_connection_manager/ssh_config.txt` and add your server details in the following format:

   ```plaintext
   server name1=user@hostname1
   server name2=user@ip-address
   ```



### TODO
* Add stanzas to the config file so you may logically group connections (home, work, projects, etc.)
* Multiple Config Files: Allow the script to manage multiple configuration files, enabling users to switch between different sets of server connections (e.g., `ssh_config_home.txt`, `ssh_config_work.txt`).
* Search and Filter: Implement a search and filter functionality within the menu to quickly find specific servers based on keywords or tags.
* Edit Existing Connections: Provide an option to edit existing server connections in the configuration file directly from the script.
* Backup and Restore: Add a feature to create backups of the configuration file and restore from backups in case of accidental deletions or file corruption.
* Connection Health Check: Include a health check feature that periodically pings or tests connections to ensure servers are reachable.
* User-Friendly Interface: Enhance the script's interface with colored output and more user-friendly prompts to improve the user experience.
* Add more robust error checking


### Contributions

Contributions are welcome! If you have ideas for new features or improvements, feel free to open an issue or submit a pull request.

### License

This project is licensed under the MIT License. See the LICENSE file for more details.

