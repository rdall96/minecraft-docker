# Minecraft Server Downloader
# minecraft_server_downloader/server_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from abc import ABC, abstractmethod
import hashlib
import os
import requests
from tempfile import TemporaryDirectory

from utilities import Logger, MagicFileTools
from utilities.exceptions import ServerDownloadError

class ServerDownloader(ABC):
    """ Downloads server version of the game from Mojang

    Usage:
    # Create a server downloader
    downloader = ServerDownloader()

    # Fetch for a list of all available game versions
    downloader.get_available_game_versions()

    # Download a specific version
    file_path = downloader.download("1.15", "~/Downloads")
    """

    # Type of downloader
    _type: str = None

    # This value keeps track of the oldest version of the game that MCManager supports
    # If the value is empty, it means we support all versions
    _EARLIEST_SUPPORTED_VERSION = None

    def __init__(self, **extra_configs: dict):
        self._logger = Logger(
            self.__class__.__name__,
            extra_configs["logging"]["level"]
        )
        self._logger.debug("Initialized ServerDownloader")

    @staticmethod
    def _make_request(url) -> str:
        """
        Makes a request and returns the string content of the response
        """
        r = requests.get(url)
        return r.content.decode("utf-8")

    @staticmethod
    def _get_file(url, download_path):
        """
        Downloads a file to the given download path
        """
        r = requests.get(url, allow_redirects=True)
        with open(download_path, mode="wb") as f:
            f.write(r.content)

    @staticmethod
    def get_file_size(fp: str) -> int:
        """
        Returns the size in bytes of a given file path
        """
        return os.stat(fp).st_size

    @staticmethod
    def get_file_sha1(fp: str) -> str:
        """
        Returns the SHA-1 of a given file path
        """
        sha1sum = hashlib.sha1()
        with open(fp, mode="rb") as f:
            block = f.read(2**16)
            while len(block) != 0:
                sha1sum.update(block)
                block = f.read(2**16)
        return sha1sum.hexdigest()

    @abstractmethod
    def _get_file_name(self, version: str) -> str:
        """ Returns the file name for this version (specific to the downloader type) """
        raise NotImplementedError()

    @abstractmethod
    def _game_versions(self) -> dict:
        """ Dictionary of released game versions and url downloads """
        raise NotImplementedError()

    def get_available_game_versions(self) -> list:
        """ Returns a list of available game versions """
        return list(self._game_versions().keys())

    @abstractmethod
    def get_download_url(self, version: str) -> str:
        """ Returns the URL where to download the specified server version """
        raise NotImplementedError()

    @abstractmethod
    def _download(self, version: str, save_location: str) -> str:
        """ Downloads the single minecraft version requested and return the full file path """
        raise NotImplementedError()

    def download(self, version: str, save_location: str) -> str:
        """ Downloads the single minecraft version requested and return the full file path """

        # If the destination file already exists, return that path instead
        dest_path = os.path.join(save_location, self._get_file_name(version))
        if os.path.isfile(dest_path):
            self._logger.info(
                f"Minecraft version {version} ({self._type}) already exists at {dest_path}")
            return dest_path
        self._logger.info(
            f"Downloading Minecraft version {version} ({self._type}) at {dest_path}")

        # Don't attempt to download if the version isn't available
        if version not in self.get_available_game_versions():
            message = f"minecraft version {version} is not available for {self._type}"
            self._logger.error(message)
            raise ServerDownloadError(message)

        # Create a new temporary download path
        with TemporaryDirectory(prefix=self.__class__.__name__) as tmp_dir:
            # Call the download task
            download_fp = self._download(version, tmp_dir)
            if not os.path.isfile(download_fp):
                message = f"an error occurred while downloading minecraft server version {version} ({self._type})"
                self._logger.error(message)
                raise ServerDownloadError(message)
            MagicFileTools.copy_file(download_fp, dest_path)

        self._logger.info(
            f"Successfully downloaded Minecraft version {version} ({self._type})")
        return dest_path
