# Minecraft Server Downloader
# vanilla_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import json
import os

from utilities.exceptions import ServerDownloadError

from .downloader import Downloader


class VanillaDownloader(Downloader):
    """ Vanilla server downloader helper """

    _type: str = "vanilla"

    def __init__(self, **extra_configs: dict):
        super().__init__(**extra_configs)
        # Download the version manifest for this downloader
        self._logger.debug("Retrieving available game versions")
        json_version_url = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        self._versions_manifest_dict = json.loads(
            Downloader._make_request(json_version_url))

    def _get_file_name(self, version: str) -> str:
        return f"{version}.jar"

    def _game_versions(self) -> dict:
        # Grab each game version and it's respective manifest json
        versions = {}
        for item in self._versions_manifest_dict.get("versions", []):
            version_type = item.get("type", None)
            if version_type == "release":
                version_id = item.get("id", None)
                version_download_url = item.get("url", None)
                versions[version_id] = version_download_url
        return versions

    def get_download_url(self, version: str) -> str:
        """
        Returns the URL where to download the specified server version
        """
        manifest = json.loads(Downloader._make_request(self._game_versions()[version]))
        self._logger.debug(
            f"Retrieved info for game version {version} ({self._type})")
        manifest_server_downloads = manifest.get(
            "downloads", {}).get("server", {})
        return manifest_server_downloads.get("url", None)
