# Minecraft Server Downloader
# minecraft_server_downloader/exceptions.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

class ServerDownloadError(Exception):
    """ Raised when the download for the server executable fails """

class MinecraftVersionError(Exception):
    """ There is an issue with building this version of Minecraft """

class ForgeVersionNotFoundError(Exception):
    """ A valid Forge binary was nto found for the selected Minecraft version """

class DockerBuildError(Exception):
    """ Docker failed to build the image """

class DockerTagError(Exception):
    """ Docker failed to perform actions on image tags """

class DockerPushError(Exception):
    """ Docker failed to push the image to the remote registry """
