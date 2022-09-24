# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os

from minecraft_server_downloader.java_server_downloader import Java_ServerDownloader
from utilities import Logger, MagicFileTools

logger = Logger("Minecraft Docker Compiler")
global_config = {
    "logging": {
        "level": os.environ.get("LOG_LEVEL", "INFO")
    }
}

# Directories
cwd = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
))
logger.debug(f"Working directory: {cwd}")
minecraft_dir = os.path.join(cwd, "minecraft", "server")

# Cleanup
if os.path.isdir(minecraft_dir):
    MagicFileTools.rm_tree(minecraft_dir)
    logger.debug("Cleaned up old minecraft server instances")
os.mkdir(minecraft_dir)

# Download the latest minecraft server version
downloader = Java_ServerDownloader(**global_config)

game_versions = downloader.get_available_game_versions()
logger.info(f"Found {len(game_versions)} available game versions")
if len(game_versions) == 0:
    logger.error(f"No game versions available for download, aborting...")
    exit(1)

latest_version = downloader.get_available_game_versions()[0]
logger.info(f"Latest game version: {latest_version}")
try:
    downloader.download(version=latest_version, save_location=minecraft_dir)
except Exception as e:
    logger.error(f"Downloading minecraft jar failed with error: {str(e)}")
    exit(1)

# Get the path to the downloaded jar to ensure it exists
minecraft_jar = os.path.join(minecraft_dir, f"{latest_version}.jar")
if not os.path.isfile(minecraft_jar):
    logger.error(f"No Minecraft jar found at {minecraft_dir}")
    exit(1)
# Rename it to be the standard `server.jar`
server_jar = os.path.join(minecraft_dir, "server.jar")
os.rename(minecraft_jar, server_jar)

# Store the downloaded server version
with open(os.path.join(minecraft_dir, "version.txt"), mode="w") as f:
    f.write(latest_version)

exit(0)
