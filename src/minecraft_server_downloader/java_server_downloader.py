# Minecraft Server Downloader
# minecraft_server_downloader/java_server_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import json
import os

from utilities.exceptions import ServerDownloadError

from .server_downloader import ServerDownloader


class Java_ServerDownloader(ServerDownloader):
    """ Java server downloader helper """

    _type: str = "JAVA"

    _EARLIEST_SUPPORTED_VERSION = "1.7.2"

    def __init__(self, **extra_configs: dict):
        super().__init__(**extra_configs)
        # Download the version manifest for this downloader
        self._logger.debug("Retrieving available game versions")
        json_version_url = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        self._versions_manifest_dict = json.loads(
            ServerDownloader._make_request(json_version_url))

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

    def get_available_game_versions(self) -> list:
        """
        Returns a list of available game versions
        """
        # Call the super method to get the full list of available game versions
        versions = super().get_available_game_versions()
        # Since the list of game versions is ordered, we can get the index of the item that is the earlier supported version,
        # and slice the list to return every element after that.
        # Note that the list is in reverse order, from the latest version number to the oldest.
        unsupported_index = versions.index(
            self._EARLIEST_SUPPORTED_VERSION) + 1
        return versions[:unsupported_index]

    def _download(self, version: str, save_location: str) -> str:
        # Destination path for this version
        file_name = self._get_file_name(version)
        dest_path = os.path.join(save_location, file_name)

        # Download the respective version manifest
        manifest = json.loads(ServerDownloader._make_request(self._game_versions()[version]))
        self._logger.debug(
            f"Retrieved info for game version {version} ({self._type})")
        manifest_server_downloads = manifest.get(
            "downloads", {}).get("server", {})
        server_url = manifest_server_downloads.get("url", None)
        server_size_bytes = manifest_server_downloads.get("size", None)
        server_sha1 = manifest_server_downloads.get("sha1", None)

        # If there's a valid server url, download that file
        if server_url:
            ServerDownloader._get_file(server_url, dest_path)

            try:
                # Ensure the downloaded file exists
                if not os.path.isfile(dest_path):
                    message = f"Downloaded file not found at {dest_path}"
                    self._logger.error(message)
                    raise ServerDownloadError(message)

                # Ensure size matches
                downloaded_jar_size = ServerDownloader.get_file_size(dest_path)
                if not downloaded_jar_size == server_size_bytes:
                    message = "downloaded server jar size does not match the expected size: {downloaded_jar_size} vs. {server_size_bytes} bytes"
                    self._logger.error(message)
                    raise ServerDownloadError(message)

                # Ensure SHA1 matches
                downloaded_jar_sha1 = ServerDownloader.get_file_sha1(dest_path)
                if not downloaded_jar_sha1 == server_sha1:
                    message = "downloaded server jar does not match the expected SHA1"
                    self._logger.error(message)
                    raise ServerDownloadError(message)

                # If the download was not successful throw
            except Exception as e:
                raise ServerDownloadError(
                    f"an error occurred while downloading minecraft server version {version} ({self._type})") from e
        else:
            message = f"could not find a url to download minecraft server version {version} ({self._type})"
            self._logger.error(message)
            raise ServerDownloadError(message)

        return dest_path
