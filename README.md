# Minecraft Server - Docker

This docker image based on Alpine Linux contains the necessary components to run a vanilla Minecraft server.

## Installation

Pull the image to your local machine with:
```
docker pull rdall96/minecraft-server:latest
```

Start a new container:
```
docker run -d --name minecraft -p 25565:25565 -e EULA=true rdall96/minecraft-server:latest
```

The new server will be running at `localhost:25565` or `<your-ip-address-here>:25565`. For access outside your home network you need to open a port on your router. It is strongly encouraged to setup DDNS (Dynamic DNS) to link your public IP to a domain name, so you don't get disconnected or loose access if your IP changes.

## Customization

### World data
You can map the container path to the world file to a local directory on your system in order to persist the data throughout server restarts and updates on a location of your choosing. Just simply add this to your *docker run* command: `-v /minecraft/world:<host-path>`.

Complete command example mapping the world data to a directory on your desktop:
```
docker run -d --name minecraft \
    -v /minecraft/world:~/Desktop/minecraft \
    -p 25565:25565 \
    -e EULA=true \
    rdall96/minecraft-server:latest
```

### Server properties
There are a number of environment variables you can pass to your container in order to customize the **server.properties** file associated with a Minecraft server. Below is a complete list.

| server.property       | Name                  | Values                                    | Default       | Description                                                                                                                                                                                   |
| --------------------- | --------------------- | ----------------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| gamemode              | GAMEMODE              | survival, creative, adventure, spectator  | survival      | Defines the mode of gameplay                                                                                                                                                                  |
| enable-command-block  | ENABLE_COMMAND_BLOCK  | true, false                               | false         | Enables command blocks                                                                                                                                                                        |
| motd                  | MOTD                  | (any string)                              | (empty)       | This is the message that is displayed in the server list of the client, below the name                                                                                                        |
| pvp                   | PVP                   | true, false                               | true          | Enable PvP (player-vs-player) on the server                                                                                                                                                   |
| generate-structures   | GENERATE_STRUCTURES   | true, false                               | true          | Defines whether structures (such as villages) can be generated                                                                                                                                |
| difficulty            | DIFFICULTY            | peaceful, easy, normal, hard              | easy          | Defines the difficulty (such as damage dealt by mobs and the way hunger and poison affects players) of the server                                                                             |
| max-players           | MAX_PLAYERS           | (any number)                              | 20            | The maximum number of players that can play on the server at the same time. Note that more players on the server consume more resources                                                       |
| allow-flight          | ALLOW_FLIGHT          | true, false                               | false         | Allows users to use flight on the server while in Survival mode, if they have a mod that provides flight installed                                                                            |
| view-distance         | VIEW_DISTANCE         | (any number)                              | 10            | Sets the amount of world data the server sends the client, measured in chunks in each direction of the player (radius, not diameter)                                                          |
| allow-nether          | ALLOW_NETHER          | true, false                               | true          | Allows players to travel to the Nether                                                                                                                                                        |
| simulation-distance   | SIMULATION_DISTANCE   | (any number between 3-32)                 | 10            | Sets the maximum distance from players that living entities may be located in order to be updated by the server, measured in chunks in each direction of the player (radius, not diameter)    |
| player-idle-timeout   | PLAYER_IDLE_TIMEOUT   | (any number, in minutes)                  | 0 (disabled)  | If non-zero, players are kicked from the server if they are idle for more than that many minutes                                                                                              |
| hardcore              | HARDCORE              | true, false                               | false         | If set to true, server difficulty is ignored and set to hard and players are set to spectator mode if they die                                                                                |
| white-list            | WHITE_LIST            | true, false                               | false         | Enables a whitelist on the server                                                                                                                                                             |
| spawn-npcs            | SPAWN_NPCS            | true, false                               | true          | Determines whether villagers can spawn                                                                                                                                                        |
| spawn-animals         | SPAWN_ANIMALS         | true, false                               | true          | Determines whether animals can spawn                                                                                                                                                          |
| spawn-monsters        | SPAWN_MONSTERS        | true, false                               | true          | Determines whether monsters can spawn                                                                                                                                                         |
| spawn-protection      | SPAWN_PROTECTION      | (any number)                              | 16            | Determines the side length of the square spawn protection area as 2x+1. Setting this to 0 disables the spawn protection                                                                       |

For more details and information regarding each of the properties above, please consult the [Minecraft wiki on server properties](https://minecraft.fandom.com/wiki/Server.properties#Java_Edition_3)

Any of these environment variables can be passed to the docker start container command with the argument `-e NAME=VALUE`.
However, when using a lot of these properties it is recommended to leverage environment files. These are files stored on your host which list all the of properties neatly in one place and can then be passed to docker using `--env-file <file-path>`.

For example, here's the contents of an environment file stored at path `~/minecraft_server/properties.env`
```
EULA=true
MOTD=Hello from Docker!
DIFFICULTY=hard
MAX_PLAYERS=5
WHITELIST=true
```

This file can then be used to star the Minecraft server as follows:
```
docker run -d --name minecraft \
    -v /minecraft/world:~/Desktop/minecraft \
    -p 25565:25565 \
    --env-file ~/minecraft_server/properties.env \
    rdall96/minecraft-server:latest
```

## Issues
All users are encouraged to report any issues they might run into or suggestions that would improve the experience of using this docker container. Simply send an email to [Minecraft Docker - Support](mailto:contact-project+rdall96-minecraft-docker-39680657-issue-@incoming.gitlab.com)

## Development

This Minecraft Docker image can easily be used as a starting point for creating your own custom Minecraft container.
Feel free to download and create modded versions by installing additional components to the image. The world file doesn't generate until the container is run for the fist time, so you are good to go.
Just note that there is a startup script which will act as the entry-point when the container is run. This can be found in `/minecraft/start_server.sh` inside the container.
