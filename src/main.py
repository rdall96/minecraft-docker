# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os

import click

from minecraft_server_downloader.java_server_downloader import Java_ServerDownloader
from utilities import Logger, MagicFileTools


NAME = "Minecraft Server Downloader"


def save_latest_version(version: str, working_dir: str):
    # Write the latest version to a local file
    latest_file_path = os.path.join(
        working_dir, "minecraft", "latest.txt"
    )
    with open(latest_file_path, mode="w") as f:
        f.write(version)


@click.command(NAME)
@click.option("-c", "--check-only", is_flag=True, help="Only check for the latest Minecraft version and save it to a file")
@click.option("-v", "--verbose", is_flag=True, help="Run in verbose mode")
def cli(check_only: bool, verbose: bool):
    logger = Logger(NAME)
    config = {
        "logging": {
            "level": "DEBUG" if verbose else "INFO"
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
        logger.debug("Cleaned up old minecraft server downloads")
    os.mkdir(minecraft_dir)
    logger.debug(f"Server download directory: {minecraft_dir}")

    # Download the latest minecraft server version
    downloader = Java_ServerDownloader(**config)

    # Get the latest game version
    game_versions = downloader.get_available_game_versions()
    logger.info(f"Found {len(game_versions)} available game versions")
    if len(game_versions) == 0:
        logger.error(f"No game versions available for download, aborting...")
        raise Exception
    latest = game_versions[0]
    logger.info(f"Latest game version: {latest}")
    
    # Store the latest version number
    with open(os.path.join(minecraft_dir, "version.txt"), mode="w") as f:
        f.write(latest)
    if check_only:
        # Quit if running in check mode only
        return

    # Download the latest minecraft server version
    try:
        downloader.download(version=latest, save_location=minecraft_dir)
    except Exception as e:
        logger.error(f"Downloading minecraft jar failed with error: {str(e)}")
        raise Exception

    # Get the path to the downloaded jar to ensure it exists
    minecraft_jar = os.path.join(minecraft_dir, f"{latest}.jar")
    if not os.path.isfile(minecraft_jar):
        logger.error(f"No Minecraft jar found at {minecraft_dir}")
        raise Exception
    # Rename it to be the standard `server.jar`
    server_jar = os.path.join(minecraft_dir, "server.jar")
    os.rename(minecraft_jar, server_jar)


if __name__ == "__main__":
    cli()
