# Minecraft Server - Docker

![minecraft-docker-logo](https://gitlab.com/rdall96/minecraft-docker/-/blob/75538a3285d67a6dd8ecd113dda8ce6ab09d27d3/project_icon.png)

This project is a build system that creates Minecraft Docker images.

> [!NOTE]
> Use this if you wish to create custom builds of Minecraft server images, otherwise, see [rdall96/minecraft-server](https://hub.docker.com/r/rdall96/minecraft-server) for pre-built images.

This docker image based on Alpine Linux contains the necessary components to run a Minecraft server. The project supports the following Minecraft versions:
* Vanilla (Java) - [Official site](https://www.minecraft.net/en-us)
* Forge - [Minecraft Forge](https://files.minecraftforge.net/net/minecraftforge/forge/)
* Fabric - [Fabric MC](https://fabricmc.net)
* NeoForge - [NeoForged](https://neoforged.net/)
* Quilt - [Quilt Project](https://quiltmc.org/en/)

## Installation

Pull the image to your local machine with:
```
docker pull rdall96/minecraft-server:latest
```

> [!NOTE]
> The Docker tags indicate the Minecraft type and version. For example, to play vanilla Minecraft 1.20.1 (java), use the tag `1.20.1`. The `latest` tag will always track the newest vanilla Minecraft Java version. For other types of Minecraft (modded or bedrock) the respective game version will have the type appended to it. i.e.: `1.20.1-fabric_0.14.21`, `latest-bedrock`, `1.19.2-bedrock`.
> Modded Minecraft doesn't have a latest tag, since mods can take some time to update, it's not safe to keep updating the image.

Start a new container:
```
docker run -d --name minecraft -p 25565:25565 -e EULA=true rdall96/minecraft-server:latest
```

The new server will be running at `localhost:25565` or `<your-ip-address-here>:25565`. For access outside your home network you need to open a port on your router. It is strongly encouraged to setup DDNS (Dynamic DNS) to link your public IP to a domain name, so you don't get disconnected or loose access if your IP changes.

> [!WARNING]
> A note regarding port forwarding.
> Opening ports on your network can be unsafe and expose you to malicious attacks, please proceed with caution and keep in mind there is a risk involved with it.
> This project's only goal is to run a Minecraft server, it and its owners are not responsible for any damage caused to you due to its usage with port forwarding.

## Customization

### World data
You can map the container path to the world file to a local directory on your system (or a Docker volume) in order to persist the data throughout server restarts and updates on a location of your choosing. To do so, just simply add this to your *docker run* command: `-v <host-path>:/minecraft/world`.

Complete example mapping the world data to a directory on your desktop:
```
docker run -d --name minecraft \
    -v ~/Desktop/minecraft:/minecraft/world \
    -p 25565:25565 \
    -e EULA=true \
    rdall96/minecraft-server:latest
```

For modded versions of Minecraft, you will likely want to map more folders to volumes like `mods` folders, or other configs. All the Minecraft server files can be found in the image at `/minecraft`, so for example the `mods folder can be found at `/minecraft/mods`.

If you're setting server operators (ops), a server whitelist, and/or banning players and want to persist those configurations on your local file system, map the `/minecraft/configurations` directory.
Here's an example with the white list enabled and the configuration mapped to a local directory:
```
docker run -d --name minecraft \
    -v ~/Desktop/minecraft/world:/minecraft/world \
    -v ~/Desktop/minecraft/configurations:/minecraft/configurations \
    -p 25565:25565 \
    -e EULA=true \
    -e WHITE_LIST=true \
    rdall96/minecraft-server:latest
```
The `/minecraft/configurations` directory will contain files for the JSON configurations (i.e.: whitelist.json), as well as the legacy text format (.txt). For more information consult the guide in the README that is generated in that directory upon starting the server.

### Server properties
There are a number of environment variables you can pass to your container in order to customize the **server.properties** file associated with a Minecraft server. Below is a complete list.

| server.property        | Name                   | Values                                    | Default          | Description                                                                                                                                                                                   |
| ---------------------- | ---------------------- | ----------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| allow-flight           | ALLOW_FLIGHT           | true, false                               | false            | Allows users to use flight on the server while in Survival mode, if they have a mod that provides flight installed                                                                            |
| allow-nether           | ALLOW_NETHER           | true, false                               | true             | Allows players to travel to the Nether                                                                                                                                                        |
| difficulty             | DIFFICULTY             | peaceful, easy, normal, hard              | easy             | Defines the difficulty (such as damage dealt by mobs and the way hunger and poison affects players) of the server                                                                             |
| enable-command-block   | ENABLE_COMMAND_BLOCK   | true, false                               | false            | Enables command blocks                                                                                                                                                                        |
| enable-status          | ENABLE_STATUS          | true, false                               | true             | Makes the server appear as "online" on the server list                                                                                                                                        |
| enable-query           | ENABLE_QUERY           | true, false                               | false            | Enables GameSpy4 protocol server listener. Used to get information about server                                                                                                               |
| enforce-secure-profile | ENFORCE_SECURE_PROFILE | true, false                               | true             | If set to true, players without a Mojang-signed public key will not be able to connect to the server                                                                                          |
| gamemode               | GAMEMODE               | survival, creative, adventure, spectator  | survival         | Defines the mode of gameplay                                                                                                                                                                  |
| generate-structures    | GENERATE_STRUCTURES    | true, false                               | true             | Defines whether structures (such as villages) can be generated                                                                                                                                |
| hardcore               | HARDCORE               | true, false                               | false            | If set to true, server difficulty is ignored and set to hard and players are set to spectator mode if they die                                                                                |
| hide-online-players    | HIDE_ONLINE_PLAYERS    | true, false                               | false            | If set to true, a player list is not sent on status requests                                                                                                                                  |
| level-seed             | LEVEL_SEED             | (any string)                              | (empty)          | Sets a world seed for the player's world, as in single player. The world generates with a random seed if left blank                                                                           |
| level-type             | LEVEL_TYPE             | (any string)                              | minecraft:normal | Determines the world preset that is generated                                                                                                                                                 |
| max-players            | MAX_PLAYERS            | (any number)                              | 20               | The maximum number of players that can play on the server at the same time. Note that more players on the server consume more resources                                                       |
| motd                   | MOTD                   | (any string)                              | (empty)          | This is the message that is displayed in the server list of the client, below the name                                                                                                        |
| online-mode            | ONLINE_MODE            | true, false                               | true             | Server checks connecting players against Minecraft account database. Set this to false only if the player's server is not connected to the Internet.                                          |
| op-permission-level    | OP_PERMISSION_LEVEL    | (number 0-4)                              | 4                | Sets the default permission level for ops when using `/op`.                                                                                                                                   |
| player-idle-timeout    | PLAYER_IDLE_TIMEOUT    | (any number, in minutes)                  | 0 (disabled)     | If non-zero, players are kicked from the server if they are idle for more than that many minutes                                                                                              |
| pvp                    | PVP                    | true, false                               | true             | Enable PvP (player-vs-player) on the server                                                                                                                                                   |
| resource-pack          | RESOURCE_PACK          | (any string)                              | (empty)          | Optional URI to a resource pack. The player may choose to use it.                                                                                                                             |
| resource-pack-prompt   | RESOURCE_PACK_PROMPT   | (any string)                              | (empty)          | Optional, adds a custom message to be shown on resource pack prompt when `require-resource-pack` is used.                                                                                     |
| require-resource-pack  | REQUIRE_RESOURCE_PACK  | true, false                               | false            | When this option is enabled (set to true), players will be prompted for a response and will be disconnected if they decline the required pack.                                                |
| simulation-distance    | SIMULATION_DISTANCE    | (any number between 3-32)                 | 10               | Sets the maximum distance from players that living entities may be located in order to be updated by the server, measured in chunks in each direction of the player (radius, not diameter)    |
| spawn-animals          | SPAWN_ANIMALS          | true, false                               | true             | Determines whether animals can spawn                                                                                                                                                          |
| spawn-monsters         | SPAWN_MONSTERS         | true, false                               | true             | Determines whether monsters can spawn                                                                                                                                                         |
| spawn-npcs             | SPAWN_NPCS             | true, false                               | true             | Determines whether villagers can spawn                                                                                                                                                        |
| spawn-protection       | SPAWN_PROTECTION       | (any number)                              | 16               | Determines the side length of the square spawn protection area as 2x+1. Setting this to 0 disables the spawn protection                                                                       |
| view-distance          | VIEW_DISTANCE          | (any number)                              | 10               | Sets the amount of world data the server sends the client, measured in chunks in each direction of the player (radius, not diameter)                                                          |
| white-list             | WHITE_LIST             | true, false                               | false            | Enables a whitelist on the server                                                                                                                                                             |

For more details and information regarding each of the properties above, please consult the [Minecraft wiki on server properties](https://minecraft.fandom.com/wiki/Server.properties#Java_Edition_3)

Any of these environment variables can be passed to the docker start container command with the argument `-e <NAME>=<VALUE>`.
If you're using a lot of these properties, you want to consider passing Docker an environment file instead. This file is stored on your system and it lists all the of properties neatly in one place.
You can an environment file to Docker using the flag `--env-file <file-path>`.

For example, here's the contents of an environment file stored at path `~/minecraft_server/properties.env` on the host computer.
```
EULA=true
MOTD=Hello from Docker!
DIFFICULTY=hard
MAX_PLAYERS=5
WHITELIST=true
```

This file can then be used to start the Minecraft server as follows:
```
docker run -d --name minecraft \
    -v ~/Desktop/minecraft:/minecraft/world \
    -p 25565:25565 \
    --env-file ~/minecraft_server/properties.env \
    rdall96/minecraft-server:latest
```

### Server arguments

You can specify additional Minecraft server (or mod loader) arguments by adding them to the docker command to create the container. For example, `docker run rdall96/minecraft-server:latest --help`, will print out all the server CLI options and quit.

### JVM Properties

You can customize the JVM runtime using JVM args. Add your args to the `jvm_args.txt` file in the server configurations directory (`/minecraft/configurations` in the container, or use the default mapped volume). For example, an argument you may want to specify is the maximum Java memory for the Minecraft server. i.e.: Add `-Xmx8G` in that file to allow the server to use up to 8GB of RAM.
All arguments in this file are forwarded to the java process used to run the Minecraft server. You can add `-XX:+PrintFlagsFinal` to log all of the JVM parameters at startup.

## Issues
All users are encouraged to report any issues they might run into or suggestions that would improve the experience of using this docker container. Simply send an email to [Minecraft Docker - Support](mailto:contact-project+rdall96-minecraft-docker-39680657-issue-@incoming.gitlab.com).
