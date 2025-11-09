# Minecraft Bedrock Server Updater

This repository contains a robust and idempotent Bash script designed to automate the update process for a Minecraft Bedrock dedicated server running on a Linux system and managed by Supervisor.

## Features

- **Automated Version Check:** Automatically fetches the latest stable download URL for the Minecraft Bedrock server.
- **Idempotent:** Ensures that the server is only updated when a new version is available.
- **Graceful Shutdown & Restart:** Integrates with `supervisorctl` to stop the server before updating and restart it afterward.
- **Critical File Backup:** Automatically backs up essential server files (worlds, `server.properties`, `permissions.json`, `allowlist.json`) before an update.
- **File Restoration:** Restores critical files after the new server version is extracted.
- **Dependency Check:** Verifies the presence of necessary tools (`curl`, `jq`, `unzip`, `wget`, `sudo`, `supervisorctl`).

## How it Works

The script performs the following steps:
1.  **Configuration:** Sets up paths for the server directory, backup directory, and Supervisor service name.
2.  **Dependency Check:** Ensures all required command-line tools are installed.
3.  **Get Latest URL:** Fetches the download URL for the latest stable Linux Bedrock server from Minecraft's official services.
4.  **Version Check:** Compares the newly fetched URL with the currently installed version. If they match, the script exits, indicating no update is needed.
5.  **Server Shutdown:** Stops the Minecraft server using `sudo supervisorctl stop`. The script waits for the server to fully stop.
6.  **Backup Critical Files:** Creates a timestamped backup of specified critical files and directories.
7.  **Download and Extract:** Downloads the new server `.zip` file and extracts its contents into the server directory.
8.  **Restore Critical Files:** Copies the backed-up critical files back into the updated server directory.
9.  **Update Version File:** Stores the new download URL to prevent unnecessary updates in the future.
10. **Restart Server:** Starts the Minecraft server using `sudo supervisorctl start`. The script waits for the server to start.

## Setup and Usage

### Prerequisites

-   A Linux system with a Minecraft Bedrock dedicated server installed.
-   `supervisor` installed and configured to manage your Minecraft server.
-   The following command-line tools: `curl`, `jq`, `unzip`, `wget`, `sudo`.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ic3land3r/Minecraft-server-updater.git
    cd Minecraft-server-updater
    ```
2.  **Place the script:** Move `update_bedrock.sh` to a suitable location on your server (e.g., `/usr/local/bin/` or `/home/mcserver/`).
3.  **Configure the script:** Open `update_bedrock.sh` and adjust the `SERVER_DIR`, `BACKUP_DIR`, and `SERVER_SERVICE_NAME` variables to match your setup.
    ```bash
    # === 1. CONFIGURATION ===
    SERVER_DIR="/home/mcserver/minecraft_bedrock" # Your server installation directory
    BACKUP_DIR="/home/mcserver/backups"           # Directory for backups
    SERVER_SERVICE_NAME="minecraft-bedrock-server" # The supervisord program name
    ```
4.  **Make it executable:**
    ```bash
    chmod +x /path/to/your/update_bedrock.sh
    ```

### Running the Script

To run the script manually:

```bash
sudo /path/to/your/update_bedrock.sh
```

### Automation (e.g., with Cron)

You can automate the script to run periodically using `cron`.

1.  Open your crontab for editing:
    ```bash
    sudo crontab -e
    ```
2.  Add a line to run the script at your desired interval. For example, to run it daily at 3:00 AM:
    ```cron
    0 3 * * * /path/to/your/update_bedrock.sh >> /var/log/minecraft_update.log 2>&1
    ```
    *Remember to replace `/path/to/your/update_bedrock.sh` with the actual path to your script.*
    *The `>> /var/log/minecraft_update.log 2>&1` part redirects all output (stdout and stderr) to a log file, which is useful for debugging.*

## Troubleshooting

-   **"Permission denied" errors:** Ensure the script is executable (`chmod +x`) and that you are running it with `sudo`. Also, verify that the user running the script (or `mcserver` user if configured in Supervisor) has appropriate write permissions to `SERVER_DIR` and `BACKUP_DIR`.
-   **"Failed to stop server" / "Failed to start server" errors:**
    -   Check your Supervisor configuration (`/etc/supervisor/conf.d/minecraft_bedrock.conf`) to ensure the `command`, `directory`, and `user` settings are correct.
    -   Verify that the `SERVER_SERVICE_NAME` in the script matches the program name in your Supervisor config (e.g., `[program:minecraft-bedrock-server]`).
    -   Manually check Supervisor status: `sudo supervisorctl status`.
-   **`jq` or `curl` not found:** Install missing dependencies (e.g., `sudo apt install jq curl` on Debian/Ubuntu).

## License

This project is open-source and available under the [MIT License](LICENSE).
