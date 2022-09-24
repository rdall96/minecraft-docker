#!/bin/sh
# Entry point for starting the minecraft server

# Print out the java version
echo "Java Runtime:"
java --version
echo -e "\n"

# Set EULA
echo "eula=$EULA" > eula.txt

# Collect environment variables
# $GAMEMODE
# $ENABLE_COMMAND_BLOCKS
# $MOTD
# $PVP
# $GENERATE_STRUCTURES
# $DIFFICULTY
# $MAX_PLAYERS
# $ALLOW_FLIGHT
# $VIEW_DISTANCE
# $ALLOW_NETHER
# $SIMULATION_DISTANCE
# $PLAYER_IDLE_TIMEOUT
# $WHITE_LIST
# $SPAWN_NPCS
# $SPAWN_ANIMALS
# $SPAWN_MONSTERS
# $SPAWN_PROTECTION

# Display current server.properties
echo -e "Server properties:\n"
cat server.properties
echo -e "\n"

# Start the server
cd /minecraft
echo -e "Starting server...\n"
java -jar server.jar
