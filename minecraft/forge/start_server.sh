#!/bin/bash
# Entry point for starting the minecraft server

# set -o errexit

# Print out the java version
java -version

# Set EULA
echo "eula=$EULA" > eula.txt

# Collect environment variables (key = env var, value = minecraft name)
declare -A PROPERTIES
PROPERTIES[ALLOW_FLIGHT]='allow-flight'
PROPERTIES[ALLOW_NETHER]='allow-nether'
PROPERTIES[DIFFICULTY]='difficulty'
PROPERTIES[ENABLE_COMMAND_BLOCK]='enable-command-block'
PROPERTIES[ENABLE_STATUS]='enable-status'
PROPERTIES[ENABLE_QUERY]='enable-query'
PROPERTIES[ENFORCE_SECURE_PROFILE]='enforce-secure-profile'
PROPERTIES[GAMEMODE]='gamemode'
PROPERTIES[GENERATE_STRUCTURES]='generate-structures'
PROPERTIES[HARDCORE]='hardcore'
PROPERTIES[HIDE_ONLINE_PLAYERS]='hide-online-players'
PROPERTIES[LEVEL_SEED]='level-seed'
PROPERTIES[LEVEL_TYPE]='level-type'
PROPERTIES[MAX_PLAYERS]='max-players'
PROPERTIES[MOTD]='motd'
PROPERTIES[ONLINE_MODE]='online-mode'
PROPERTIES[OP_PERMISSION_LEVEL]='op-permission-level'
PROPERTIES[PLAYER_IDLE_TIMEOUT]='player-idle-timeout'
PROPERTIES[PVP]='pvp'
PROPERTIES[QUERY_PORT]='query.port'
PROPERTIES[RESOURCE_PACK]='resource-pack'
PROPERTIES[RESOURCE_PACK_PROMPT]='resource-pack-prompt'
PROPERTIES[REQUIRE_RESOURCE_PACK]='require-resource-pack'
PROPERTIES[SIMULATION_DISTANCE]='simulation-distance'
PROPERTIES[SPAWN_ANIMALS]='spawn-animals'
PROPERTIES[SPAWN_MONSTERS]='spawn-monsters'
PROPERTIES[SPAWN_NPCS]='spawn-npcs'
PROPERTIES[SPAWN_PROTECTION]='spawn-protection'
PROPERTIES[VIEW_DISTANCE]='view-distance'
PROPERTIES[WHITE_LIST]='white-list'

# Wipe the server.properties file and re-write it with any overrides found in environment variables
echo '' > server.properties
for key in "${!PROPERTIES[@]}"; do
    # Check if environment variable is set
    if [[ -n "${!key}" ]]; then
        echo "${PROPERTIES[$key]}=${!key}" >> server.properties
    fi
done

# Persistent server configuration files (i.e.: whitelist, ops, etc...)
LEGACY_CONFIG_FILES=(
    "white-list.txt" "ops.txt" "banned-players.txt"
)
CONFIG_FILES=(
    "whitelist.json" "ops.json" "banned-players.json"
)
# Create the persistent server configuration file (if they don't exist already)
for file_name in "${LEGACY_CONFIG_FILES[@]}"; do
    touch "/minecraft/configurations/$file_name"
    # Create symlinks to the server persistent configurations
    ln -sf "/minecraft/configurations/$file_name" "/minecraft/$file_name"
done
# Create the persistent server configuration file (if they don't exist already)
for file_name in "${CONFIG_FILES[@]}"; do
    if [[ ! -e "/minecraft/configurations/$file_name" ]]; then
        echo "[]" > "/minecraft/configurations/$file_name"
    fi
    # Create symlinks to the server persistent configurations
    ln -sf "/minecraft/configurations/$file_name" "/minecraft/$file_name"
done
# Add a guide to what these configuration files are for
echo -e '# Minecraft server configuration files\n\nText files (.txt) are for legacy versions (prior to 1.8), any new version of Minecraft will use the JSON format.\nIf your server is running Minecraft 1.8 or newer, you can delete the old (txt) files.' > /minecraft/configurations/README.txt

# Display current server.properties
echo -e "\nServer properties:"
cat server.properties

# Start the server
cd /minecraft
echo -e "Starting server...\n"
if [[ -e "run.sh" ]]; then
    bash run.sh --nogui
else
    java -jar forge*.jar --nogui
fi
