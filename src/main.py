# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os
import subprocess

import click

from minecraft_server_downloader.java_server_downloader import Java_ServerDownloader
from utilities import Config, Logger
from utilities.exceptions import *


SCRIPT_NAME = "Minecraft Docker Builder"


def build(build_root: str, config: Config, image_name: str, minecraft_version: str, java_version: int, tag_latest: bool):
    """ Build minecraft-docker """
    logger = Logger("Builder", level=config.log_level)

    # Show build settings
    logger.info(f"Selected Java version: {java_version} ({config.java_package_name(java_version)})")
    logger.info(f"Selected Minecraft version: {minecraft_version}")

    # Get the Minecraft server download URL
    logger.info("Fetching Minecraft server URL...")
    try:
        downloader = Java_ServerDownloader(**config.logger_config_dict)
        minecraft_url = downloader.get_download_url(version=minecraft_version)
    except Exception as e:
        logger.error(f"Fetching minecraft jar URL failed with error: {str(e)}")
        raise ServerDownloadError

    # Build the image
    logger.info("Building image...")
    cmd = [
        "docker", "build", build_root,
        "--build-arg", f"JAVA_VER={config.java_package_name(java_version)}",
        "--build-arg", f"MINECRAFT_JAR_URL={minecraft_url}",
        "-t", f"{image_name}:{minecraft_version}"
    ]
    logger.debug(f"Build command: {' '.join(cmd)}")
    build_result = subprocess.run(cmd)
    if build_result.returncode:
        logger.error("The image failed to build, an error occurred")
        raise DockerBuildError
    logger.info(f"Tagged Minecraft docker image '{image_name}:{minecraft_version}'")
    # If this is the latest Minecraft version tag the image with 'latest' as well
    if tag_latest:
        cmd = [
            "docker", "tag",
            f"{image_name}:{minecraft_version}",
            f"{image_name}:latest"
        ]
        if subprocess.run(cmd).returncode:
            logger.error(f"An error occurred while tagging the image with 'latest'")
            raise DockerTagError
        logger.info(f"Tagged Minecraft docker image '{image_name}:latest'")


@click.command("Minecraft Docker Builder CLI")
@click.option("-d", "--dryrun", is_flag=True, help="Dryrun (build the image but don't upload)")
@click.option("-k", "--keep-image", is_flag=True, help="Save the tagged image (don't delete the artifacts)")
@click.option("-f", "--force", is_flag=True, help="Force upload to overwrite the remote registry")
@click.option("--minecraft", "minecraft_version", type=str, default="latest", show_default=True, help="Specify the version of Minecraft to build")
@click.option("-v", "--verbose", is_flag=True, help="Run in verbose mode")
def cli(dryrun: bool, keep_image: bool, force: bool, minecraft_version: str, verbose: bool):
    
    # Setup the working directory and config
    cwd = os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)
    ))
    config = Config(os.path.join(cwd, "config.yaml"))

    if verbose:
        config.set_log_level("debug")

    logger = Logger("CLI", level=config.log_level)
    logger.debug(f"Working directory: {cwd}")

    # Flag to determine if docker should tag a 'latest' version. This will depend on the version of Minecraft
    tag_latest=False

    # Prepare to build
    downloader = Java_ServerDownloader(**config.logger_config_dict)
    logger.debug("Checking for available Minecraft versions...")
    game_versions = downloader.get_available_game_versions()
    logger.debug(f"Found {len(game_versions)} available game versions")
    if len(game_versions) == 0:
        logger.error(f"No game versions available for download, aborting...")
        raise MinecraftVersionError
    if minecraft_version == "latest":
        tag_latest=True
        minecraft_version = game_versions[0]

    # Check if the image already exists in DockerHub
    if not force:
        cmd = [
            "docker", "manifest", "inspect",
            f"{config.docker_image_name}:{minecraft_version}"
        ]
        if not subprocess.run(cmd).returncode:
            logger.warning(f"Found image for selected Minecraft version in DockerHub {config.docker_image_name}:{minecraft_version}, no need to rebuild")
            return

    # Fetch the correct Java version for this build
    java_version = config.java_version(minecraft_version=minecraft_version)
    if not java_version:
        logger.warning(f"No optimal Java version found for Minecraft {minecraft_version}, proceeding with the default")
        java_version = config.latest_java_version

    # Run the build
    build(os.path.join(cwd, config.docker_build_directory), config,
        config.docker_image_name, minecraft_version, java_version, tag_latest)

    # Push to DockerHub
    if not dryrun:
        logger.info("Pushing to DockerHub...")
        tags = [minecraft_version]
        if tag_latest:
            tags.append("latest")
        for tag in tags:
            cmd = ["docker", "push", f"{config.docker_image_name}:{tag}"]
            if subprocess.run(cmd).returncode:
                logger.error(f"Pushing tag '{tag}' failed!")
                raise DockerPushError
        logger.info(f"Pushed {len(tags)} tag(s) successfully")

    # Cleanup
    if not keep_image:
        logger.debug("Removing built images form local storage")
        tags = [minecraft_version]
        if tag_latest:
            tags.append("latest")
        for tag in tags:
            cmd = ["docker", "rmi", f"{config.docker_image_name}:{tag}"]
            if subprocess.run(cmd).returncode:
                logger.error(f"Un-tagging '{tag}' failed!")
                raise DockerTagError
        logger.info(f"Cleaned up {len(tags)} local tag(s)")


if __name__ == "__main__":
    cli()
