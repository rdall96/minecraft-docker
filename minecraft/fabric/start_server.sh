#!/bin/bash
# Entry point for starting the minecraft server

# set -o errexit

# Print out the java version
echo "Java Runtime:"
java --version
echo -e "\n"

# Set EULA
echo "eula=$EULA" > eula.txt

# Collect environment variables (key = env var, value = minecraft name)
declare -A PROPERTIES
PROPERTIES[ALLOW_FLIGHT]='allow-flight'
PROPERTIES[ALLOW_NETHER]='allow-nether'
PROPERTIES[DIFFICULTY]='difficulty'
PROPERTIES[ENABLE_COMMAND_BLOCK]='enable-command-block'
PROPERTIES[ENABLE_STATUS]='enable-status'
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
PROPERTIES[PLAYER_IDLE_TIMEOUT]='player-idle-timeout'
PROPERTIES[PVP]='pvp'
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

# Display current server.properties
echo -e "Server properties:\n"
cat server.properties
echo -e "\n"

# Start the server
cd /minecraft
echo -e "Starting server...\n"
java -jar fabric_server.jar nogui
