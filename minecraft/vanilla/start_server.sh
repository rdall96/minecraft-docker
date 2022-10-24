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
PROPERTIES[GAMEMODE]='gamemode'
PROPERTIES[ENABLE_COMMAND_BLOCK]='enable-command-block'
PROPERTIES[MOTD]='motd'
PROPERTIES[PVP]='pvp'
PROPERTIES[GENERATE_STRUCTURES]='generate-structures'
PROPERTIES[DIFFICULTY]='difficulty'
PROPERTIES[MAX_PLAYERS]='max-players'
PROPERTIES[ALLOW_FLIGHT]='allow-flight'
PROPERTIES[VIEW_DISTANCE]='view-distance'
PROPERTIES[ALLOW_NETHER]='allow-nether'
PROPERTIES[SIMULATION_DISTANCE]='simulation-distance'
PROPERTIES[PLAYER_IDLE_TIMEOUT]='player-idle-timeout'
PROPERTIES[HARDCORE]='hardcore'
PROPERTIES[WHITE_LIST]='white-list'
PROPERTIES[SPAWN_NPCS]='spawn-npcs'
PROPERTIES[SPAWN_ANIMALS]='spawn-animals'
PROPERTIES[SPAWN_MONSTERS]='spawn-monsters'
PROPERTIES[SPAWN_PROTECTION]='spawn-protection'

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
java -jar server.jar
