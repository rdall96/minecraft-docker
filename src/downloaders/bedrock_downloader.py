# Minecraft Server Downloader
# bedrock_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from .downloader import Downloader

# URLs
BEDROCK_DOWNLOAD_URL_TEMPLATE_STRING = "https://minecraft.azureedge.net/bin-linux/bedrock-server-{}.zip"
DEFAULT_BEDROCK_VERSION = "1.19.40.02"


class BedrockDownloader(Downloader):
    """ Download Minecraft Bedrock server """

    _type: str = "bedrock"

    def __init__(self, **extra_configs: dict):
        super().__init__(**extra_configs)

    @staticmethod
    def _assemble_download_url(minecraft_version: str) -> str:
        """ Build a url to download the server zip for a given Minecraft version """
        return BEDROCK_DOWNLOAD_URL_TEMPLATE_STRING.format(minecraft_version)
    
    def _get_file_name(self, version: str) -> str:
        """ Returns the file name for this version (specific to the downloader type) """
        return f"bedrock-server-{version}.zip"
    
    def _game_versions(self) -> dict:
        """ Dictionary of released game versions and url downloads """
        raise NotImplementedError()

    def get_available_game_versions(self) -> list:
        """ Returns a list of available game versions """
        return list(self._game_versions().keys())

    def get_download_url(self, version: str) -> str:
        """ Returns the URL where to download the specified server version """
        """
        Fetch the Forge download URL for the given Minecraft version.
        This will try to use the recommended version of Forge and fallback to the latest version otherwise.
        """
        return BedrockDownloader._assemble_download_url(DEFAULT_BEDROCK_VERSION)
