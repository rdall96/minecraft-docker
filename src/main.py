# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os
import subprocess

import click

from minecraft_server_downloader.java_server_downloader import Java_ServerDownloader
from utilities import Logger


NAME = "Minecraft Docker Builder"
IMAGE_NAME = "rdall96/minecraft-server"


@click.command(NAME)
@click.option("-d", "--dryrun", is_flag=True, help="Dryrun (build the image but don't upload)")
@click.option("-k", "--keep-image", is_flag=True, help="Save the tagged image (don't delete the artifacts)")
@click.option("-f", "--force", is_flag=True, help="Force upload to overwrite the remote registry")
@click.option("--java", "java_version", type=int, default=17, show_default=True, help="Specify the Java version to use for this build")
@click.option("--minecraft", "minecraft_version", type=str, default="latest", show_default=True, help="Specify the version of Minecraft to build")
@click.option("-v", "--verbose", is_flag=True, help="Run in verbose mode")
def cli(dryrun: bool, keep_image: bool, force: bool, java_version: str, minecraft_version: str, verbose: bool):
    logger = Logger(NAME)
    config = {
        "logging": {
            "level": "DEBUG" if verbose else "INFO"
        }
    }
    # Flag to determine if docker should tag a 'latest' version. This will depend on the version of Minecraft
    tag_latest=False

    # Directories
    cwd = os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)
    ))
    logger.debug(f"Working directory: {cwd}")

    # Show build settings
    logger.info(f"Selected Java version: {java_version}")
    logger.info(f"Selected Minecraft version: {minecraft_version}")

    # Prepare to build
    downloader = Java_ServerDownloader(**config)
    logger.debug("Checking for available Minecraft versions...")
    game_versions = downloader.get_available_game_versions()
    logger.debug(f"Found {len(game_versions)} available game versions")
    if len(game_versions) == 0:
        logger.error(f"No game versions available for download, aborting...")
        raise Exception
    if minecraft_version == "latest":
        tag_latest=True
        minecraft_version = game_versions[0]

    # Check if the image already exists in DockerHub
    if not force:
        cmd = [
            "docker", "manifest", "inspect",
            f"{IMAGE_NAME}:{minecraft_version}"
        ]
        if not subprocess.run(cmd).returncode:
            logger.warning(f"Found image for selected Minecraft version in DockerHub {IMAGE_NAME}:{minecraft_version}, no need to rebuild")
            return
    
    # Get the Minecraft server download URL
    try:
        logger.info("Fetching Minecraft server URL...")
        minecraft_url = downloader.get_download_url(version=minecraft_version)
    except Exception as e:
        logger.error(f"Fetching minecraft jar URL failed with error: {str(e)}")
        raise Exception

    # Build the image
    logger.info("Building image...")
    cmd = [
        "docker", "build", os.path.join(cwd, "minecraft"),
        "--build-arg", f"JAVA_VER={java_version}",
        "--build-arg", f"MINECRAFT_JAR_URL={minecraft_url}",
        "-t", f"{IMAGE_NAME}:{minecraft_version}"
    ]
    logger.debug(f"Build command: {' '.join(cmd)}")
    build_result = subprocess.run(cmd)
    if build_result.returncode:
        logger.error("The image failed to build, an error occurred")
        raise Exception
    logger.info(f"Tagged Minecraft docker image '{IMAGE_NAME}:{minecraft_version}'")
    # If this is the latest Minecraft version tag the image with 'latest' as well
    if tag_latest:
        cmd = [
            "docker", "tag",
            f"{IMAGE_NAME}:{minecraft_version}",
            f"{IMAGE_NAME}:latest"
        ]
        if subprocess.run(cmd).returncode:
            logger.error(f"An error occurred while tagging the image with 'latest'")
            raise Exception
        logger.info(f"Tagged Minecraft docker image '{IMAGE_NAME}:latest'")

    # Push to DockerHub
    if not dryrun:
        logger.info("Pushing to DockerHub...")
        tags = [minecraft_version]
        if tag_latest:
            tags.append("latest")
        for tag in tags:
            cmd = ["docker", "push", f"{IMAGE_NAME}:{tag}"]
            if subprocess.run(cmd).returncode:
                logger.error(f"Pushing tag '{tag}' failed!")
                raise Exception
        logger.info(f"Pushed {len(tags)} tag(s) successfully")

    # Cleanup
    if not keep_image:
        logger.debug("Removing built images form local storage")
        tags = [minecraft_version]
        if tag_latest:
            tags.append("latest")
        for tag in tags:
            cmd = ["docker", "rmi", f"{IMAGE_NAME}:{tag}"]
            if subprocess.run(cmd).returncode:
                logger.error(f"Un-tagging '{tag}' failed!")
                raise Exception
        logger.info(f"Cleaned up {len(tags)} local tag(s)")


if __name__ == "__main__":
    try:
        cli()
    except:
        exit(1)
    finally:
        exit(0)
