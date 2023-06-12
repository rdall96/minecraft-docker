# Minecraft Docker Compiler
# main.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os
import subprocess

import click

from downloaders import DownloaderFactory, VanillaDownloader, ForgeDownloader, FabricDownloader
from utilities import Config, Logger, MinecraftVersionType
from utilities.exceptions import *


class MinecraftDockerBuilder:

    def __init__(self, dryrun: bool, keep_images: bool, build_type: MinecraftVersionType, verbose_output: bool):
        """ Object to manage and orchestrate Minecraft Docker builds """
        # Setup the working directory and config
        cwd = os.path.dirname(
            os.path.dirname(
                os.path.abspath(__file__)
        ))
        self._config = Config(os.path.join(cwd, "config.yaml"))

        # Setup build parameters
        self._dryrun = dryrun
        self._keep_images = keep_images
        self._build_type = build_type
        if verbose_output:
            self._config.set_log_level("debug")
        
        # Create a logger
        self._logger = Logger("MinecraftDockerBuilder", level=self._config.log_level)
        self._logger.debug(f"Working directory: {cwd}")
        self._logger.info(f"Build type: {self._build_type.value}")


    @property
    def all_minecraft_versions(self) -> list:
        """ Fetch a list of all Minecraft versions from newest to oldest """
        downloader = VanillaDownloader(**self._config.logger_config_dict)
        self._logger.debug("Checking for available Minecraft versions...")
        return downloader.get_available_game_versions()


    def _compile(self, image_name: str, image_tag: str, minecraft_url: str, java_package_name: str):
        """ Run docker build to create the image """
        # Build the image using the first tag
        self._logger.info("Building image...")
        cmd = [
            "docker", "build", self._config.docker_build_directory(self._build_type),
            "-t", f"{image_name}:{image_tag}"
        ]
        if self._build_type is MinecraftVersionType.bedrock:
            cmd.extend(["--build-arg", f"MINECRAFT_SERVER_URL={minecraft_url}"])
        else:
            cmd.extend([
                "--build-arg", f"JAVA_VER={java_package_name}",
                "--build-arg", f"MINECRAFT_JAR_URL={minecraft_url}"
            ])
        self._logger.debug(f"Build command: {' '.join(cmd)}")
        build_result = subprocess.run(cmd)
        if build_result.returncode:
            self._logger.error("The image failed to build, an error occurred")
            raise DockerBuildError
        self._logger.info(f"Tagged Minecraft docker image '{image_name}:{image_tag}'")


    def build(self, minecraft_version: str, force: bool):
        """ Build a Docker image for the given Minecraft version """
        # Prepare to build (validate the Minecraft version)
        game_versions = self.all_minecraft_versions # call it once so we don't get throttled by calling it over and over
        self._logger.debug(f"Found {len(game_versions)} available game versions")
        if len(game_versions) == 0:
            self._logger.error(f"No game versions available for download, aborting...")
            raise MinecraftVersionError
        
        # If the `minecraft_version` is "latest" grab the newest one from the available game versions
        if minecraft_version == "latest":
            minecraft_version = game_versions[0]
        
        # List of tags for the current build
        build_tags = MinecraftDockerBuilder.generate_build_tags(
            minecraft_version=minecraft_version,
            build_type=self._build_type,
            is_latest=minecraft_version == game_versions[0],
            logger_config=self._config.logger_config_dict
        )

        # Check if the image already exists in DockerHub
        if not force:
            image_name = self._config.docker_image_name
            latest_build_tag = build_tags[0]
            if MinecraftDockerBuilder.image_exists(image_name, latest_build_tag):
                self._logger.warning(f"Found image for selected Minecraft version in DockerHub {image_name}:{latest_build_tag}, no need to rebuild")
                return

        # Fetch the correct Java version for this build
        java_version = self._config.java_version(minecraft_version=minecraft_version)
        if self._build_type is not MinecraftVersionType.bedrock:
            if not java_version:
                self._logger.warning(f"No optimal Java version found for Minecraft {minecraft_version}, proceeding with the default ({self._config.latest_java_version})")
                java_version = self._config.latest_java_version

        # Show build settings
        self._logger.info(f"Selected Minecraft version: {minecraft_version}")
        if self._build_type is not MinecraftVersionType.bedrock:
            self._logger.info(f"Using optimal Java version: {java_version} ({self._config.java_package_name(java_version)})")
        self._logger.info(f"Upload to DockerHub enabled: {not self._dryrun}")
        self._logger.info(f"Keep image after building: {self._keep_images}")

        # Get the Minecraft server download URL
        self._logger.debug("Fetching Minecraft server URL...")
        factory = DownloaderFactory()
        try:
            downloader = factory.create_downloader(downloader_type=self._build_type, **self._config.logger_config_dict)
            minecraft_url = downloader.get_download_url(version=minecraft_version)
        except Exception as e:
            self._logger.error(f"Fetching Minecraft server download URL failed with error: {str(e)}")
            raise ServerDownloadError

        # Run docker build
        self._compile(
            image_name=self._config.docker_image_name,
            image_tag=build_tags[0],
            minecraft_url=minecraft_url,
            java_package_name=self._config.java_package_name(java_version)
        )
        # We want to re-tag the image instead of building with the new tag because
        # a new version of the base image might have become available in the mean time,
        # which would cause software discrepancies between the tags.
        for tag in build_tags[1:]:
            if not MinecraftDockerBuilder.tag(
                image_name=self._config.docker_image_name,
                current_tag=build_tags[0],
                new_tag=tag
            ):
                self._logger.error(f"An error occurred while tagging the image with '{tag}'")
                raise DockerTagError
            self._logger.info(f"Tagged Minecraft docker image '{self._config.docker_image_name}:{tag}'")

        # Push to DockerHub
        if not self._dryrun:
            self._logger.info("Pushing to DockerHub...")
            for tag in build_tags:
                success = MinecraftDockerBuilder.push(image_name=self._config.docker_image_name, tag=tag)
                if not success:
                    self._logger.error(f"Pushing tag '{tag}' failed!")
                    raise DockerPushError
            self._logger.info(f"Pushed {len(build_tags)} tag(s) successfully")

        # Cleanup
        if not self._keep_images:
            self._logger.debug("Removing built images from local storage")
            for tag in build_tags:
                success = MinecraftDockerBuilder.remove_image(image_name=self._config.docker_image_name, tag=tag)
                if not success:
                    self._logger.error(f"Un-tagging '{tag}' failed!")
                    raise DockerTagError
            self._logger.info(f"Cleaned up {len(build_tags)} local tag(s)")


    @staticmethod
    def generate_build_tags(minecraft_version: str, build_type: MinecraftVersionType, is_latest: bool, logger_config: dict) -> list:
        """ Create a list of docker image tags for the configured build """
        tags = []

        # vanilla
        if build_type == MinecraftVersionType.vanilla:
            tags.append(minecraft_version)
            if is_latest:
                # Add the 'latest' tag as this is the newest Minecraft version
                tags.append("latest")
        # forge/fabric - we don't use the latest tag with forge and fabric,
        # we instead pick the latest available forge/fabric and add the version number to the tag
        elif build_type == MinecraftVersionType.forge:
            downloader = ForgeDownloader(**logger_config)
            versions = downloader.get_forge_versions(minecraft_version=minecraft_version)
            latest_forge_version = versions.get("latest")
            tags.append(f"{minecraft_version}-{build_type.value}_{latest_forge_version}")
        elif build_type == MinecraftVersionType.fabric:
            downloader = FabricDownloader(**logger_config)
            versions = downloader.get_fabric_versions(minecraft_version=minecraft_version)
            latest_forge_version = versions.get("latest").get("loader")
            tags.append(f"{minecraft_version}-{build_type.value}_{latest_forge_version}")
        else:
            tags.append(f"{minecraft_version}-{build_type.value}")
            if is_latest:
                # Add the 'latest' tag as this is the newest Minecraft version
                tags.append(f"latest-{build_type.value}")

        return tags


    @staticmethod
    def tag(image_name: str, current_tag: str, new_tag: str) -> bool:
        """ Re-tag a Docker image """
        cmd = [
            "docker", "tag",
            f"{image_name}:{current_tag}",
            f"{image_name}:{new_tag}"
        ]
        return subprocess.run(cmd).returncode == 0


    @staticmethod
    def push(image_name: str, tag: str) -> bool:
        """ Pushes the image to DockerHub and returns the success status """
        # docker push <image_name>:<tag>
        cmd = ["docker", "push", f"{image_name}:{tag}"]
        return subprocess.run(cmd).returncode == 0


    @staticmethod
    def image_exists(image_name: str, tag: str) -> bool:
        """ Checks if an image already exists in DockerHub """
        cmd = [
            "docker", "manifest", "inspect",
            f"{image_name}:{tag}"
        ]
        return subprocess.run(cmd).returncode == 0


    @staticmethod
    def remove_image(image_name: str, tag: str) -> bool:
        """ Deletes the Docker image from local storage and returns the success status """
        # docker rmi <image_name>:<tag>
        cmd = ["docker", "rmi", f"{image_name}:{tag}"]
        return subprocess.run(cmd).returncode == 0

#--------------------------------------------------------------------------------------------------
# CLI
#--------------------------------------------------------------------------------------------------

@click.command("Minecraft Docker Builder CLI")
@click.option("-d", "--dryrun", is_flag=True, help="Dryrun (build the image but don't upload).")
@click.option("-k", "--keep-image", is_flag=True, help="Save the tagged image (don't delete the artifacts).")
@click.option("-f", "--force", is_flag=True, help="Force upload to overwrite the remote registry.")
@click.option("--minecraft", "minecraft_version", type=str, default="latest", show_default=True, help="Specify the version of Minecraft to build. Set to 'all' to build every version.")
@click.option("-t", "--build-type", type=click.Choice(MinecraftVersionType._member_names_), default=MinecraftVersionType.vanilla.value, show_default=True, help="The type of Minecraft installation to build into this container.")
@click.option("-v", "--verbose", is_flag=True, help="Run in verbose mode.")
def cli(dryrun: bool, keep_image: bool, force: bool, minecraft_version: str, build_type: str, verbose: bool):
    builder = MinecraftDockerBuilder(
        dryrun=dryrun,
        keep_images=keep_image,
        build_type=MinecraftVersionType(build_type),
        verbose_output=verbose
    )

    # If the `minecraft_version` is "all" rebuilt all available game versions,
    # so call create a list of versions to build and call the build method for each one
    if minecraft_version == "all":
        game_versions = builder.all_minecraft_versions
        # Reverse the game versions first so we build them in order from oldest to newest
        game_versions.reverse()
        # Keep track of how many versions fail to build
        failed = []
        for game in game_versions:
            print("\n\n")
            print(f" Minecraft {game} ".center(80, "-"))
            try:
                builder.build(
                    minecraft_version=game,
                    force=True # we set force to `True` since we want to re-compile every image anyway
                )
            except:
                # FIXME: Ignore build errors for a single version, some older Minecraft versions have a broken download link
                failed.append(game)
        print("\n\n")
        print(f"Built {len(game_versions)} Minecraft Docker images, {len(failed)} failed.")
        if failed:
            print(f"Failed versions: {', '.join(failed)}")
        # Exit here since all images have already been built
        return

    builder.build(
        minecraft_version=minecraft_version,
        force=force
    )


if __name__ == "__main__":
    cli()
