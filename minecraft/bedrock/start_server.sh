#!/bin/bash
# Entry point for starting the minecraft server

# set -o errexit

# Print out some info
echo "Release notes:"
cat release-notes.txt
echo -e "\n"

# Collect environment variables (key = env var, value = minecraft name)
declare -A PROPERTIES
PROPERTIES[SERVER_NAME]='server-name'
PROPERTIES[GAMEMODE]='gamemode'
PROPERTIES[LEVEL_NAME]='level-name'
PROPERTIES[DIFFICULTY]='difficulty'
PROPERTIES[MAX_PLAYERS]='max-players'
PROPERTIES[ALLOW_FLIGHT]='allow-flight'
PROPERTIES[VIEW_DISTANCE]='view-distance'
PROPERTIES[PLAYER_IDLE_TIMEOUT]='player-idle-timeout'
PROPERTIES[ALLOW_LIST]='allow-list'
PROPERTIES[CHAT_RESTRICTION]='chat-restriction'
PROPERTIES[DEFAULT_PLAYER_PERMISSION_LEVEL]='default-player-permission-level'

# Wipe the server.properties file and re-write it with any overrides found in environment variables
echo '' > server.properties
for key in "${!PROPERTIES[@]}"; do
    # Check if environment variable is set
    if [[ -n "${!key}" ]]; then
        echo "${PROPERTIES[$key]}=${!key}" >> server.properties
    fi
done
# Override the server port to be inline with the Java version
echo "server-port=25565" >> server.properties
# Disable server telemetry
echo "emit-server-telemetry=false" >> server.properties

# Display current server.properties
echo -e "Server properties:\n"
cat server.properties
echo -e "\n"

# Start the server
cd /minecraft
echo -e "Starting server...\n"
LD_LIBRARY_PATH=. ./bedrock_server
