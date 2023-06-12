# Minecraft Server Downloader
# fabric_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import json

from utilities.exceptions import FabricVersionNotFoundError

from .downloader import Downloader

# URLs
LIST_FABRIC_LOADERS_URL_FORMAT = "https://meta.fabricmc.net/v2/versions/loader/{}" # needs Minecraft version (i.e.: 1.20)
LIST_FABRIC_INSTALLERS_URL = "https://meta.fabricmc.net/v2/versions/installer"
# needs Minecraft version, fabric "loader/installer" string
JAR_DOWNLOAD_LINK_TEMPLATE_STRING = "https://meta.fabricmc.net/v2/versions/loader/{minecraft}/{fabric}/server/jar"


class FabricDownloader(Downloader):
    """ Download Minecraft Fabric jar """

    _type: str = "fabric"

    def __init__(self, **extra_configs: dict):
        super().__init__(**extra_configs)
    
    def get_fabric_versions(self, minecraft_version: str, allow_unstable: bool = False) -> dict:
        """
        Dictionary of available Fabric loader version for the given Minecraft version
        {
            "versions": [
                {
                    "version": str
                    "stable": bool
                }
            ],
            "latest": {
                "version": str
                "stable": bool
            }
        }
        """
        data = {"versions": []}
        # Fabric doesn't provide an official API (that I know of), but we can deduce the format from this page: https://fabricmc.net/use/server/
        loader_web_page_url = LIST_FABRIC_LOADERS_URL_FORMAT.format(minecraft_version)
        loader_content = json.loads(
            Downloader._make_request(loader_web_page_url)
        )
        installer_content = json.loads(
            Downloader._make_request(LIST_FABRIC_INSTALLERS_URL)
        )
        if not (loader_content and installer_content):
            self._logger.error("No content data found in page!")
            return data
        
        # Get the latest installer version
        installer_version: str = None
        for item in installer_content:
            if not allow_unstable and not item.get("stable", False):
                continue
            installer_version = item.get("version")
            if installer_version and isinstance(installer_version, str):
                break
        
        # Example response for loader_content:
        # [
        #     {
        #         "loader": {
        #             "build": 21,
        #             "maven": "net.fabricmc:fabric-loader:0.14.21",
        #             "version": "0.14.21",
        #             "stable": true
        #         },
        #         "intermediary": {
        #             "maven": "net.fabricmc:intermediary:1.19.3",
        #             "version": "1.19.3",
        #             "stable": true
        #         },
        #         "launcherMeta": {}
        #     },
        #     ...
        # ]
        #
        # We only need the information in "loader" and "intermediary", and check for stable versions (unless otherwise specified)

        # keep an impossible build revision for the latest, so we can assign it in the following loop if the value is greater
        latest = {}
        for item in loader_content:
            loader = item.get("loader", {})
            intermediary = item.get("intermediary", {})
            if (not loader) or (not intermediary):
                continue

            # TODO: Parse the data to extract the versions we want to track
            loader_is_stable: bool = loader.get("stable")
            intermediary_is_stable: bool = intermediary.get("stable")
            is_stable = (loader_is_stable and intermediary_is_stable)
            # both need to be true in order to add them, unless allow_unstable
            if not allow_unstable and not is_stable:
                continue
            loader_version: str = loader.get("version")
            if not (loader_version and isinstance(loader_version, str)):
                continue
            rev = loader.get("build", -1)
            try:
                rev = int(rev)
            except:
                rev = -1
            version_data = {
                "rev": rev,
                "stable": is_stable,
                "version": f"{loader_version}/{installer_version}"
            }
            data["versions"].append(version_data)
            if rev > latest.get("rev", -1):
                latest = version_data

        data["latest"] = latest.get("version")
        return data
    
    @staticmethod
    def _assemble_download_url(minecraft_version: str, fabric_version: str) -> str:
        """ Build a url to download forge for a given Minecraft version """
        return JAR_DOWNLOAD_LINK_TEMPLATE_STRING.format(
            minecraft=minecraft_version,
            fabric=fabric_version
        )

    def _get_file_name(self, version: str) -> str:
        """ Returns the file name for this version (specific to the downloader type) """
        raise NotImplementedError()
    
    def _game_versions(self) -> dict:
        """ Dictionary of released game versions and url downloads """
        raise NotImplementedError()

    def get_download_url(self, version: str) -> str:
        """ Returns the URL where to download the specified server version """
        versions = self.get_fabric_versions(minecraft_version=version)
        print(versions)
        fabric_version = versions.get("latest", {})
        if not fabric_version:
            self._logger.error(f"No fabric version found for Minecraft {version}, does it exist?")
            raise FabricVersionNotFoundError
        return FabricDownloader._assemble_download_url(version, fabric_version)