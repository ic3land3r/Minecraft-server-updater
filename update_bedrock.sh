#!/bin/bash
# A robust, idempotent script to update a Minecraft Bedrock server
set -eu # Strict mode. 'set -e' is from. 

# === 1. CONFIGURATION ===
# Set paths: Server install, backups, and the service name
SERVER_DIR="/home/mcserver/minecraft_bedrock"
BACKUP_DIR="/home/mcserver/backups"
SERVER_SERVICE_NAME="minecraft-bedrock-server" # The supervisord program name
VERSION_FILE="$SERVER_DIR/current_version_url.txt"
# Files to preserve during an update [11, 12, 13]
PRESERVE_FILES=("worlds" "server.properties" "permissions.json" "allowlist.json")

echo "Starting Bedrock Server update check..."
mkdir -p "$SERVER_DIR" "$BACKUP_DIR" # Ensure directories exist
cd "$SERVER_DIR" || exit 1

# === 2. DEPENDENCY CHECK  ===
for CMD in curl jq unzip wget sudo supervisorctl; do
  if [ ! -x "$(command -v "$CMD")" ]; then
    echo "ERROR: Required command '$CMD' is not installed." >&2
    exit 1
  fi
done

# === 3. GET LATEST STABLE URL (from Section 3) ===
echo "Fetching latest stable download URL..."
DOWNLOAD_URL=$(curl -sS -A "BEDROCK-UPDATER-SCRIPT" \
  "https://net-secondary.web.minecraft-services.net/api/v1.0/download/links" | \
  jq -r '.result.links[] | select(.downloadType=="serverBedrockLinux") | .downloadUrl')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "ERROR: Failed to retrieve download URL." >&2
  exit 1
fi

# === 4. VERSION CHECK  ===
touch "$VERSION_FILE" # Ensure file exists
CURRENT_URL=$(cat "$VERSION_FILE")

if [ "$DOWNLOAD_URL" == "$CURRENT_URL" ]; then
  echo "Server is already up to date. No action taken."
  exit 0
fi
echo "New version found. Proceeding with update."
echo "  Old: $CURRENT_URL"
echo "  New: $DOWNLOAD_URL"

# === 5. SERVER SHUTDOWN [12, 17] ===
echo "Stopping Minecraft server: $SERVER_SERVICE_NAME"
sudo supervisorctl stop "$SERVER_SERVICE_NAME"
# Wait for the server to stop
for i in {1..10}; do
  if sudo supervisorctl status "$SERVER_SERVICE_NAME" | grep -q -E "STOPPED|EXITED"; then
    break
  fi
  sleep 1
done

if ! sudo supervisorctl status "$SERVER_SERVICE_NAME" | grep -q -E "STOPPED|EXITED"; then
    echo "ERROR: Failed to stop server. Aborting update." >&2
    exit 1
fi
echo "Server stopped."

# === 6. BACKUP CRITICAL FILES [11, 12, 13] ===
echo "Backing up critical files..."
BACKUP_TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/bedrock-backup-$BACKUP_TIMESTAMP"
mkdir -p "$BACKUP_PATH"

for FILE in "${PRESERVE_FILES[@]}"; do
  if [ -e "$FILE" ]; then
    cp -r "$FILE" "$BACKUP_PATH/"
  fi
done
echo "Backup complete: $BACKUP_PATH"

# === 7. DOWNLOAD AND EXTRACT  ===
echo "Downloading new server version from $DOWNLOAD_URL"
# Use a user-agent as a best practice 
wget -O bedrock_server.zip "$DOWNLOAD_URL" -U "BEDROCK-UPDATER"

echo "Extracting server files..."
# Unzip, overwriting old files (-o), quietly (-q)
unzip -o -q bedrock_server.zip -d "$SERVER_DIR"
rm bedrock_server.zip

# === 8. RESTORE CRITICAL FILES  ===
echo "Restoring worlds and configuration..."
for FILE in "${PRESERVE_FILES[@]}"; do
  if [ -e "$BACKUP_PATH/$FILE" ]; then
    cp -r "$BACKUP_PATH/$FILE" "$SERVER_DIR/"
  fi
done

# === 9. UPDATE VERSION FILE  ===
echo "Update complete. Storing new version URL."
echo "$DOWNLOAD_URL" > "$VERSION_FILE"

# === 10. RESTART SERVER [17] ===
echo "Starting Minecraft server: $SERVER_SERVICE_NAME"
sudo supervisorctl start "$SERVER_SERVICE_NAME"
# Wait for the server to start
for i in {1..10}; do
    if sudo supervisorctl status "$SERVER_SERVICE_NAME" | grep -q "RUNNING"; then
        break
    fi
    sleep 1
done

if ! sudo supervisorctl status "$SERVER_SERVICE_NAME" | grep -q "RUNNING"; then
    echo "ERROR: Failed to start server." >&2
    exit 1
fi
echo "Server started."

echo "Bedrock Server update script finished successfully."
exit 0
