# SSH Connection Manager

## Version: 0.0.6

### Description

The SSH Connection Manager is a simple and efficient shell script to manage and add SSH connections. It allows you to select from pre-configured servers, add new servers, and scan your bash history for SSH connections to offer saving them.

### Features

- **Select SSH Server:** Choose from a list of pre-configured servers to connect to.
- **Add New Server:** Easily add new SSH connection details and save them to the configuration file.
- **Scan Bash History:** Scan your bash history for SSH connections and offer to save any new ones.
- **Connection Timeout:** Set a timeout for SSH connections to reduce delays when an IP address is not responding. Run the Script with the `--set-timeout` Flag
```
./connect.sh --set-timeout
```


## Installation

1.  **Download the script:**

    ```bash
    wget https://github.com/chevybowtie/SSH-Connection-Manager/blob/master/connect.sh  
    ```

2.  **Make the script executable:**

    ```bash
    chmod +x ssh_connection_manager.sh
    ```

3.  **Move the script to a directory in your PATH (optional):**

    ```bash
    sudo mv ssh_connection_manager.sh /usr/local/bin/
    ```





## Setting Up SSH Configuration

1. **Create your personal `config.json` file**:

   The configuration file is located in `~/.config/ssh_connection_manager/config.json`. If it doesn't exist, the script will create it for you.

    Note: A sanitized example configuration is provided as `sample.config.json` in this repository. After installing, you can copy it into place and edit it with your own server names and connection details:

    ```bash
    mkdir -p ~/.config/ssh_connection_manager
    cp sample.config.json ~/.config/ssh_connection_manager/config.json
    ```

2. **Edit `config.json`**:

   Open `~/.config/ssh_connection_manager/config.json` and add your server details in the following format:

   ```json
   {
       "Category1": {
           "ServerName1": "user@hostname1",
           "ServerName2": "user@ip-address"
       },
       "Category2": {
           "ServerName3": "user@hostname2"
       }
   }
   ```
   

### TODO
* Multiple Config Files: Allow the script to manage multiple configuration files, enabling users to switch between different sets of server connections (e.g., `config_home.json`, `config_work.json`).
* Search and Filter: Implement a search and filter functionality within the menu to quickly find specific servers based on keywords or tags.
* Edit Existing Connections: Provide an option to edit existing server connections in the configuration file directly from the script.
* Convert to a numbered menu instead of arrow key navigation.


### Contributions

Contributions are welcome! If you have ideas for new features or improvements, feel free to open an issue or submit a pull request.

### License

This project is licensed under the MIT License. See the LICENSE file for more details.

### Dependencies

This script requires the following tools to be installed on your system:

- **jq**: A lightweight and flexible command-line JSON processor. Used for parsing and manipulating the `config.json` file.
- **ssh**: The OpenSSH client for establishing SSH connections.
- **awk**: A text processing tool used for parsing and extracting data from strings.

Ensure these tools are installed and available in your system's PATH before running the script.

