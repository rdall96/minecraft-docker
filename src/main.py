# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os
import subprocess

import click

from downloaders import DownloaderFactory, VanillaDownloader
from utilities import Config, Logger, InstallType
from utilities.exceptions import *


SCRIPT_NAME = "Minecraft Docker Builder"


def generate_build_tags(minecraft_version: str, install_type: InstallType, is_latest: bool) -> list:
    """ Create a list of docker image tags for this build """
    tags = []

    # vanilla
    if install_type == InstallType.vanilla:
        tags.append(minecraft_version)
        if is_latest:
            # Add the 'latest' tag as this is the newest Minecraft version
            tags.append("latest")
    else:
        tags.append(f"{minecraft_version}-{install_type.value}")
        if is_latest:
            # Add the 'latest' tag as this is the newest Minecraft version
            tags.append(f"latest-{install_type.value}")

    return tags


def build(build_root: str, config: Config, image_name: str, minecraft_version: str, java_version: int, type: InstallType, tags: list):
    """ Build minecraft-docker """
    logger = Logger("Builder", level=config.log_level)

    # Show build settings
    logger.info(f"Selected Java version: {java_version} ({config.java_package_name(java_version)})")
    logger.info(f"Selected Minecraft version: {minecraft_version}")

    # Get the Minecraft server download URL
    logger.debug("Fetching Minecraft server URL...")
    factory = DownloaderFactory()
    try:
        downloader = factory.create_downloader(type=type, **config.logger_config_dict)
        minecraft_url = downloader.get_download_url(version=minecraft_version)
    except Exception as e:
        logger.error(f"Fetching Minecraft jar URL failed with error: {str(e)}")
        raise ServerDownloadError

    # Build the image using the first tag
    logger.debug("Building image...")
    main_tag = tags[0]
    cmd = [
        "docker", "build", build_root,
        "--build-arg", f"JAVA_VER={config.java_package_name(java_version)}",
        "--build-arg", f"MINECRAFT_JAR_URL={minecraft_url}",
        "-t", f"{image_name}:{main_tag}"
    ]
    logger.debug(f"Build command: {' '.join(cmd)}")
    build_result = subprocess.run(cmd)
    if build_result.returncode:
        logger.error("The image failed to build, an error occurred")
        raise DockerBuildError
    logger.info(f"Tagged Minecraft docker image '{image_name}:{main_tag}'")
    # Apply all the other tags as well
    for tag in tags[1:]:
        cmd = [
            "docker", "tag",
            f"{image_name}:{main_tag}",
            f"{image_name}:{tag}"
        ]
        if subprocess.run(cmd).returncode:
            logger.error(f"An error occurred while tagging the image with '{tag}'")
            raise DockerTagError
        logger.info(f"Tagged Minecraft docker image '{image_name}:{tag}'")


def push(image_name: str, tag: str) -> bool:
    """ Pushes the image to DockerHub and returns the success status """
    # docker push <image_name>:<tag>
    cmd = ["docker", "push", f"{image_name}:{tag}"]
    return subprocess.run(cmd).returncode == 0


def remove_image(image_name: str, tag: str) -> bool:
    """ Deletes the Docker image from local storage and returns the success status """
    # docker rmi <image_name>:<tag>
    cmd = ["docker", "rmi", f"{image_name}:{tag}"]
    return subprocess.run(cmd).returncode == 0


def minecraft_docker(dryrun: bool, keep_image: bool, force: bool, minecraft_version: str, install_type: InstallType, verbose: bool):
    """ Compile Minecraft Docker images """
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
    logger.info(f"Type: {install_type.value}")

    # Prepare to build (validate the Minecraft version)
    downloader = VanillaDownloader(**config.logger_config_dict)
    logger.debug("Checking for available Minecraft versions...")
    game_versions = downloader.get_available_game_versions()
    logger.debug(f"Found {len(game_versions)} available game versions")
    if len(game_versions) == 0:
        logger.error(f"No game versions available for download, aborting...")
        raise MinecraftVersionError
    
    # If the `minecraft_version` is "latest" grab the newest one from the available game versions
    if minecraft_version == "latest":
        minecraft_version = game_versions[0]
    
    # If the `minecraft_version` is "all" rebuilt all available game versions, so call this function recursively which will handle just that
    if minecraft_version == "all":
        # Reverse the game versions first so we build them in order
        game_versions.reverse()
        # Keep track of how many versions fail to build
        failed = []
        for game in game_versions:
            print("\n\n")
            print(f" Minecraft {game} ".center(80, "-"))
            try:
                minecraft_docker(
                    dryrun=dryrun,
                    keep_image=keep_image,
                    force=True, # we set force to `True` since we want to re-compile every image anyway
                    minecraft_version=game,
                    install_type=install_type,
                    verbose=verbose
                )
            except:
                # FIXME: Ignore build errors for a single version, some older Minecraft versions have a broken download link
                failed.append(game)
        print("\n\n")
        print(f"Built {len(game_versions)} Minecraft Docker images. {len(failed)} failed: {', '.join(failed)}")
        # Exit here since all images have already been built
        return

    # List of tags for the current build
    build_tags = generate_build_tags(
        minecraft_version=minecraft_version,
        install_type=install_type,
        is_latest=minecraft_version == game_versions[0]
    )

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
    build(
        build_root=os.path.join(cwd, config.docker_build_directory(install_type=install_type)),
        config=config,
        image_name=config.docker_image_name,
        minecraft_version=minecraft_version,
        java_version=java_version,
        type=install_type,
        tags=build_tags
    )

    # Push to DockerHub
    if not dryrun:
        logger.info("Pushing to DockerHub...")
        for tag in build_tags:
            success = push(image_name=config.docker_image_name, tag=tag)
            if not success:
                logger.error(f"Pushing tag '{tag}' failed!")
                raise DockerPushError
        logger.info(f"Pushed {len(build_tags)} tag(s) successfully")

    # Cleanup
    if not keep_image:
        logger.debug("Removing built images from local storage")
        for tag in build_tags:
            success = remove_image(image_name=config.docker_image_name, tag=tag)
            if not success:
                logger.error(f"Un-tagging '{tag}' failed!")
                raise DockerTagError
        logger.info(f"Cleaned up {len(build_tags)} local tag(s)")


@click.command("Minecraft Docker Builder CLI")
@click.option("-d", "--dryrun", is_flag=True, help="Dryrun (build the image but don't upload)")
@click.option("-k", "--keep-image", is_flag=True, help="Save the tagged image (don't delete the artifacts)")
@click.option("-f", "--force", is_flag=True, help="Force upload to overwrite the remote registry")
@click.option("--minecraft", "minecraft_version", type=str, default="latest", show_default=True, help="Specify the version of Minecraft to build")
@click.option("-t", "--install-type", type=click.Choice(InstallType._member_names_), default=InstallType.vanilla.value, show_default=True, help="The type of Minecraft installation to build into this container")
@click.option("-v", "--verbose", is_flag=True, help="Run in verbose mode")
def cli(dryrun: bool, keep_image: bool, force: bool, minecraft_version: str, install_type: str, verbose: bool):
    install_type = InstallType(install_type)
    minecraft_docker(
        dryrun=dryrun,
        keep_image=keep_image,
        force=force,
        minecraft_version=minecraft_version,
        install_type=install_type,
        verbose=verbose
    )


if __name__ == "__main__":
    cli()
